package com.fluxhome.app.bridge

import android.content.Context
import com.fluxhome.app.chip.clusters.EnergyCluster
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
    private val subscriptions = SubscriptionBridge(core)
    private val ota           = OtaBridge(core)
    private val network       = NetworkBridge(core)
    private val diagnostics   = DiagnosticsBridge(core)
    private val deviceInfo    = DeviceInfoBridge(core)
    private val onOff         = OnOffBridge(core)
    private val covering      = CoveringBridge(core)
    private val fan           = FanBridge(core)
    private val color         = ColorBridge(core)
    private val thermostat    = ThermostatBridge(core)
    private val sensors       = SensorBridge(core)
    private val doorLock      = DoorLockBridge(core)

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
                                result: MethodChannel.Result) =
        commissioning.openCommissioningWindow(nodeId, vendorId, productId, result)

    fun parsePayload(payload: String, result: MethodChannel.Result) =
        commissioning.parsePayload(payload, result)

    // ── Subscriptions ─────────────────────────────────────────────────────────
    fun startSubscription(nodeId: Long, result: MethodChannel.Result) =
        subscriptions.startSubscription(nodeId, result)

    fun stopSubscription(nodeId: Long, result: MethodChannel.Result) =
        subscriptions.stopSubscription(nodeId, result)

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

    fun identify(nodeId: Long, seconds: Int, result: MethodChannel.Result) =
        deviceInfo.identify(nodeId, seconds, result)

    fun getFabricId(result: MethodChannel.Result) =
        deviceInfo.getFabricId(result)

    fun getVendorId(result: MethodChannel.Result) =
        deviceInfo.getVendorId(result)

    fun discoverCommissionableNodes(result: MethodChannel.Result) =
        deviceInfo.discoverCommissionableNodes(result)

    // ── OnOff + Level ─────────────────────────────────────────────────────────
    fun toggleDevice(nodeId: Long, on: Boolean, result: MethodChannel.Result) =
        onOff.toggleDevice(nodeId, on, result)

    fun setLevel(nodeId: Long, level: Int, result: MethodChannel.Result) =
        onOff.setLevel(nodeId, level, result)

    fun stepLevel(nodeId: Long, stepUp: Boolean, result: MethodChannel.Result) =
        onOff.stepLevel(nodeId, stepUp, result)

    fun readDeviceState(nodeId: Long, result: MethodChannel.Result) =
        onOff.readDeviceState(nodeId, result)

    // ── Window Covering ───────────────────────────────────────────────────────
    fun coveringUp(nodeId: Long, result: MethodChannel.Result) =
        covering.coveringUp(nodeId, result)

    fun coveringDown(nodeId: Long, result: MethodChannel.Result) =
        covering.coveringDown(nodeId, result)

    fun coveringStop(nodeId: Long, result: MethodChannel.Result) =
        covering.coveringStop(nodeId, result)

    fun coveringGoToLift(nodeId: Long, percent100ths: Int, result: MethodChannel.Result) =
        covering.coveringGoToLift(nodeId, percent100ths, result)

    // ── Fan ───────────────────────────────────────────────────────────────────
    fun setFanMode(nodeId: Long, mode: Int, result: MethodChannel.Result) =
        fan.setFanMode(nodeId, mode, result)

    fun setFanPercent(nodeId: Long, percent: Int, result: MethodChannel.Result) =
        fan.setFanPercent(nodeId, percent, result)

    // ── Color ─────────────────────────────────────────────────────────────────
    fun setColorTemperature(nodeId: Long, mireds: Int, result: MethodChannel.Result) =
        color.setColorTemperature(nodeId, mireds, result)

    // ── Thermostat ────────────────────────────────────────────────────────────
    fun readThermostat(nodeId: Long, result: MethodChannel.Result) =
        thermostat.readThermostat(nodeId, result)

    fun writeHeatingSetpoint(nodeId: Long, centidegrees: Int, result: MethodChannel.Result) =
        thermostat.writeHeatingSetpoint(nodeId, centidegrees, result)

    fun writeSystemMode(nodeId: Long, mode: Int, result: MethodChannel.Result) =
        thermostat.writeSystemMode(nodeId, mode, result)

    // ── Sensors ───────────────────────────────────────────────────────────────
    fun readHumidity(nodeId: Long, result: MethodChannel.Result) =
        sensors.readHumidity(nodeId, result)

    fun readBattery(nodeId: Long, result: MethodChannel.Result) =
        sensors.readBattery(nodeId, result)
    // ── Door Lock ─────────────────────────────────────────────────────────────
    fun lockDoor(nodeId: Long, pin: String?, result: MethodChannel.Result) =
        doorLock.lockDoor(nodeId, pin, result)

    fun unlockDoor(nodeId: Long, pin: String?, result: MethodChannel.Result) =
        doorLock.unlockDoor(nodeId, pin, result)

    fun readLockState(nodeId: Long, result: MethodChannel.Result) =
        doorLock.readLockState(nodeId, result)

    // ── Energy ────────────────────────────────────────────────────────────────
    fun readCumulativeEnergy(nodeId: Long, endpoint: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            val data = EnergyCluster.readCumulativeEnergy(core.context, nodeId, endpoint)
            core.main.post {
                result.success(mapOf(
                    "importedMwh" to data.importedMwh,
                    "exportedMwh" to data.exportedMwh,
                ))
            }
        }
}