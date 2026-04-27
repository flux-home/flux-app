package com.fluxhome.app.chip

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.util.Log
import kotlinx.coroutines.delay
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Scans the local network for commissionable Matter devices via DNS-SD
 * (_matterc._udp) using Android's NsdManager — the same API used by
 * third-party DNS-SD browser apps.
 *
 * Relevant _matterc._udp TXT keys (Matter Core spec §4.3.1):
 *   D  — discriminator (decimal)
 *   VP — VID+PID, e.g. "4107+5678"
 *   DT — device type (decimal)
 *   DN — device name
 *   CM — commissioning mode: 1=Basic, 2=Enhanced
 *   RI — rotating device ID
 *   PH — pairing hint bitmask
 *   PI — pairing instruction
 */
object MatterCommissionableScanner {

    private const val TAG          = "MatterCommScanner"
    private const val SERVICE_TYPE = "_matterc._udp"
    private const val SCAN_MS      = 6_000L

    data class CommissionableInfo(
        val instanceName:      String,
        val ipAddress:         String,
        val port:              Int,
        val discriminator:     Long,
        val vendorId:          Int,
        val productId:         Int,
        val deviceType:        Long,
        val deviceName:        String,
        /** "EnhancedWindowOpen", "BasicWindowOpen", or "WindowNotOpen" */
        val commissioningMode: String,
        /** PH TXT key — pairing hint bitmask (0 if absent). */
        val pairingHint:       Int,
        /** True when the ICD TXT key is present and equals "1". */
        val isIcd:             Boolean,
    )

    suspend fun scan(context: Context): List<CommissionableInfo> {
        val nsd  = context.getSystemService(Context.NSD_SERVICE) as NsdManager
        val wifi = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as WifiManager

        // Acquire a multicast lock so Android delivers mDNS multicast to us.
        val lock = wifi.createMulticastLock("matter_comm_scan").also {
            it.setReferenceCounted(false)
            it.acquire()
        }

        val found         = ConcurrentHashMap<String, CommissionableInfo>()
        val queue         = LinkedBlockingQueue<NsdServiceInfo>()
        val resolveActive = AtomicBoolean(false)

        fun ByteArray.str() = try { toString(Charsets.UTF_8) } catch (_: Exception) { "" }

        fun resolveNext() {
            val svc = queue.poll() ?: run { resolveActive.set(false); return }
            nsd.resolveService(svc, object : NsdManager.ResolveListener {
                override fun onResolveFailed(s: NsdServiceInfo?, err: Int) {
                    Log.w(TAG, "Resolve failed err=$err for ${s?.serviceName}")
                    resolveNext()
                }
                override fun onServiceResolved(info: NsdServiceInfo) {
                    val a    = info.attributes ?: emptyMap()
                    fun txt(key: String) = a[key]?.str()?.ifBlank { null }
                        ?: a[key.lowercase()]?.str()?.ifBlank { null }

                    // Discriminator: key "D"
                    val disc = txt("D")?.toLongOrNull() ?: 0L

                    // VID+PID: key "VP", format "VVVV+PPPP"
                    val vp      = txt("VP")?.split("+") ?: emptyList()
                    val vid     = vp.getOrNull(0)?.trim()?.toIntOrNull() ?: 0
                    val pid     = vp.getOrNull(1)?.trim()?.toIntOrNull() ?: 0

                    // Device type: key "DT"
                    val dt      = txt("DT")?.toLongOrNull() ?: 0L

                    // Device name: key "DN"
                    val dn      = txt("DN") ?: ""

                    // Commissioning mode: key "CM" — 1=Basic, 2=Enhanced
                    val cm      = txt("CM")?.toIntOrNull() ?: 0
                    val mode    = when (cm) {
                        2 -> "EnhancedWindowOpen"
                        1 -> "BasicWindowOpen"
                        else -> "WindowNotOpen"
                    }

                    // Pairing hint: key "PH"
                    val ph   = txt("PH")?.toIntOrNull() ?: 0

                    // ICD (sleepy device): key "ICD"
                    val icd  = txt("ICD") == "1"

                    val host = info.host?.hostAddress ?: ""
                    Log.d(TAG, "✓ Resolved: instance=${info.serviceName} " +
                            "host=$host port=${info.port} disc=$disc VP=$vid+$pid " +
                            "DT=$dt DN=$dn CM=$cm")

                    found[info.serviceName] = CommissionableInfo(
                        instanceName      = info.serviceName,
                        ipAddress         = host,
                        port              = info.port,
                        discriminator     = disc,
                        vendorId          = vid,
                        productId         = pid,
                        deviceType        = dt,
                        deviceName        = dn,
                        commissioningMode = mode,
                        pairingHint       = ph,
                        isIcd             = icd,
                    )
                    resolveNext()
                }
            })
        }

        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(t: String)             { Log.d(TAG, "Discovery started: $t") }
            override fun onDiscoveryStopped(t: String)             { Log.d(TAG, "Discovery stopped: $t") }
            override fun onStartDiscoveryFailed(t: String, e: Int) { Log.w(TAG, "Start failed: $t err=$e") }
            override fun onStopDiscoveryFailed(t: String, e: Int)  { Log.w(TAG, "Stop failed: $t err=$e") }
            override fun onServiceLost(s: NsdServiceInfo)          { Log.d(TAG, "Lost: ${s.serviceName}") }
            override fun onServiceFound(s: NsdServiceInfo) {
                Log.d(TAG, "Found: ${s.serviceName}")
                queue.put(s)
                if (resolveActive.compareAndSet(false, true)) resolveNext()
            }
        }

        nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
        delay(SCAN_MS)
        try { nsd.stopServiceDiscovery(listener) } catch (e: Exception) {
            Log.w(TAG, "stopDiscovery: ${e.message}")
        }
        lock.release()

        Log.i(TAG, "Scan complete — ${found.size} commissionable device(s)")
        return found.values.sortedBy { it.instanceName }
    }
}
