package com.example.matter_home.chip

import android.bluetooth.BluetoothGatt
import android.content.Context
import android.util.Log
import chip.devicecontroller.CommissionParameters
import chip.devicecontroller.ICDRegistrationInfo
import chip.devicecontroller.NetworkCredentials
import matter.onboardingpayload.OnboardingPayload
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import java.security.SecureRandom

/** Thrown when commissioning fails. */
class CommissioningException(val errorCode: Long, message: String) : Exception(message)

// ── Error-code registry ───────────────────────────────────────────────────

/**
 * Returns a human-readable description for a CHIP/Matter error code.
 *
 * Values are CHIP core errors (range=0, sdk=0) encoded as raw 32-bit ints:
 *   CHIP_CORE_ERROR(n) = n  (for n < 0x1000, which covers all common codes).
 *
 * Reference: connectedhomeip/src/lib/core/CHIPError.h
 */
fun chipErrorDescription(code: Long): String = when (code) {
    0L   -> "Success"
    1L   -> "Send failed"
    2L   -> "Bad request data"
    3L   -> "Incorrect state — unexpected call order in the SDK state machine"
    4L   -> "Message too long"
    11L  -> "Connection closed unexpectedly (0x0B)"
    17L  -> "Wrong node ID (0x11)"
    24L  -> "Buffer too small (0x18)"
    32L  -> "Timeout (0x20) — device did not respond in time; check range and power"
    47L  -> "Invalid PASE parameter (0x2F)"
    50L  -> "No shared trusted root (0x32)"
    70L  -> "Internal error (0x46)"
    71L  -> "Invalid PASE parameter (0x47)"
    80L  -> "IM status code received (0x50) — the device rejected a commissioning " +
            "command via the Interaction Model. " +
            "Common causes: Thread dataset does not match the device's network, " +
            "wrong Wi-Fi credentials, or the device is already commissioned"
    81L  -> "IM cluster-specific status received (0x51)"
    88L  -> "Invalid destination node ID (0x58)"
    96L  -> "Not connected (0x60) — no active session to the device"
    100L -> "Network not found (0x64)"
    101L -> "Invalid network ID (0x65)"
    105L -> "Operation already in progress (0x69)"
    else -> "Unknown error (check CHIP SDK CHIPError.h)"
}

/** Formats an error code as "80 (0x50): <description>". */
fun chipErrorLabel(code: Long): String =
    "$code (0x${code.toString(16).uppercase()}): ${chipErrorDescription(code)}"

/**
 * Orchestrates the full Matter commissioning flow and emits plain-text progress
 * events via [onEvent] at every meaningful step:
 *   • BLE scanning / GATT connect / MTU negotiation
 *   • Every CHIP SDK stage callback (ArmFailSafe, WifiNetworkEnable, …)
 *   • Device info (VID / PID) once read from the device
 *   • Final success / failure
 */
object MatterCommissioner {

    private const val TAG = "MatterCommissioner"
    const val STATUS_PAIRING_SUCCESS = 0L

    /** Holds the BLE manager from the last (or current) commission attempt so
     *  it can be explicitly closed before retrying, even when the CHIP SDK
     *  failed to call back [BleCallback.onNotifyChipConnectionClosed]. */
    private var activeBle: BleConnectionManager? = null

    // ── BLE commissioning ────────────────────────────────────────────────────

