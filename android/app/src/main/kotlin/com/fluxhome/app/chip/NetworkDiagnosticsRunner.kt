package com.fluxhome.app.chip

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Runs a suite of passive network checks that help diagnose why Matter over
 * Thread commissioning fails.  No CHIP SDK required; no user interaction needed.
 *
 * Checks performed:
 *  1.  Phone IPv6          — routable IPv6 address on the active Wi-Fi interface?
 *  2.  Phone IPv4          — captured for subnet comparison with border routers
 *  3.  Wi-Fi band          — 2.4 / 5 / 6 GHz; band-specific SSID suffix detected?
 *  4.  VPN                 — is a VPN active that could tunnel local traffic?
 *  5.  Multicast lock      — can the app acquire a Wi-Fi multicast lock?
 *  6.  _meshcop._udp scan  — discover Thread Border Routers; collect ALL IPv4 and
 *                            IPv6 addresses (link-local / ULA / GUA); decode the
 *                            `sb` state bitmap
 *  7.  TCP reachability    — for each BR: open a TCP socket to the border-agent
 *                            port; "connection refused" counts as reachable
 *  8.  IPv4 subnet match   — phone and BR on the same /N network prefix?
 *  9.  IPv6 /64 match      — phone and BR ULA addresses on the same /64 segment?
 *  10. _matter._tcp scan   — any commissioned Matter nodes visible via mDNS?
 *                            (confirms the BR's mDNS proxy works end-to-end)
 *
 * Scans 6 and 10 run in parallel (both take SCAN_MS).
 * TCP probes (7) run in parallel across all BRs after the scan.
 */
object NetworkDiagnosticsRunner {

    private const val TAG          = "NetDiagRunner"
    private const val SCAN_MS      = 6_000L
    private const val TCP_TIMEOUT  = 3_000
    private const val MESHCOP_TYPE = "_meshcop._udp"
    private const val MATTER_TYPE  = "_matter._tcp"

    // ── Result types ──────────────────────────────────────────────────────────

    data class PhoneIpv6Result(
        val guaAddresses:       List<String>,
        val ulaAddresses:       List<String>,
        val linkLocalAddresses: List<String>,
    ) {
        val hasRoutableIpv6: Boolean get() = guaAddresses.isNotEmpty() || ulaAddresses.isNotEmpty()
    }

    /** Wi-Fi radio band and SSID of the phone's current connection. */
    data class WifiBandResult(
        val frequencyMhz:  Int,     // -1 if unavailable
        val band:          String,  // "2.4 GHz" | "5 GHz" | "6 GHz" | "unknown"
        val ssid:          String,  // may be "<unknown ssid>" when permission denied
        val hasBandSuffix: Boolean, // SSID ends with _5G, _5GHz, _6G, etc.
    )

    /** Whether a VPN network interface is currently active on the phone. */
    data class VpnResult(val isActive: Boolean)

    /**
     * Decoded `sb` state bitmap per Thread spec §8.10.3.3 (4-byte big-endian).
     *   bits [2:0]  Connection Mode  0=none 1=UDP 2=TCP
     *   bits [4:3]  Thread Interface Status  0=not-init 1=init 2=active
     *   bits [6:5]  Availability  0=infrequent 1=high
     *   bit  [7]    BBR active
     *   bit  [8]    BBR is primary
     */
    data class StateBitmapResult(
        val raw:                    Long,
        val connectionMode:         Int,
        val threadInterfaceStatus:  Int,
        val availability:           Int,
        val bbrActive:              Boolean,
        val bbrIsPrimary:           Boolean,
    ) {
        val threadInterfaceActive:   Boolean get() = threadInterfaceStatus == 2
        val hasExternalConnectivity: Boolean get() = connectionMode != 0
        val connectionModeLabel: String get() = when (connectionMode) {
            1    -> "UDP"; 2 -> "TCP"; else -> "none"
        }
        val threadInterfaceLabel: String get() = when (threadInterfaceStatus) {
            1    -> "Initialised (not attached)"
            2    -> "Active (attached)"
            else -> "Not initialised"
        }
    }

    data class BorderRouterDiagnostic(
        val serviceName:          String,
        val networkName:          String,
        val extPanId:             String,
        val vendorName:           String,
        val modelName:            String,
        val port:                 Int,
        val hostsV4:              List<String>,
        val hostsV6LinkLocal:     List<String>,
        val hostsV6Ula:           List<String>,
        val hostsV6Gua:           List<String>,
        val stateBitmap:          StateBitmapResult?,
        // Populated after the mDNS scan via parallel probes
        val tcpReachable:         Boolean? = null,  // null = not probed (no address)
        val sameSubnetAsPhone:    Boolean? = null,  // null = IPv4 unavailable
        val ipv6PrefixMatchesPhone: Boolean? = null, // null = no ULA on phone or BR
    ) {
        val hasIpv4:         Boolean get() = hostsV4.isNotEmpty()
        val hasRoutableIpv6: Boolean get() = hostsV6Ula.isNotEmpty() || hostsV6Gua.isNotEmpty()
        val hasAnyIpv6:      Boolean get() = hostsV6LinkLocal.isNotEmpty() || hasRoutableIpv6
    }

    data class DiagnosticsReport(
        val phoneIpv6:             PhoneIpv6Result,
        val multicastLockAcquired: Boolean,
        val wifi:                  WifiBandResult,
        val vpn:                   VpnResult,
        val borderRouters:         List<BorderRouterDiagnostic>,
        val matterTcpServices:     List<String>,
    )

    // ── Entry point ───────────────────────────────────────────────────────────

    suspend fun run(context: Context): DiagnosticsReport {
        // Synchronous checks — no I/O
        val phoneIpv6 = checkPhoneIpv6(context)
        val phoneIpv4 = checkPhoneIpv4(context)   // (address, prefixLen) or null
        val wifiBand  = checkWifiBand(context)
        val vpn       = checkVpn(context)

        val nsd     = context.getSystemService(Context.NSD_SERVICE) as NsdManager
        val wifiMgr = context.applicationContext
                         .getSystemService(Context.WIFI_SERVICE) as WifiManager
        val lock    = wifiMgr.createMulticastLock("net_diag").also {
            it.setReferenceCounted(false)
        }
        val lockAcquired = try { lock.acquire(); true }
                           catch (e: Exception) {
                               Log.w(TAG, "Multicast lock failed: ${e.message}")
                               false
                           }

        // Parallel mDNS scans (6 s each)
        val (rawBrs, matterServices) = coroutineScope {
            val brDef  = async { scanMeshcop(nsd) }
            val matDef = async { scanMatterTcp(nsd) }
            Pair(brDef.await(), matDef.await())
        }

        try { lock.release() } catch (_: Exception) {}

        // Parallel TCP probes + subnet checks across all border routers
        val borderRouters = coroutineScope {
            rawBrs.map { br ->
                async {
                    val probeHost = br.hostsV4.firstOrNull()
                        ?: br.hostsV6Ula.firstOrNull()
                        ?: br.hostsV6Gua.firstOrNull()

                    val tcpReachable = if (probeHost != null && br.port > 0)
                        probeTcp(probeHost, br.port) else null

                    val sameSubnet = if (phoneIpv4 != null && br.hostsV4.isNotEmpty())
                        checkSameSubnet(phoneIpv4.first, phoneIpv4.second, br.hostsV4.first())
                    else null

                    val ipv6Match = checkIpv6PrefixMatch(
                        phoneIpv6.ulaAddresses + phoneIpv6.guaAddresses,
                        br.hostsV6Ula + br.hostsV6Gua,
                    )

                    Log.i(TAG, "BR ${br.networkName}: tcp=$tcpReachable " +
                        "subnet=$sameSubnet ipv6prefix=$ipv6Match")

                    br.copy(
                        tcpReachable          = tcpReachable,
                        sameSubnetAsPhone     = sameSubnet,
                        ipv6PrefixMatchesPhone = ipv6Match,
                    )
                }
            }.map { it.await() }
        }

        Log.i(TAG, "Diagnostics complete — ${borderRouters.size} BR(s), " +
            "${matterServices.size} _matter._tcp, " +
            "band=${wifiBand.band} vpn=${vpn.isActive}")

        return DiagnosticsReport(
            phoneIpv6             = phoneIpv6,
            multicastLockAcquired = lockAcquired,
            wifi                  = wifiBand,
            vpn                   = vpn,
            borderRouters         = borderRouters,
            matterTcpServices     = matterServices,
        )
    }

    // ── Check 1: phone IPv6 ───────────────────────────────────────────────────

    private fun checkPhoneIpv6(context: Context): PhoneIpv6Result {
        val cm    = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val props = cm.activeNetwork?.let { cm.getLinkProperties(it) }

        val gua = mutableListOf<String>()
        val ula = mutableListOf<String>()
        val ll  = mutableListOf<String>()

        props?.linkAddresses?.forEach { la ->
            val addr = la.address
            if (addr is Inet6Address) {
                val clean = (addr.hostAddress ?: return@forEach).substringBefore('%')
                when {
                    addr.isLinkLocalAddress  -> ll.add(clean)
                    isUla(addr.address)      -> ula.add(clean)
                    isGua(addr.address)      -> gua.add(clean)
                }
            }
        }
        return PhoneIpv6Result(gua, ula, ll)
    }

    // ── Check 2: phone IPv4 (for subnet comparison) ───────────────────────────

    /** Returns (addressString, prefixLength) or null if unavailable. */
    private fun checkPhoneIpv4(context: Context): Pair<String, Int>? {
        val cm    = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val props = cm.activeNetwork?.let { cm.getLinkProperties(it) } ?: return null
        val la    = props.linkAddresses.firstOrNull { it.address is Inet4Address } ?: return null
        return Pair(la.address.hostAddress ?: return null, la.prefixLength)
    }

    // ── Check 3: Wi-Fi band and SSID ─────────────────────────────────────────

    @Suppress("DEPRECATION")
    private fun checkWifiBand(context: Context): WifiBandResult {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val wifiInfo: WifiInfo? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val caps = cm.activeNetwork?.let { cm.getNetworkCapabilities(it) }
            caps?.transportInfo as? WifiInfo
        } else {
            val wm = context.applicationContext
                         .getSystemService(Context.WIFI_SERVICE) as WifiManager
            wm.connectionInfo
        }

        val freq = wifiInfo?.frequency ?: -1
        // Android wraps SSIDs in double-quotes; strip them
        val ssid = wifiInfo?.ssid?.removePrefix("\"")?.removeSuffix("\"") ?: ""

        val band = when (freq) {
            in 2412..2484 -> "2.4 GHz"
            in 5180..5825 -> "5 GHz"
            in 5955..7115 -> "6 GHz"
            else           -> "unknown"
        }

        val hasBandSuffix = ssid.isNotEmpty() && ssid != "<unknown ssid>" &&
            listOf("_5g", "_5ghz", "-5g", "-5ghz", " 5g", "_6g", "_6ghz", "-6g", " 6g")
                .any { ssid.lowercase().endsWith(it) }

        return WifiBandResult(freq, band, ssid, hasBandSuffix)
    }

    // ── Check 4: VPN detection ────────────────────────────────────────────────

    private fun checkVpn(context: Context): VpnResult {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val isActive = cm.allNetworks.any { network ->
            cm.getNetworkCapabilities(network)
                ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        }
        return VpnResult(isActive)
    }

    // ── Check 6: _meshcop._udp scan ───────────────────────────────────────────

    private suspend fun scanMeshcop(nsd: NsdManager): List<BorderRouterDiagnostic> {
        val found         = ConcurrentHashMap<String, BorderRouterDiagnostic>()
        val queue         = LinkedBlockingQueue<NsdServiceInfo>()
        val resolveActive = AtomicBoolean(false)

        fun ByteArray.hex()         = joinToString("") { "%02x".format(it) }
        fun ByteArray.str()         = try { toString(Charsets.UTF_8) } catch (_: Exception) { hex() }
        fun ByteArray.isPrintable() = all { it in 0x20..0x7E }

        fun resolveNext() {
            val svc = queue.poll() ?: run { resolveActive.set(false); return }
            @Suppress("DEPRECATION")
            nsd.resolveService(svc, object : NsdManager.ResolveListener {
                override fun onResolveFailed(s: NsdServiceInfo?, err: Int) {
                    Log.w(TAG, "meshcop resolve failed err=$err for ${s?.serviceName}")
                    resolveNext()
                }
                override fun onServiceResolved(info: NsdServiceInfo) {
                    val a    = info.attributes
                    val nn   = a["nn"]?.str()?.ifEmpty { info.serviceName } ?: info.serviceName
                    val xp   = a["xp"]?.hex() ?: ""
                    val vn   = a["vn"]?.str() ?: ""
                    val mn   = a["mn"]?.str() ?: ""
                    val txtSb = a["sb"]?.hex()

                    val hostsV4   = mutableListOf<String>()
                    val hostsV6ll = mutableListOf<String>()
                    val hostsV6u  = mutableListOf<String>()
                    val hostsV6g  = mutableListOf<String>()

                    for (addr in getAllAddresses(info)) {
                        val clean = (addr.hostAddress ?: continue).substringBefore('%')
                        when {
                            addr is Inet4Address                        -> hostsV4.add(clean)
                            addr is Inet6Address && addr.isLinkLocalAddress -> hostsV6ll.add(clean)
                            addr is Inet6Address && isUla(addr.address) -> hostsV6u.add(clean)
                            addr is Inet6Address && isGua(addr.address) -> hostsV6g.add(clean)
                        }
                    }

                    Log.d(TAG, "BR resolved: nn=$nn port=${info.port} " +
                        "v4=$hostsV4 v6ula=$hostsV6u v6gua=$hostsV6g")

                    found[info.serviceName] = BorderRouterDiagnostic(
                        serviceName      = info.serviceName,
                        networkName      = nn,
                        extPanId         = xp,
                        vendorName       = vn,
                        modelName        = mn,
                        port             = info.port,
                        hostsV4          = hostsV4,
                        hostsV6LinkLocal = hostsV6ll,
                        hostsV6Ula       = hostsV6u,
                        hostsV6Gua       = hostsV6g,
                        stateBitmap      = parseSb(txtSb),
                    )
                    resolveNext()
                }
            })
        }

        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(t: String)             { Log.d(TAG, "meshcop started") }
            override fun onDiscoveryStopped(t: String)             { Log.d(TAG, "meshcop stopped") }
            override fun onStartDiscoveryFailed(t: String, e: Int) { Log.w(TAG, "meshcop start failed e=$e") }
            override fun onStopDiscoveryFailed(t: String, e: Int)  { }
            override fun onServiceLost(s: NsdServiceInfo)          { }
            override fun onServiceFound(s: NsdServiceInfo) {
                queue.put(s)
                if (resolveActive.compareAndSet(false, true)) resolveNext()
            }
        }

        nsd.discoverServices(MESHCOP_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
        delay(SCAN_MS)
        try { nsd.stopServiceDiscovery(listener) } catch (e: Exception) {
            Log.w(TAG, "stopDiscovery meshcop: ${e.message}")
        }
        return found.values.sortedBy { it.networkName }
    }

    // ── Check 10: _matter._tcp scan ───────────────────────────────────────────

    private suspend fun scanMatterTcp(nsd: NsdManager): List<String> {
        val found = ConcurrentHashMap.newKeySet<String>()
        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(t: String)             { Log.d(TAG, "_matter._tcp started") }
            override fun onDiscoveryStopped(t: String)             { Log.d(TAG, "_matter._tcp stopped") }
            override fun onStartDiscoveryFailed(t: String, e: Int) { Log.w(TAG, "_matter._tcp start failed e=$e") }
            override fun onStopDiscoveryFailed(t: String, e: Int)  { }
            override fun onServiceLost(s: NsdServiceInfo)          { }
            override fun onServiceFound(s: NsdServiceInfo) { found.add(s.serviceName) }
        }
        nsd.discoverServices(MATTER_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
        delay(SCAN_MS)
        try { nsd.stopServiceDiscovery(listener) } catch (e: Exception) {
            Log.w(TAG, "stopDiscovery _matter._tcp: ${e.message}")
        }
        return found.toList().sorted()
    }

    // ── Check 7: TCP reachability probe ───────────────────────────────────────

    /**
     * Tries to open a TCP connection to [host]:[port].
     * Returns true if the device is reachable at the IP layer (connected OR
     * connection-refused both count — both require IP-layer delivery).
     * Returns false on timeout or network error (not reachable).
     */
    private fun probeTcp(host: String, port: Int): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress(InetAddress.getByName(host), port), TCP_TIMEOUT)
                true
            }
        } catch (e: java.net.ConnectException) {
            true   // RST received → IP layer works, port just not open
        } catch (_: Exception) {
            false  // SocketTimeoutException or anything else → not reachable
        }
    }

    // ── Check 8: IPv4 subnet match ────────────────────────────────────────────

    private fun checkSameSubnet(phoneIp: String, phonePrefixLen: Int, brIp: String): Boolean? {
        return try {
            val phoneAddr = InetAddress.getByName(phoneIp) as? Inet4Address ?: return null
            val brAddr    = InetAddress.getByName(brIp)   as? Inet4Address ?: return null
            val bits      = phonePrefixLen.coerceIn(0, 32)
            val mask      = if (bits == 0) 0 else (0xFFFFFFFFL shl (32 - bits)).toInt()
            fun Inet4Address.asInt(): Int {
                val b = address
                return ((b[0].toInt() and 0xFF) shl 24) or ((b[1].toInt() and 0xFF) shl 16) or
                       ((b[2].toInt() and 0xFF) shl 8)  or  (b[3].toInt() and 0xFF)
            }
            (phoneAddr.asInt() and mask) == (brAddr.asInt() and mask)
        } catch (_: Exception) { null }
    }

    // ── Check 9: IPv6 /64 prefix match ───────────────────────────────────────

    private fun checkIpv6PrefixMatch(phoneAddrs: List<String>, brAddrs: List<String>): Boolean? {
        if (phoneAddrs.isEmpty() || brAddrs.isEmpty()) return null
        return try {
            val pBytes = (InetAddress.getByName(phoneAddrs.first()) as? Inet6Address)
                             ?.address ?: return null
            val bBytes = (InetAddress.getByName(brAddrs.first())   as? Inet6Address)
                             ?.address ?: return null
            pBytes.slice(0..7) == bBytes.slice(0..7)   // compare first 8 bytes = /64
        } catch (_: Exception) { null }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    @Suppress("UNCHECKED_CAST", "DEPRECATION")
    private fun getAllAddresses(info: NsdServiceInfo): List<InetAddress> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return try {
                val m = NsdServiceInfo::class.java.getMethod("getHostAddresses")
                (m.invoke(info) as? List<InetAddress>) ?: listOfNotNull(info.host)
            } catch (e: Exception) {
                Log.w(TAG, "getHostAddresses: ${e.message}")
                listOfNotNull(info.host)
            }
        }
        return listOfNotNull(info.host)
    }

    private fun parseSb(sbHex: String?): StateBitmapResult? {
        sbHex ?: return null
        val raw = try { sbHex.toLong(16) } catch (_: Exception) { return null }
        val result = StateBitmapResult(
            raw                   = raw,
            connectionMode        = (raw and 0x7L).toInt(),
            threadInterfaceStatus = ((raw shr 3) and 0x3L).toInt(),
            availability          = ((raw shr 5) and 0x3L).toInt(),
            bbrActive             = ((raw shr 7) and 1L) == 1L,
            bbrIsPrimary          = ((raw shr 8) and 1L) == 1L,
        )
        Log.i(TAG, "sb hex=$sbHex cm=${result.connectionMode}(${result.connectionModeLabel}) " +
            "threadIf=${result.threadInterfaceStatus}(${result.threadInterfaceLabel})")
        return result
    }

    private fun isUla(bytes: ByteArray): Boolean =
        bytes.isNotEmpty() && (bytes[0].toInt() and 0xFE) == 0xFC

    private fun isGua(bytes: ByteArray): Boolean =
        bytes.isNotEmpty() && (bytes[0].toInt() and 0xE0) == 0x20
}
