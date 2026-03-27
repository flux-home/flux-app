package com.example.matter_home

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.matter_home.chip.ChipClient
import com.example.matter_home.chip.ClusterClient
import com.example.matter_home.chip.OtaManager
import com.example.matter_home.chip.MatterCommissioner
import com.example.matter_home.chip.NetworkDiagnosticsRunner
import com.example.matter_home.chip.SetupPayloadHelper
import com.example.matter_home.chip.AndroidThreadCredentialReader
import com.example.matter_home.chip.ThreadBorderRouterScanner
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume

class MatterBridge(private val context: Context) {

    private val main  = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // ── EventChannel sinks ────────────────────────────────────────────────────
    @Volatile private var commissionEventSink: EventChannel.EventSink? = null
    @Volatile private var deviceStateSink:     EventChannel.EventSink? = null

    fun setEventSink(sink: EventChannel.EventSink?)       { commissionEventSink = sink }
    fun setDeviceStateSink(sink: EventChannel.EventSink?) { deviceStateSink = sink }

    fun emitEvent(msg: String) {
        main.post { commissionEventSink?.success(msg) }
    }

    private fun emitDeviceState(payload: Map<String, Any?>) {
        main.post { deviceStateSink?.success(payload) }
    }

    // ── Subscription management ───────────────────────────────────────────────
    /** Node IDs for which we should suppress further events (stopped/removed). */
    private val cancelledNodeIds = mutableSetOf<Long>()

    // ── Guard: require real CHIP SDK ──────────────────────────────────────────
    private fun requireChip(result: MethodChannel.Result, block: suspend () -> Unit) {
        if (!ChipClient.isAvailable) {
            result.error(
                "CHIP_SDK_UNAVAILABLE",
                "The CHIP SDK is not loaded. Place CHIPController.aar in android/app/libs/ and rebuild.",
                null,
            )
            return
        }
        scope.launch {
            try { block() } catch (e: Exception) {
                Log.e(TAG, "CHIP call failed", e)
                main.post { result.error("CHIP_ERROR", e.message, null) }
            }
        }
    }

    // ── Subscription start / stop ─────────────────────────────────────────────

    fun startSubscription(nodeId: Long, result: MethodChannel.Result) = requireChip(result) {
        startSubscriptionForNode(nodeId)
        main.post { result.success(true) }
    }

    private fun startSubscriptionForNode(nodeId: Long) {
        cancelledNodeIds.remove(nodeId)
        ClusterClient.subscribeDeviceState(
            context = context,
            nodeId  = nodeId,
            onUpdate = { nid, attrs ->
                if (nid !in cancelledNodeIds) {
                    val payload = mutableMapOf<String, Any?>(
                        "nodeId" to nid.toInt(),
                        "type"   to "update",
                    )
                    payload.putAll(attrs)
                    emitDeviceState(payload)
                }
            },
            onEstablished = { nid ->
                if (nid !in cancelledNodeIds)
                    emitDeviceState(mapOf("nodeId" to nid.toInt(), "type" to "established"))
            },
            onResubscribing = { nid, nextMs ->
                if (nid !in cancelledNodeIds) {
                    emitDeviceState(mapOf("nodeId" to nid.toInt(), "type" to "resubscribing",
                                         "nextMs" to nextMs))
                    // SDK exponential backoff can grow to minutes — if it exceeds 30 s,
                    // the UDP socket is likely permanently broken.  Restart cleanly.
                    if (nextMs > 30_000L) {
                        Log.w(TAG, "Resubscription backoff too large (${nextMs}ms) for " +
                                   "nodeId=$nid — forcing restart")
                        scope.launch {
                            delay(2_000L)   // brief pause before restarting
                            if (nid !in cancelledNodeIds) {
                                startSubscriptionForNode(nid)
                            }
                        }
                    }
                }
            },
            onError = { nid, err ->
                if (nid !in cancelledNodeIds)
                    emitDeviceState(mapOf("nodeId" to nid.toInt(), "type" to "error",
                                         "message" to (err.message ?: "unknown")))
            },
        )
    }