    suspend fun commission(
        context: Context,
        payload: OnboardingPayload,
        wifiSsid: String?,
        wifiPassword: String?,
        threadDatasetTlv: ByteArray?,
        nodeId: Long,
        onEvent: (String) -> Unit,
    ): Long {
        // 1. Close any leftover GATT connection from a previous attempt.
        activeBle?.let { prevBle ->
            val prevConnId = prevBle.connectionId
            Log.i(TAG, "Closing stale BLE connection connId=$prevConnId")
            onEvent("♻ Closing previous BLE connection…")
            prevBle.close()
            activeBle = null
        }

        // 2. Reset the CHIP SDK's internal BLE connection state.
        //    ChipDeviceController keeps a private `connectionId` field.
        //    pairDeviceThroughBLE throws "already in use" if it is non-zero.
        //    onNotifyChipConnectionClosed() is the SDK's own public method
        //    that clears it — but it's normally triggered by native code after
        //    commissioning finishes, which never happens on failure.
        resetChipBleState(onEvent)

        val ble = BleConnectionManager()
        activeBle = ble

        // 1 ── BLE scan ────────────────────────────────────────────────────────
        onEvent("🔍 BLE scanning… (discriminator=${payload.discriminator})")
        val device = ble.findDevice(
            context              = context,
            discriminator        = payload.discriminator,
            isShortDiscriminator = payload.hasShortDiscriminator,
        ) ?: throw CommissioningException(
            -1,
            "BLE scan timed out – device not found (discriminator=${payload.discriminator})"
        )
        onEvent("📡 Found device ${device.address}")

        // 2 ── GATT connect ────────────────────────────────────────────────────
        onEvent("🔗 GATT connecting to ${device.address}…")
        val gatt: BluetoothGatt = ble.connect(context, device)
            ?: throw CommissioningException(-2, "GATT connection failed to ${device.address}")
        onEvent("✓ BLE connected (MTU negotiated)")

        // 3 ── Network credentials ─────────────────────────────────────────────
        val safeSsid = wifiSsid?.trim()?.takeIf { it.isNotEmpty() }
        val networkCreds: NetworkCredentials? = when {
            safeSsid != null -> {
                onEvent("📶 Using Wi-Fi SSID: $safeSsid")
                NetworkCredentials.forWiFi(
                    NetworkCredentials.WiFiCredentials(safeSsid, wifiPassword ?: "")
                )
            }
            threadDatasetTlv != null -> {
                onEvent("🧵 Using Thread operational dataset (${threadDatasetTlv.size} bytes)")
                NetworkCredentials.forThread(
                    NetworkCredentials.ThreadCredentials(threadDatasetTlv)
                )
            }
            else -> {
                onEvent("🌐 No network credentials – Ethernet device")
                null
            }
        }

        // 4 ── CHIP pairing ────────────────────────────────────────────────────
        onEvent("⚙ Starting CHIP commissioning (PASE)…")
        val commissionedNodeId = pairViaBle(
            context = context,
            gatt    = gatt,
            connId  = ble.connectionId,
            nodeId  = nodeId,
            pinCode = payload.setupPinCode,
            network = networkCreds,
            onEvent = onEvent,
        )

        activeBle = null  // CHIP SDK owns the BLE lifecycle from here; clear our ref
        onEvent("🎉 Done! Node 0x${commissionedNodeId.toULong().toString(16).padStart(16,'0').uppercase()}")
        return commissionedNodeId
    }

    // ── IP commissioning ─────────────────────────────────────────────────────

    suspend fun commissionViaIp(
        context: Context,
        ipAddress: String,
        port: Int = 5540,
        discriminator: Int,
        setupPinCode: Long,
        nodeId: Long,
        onEvent: (String) -> Unit = {},
    ): Long {
        val params = CommissionParameters.Builder()
            .setCsrNonce(null)
            .setICDRegistrationInfo(null)
            .build()
        onEvent("🌐 Commissioning via IP $ipAddress:$port…")
        onEvent("⚙ Starting CHIP commissioning (PASE)…")
        return pairViaIp(context, ipAddress, port, discriminator, setupPinCode, nodeId, params, onEvent)
    }

    // ── Private: reset CHIP SDK BLE state ────────────────────────────────────

