package com.fluxhome.app.bridge

import android.content.Context
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Thin coordinator: owns one [BridgeCore] and all cluster-domain sub-bridges.
 *
 * [MainActivity] creates a single instance and routes MethodChannel calls through
 * it. No business logic lives here — every method is a one-line delegation.
 *
 * Adding a new Matter device type:
 *   1. Create a new `XyzBridge(core)` in this package.
 *   2. Add `private val xyz = XyzBridge(core)` below.
 *   3. Add delegation methods at the bottom of this file.
 *   4. Add the `when` cases to MainActivity.
 */
class MatterBridge(context: Context) {

    private val core = BridgeCore(context)

    // ── Sub-bridges ───────────────────────────────────────────────────────────
    private val commissioning = CommissioningBridge(core)
    private val ota           = OtaBridge(core)
    private val network       = NetworkBridge(core)
    private val diagnostics   = DiagnosticsBridge(core)
    private val deviceInfo    = DeviceInfoBridge(core)

    // ── Event sink wiring (called from MainActivity) ──────────────────────────
    fun setEventSink(sink: EventChannel.EventSink?)       { core.commissionEventSink = sink }
    fun setDeviceStateSink(sink: EventChannel.EventSink?) { core.deviceStateSink     = sink }

    // ── Commissioning ─────────────────────────────────────────────────────────
    fun ping(result: MethodChannel.Result) =
        commissioning.ping(result)

    fun commissionDevice(payload: String, wifiSsid: String?, wifiPassword: String?,
                         threadDatasetHex: String?, nodeId: Long, result: MethodChannel.Result) =
        commissioning.commissionDevice(payload, wifiSsid, wifiPassword, threadDatasetHex, nodeId, result)

    fun commissionViaIp(ipAddress: String, port: Int, discriminator: Int, setupPinCode: Long,
                        nodeId: Long, result: MethodChannel.Result) =
        commissioning.commissionViaIp(ipAddress, port, discriminator, setupPinCode, nodeId, result)

    fun commissionViaCode(setupCode: String, nodeId: Long, result: MethodChannel.Result) =
        commissioning.commissionViaCode(setupCode, nodeId, result)

    fun removeDevice(nodeId: Long, result: MethodChannel.Result) =
        commissioning.removeDevice(nodeId, result)

    fun openCommissioningWindow(nodeId: Long, vendorId: Int, productId: Int,
                                awaitReachable: Boolean, result: MethodChannel.Result) =
        commissioning.openCommissioningWindow(nodeId, vendorId, productId, awaitReachable, result)

    fun removeFabric(nodeId: Long, fabricIndex: Int, result: MethodChannel.Result) =
        deviceInfo.removeFabric(nodeId, fabricIndex, result)

    fun parsePayload(payload: String, result: MethodChannel.Result) =
        commissioning.parsePayload(payload, result)

    // ── OTA ───────────────────────────────────────────────────────────────────
    fun downloadAndFlash(nodeId: Long, otaUrl: String, targetVersion: Long,
                         targetVersionString: String, dryRun: Boolean, otaEndpoint: Int,
                         result: MethodChannel.Result) =
        ota.downloadAndFlash(nodeId, otaUrl, targetVersion, targetVersionString, dryRun, otaEndpoint, result)

    fun cancelOta(result: MethodChannel.Result) =
        ota.cancelOta(result)

    // ── Network (Wi-Fi + Thread) ──────────────────────────────────────────────
    fun scanWifiNetworks(result: MethodChannel.Result) =
        network.scanWifiNetworks(result)

    fun discoverThreadNetworks(result: MethodChannel.Result) =
        network.discoverThreadNetworks(result)

    // ── Diagnostics ───────────────────────────────────────────────────────────
    fun runNetworkDiagnostics(result: MethodChannel.Result) =
        diagnostics.runNetworkDiagnostics(result)

    fun readThreadNetworkDiagnostics(nodeId: Long, result: MethodChannel.Result) =
        diagnostics.readThreadNetworkDiagnostics(nodeId, result)

    fun readClusters(nodeId: Long, result: MethodChannel.Result) =
        diagnostics.readClusters(nodeId, result)

    // ── Device info ───────────────────────────────────────────────────────────
    fun readBasicInfo(nodeId: Long, result: MethodChannel.Result) =
        deviceInfo.readBasicInfo(nodeId, result)

    fun readServerClusterList(nodeId: Long, endpoint: Int, result: MethodChannel.Result) =
        deviceInfo.readServerClusterList(nodeId, endpoint, result)

    fun readPartsList(nodeId: Long, result: MethodChannel.Result) =
        deviceInfo.readPartsList(nodeId, result)

    fun readDeviceType(nodeId: Long, result: MethodChannel.Result) =
        deviceInfo.readDeviceType(nodeId, result)

    fun readFabrics(nodeId: Long, result: MethodChannel.Result) =
        deviceInfo.readFabrics(nodeId, result)

    fun identify(nodeId: Long, seconds: Int, result: MethodChannel.Result) =
        deviceInfo.identify(nodeId, seconds, result)

    fun getFabricId(result: MethodChannel.Result) =
        deviceInfo.getFabricId(result)

    fun getVendorId(result: MethodChannel.Result) =
        deviceInfo.getVendorId(result)

    fun discoverCommissionableNodes(result: MethodChannel.Result) =
        deviceInfo.discoverCommissionableNodes(result)

    fun exportFabricForController(result: MethodChannel.Result) =
        deviceInfo.exportFabricForController(result)
}