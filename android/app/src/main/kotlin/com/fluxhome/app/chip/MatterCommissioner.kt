package com.fluxhome.app.chip

import android.bluetooth.BluetoothGatt
import android.content.Context
import android.util.Log
import chip.devicecontroller.CommissionParameters
import chip.devicecontroller.ICDRegistrationInfo
import chip.devicecontroller.NetworkCredentials
import matter.onboardingpayload.OnboardingPayload
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
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
    3L   -> "Incorrect state — use IP commissioning for devices already on the network " +
            "(Ethernet/on-network devices cannot be commissioned over BLE without WiFi/Thread credentials)"
    4L   -> "Message too long"
    11L  -> "Connection closed unexpectedly (0x0B)"
    17L  -> "Wrong node ID (0x11)"
    24L  -> "Buffer too small (0x18)"
    32L  -> "Timeout (0x20) — device did not respond in time; check range and power"
    45L  -> "Wi-Fi credentials error (0x2D) — device rejected credentials or network not found; " +
            "check SSID and password"
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
 * events via [onEvent] at every meaningful step.
 *
 * Two commissioning paths:
 *  - [commission]      — BLE transport. Requires Wi-Fi or Thread credentials.
 *                        The CHIP SDK always enables network-setup mode for BLE,
 *                        so devices without a NetworkCommissioning cluster
 *                        (Ethernet / already-on-network) cannot use this path.
 *  - [commissionViaIp] — UDP/IP transport. For devices already on the network.
 *                        Does not require network credentials; sends
 *                        CommissioningComplete over CASE after AddNOC.
 */
object MatterCommissioner {

    private const val TAG = "MatterCommissioner"
    const val STATUS_PAIRING_SUCCESS = 0L

    /** Holds the BLE manager from the last (or current) commission attempt so
     *  it can be explicitly closed before retrying, even when the CHIP SDK
     *  failed to call back [BleCallback.onNotifyChipConnectionClosed]. */
    private var activeBle: BleConnectionManager? = null

    /**
     * Fulfilled by [provideCredentials] when Flutter responds to a
     * [CREDENTIALS_NEEDED] event.  null = cancel; non-null = proceed.
     */
    private var pendingCreds: CompletableDeferred<NetworkCredentials?>? = null

    /**
     * Called from [MatterBridge] after Flutter collects credentials in response
     * to a [CREDENTIALS_NEEDED] event.
     *   ssid == null → use stored Thread credentials (or cancel if none)
     *   ssid != null → use these WiFi credentials
     */
    fun provideCredentials(ssid: String?, password: String?, threadTlv: ByteArray?) {
        val creds: NetworkCredentials? = when {
            ssid != null -> NetworkCredentials.forWiFi(
                NetworkCredentials.WiFiCredentials(ssid, password ?: ""))
            threadTlv != null -> NetworkCredentials.forThread(
                NetworkCredentials.ThreadCredentials(threadTlv))
            else -> null  // cancel
        }
        pendingCreds?.complete(creds)
    }

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
        //
        // If neither WiFi nor Thread credentials are available, or if only one
        // type is available but we don't yet know which the device needs, emit
        // CREDENTIALS_NEEDED and suspend until Flutter replies via provideCredentials().
        //
        // If we already have exactly one type of credentials we can pass them
        // immediately; onReadCommissioningInfo will call
        // updateCommissioningNetworkCredentials() to switch if needed.
        val safeSsid = wifiSsid?.trim()?.takeIf { it.isNotEmpty() }
        val hasWifi   = safeSsid != null
        val hasThread = threadDatasetTlv != null