    fun stopSubscription(nodeId: Long, result: MethodChannel.Result) {
        cancelledNodeIds.add(nodeId)
        result.success(true)
    }

    // ── ping ──────────────────────────────────────────────────────────────────

    fun ping(result: MethodChannel.Result) = result.success(true)

    // ── Commission via BLE ────────────────────────────────────────────────────

    fun commissionDevice(
        payload: String,
        wifiSsid: String?,
        wifiPassword: String?,
        threadDatasetHex: String?,
        nodeId: Long,
        result: MethodChannel.Result,
    ) = requireChip(result) {
        val parsed = SetupPayloadHelper.parse(payload)
        val threadDataset = threadDatasetHex
            ?.filter { it.isLetterOrDigit() }
            ?.chunked(2)
            ?.map { it.toInt(16).toByte() }
            ?.toByteArray()
        val commissionedNodeId = MatterCommissioner.commission(
            context          = context,
            payload          = parsed,
            wifiSsid         = wifiSsid,
            wifiPassword     = wifiPassword,
            threadDatasetTlv = threadDataset,
            nodeId           = nodeId,
            onEvent          = { msg -> Log.i(TAG, msg); emitEvent(msg) },
        )
        val deviceTypeId = readPrimaryDeviceType(commissionedNodeId)
        main.post {
            result.success(mapOf("nodeId" to commissionedNodeId.toInt(), "deviceTypeId" to deviceTypeId))
        }
    }

    // ── Commission via IP ─────────────────────────────────────────────────────

    fun commissionViaIp(
        ipAddress: String,
        port: Int,
        discriminator: Int,
        setupPinCode: Long,
        nodeId: Long,
        result: MethodChannel.Result,
    ) = requireChip(result) {
        val commissionedNodeId = MatterCommissioner.commissionViaIp(
            context       = context,
            ipAddress     = ipAddress,
            port          = port,
            discriminator = discriminator,
            setupPinCode  = setupPinCode,
            nodeId        = nodeId,
            onEvent       = { msg -> Log.i(TAG, msg); emitEvent(msg) },
        )
        val deviceTypeId = readPrimaryDeviceType(commissionedNodeId)
        main.post {
            result.success(mapOf("nodeId" to commissionedNodeId.toInt(), "deviceTypeId" to deviceTypeId))
        }
    }

    // ── On/Off ────────────────────────────────────────────────────────────────

    fun toggleDevice(nodeId: Long, on: Boolean, result: MethodChannel.Result) =
        requireChip(result) {
            ClusterClient.setOnOff(context, nodeId, on)
            main.post { result.success(true) }
        }

    // ── Level control ─────────────────────────────────────────────────────────

    fun setLevel(nodeId: Long, level: Int, result: MethodChannel.Result) =
        requireChip(result) {
            ClusterClient.moveToLevel(context, nodeId, level)
            main.post { result.success(true) }
        }

    // ── Read device state ─────────────────────────────────────────────────────

    fun readDeviceState(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            try {
                val on = ClusterClient.readOnOff(context, nodeId)
                main.post {
                    result.success(mapOf("isOnline" to true, "isOn" to on, "brightness" to 254))
                }
            } catch (e: Exception) {
                Log.w(TAG, "readDeviceState offline? nodeId=$nodeId: ${e.message}")
                main.post { result.success(mapOf("isOnline" to false)) }
            }
        }

    // ── Multi-admin / share ───────────────────────────────────────────────────

    fun openCommissioningWindow(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            // TODO: AdministratorCommissioning cluster openCommissioningWindow
            main.post { result.success(true) }
        }

    // ── Remove ───────────────────────────────────────────────────────────────

    fun removeDevice(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            ChipClient.getController().unpairDevice(nodeId)
            main.post { result.success(true) }
        }

    // ── Wi-Fi network scan ────────────────────────────────────────────────────