    /**
     * Reads the private `connectionId` field from [ChipDeviceController] via
     * reflection and calls the SDK's own public [ChipDeviceController.onNotifyChipConnectionClosed]
     * to reset it to zero.
     *
     * Why this is necessary:
     * [ChipDeviceController.pairDeviceThroughBLE] checks `connectionId != 0`
     * and throws "Bluetooth connection already in use" if true.
     * The field is normally cleared by the native callback `onNotifyChipConnectionClosed`,
     * but that callback is not reliably delivered when commissioning fails mid-way —
     * leaving the field set for the rest of the process lifetime.
     */
    private fun buildIcdRegistrationInfo(): ICDRegistrationInfo {
        val key = ByteArray(16).also { SecureRandom().nextBytes(it) }
        return ICDRegistrationInfo.newBuilder()
            .setSymmetricKey(key)
            .setCheckInNodeId(ChipClient.getController().compressedFabricId)
            .setMonitoredSubject(ChipClient.getController().compressedFabricId)
            .build()
    }

    private fun resetChipBleState(onEvent: (String) -> Unit) {
        if (!ChipClient.isAvailable) return
        try {
            val controller = ChipClient.getController()
            val field = controller.javaClass.getDeclaredField("connectionId")
            field.isAccessible = true
            val staleConnId = field.getInt(controller)
            if (staleConnId != 0) {
                Log.w(TAG, "Stale ChipDeviceController.connectionId=$staleConnId — calling onNotifyChipConnectionClosed to reset")
                onEvent("♻ Resetting CHIP SDK BLE state (stale connId=$staleConnId)…")
                controller.onNotifyChipConnectionClosed(staleConnId)
                Log.i(TAG, "CHIP SDK BLE state reset — connectionId now ${field.getInt(controller)}")
            } else {
                Log.d(TAG, "ChipDeviceController.connectionId=0, no reset needed")
            }
        } catch (e: Exception) {
            Log.e(TAG, "resetChipBleState failed: ${e.message}")
        }
    }

    // ── Private: BLE pairing ──────────────────────────────────────────────────

    private suspend fun pairViaBle(
        context: Context,
        gatt: BluetoothGatt,
        connId: Int,
        nodeId: Long,
        pinCode: Long,
        network: NetworkCredentials?,
        onEvent: (String) -> Unit,
    ): Long = suspendCancellableCoroutine { cont ->
        val controller = ChipClient.getController()
        val params = CommissionParameters.Builder()
            .setCsrNonce(null)
            .setNetworkCredentials(network)
            .setICDRegistrationInfo(null)
            .build()

        controller.setCompletionListener(object : GenericChipDeviceListener() {
            override fun onStatusUpdate(status: Int) {
                onEvent("ℹ Status: $status")
            }

            override fun onCommissioningStageStart(nodeId: Long, stage: String) {
                onEvent("▶ Stage: $stage")
            }

            override fun onCommissioningStatusUpdate(nodeId: Long, stage: String, errorCode: Long) {
                if (errorCode == 0L) {
                    onEvent("  ✓ $stage")
                } else {
                    onEvent("  ✗ $stage — ${chipErrorLabel(errorCode)}")
                }
            }

            override fun onReadCommissioningInfo(
                vendorId: Int, productId: Int,
                wifiEndpointId: Int, threadEndpointId: Int,
            ) {
                val kInvalidEndpointId = 0xFFFF
                onEvent(
                    "📋 Device info: " +
                    "VID=0x${vendorId.toString(16).uppercase().padStart(4,'0')} " +
                    "PID=0x${productId.toString(16).uppercase().padStart(4,'0')} " +
                    "wifi-ep=${if (wifiEndpointId == kInvalidEndpointId) "none" else wifiEndpointId} " +
                    "thread-ep=${if (threadEndpointId == kInvalidEndpointId) "none" else threadEndpointId}"
                )
            }

            override fun onCommissioningComplete(returnedNodeId: Long, errorCode: Long) {
                if (!cont.isActive) return
                if (errorCode == STATUS_PAIRING_SUCCESS) {
                    cont.resume(returnedNodeId)
                } else {
                    val label = chipErrorLabel(errorCode)
                    onEvent("✗ Commissioning failed — $label")
                    Log.e(TAG, "onCommissioningComplete error: $label")
                    cont.resumeWithException(
                        CommissioningException(errorCode, "Commission failed: $label")
                    )
                }
            }

            override fun onICDRegistrationInfoRequired() {
                Log.d(TAG, "ICD device detected — providing registration info")
                onEvent("ICD device detected, registering…")
                ChipClient.getController().updateCommissioningICDRegistrationInfo(buildIcdRegistrationInfo())
            }
            override fun onError(error: Throwable?) {
                if (!cont.isActive) return
                val msg = error?.message ?: "unknown"
                onEvent("✗ Error: $msg")
                Log.e(TAG, "onError during BLE commissioning: $msg", error)
                cont.resumeWithException(
                    error ?: CommissioningException(-3, "Commission error: $msg")
                )
            }
        })

        Log.i(TAG, "pairDeviceThroughBLE nodeId=$nodeId connId=$connId")
        controller.pairDeviceThroughBLE(gatt, connId, nodeId, pinCode, params)
    }

