package com.fluxhome.app

import android.content.Intent
import android.util.Log
import com.fluxhome.app.bridge.MatterBridge
import com.fluxhome.app.chip.AndroidThreadCredentialReader
import com.fluxhome.app.chip.ChipClient
import com.fluxhome.app.chip.MatterCommissioner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reads a nodeId argument that may arrive as Int32 or Int64 depending on
 * whether the Dart value fits in a signed 32-bit integer.
 *
 * Background: Flutter's standard message codec encodes a Dart `int` as int32
 * when -2^31 ≤ value ≤ 2^31-1, and as int64 otherwise.  Matter nodeIds are
 * unsigned 64-bit values and can exceed Int.MAX_VALUE, so we must handle both
 * cases.  Using `argument<Int>` alone silently returns null for int64 values,
 * causing the fallback nodeId 0L to be used and routing commands to the wrong
 * (nonexistent) device.
 */
private fun MethodCall.nodeIdArg(key: String = "nodeId"): Long? =
    when (val v = argument<Any>(key)) {
        is Int  -> v.toLong()
        is Long -> v
        else    -> null
    }

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG             = "MainActivity"
        private const val METHOD_CHANNEL  = "com.fluxhome.app/matter"
        private const val EVENT_CHANNEL   = "com.fluxhome.app/commission_events"
        private const val DEVICE_CHANNEL  = "com.fluxhome.app/device_state"
    }

    private val bridge by lazy { MatterBridge(applicationContext) }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Start the foreground service so automations keep running
        // even when the user navigates away from the app.
        startForegroundService(Intent(this, MatterForegroundService::class.java))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        ChipClient.init(applicationContext)
        Log.i(TAG, "CHIP SDK available: ${ChipClient.isAvailable}")

        // ── EventChannel: commissioning progress ──────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    bridge.setEventSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    bridge.setEventSink(null)
                }
            })

        // ── EventChannel: live device state (subscriptions) ───────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    bridge.setDeviceStateSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    bridge.setDeviceStateSink(null)
                }
            })

        // ── MethodChannel ─────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "← ${call.method}")
                when (call.method) {
                    "ping" ->
                        bridge.ping(result)

                    "commissionDevice" -> {
                        val payload          = call.argument<String>("payload") ?: ""
                        val wifiSsid         = call.argument<String>("wifiSsid")
                        val wifiPassword     = call.argument<String>("wifiPassword")
                        val threadDatasetHex = call.argument<String>("threadDatasetHex")
                        val nodeId           = call.nodeIdArg()
                                               ?: (System.currentTimeMillis() and 0xFFFF_FFFFL)
                        bridge.commissionDevice(payload, wifiSsid, wifiPassword, threadDatasetHex, nodeId, result)
                    }

                    "commissionViaIp" -> {
                        val ip      = call.argument<String>("ipAddress") ?: ""
                        val port    = call.argument<Int>("port") ?: 5540
                        val disc    = call.argument<Int>("discriminator") ?: 0
                        val pin     = call.argument<Int>("setupPinCode")?.toLong() ?: 0L
                        val nodeId  = call.nodeIdArg()
                                      ?: (System.currentTimeMillis() and 0xFFFF_FFFFL)
                        bridge.commissionViaIp(ip, port, disc, pin, nodeId, result)
                    }

                    "commissionViaCode" -> {
                        val setupCode = call.argument<String>("setupCode") ?: ""
                        val nodeId    = call.nodeIdArg()
                                        ?: (System.currentTimeMillis() and 0xFFFF_FFFFL)
                        bridge.commissionViaCode(setupCode, nodeId, result)
                    }

                    "toggleDevice" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        val on     = call.argument<Boolean>("on") ?: false
                        bridge.toggleDevice(nodeId, on, result)
                    }

                    "setLevel" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        val level  = call.argument<Int>("level") ?: 0
                        bridge.setLevel(nodeId, level, result)
                    }

                    "stepLevel" -> {
                        val nodeId  = call.nodeIdArg() ?: 0L
                        val stepUp  = call.argument<Boolean>("stepUp") ?: true
                        bridge.stepLevel(nodeId, stepUp, result)
                    }

                    "coveringUp" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.coveringUp(nodeId, result)
                    }

                    "coveringDown" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.coveringDown(nodeId, result)
                    }

                    "coveringStop" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.coveringStop(nodeId, result)
                    }

                    "coveringGoToLift" -> {
                        val nodeId        = call.nodeIdArg() ?: 0L
                        val percent100ths = call.argument<Int>("percent100ths") ?: 0
                        bridge.coveringGoToLift(nodeId, percent100ths, result)
                    }

                    "setFanMode" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        val mode   = call.argument<Int>("mode") ?: 0
                        bridge.setFanMode(nodeId, mode, result)
                    }

                    "setFanPercent" -> {
                        val nodeId  = call.nodeIdArg() ?: 0L
                        val percent = call.argument<Int>("percent") ?: 0
                        bridge.setFanPercent(nodeId, percent, result)
                    }

                    "setColorTemperature" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        val mireds = call.argument<Int>("mireds") ?: 370
                        bridge.setColorTemperature(nodeId, mireds, result)
                    }

                    "readDeviceState" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.readDeviceState(nodeId, result)
                    }

                    "readBasicInfo" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.readBasicInfo(nodeId, result)
                    }

                    "readServerClusterList" -> {
                        val nodeId   = call.nodeIdArg() ?: 0L
                        val endpoint = call.argument<Int>("endpoint") ?: 0
                        bridge.readServerClusterList(nodeId, endpoint, result)
                    }

                    "readPartsList" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.readPartsList(nodeId, result)
                    }

                    "readThermostat" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.readThermostat(nodeId, result)
                    }

                    "writeHeatingSetpoint" -> {
                        val nodeId      = call.nodeIdArg() ?: 0L
                        val centidegrees = call.argument<Int>("centidegrees") ?: 0
                        bridge.writeHeatingSetpoint(nodeId, centidegrees, result)
                    }

                    "writeSystemMode" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        val mode   = call.argument<Int>("mode") ?: 0
                        bridge.writeSystemMode(nodeId, mode, result)
                    }

                    "readHumidity" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.readHumidity(nodeId, result)
                    }

                    "readBattery" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.readBattery(nodeId, result)
                    }

                    "lockDoor" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        val pin    = call.argument<String>("pin")
                        bridge.lockDoor(nodeId, pin, result)
                    }

                    "unlockDoor" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        val pin    = call.argument<String>("pin")
                        bridge.unlockDoor(nodeId, pin, result)
                    }

                    "readThreadNetworkDiagnostics" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.readThreadNetworkDiagnostics(nodeId, result)
                    }

                    "readClusters" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.readClusters(nodeId, result)
                    }

                    "readDeviceType" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.readDeviceType(nodeId, result)
                    }

                    "downloadAndFlash" -> {
                        val nodeId              = call.nodeIdArg() ?: 0L
                        val otaUrl              = call.argument<String>("otaUrl") ?: ""
                        val targetVersion       = call.argument<String>("targetVersion")
                                                    ?.toLongOrNull() ?: 0L
                        val targetVersionString = call.argument<String>("targetVersionString") ?: ""
                        val dryRun              = call.argument<Boolean>("dryRun") ?: false
                        val endpoint            = call.argument<Int>("endpoint") ?: 0
                        bridge.downloadAndFlash(nodeId, otaUrl, targetVersion, targetVersionString, dryRun, endpoint, result)
                    }

                    "cancelOta" -> bridge.cancelOta(result)

                    "identify" -> {
                        val nodeId  = call.nodeIdArg() ?: 0L
                        val seconds = call.argument<Int>("seconds") ?: 15
                        bridge.identify(nodeId, seconds, result)
                    }

                    "shareDevice" -> {
                        val nodeId    = call.nodeIdArg() ?: 0L
                        val vendorId  = call.argument<Int>("vendorId")  ?: 0
                        val productId = call.argument<Int>("productId") ?: 0
                        bridge.openCommissioningWindow(nodeId, vendorId, productId, result)
                    }

                    "removeDevice" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.removeDevice(nodeId, result)
                    }

                    "startSubscription" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.startSubscription(nodeId, result)
                    }

                    "stopSubscription" -> {
                        val nodeId = call.nodeIdArg() ?: 0L
                        bridge.stopSubscription(nodeId, result)
                    }

                    "scanWifiNetworks" ->
                        bridge.scanWifiNetworks(result)

                    "readAndroidThreadCredentials" ->
                        AndroidThreadCredentialReader.requestPreferredCredentials(this, result)

                    "discoverThreadNetworks" -> bridge.discoverThreadNetworks(result)

                    "runNetworkDiagnostics" -> bridge.runNetworkDiagnostics(result)

                    "parsePayload" -> {
                        val payload = call.argument<String>("payload") ?: ""
                        bridge.parsePayload(payload, result)
                    }

                    "provideCredentials" -> {
                        val ssid     = call.argument<String?>("ssid")
                        val password = call.argument<String?>("password")
                        val threadHex = call.argument<String?>("threadDatasetHex")
                        val threadTlv = threadHex?.let {
                            it.chunked(2).map { b -> b.toInt(16).toByte() }.toByteArray()
                        }
                        MatterCommissioner.provideCredentials(ssid, password, threadTlv)
                        result.success(null)
                    }

                    "getFabricId" ->
                        bridge.getFabricId(result)

                    "getVendorId" ->
                        bridge.getVendorId(result)

                    "discoverCommissionableNodes" ->
                        bridge.discoverCommissionableNodes(result)

                    else ->
                        result.notImplemented()
                }
            }
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == AndroidThreadCredentialReader.REQUEST_CODE) {
            AndroidThreadCredentialReader.onActivityResult(resultCode, data)
        }
    }
}