    /**
     * Triggers a fresh Wi-Fi scan and returns only networks that respond within
     * [WIFI_SCAN_TIMEOUT_MS].  Falls back to the last cached results if the scan
     * is throttled or times out.
     *
     * Each entry is a map with:
     *   - ssid        (String)  — network name
     *   - rssi        (Int)     — signal in dBm (only networks ≥ [WIFI_MIN_RSSI])
     *   - isConnected (Boolean) — true for the currently associated network
     */
    fun scanWifiNetworks(result: MethodChannel.Result) {
        scope.launch {
            val networks = doWifiScan()
            main.post { result.success(networks) }
        }
    }

    private suspend fun doWifiScan(): List<Map<String, Any?>> {
        val wifiManager =
            context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

        // ── Trigger a fresh scan, wait for the broadcast ──────────────────────
        val scanCompleted = suspendCancellableCoroutine { cont ->
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context, intent: Intent) {
                    try { ctx.unregisterReceiver(this) } catch (_: Exception) {}
                    if (cont.isActive) cont.resume(Unit)
                }
            }
            try {
                context.registerReceiver(
                    receiver,
                    IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION),
                )
                @Suppress("DEPRECATION")
                val started = wifiManager.startScan()
                if (!started) {
                    // Throttled by Android — unregister and fall through to cache
                    try { context.unregisterReceiver(receiver) } catch (_: Exception) {}
                    Log.d(TAG, "Wi-Fi startScan throttled — using cached results")
                    if (cont.isActive) cont.resume(Unit)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Wi-Fi scan setup failed: ${e.message}")
                if (cont.isActive) cont.resume(Unit)
            }
            // Timeout: unregister and proceed with whatever is in cache
            cont.invokeOnCancellation {
                try { context.unregisterReceiver(receiver) } catch (_: Exception) {}
            }
        }

        // Allow the OS a brief moment to populate results after the broadcast
        delay(WIFI_SCAN_TIMEOUT_MS)
        return buildWifiResults(wifiManager)
    }

    private fun buildWifiResults(wifiManager: WifiManager): List<Map<String, Any?>> {
        val currentSsid = wifiManager.connectionInfo?.ssid
            ?.removeSurrounding("\"")
            ?.takeIf { it.isNotEmpty() && it != "<unknown ssid>" }

        val seen     = mutableSetOf<String>()
        val networks = mutableListOf<Map<String, Any?>>()

        // Connected network always first regardless of RSSI
        if (!currentSsid.isNullOrEmpty()) {
            seen.add(currentSsid)
            networks.add(mapOf(
                "ssid"        to currentSsid,
                "rssi"        to wifiManager.connectionInfo.rssi,
                "isConnected" to true,
            ))
        }

        wifiManager.scanResults
            .filter { sr ->
                sr.SSID.isNotEmpty()         // ignore unnamed (hidden) networks
                && sr.level >= WIFI_MIN_RSSI // only networks with usable signal
            }
            .groupBy { it.SSID }             // one entry per SSID
            .mapValues { (_, aps) -> aps.maxBy { it.level } } // keep strongest AP
            .values
            .sortedByDescending { it.level }
            .filter { it.SSID !in seen }     // drop already-listed connected network
            .forEach { sr ->
                seen.add(sr.SSID)
                networks.add(mapOf(
                    "ssid"        to sr.SSID,
                    "rssi"        to sr.level,
                    "isConnected" to false,
                ))
            }

        return networks
    }

    // ── OTA update ────────────────────────────────────────────────────────────

    private val otaManager        = OtaManager()
    @Volatile private var queryWatchdogJob: Job? = null

    /**
     * Downloads the OTA image from [otaUrl] to the app cache directory, then
     * registers this controller as an OTA Provider on the fabric and sends
     * AnnounceOTAProvider to [nodeId].
     *
     * Progress is emitted on the device-state event channel as maps with:
     *   type     = "otaProgress"
     *   nodeId   = Int
     *   phase    = "download" | "querying" | "installing" | "applying" | "complete" | "error"
     *   progress = Int (0-100, omitted for non-progress phases)
     *   message  = String (error description, omitted otherwise)
     */
    fun downloadAndFlash(
        nodeId:              Long,
        otaUrl:              String,
        targetVersion:       Long,
        targetVersionString: String,
        dryRun:              Boolean,
        otaEndpoint:         Int,
        result:              MethodChannel.Result,
    ) = requireChip(result) {

        // ── Teardown any previous attempt ─────────────────────────────────────
        queryWatchdogJob?.cancel()
        queryWatchdogJob = null
        try { ChipClient.getController().finishOTAProvider() } catch (_: Exception) {}
        otaManager.reset()

        val destPath = "${context.cacheDir.absolutePath}/ota_${nodeId}.bin"

        // ── Download ──────────────────────────────────────────────────────────
        emitOtaProgress(nodeId, "download", 0, null)
        try {
            downloadOtaFile(otaUrl, destPath) { pct ->
                emitOtaProgress(nodeId, "download", pct, null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "OTA download failed: ${e.message}")
            emitOtaProgress(nodeId, "error", null, "Download failed: ${e.message}")
            main.post { result.error("OTA_DOWNLOAD_ERROR", e.message, null) }
            cleanupOtaFile(destPath)
            return@requireChip
        }

        // ── Configure OTA manager callbacks ───────────────────────────────────
        otaManager.configure(destPath, targetVersion, targetVersionString, dryRun)

        otaManager.onBdxProgress = { nid, pct ->
            queryWatchdogJob?.cancel()   // BDX started — watchdog no longer needed
            emitOtaProgress(nid, "installing", pct, null)
        }
        otaManager.onApplyUpdate = { nid ->
            if (dryRun) {
                emitOtaProgress(nid, "dryrun", null, null)
                ChipClient.getController().finishOTAProvider()
                otaManager.reset()
                cleanupOtaFile(destPath)
            } else {
                emitOtaProgress(nid, "applying", null, null)
            }
        }
        otaManager.onUpdateApplied = { nid ->
            queryWatchdogJob?.cancel()
            emitOtaProgress(nid, "complete", 100, null)
            ChipClient.getController().finishOTAProvider()
            otaManager.reset()
            cleanupOtaFile(destPath)
        }
        otaManager.onTransferComplete = { nid, success ->
            queryWatchdogJob?.cancel()
            if (!success) {
                emitOtaProgress(nid, "error", null, "BDX transfer failed")
                ChipClient.getController().finishOTAProvider()
                otaManager.reset()
                cleanupOtaFile(destPath)
            }
        }

        // ── Start OTA provider & announce ─────────────────────────────────────
        ChipClient.getController().startOTAProvider(otaManager)
        val providerNodeId = ChipClient.getController().getControllerNodeId()

        try {
            ClusterClient.announceOtaProvider(context, nodeId, providerNodeId, ChipClient.VENDOR_ID, otaEndpoint)
            emitOtaProgress(nodeId, "querying", null, null)
        } catch (e: Exception) {
            // AnnounceOTAProvider is optional — some devices don't support it
            // (returns UNSUPPORTED_COMMAND).  Try writing DefaultOTAProviders
            // so the device's background polling picks up our provider instead.
            Log.w(TAG, "AnnounceOTAProvider failed (${e.message}), trying DefaultOTAProviders")
            try {
                ClusterClient.writeDefaultOtaProviders(context, nodeId, providerNodeId)
                emitOtaProgress(nodeId, "querying", null, null)
            } catch (e2: Exception) {
                Log.e(TAG, "DefaultOTAProviders write also failed: ${e2.message}")
                ChipClient.getController().finishOTAProvider()
                otaManager.reset()
                cleanupOtaFile(destPath)
                emitOtaProgress(nodeId, "error", null,
                    "Could not reach OTA Requestor: ${e2.message}")
            }
        }

        // Watchdog: if the device hasn't started a BDX session within 90 s,
        // clean up and report a timeout rather than hanging indefinitely.
        queryWatchdogJob = scope.launch {
            delay(90_000L)
            Log.w(TAG, "OTA query watchdog expired for nodeId=$nodeId")
            ChipClient.getController().finishOTAProvider()
            otaManager.reset()
            cleanupOtaFile(destPath)
            emitOtaProgress(nodeId, "error", null,
                "Device did not initiate an OTA session within 90 s")
        }

        main.post { result.success(true) }
    }

    fun cancelOta(result: MethodChannel.Result) = requireChip(result) {
        queryWatchdogJob?.cancel()
        queryWatchdogJob = null
        // Graceful cancel: mark NotAvailable so the device gets a clean
        // "no update" response rather than a network error — this lets it
        // reset its backoff state immediately so a new attempt works right away.
        otaManager.markNotAvailable()
        delay(3_000L)   // give the device a moment to query and get NotAvailable
        ChipClient.getController().finishOTAProvider()
        otaManager.reset()
        main.post { result.success(true) }
    }

    private fun emitOtaProgress(nodeId: Long, phase: String, progress: Int?, message: String?) {
        val map = mutableMapOf<String, Any?>(
            "type"   to "otaProgress",
            "nodeId" to nodeId.toInt(),
            "phase"  to phase,
        )
        if (progress != null) map["progress"] = progress
        if (message  != null) map["message"]  = message
        emitDeviceState(map)
    }

    private suspend fun downloadOtaFile(
        url:        String,
        destPath:   String,
        onProgress: (Int) -> Unit,
    ) = withContext(Dispatchers.IO) {
        val conn = java.net.URL(url).openConnection() as java.net.HttpURLConnection
        try {
            conn.instanceFollowRedirects = true
            conn.connect()
            if (conn.responseCode !in 200..299) {
                throw Exception("HTTP ${conn.responseCode}")
            }
            val total   = conn.contentLengthLong   // -1 if unknown
            var received = 0L
            java.io.FileOutputStream(destPath).use { out ->
                conn.inputStream.use { input ->
                    val buf = ByteArray(32 * 1024)
                    var n: Int
                    while (input.read(buf).also { n = it } != -1) {
                        out.write(buf, 0, n)
                        received += n
                        if (total > 0L) {
                            onProgress(((received.toDouble() / total) * 100).toInt().coerceIn(0, 99))
                        }
                    }
                }
            }
            onProgress(100)
            Log.d(TAG, "OTA download complete: $received bytes → $destPath")
        } finally {
            conn.disconnect()
        }
    }

    private fun cleanupOtaFile(path: String) {
        try { java.io.File(path).delete() } catch (_: Exception) {}
    }

    companion object {
        private const val TAG = "MatterBridge"
        /** Minimum RSSI to include a network — filters out ghost/stale entries. */
        private const val WIFI_MIN_RSSI         = -85 // dBm
        /** How long to wait after the scan broadcast before reading results. */
        private const val WIFI_SCAN_TIMEOUT_MS  = 300L
    }

    // ── Thread credential store ───────────────────────────────────────────────

    // NOTE: requestPreferredCredentials is called directly from MainActivity
    //       (needs Activity reference for startIntentSenderForResult).

    // ── Thread Border Router discovery ───────────────────────────────────────

    fun discoverThreadNetworks(result: MethodChannel.Result) {
        scope.launch {
            try {
                val routers = ThreadBorderRouterScanner.scan(context)
                val sb = StringBuilder("[")
                routers.forEachIndexed { i, r ->
                    if (i > 0) sb.append(",")
                    sb.append("{")
                    sb.append("\"serviceName\":${jsonStr(r.serviceName)},")
                    sb.append("\"networkName\":${jsonStr(r.networkName)},")
                    sb.append("\"extPanId\":${jsonStr(r.extPanId)},")
                    sb.append("\"vendorName\":${jsonStr(r.vendorName)},")
                    sb.append("\"modelName\":${jsonStr(r.modelName)},")
                    sb.append("\"host\":${jsonStr(r.host)},")
                    sb.append("\"port\":${r.port},")
                    // txt: inline JSON object
                    sb.append("\"txt\":{")
                    r.txt.entries.forEachIndexed { j, (k, v) ->
                        if (j > 0) sb.append(",")
                        sb.append("${jsonStr(k)}:${jsonStr(v)}")
                    }
                    sb.append("}}")
                }
                sb.append("]")
                main.post { result.success(sb.toString()) }
            } catch (e: Exception) {
                Log.e(TAG, "discoverThreadNetworks error", e)
                main.post { result.error("THREAD_SCAN_ERROR", e.message, null) }
            }
        }
    }

    private fun jsonStr(s: String) = "\"${s.replace("\\","\\\\").replace("\"","\\\"")}\""

    // ── Network diagnostics ───────────────────────────────────────────────────

    fun runNetworkDiagnostics(result: MethodChannel.Result) {
        scope.launch {
            try {
                val report = NetworkDiagnosticsRunner.run(context)
                val json   = buildDiagnosticsJson(report)
                main.post { result.success(json) }
            } catch (e: Exception) {
                Log.e(TAG, "runNetworkDiagnostics error", e)
                main.post { result.error("DIAGNOSTICS_ERROR", e.message, null) }
            }
        }
    }

    private fun buildDiagnosticsJson(r: NetworkDiagnosticsRunner.DiagnosticsReport): String {
        val sb = StringBuilder()
        sb.append("{")

        // phoneIpv6
        sb.append("\"phoneIpv6\":{")
        sb.append("\"hasRoutableIpv6\":${r.phoneIpv6.hasRoutableIpv6},")
        sb.append("\"guaAddresses\":${jsonStrArray(r.phoneIpv6.guaAddresses)},")
        sb.append("\"ulaAddresses\":${jsonStrArray(r.phoneIpv6.ulaAddresses)},")
        sb.append("\"linkLocalAddresses\":${jsonStrArray(r.phoneIpv6.linkLocalAddresses)}")
        sb.append("},")

        // multicastLockAcquired
        sb.append("\"multicastLockAcquired\":${r.multicastLockAcquired},")

        // wifi
        sb.append("\"wifi\":{")
        sb.append("\"frequencyMhz\":${r.wifi.frequencyMhz},")
        sb.append("\"band\":${jsonStr(r.wifi.band)},")
        sb.append("\"ssid\":${jsonStr(r.wifi.ssid)},")
        sb.append("\"hasBandSuffix\":${r.wifi.hasBandSuffix}")
        sb.append("},")

        // vpn
        sb.append("\"vpn\":{")
        sb.append("\"isActive\":${r.vpn.isActive}")
        sb.append("},")

        // borderRouters
        sb.append("\"borderRouters\":[")
        r.borderRouters.forEachIndexed { i, br ->
            if (i > 0) sb.append(",")
            sb.append("{")
            sb.append("\"serviceName\":${jsonStr(br.serviceName)},")
            sb.append("\"networkName\":${jsonStr(br.networkName)},")
            sb.append("\"extPanId\":${jsonStr(br.extPanId)},")
            sb.append("\"vendorName\":${jsonStr(br.vendorName)},")
            sb.append("\"modelName\":${jsonStr(br.modelName)},")
            sb.append("\"port\":${br.port},")
            sb.append("\"hostsV4\":${jsonStrArray(br.hostsV4)},")
            sb.append("\"hostsV6LinkLocal\":${jsonStrArray(br.hostsV6LinkLocal)},")
            sb.append("\"hostsV6Ula\":${jsonStrArray(br.hostsV6Ula)},")
            sb.append("\"hostsV6Gua\":${jsonStrArray(br.hostsV6Gua)},")
            sb.append("\"tcpReachable\":${br.tcpReachable?.toString() ?: "null"},")
            sb.append("\"sameSubnetAsPhone\":${br.sameSubnetAsPhone?.toString() ?: "null"},")
            sb.append("\"ipv6PrefixMatchesPhone\":${br.ipv6PrefixMatchesPhone?.toString() ?: "null"},")
            if (br.stateBitmap != null) {
                val bm = br.stateBitmap
                sb.append("\"stateBitmap\":{")
                sb.append("\"raw\":${bm.raw},")
                sb.append("\"connectionMode\":${bm.connectionMode},")
                sb.append("\"connectionModeLabel\":${jsonStr(bm.connectionModeLabel)},")
                sb.append("\"threadInterfaceStatus\":${bm.threadInterfaceStatus},")
                sb.append("\"threadInterfaceLabel\":${jsonStr(bm.threadInterfaceLabel)},")
                sb.append("\"threadInterfaceActive\":${bm.threadInterfaceActive},")
                sb.append("\"availability\":${bm.availability},")
                sb.append("\"bbrActive\":${bm.bbrActive},")
                sb.append("\"bbrIsPrimary\":${bm.bbrIsPrimary}")
                sb.append("}")
            } else {
                sb.append("\"stateBitmap\":null")
            }
            sb.append("}")
        }
        sb.append("],")

        // matterTcpServices
        sb.append("\"matterTcpServices\":${jsonStrArray(r.matterTcpServices)}")

        sb.append("}")
        return sb.toString()
    }

    private fun jsonStrArray(list: List<String>): String {
        val items = list.joinToString(",") { jsonStr(it) }
        return "[$items]"
    }

    // ── Parse setup payload (for UI pre-fill) ────────────────────────────────

    fun parsePayload(payload: String, result: MethodChannel.Result) {
        if (!ChipClient.isAvailable) {
            result.error("CHIP_SDK_UNAVAILABLE", "CHIP SDK not loaded", null)
            return
        }
        try {
            val parsed = SetupPayloadHelper.parse(payload)
            val caps = parsed.discoveryCapabilities.map { it.name }
            result.success(mapOf(
                "vendorId"              to parsed.vendorId,
                "productId"             to parsed.productId,
                "discriminator"         to parsed.discriminator,
                "hasShortDiscriminator" to parsed.hasShortDiscriminator,
                "setupPinCode"          to parsed.setupPinCode.toInt(),
                "discoveryCapabilities" to caps,
            ))
        } catch (e: Exception) {
            result.error("PARSE_ERROR", e.message, null)
        }
    }

    fun getFabricId(result: MethodChannel.Result) {
        if (!ChipClient.isAvailable) { result.success("N/A"); return }
        val id = ChipClient.fabricId
        result.success("0x${id.toULong().toString(16).padStart(16,'0').uppercase()}")
    }

    fun getVendorId(result: MethodChannel.Result) {
        result.success(ChipClient.VENDOR_ID)
    }

    fun readBasicInfo(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val info = ClusterClient.readBasicInfo(context, nodeId)
            main.post {
                result.success(mapOf(
                    "productName"       to (info.productName      ?: ""),
                    "vendorName"        to (info.vendorName       ?: ""),
                    "vendorId"          to (info.vendorId         ?: ""),
                    "productId"         to (info.productId        ?: ""),
                    "hwVersion"         to (info.hwVersion        ?: ""),
                    "softwareVersion"   to (info.swVersion        ?: ""),
                    "softwareVersionNum" to (info.swVersionNum    ?: -1),
                    "manufacturingDate" to (info.manufacturingDate ?: ""),
                    "partNumber"        to (info.partNumber       ?: ""),
                    "productUrl"        to (info.productUrl       ?: ""),
                    "serialNumber"      to (info.serialNumber     ?: ""),
                    "uniqueId"          to (info.uniqueId         ?: ""),
                ))
            }
        }

    fun readServerClusterList(nodeId: Long, endpoint: Int, result: MethodChannel.Result) =
        requireChip(result) {
            val ids = ClusterClient.readServerClusterList(context, nodeId, endpoint = endpoint)
            main.post { result.success(ids.map { it.toInt() }) }
        }

    fun readPartsList(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val ids = ClusterClient.readPartsList(context, nodeId)
            main.post { result.success(ids) }
        }

    // ── Thermostat ────────────────────────────────────────────────────────────

    fun readThermostat(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val data = ClusterClient.readThermostat(context, nodeId)
            // MethodChannel can't carry Map<String,Int?> with null values reliably;
            // send as individual keys, using sentinel -32768 for "null / not present".
            main.post {
                result.success(mapOf(
                    "localTemp"       to (data["localTemp"]       ?: Int.MIN_VALUE),
                    "heatingSetpoint" to (data["heatingSetpoint"] ?: Int.MIN_VALUE),
                    "coolingSetpoint" to (data["coolingSetpoint"] ?: Int.MIN_VALUE),
                    "systemMode"      to (data["systemMode"]      ?: -1),
                    "controlSequence" to (data["controlSequence"] ?: -1),
                ))
            }
        }

    fun writeHeatingSetpoint(nodeId: Long, centidegrees: Int, result: MethodChannel.Result) =
        requireChip(result) {
            ClusterClient.writeHeatingSetpoint(context, nodeId, centidegrees)
            main.post { result.success(true) }
        }

    fun writeSystemMode(nodeId: Long, mode: Int, result: MethodChannel.Result) =
        requireChip(result) {
            ClusterClient.writeSystemMode(context, nodeId, mode)
            main.post { result.success(true) }
        }

    fun readHumidity(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val centi = ClusterClient.readHumidity(context, nodeId)
            main.post { result.success(centi) }
        }

    fun readBattery(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val data = ClusterClient.readBattery(context, nodeId)
            // Pass null when cluster was absent (empty map), else the attribute map
            main.post { result.success(if (data.isEmpty()) null else data) }
        }

    // ── Cluster Inspector — wildcard read ────────────────────────────────────

    fun readThreadNetworkDiagnostics(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val json = ClusterClient.readThreadNetworkDiagnostics(context, nodeId)
            main.post {
                if (json != null) result.success(json)
                else result.error("CLUSTER_ABSENT", "ThreadNetworkDiagnostics cluster not found on this device", null)
            }
        }

    fun readClusters(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val json = ClusterClient.readAllClusters(context, nodeId)
            main.post { result.success(json) }
        }

    // ── Read device type from Descriptor cluster ───────────────────────────────

    fun identify(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            ClusterClient.sendIdentify(context, nodeId)
            main.post { result.success(null) }
        }

    fun readDeviceType(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val typeId = readPrimaryDeviceType(nodeId)
            main.post { result.success(typeId) }
        }

    /**
     * Reads the primary application device-type from the Descriptor cluster.
     *
     * Strategy per Matter spec:
     *  - Endpoint 0  = Root Node (infrastructure types: 0x0011, 0x0016, …)
     *  - Endpoint 1  = Primary application endpoint (thermostat, light, …)
     *
     * We try endpoint 1 first; if it yields nothing useful we fall back to
     * endpoint 0 while skipping known infrastructure types.
     */
    private val infraTypes = setOf(
        0x000E, // Aggregator
        0x0011, // Root Node
        0x0012, // OTA Requestor
        0x0013, // Bridged Node
        0x0014, // OTA Provider
        0x0016, // Secondary Network Interface
        0x0017, // Power Source (utility node type)
        // Note: 0x000F is Generic Switch — an APPLICATION type, NOT infra
    )

    private suspend fun readPrimaryDeviceType(nodeId: Long): Int {
        // Endpoint 0 is the Root Node endpoint — skip it entirely.
        // Application device types always live on endpoint 1 or higher.
        for (ep in 1..5) {
            try {
                val types = ClusterClient.readDeviceTypes(context, nodeId, ep)
                if (types.isEmpty()) continue
                Log.d(TAG, "Descriptor ep=$ep types=${types.map { "0x%04X".format(it) }}")
                val appType = types.firstOrNull { it !in infraTypes }
                if (appType != null) {
                    Log.i(TAG, "Primary device type 0x%04X from ep=$ep".format(appType))
                    return appType
                }
            } catch (e: Exception) {
                Log.w(TAG, "readDeviceTypes ep=$ep failed: ${e.message}")
            }
        }
        Log.w(TAG, "No application device type found, defaulting to OnOff Light")
        return 0x0100
    }
}