    // ── Private: IP pairing ───────────────────────────────────────────────────

    private suspend fun pairViaIp(
        context: Context,
        address: String,
        port: Int,
        discriminator: Int,
        pinCode: Long,
        nodeId: Long,
        params: CommissionParameters,
        onEvent: (String) -> Unit,
    ): Long = suspendCancellableCoroutine { cont ->
        val controller = ChipClient.getController()
        controller.setCompletionListener(object : GenericChipDeviceListener() {
            override fun onStatusUpdate(status: Int) {
                onEvent("ℹ Status: $status")
            }
            override fun onCommissioningStageStart(nodeId: Long, stage: String) {
                onEvent("▶ Stage: $stage")
            }
            override fun onCommissioningStatusUpdate(nodeId: Long, stage: String, errorCode: Long) {
                if (errorCode == 0L) onEvent("  ✓ $stage")
                else                 onEvent("  ✗ $stage — ${chipErrorLabel(errorCode)}")
            }
            override fun onReadCommissioningInfo(vendorId: Int, productId: Int, wifiEndpointId: Int, threadEndpointId: Int) {
                onEvent("📋 Device: VID=0x${vendorId.toString(16).uppercase().padStart(4,'0')} PID=0x${productId.toString(16).uppercase().padStart(4,'0')}")
            }
            override fun onCommissioningComplete(returnedNodeId: Long, errorCode: Long) {
                if (!cont.isActive) return
                if (errorCode == STATUS_PAIRING_SUCCESS) cont.resume(returnedNodeId)
                else {
                    val label = chipErrorLabel(errorCode)
                    onEvent("✗ Commissioning failed — $label")
                    Log.e(TAG, "onCommissioningComplete (IP) error: $label")
                    cont.resumeWithException(
                        CommissioningException(errorCode, "IP commission failed: $label")
                    )
                }
            }
            override fun onICDRegistrationInfoRequired() {
                Log.d(TAG, "ICD device detected — providing registration info")
                onEvent("ICD device detected, registering…")
                ChipClient.getController().updateCommissioningICDRegistrationInfo(buildIcdRegistrationInfo())
            }
            override fun onError(error: Throwable?) {
                if (!cont.isActive) return
                val msg = error?.message ?: "unknown"
                onEvent("✗ Error: $msg")
                Log.e(TAG, "onError during IP commissioning: $msg", error)
                cont.resumeWithException(error ?: CommissioningException(-4, "IP commission error: $msg"))
            }
        })
        Log.i(TAG, "pairDeviceWithAddress nodeId=$nodeId addr=$address port=$port")
        controller.pairDeviceWithAddress(nodeId, address, port, discriminator, pinCode, params)
    }
}