        // Provide best-guess credentials when we already know the type.
        // When both or neither are available we pass null and defer the
        // decision to onReadCommissioningInfo, which fires after the SDK
        // has read the device's actual network interface endpoints.
        val networkCreds: NetworkCredentials? = when {
            hasWifi && !hasThread -> {
                onEvent("📶 Using Wi-Fi SSID: $safeSsid")
                NetworkCredentials.forWiFi(
                    NetworkCredentials.WiFiCredentials(safeSsid!!, wifiPassword ?: ""))
            }
            hasThread && !hasWifi -> {
                onEvent("🧵 Using Thread operational dataset (${threadDatasetTlv!!.size} bytes)")
                NetworkCredentials.forThread(
                    NetworkCredentials.ThreadCredentials(threadDatasetTlv))
            }
            else -> null  // resolved in onReadCommissioningInfo
        }

        // 4 ── CHIP pairing ────────────────────────────────────────────────────
        onEvent("⚙ Starting CHIP commissioning (PASE)…")
        val commissionedNodeId = pairViaBle(
            context          = context,
            gatt             = gatt,
            connId           = ble.connectionId,
            nodeId           = nodeId,
            pinCode          = payload.setupPinCode,
            network          = networkCreds,
            wifiSsid         = wifiSsid,
            wifiPassword     = wifiPassword,
            threadDatasetTlv = threadDatasetTlv,
            onEvent          = onEvent,
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

    /**
     * Commissions a device that is already on the network using DNS-SD discovery.
     *
     * The SDK advertises commissionable devices under `_matterc._udp` and this
     * method uses [ChipDeviceController.pairDeviceWithCode] with
     * `useOnlyOnNetworkDiscovery = true` so no IP address is required from the
     * user.  The short discriminator from the manual pairing code is sufficient
     * to locate the device via mDNS.
     */
    suspend fun commissionViaCode(
        context: Context,
        setupCode: String,
        nodeId: Long,
        onEvent: (String) -> Unit = {},
    ): Long {
        val controller = ChipClient.getController()
        val params = CommissionParameters.Builder()
            .setCsrNonce(null)
            .setICDRegistrationInfo(null)
            .build()

        onEvent("🔍 Discovering device on network via DNS-SD…")
        onEvent("⚙ Starting CHIP commissioning (on-network PASE)…")

        return suspendCancellableCoroutine { cont ->
            controller.setCompletionListener(object : GenericChipDeviceListener() {
                override fun onCommissioningComplete(nodeId: Long, errorCode: Long) {
                    Log.i(TAG, "commissionViaCode complete nodeId=$nodeId errorCode=$errorCode")
                    if (!cont.isActive) return
                    if (errorCode == 0L) {
                        onEvent("✓ Commissioning complete")
                        cont.resume(nodeId)
                    } else {
                        val ex = CommissioningException(errorCode,
                            "On-network commission failed (error $errorCode)")
                        onEvent("✗ Error: ${ex.message}")
                        cont.resumeWithException(ex)
                    }
                }
                override fun onCommissioningStatusUpdate(nodeId: Long, stage: String, errorCode: Long) {
                    onEvent("🔄 $stage")
                }
                override fun onICDRegistrationInfoRequired() {
                    controller.updateCommissioningICDRegistrationInfo(buildIcdRegistrationInfo())
                }
                override fun onError(error: Throwable?) {
                    if (!cont.isActive) return
                    val msg = error?.message ?: "unknown"
                    onEvent("✗ Error: $msg")
                    Log.e(TAG, "onError during on-network commissioning: $msg", error)
                    cont.resumeWithException(error ?: CommissioningException(-4, "On-network commission error: $msg"))
                }
            })
            ChipClient.setPendingNodeId(nodeId)
            Log.i(TAG, "pairDeviceWithCode nodeId=$nodeId setupCode=$setupCode")
            installAttestationDelegate(controller, onEvent)
            controller.pairDeviceWithCode(
                nodeId,
                setupCode,
                /* discoverOnce            = */ false,
                /* useOnlyOnNetworkDiscovery = */ true,
                params,
            )
        }
    }

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
    /**
     * Installs a [DeviceAttestationDelegate] that logs and continues past any
     * attestation failure (including [AttestationRevocationCheck]).
     *
     * The revocation check queries the CSA DCL; it fails for development /
     * uncertified devices and for network-unreachable environments. We log the
     * error code and call [continueCommissioning] with
     * [ignoreAttestationFailure] = true so commissioning is not blocked.
     */
    private fun installAttestationDelegate(
        controller: chip.devicecontroller.ChipDeviceController,
        onEvent: (String) -> Unit,
    ) {
        controller.setDeviceAttestationDelegate(
            /* failureSafeTimeoutSecs = */ 600,
        ) { devicePtr, _, errorCode ->
            if (errorCode != 0L) {
                onEvent("⚠ Attestation check warning (code $errorCode) — continuing")
                Log.w(TAG, "DeviceAttestation non-zero errorCode=$errorCode — calling continueCommissioning(ignore=true)")
            }
            // Always continue — for certified production devices errorCode == 0
            // and ignoreAttestationFailure has no effect.
            controller.continueCommissioning(devicePtr, errorCode != 0L)
        }
    }

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
        wifiSsid: String?,
        wifiPassword: String?,
        threadDatasetTlv: ByteArray?,
        onEvent: (String) -> Unit,
    ): Long = suspendCancellableCoroutine { cont ->
        val controller = ChipClient.getController()
        val params = CommissionParameters.Builder()
            .setCsrNonce(null)
            .apply { if (network != null) setNetworkCredentials(network) }
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
                val isWifi   = wifiEndpointId   != kInvalidEndpointId
                val isThread = threadEndpointId != kInvalidEndpointId
                onEvent(
                    "📋 Device info: " +
                    "VID=0x${vendorId.toString(16).uppercase().padStart(4,'0')} " +
                    "PID=0x${productId.toString(16).uppercase().padStart(4,'0')} " +
                    "wifi-ep=${if (isWifi) wifiEndpointId else "none"} " +
                    "thread-ep=${if (isThread) threadEndpointId else "none"}"
                )
                val safeSsid = wifiSsid?.trim()?.takeIf { it.isNotEmpty() }
                when {
                    // Correct credentials already match device type — confirm and continue.
                    isWifi && safeSsid != null ->
                        controller.updateCommissioningNetworkCredentials(
                            NetworkCredentials.forWiFi(
                                NetworkCredentials.WiFiCredentials(safeSsid, wifiPassword ?: ""))
                        ).also { onEvent("📶 Confirmed: Wi-Fi network «$safeSsid»") }
                    isThread && threadDatasetTlv != null ->
                        controller.updateCommissioningNetworkCredentials(
                            NetworkCredentials.forThread(
                                NetworkCredentials.ThreadCredentials(threadDatasetTlv))
                        ).also { onEvent("🧵 Confirmed: Thread dataset") }

                    // WiFi device but no WiFi credentials — block the JNI thread
                    // and wait for Flutter to collect them.
                    isWifi && safeSsid == null -> {
                        onEvent("🔌 CREDENTIALS_NEEDED:WIFI")
                        pendingCreds = CompletableDeferred()
                        val chosen = runBlocking { pendingCreds!!.await() }
                        if (chosen != null) {
                            controller.updateCommissioningNetworkCredentials(chosen)
                        }
                    }
                    // Thread device but no Thread dataset — same pattern.
                    isThread && threadDatasetTlv == null -> {
                        onEvent("🔌 CREDENTIALS_NEEDED:THREAD")
                        pendingCreds = CompletableDeferred()
                        val chosen = runBlocking { pendingCreds!!.await() }
                        if (chosen != null) {
                            controller.updateCommissioningNetworkCredentials(chosen)
                        }
                    }
                }
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

        ChipClient.setPendingNodeId(nodeId)
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
        ChipClient.setPendingNodeId(nodeId)
        Log.i(TAG, "pairDeviceWithAddress nodeId=$nodeId addr=$address port=$port")
        controller.pairDeviceWithAddress(nodeId, address, port, discriminator, pinCode, params)
    }
}
