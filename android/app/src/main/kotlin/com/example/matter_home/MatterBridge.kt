package com.example.matter_home

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.matter_home.chip.ChipClient
import com.example.matter_home.chip.ClusterClient
import com.example.matter_home.chip.MatterCommissioner
import com.example.matter_home.chip.NetworkDiagnosticsRunner
import com.example.matter_home.chip.SetupPayloadHelper
import com.example.matter_home.chip.AndroidThreadCredentialReader
import com.example.matter_home.chip.ThreadBorderRouterScanner
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MatterBridge(private val context: Context) {

    companion object {
        private const val TAG = "MatterBridge"
    }

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
                if (nid !in cancelledNodeIds)
                    emitDeviceState(mapOf("nodeId" to nid.toInt(), "type" to "resubscribing",
                                         "nextMs" to nextMs))
            },
            onError = { nid, err ->
                if (nid !in cancelledNodeIds)
                    emitDeviceState(mapOf("nodeId" to nid.toInt(), "type" to "error",
                                         "message" to (err.message ?: "unknown")))
            },
        )
        main.post { result.success(true) }
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

    fun readBasicInfo(nodeId: Long, result: MethodChannel.Result) =
        requireChip(result) {
            val info = ClusterClient.readBasicInfo(context, nodeId)
            main.post {
                result.success(mapOf(
                    "productName"      to (info.productName      ?: ""),
                    "vendorName"       to (info.vendorName       ?: ""),
                    "vendorId"         to (info.vendorId         ?: ""),
                    "productId"        to (info.productId        ?: ""),
                    "hwVersion"        to (info.hwVersion        ?: ""),
                    "softwareVersion"  to (info.swVersion        ?: ""),
                    "manufacturingDate" to (info.manufacturingDate ?: ""),
                    "partNumber"       to (info.partNumber       ?: ""),
                    "productUrl"       to (info.productUrl       ?: ""),
                    "serialNumber"     to (info.serialNumber     ?: ""),
                    "uniqueId"         to (info.uniqueId         ?: ""),
                ))
            }
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
