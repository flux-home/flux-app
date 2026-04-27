package com.fluxhome.app.bridge

import android.util.Log
import com.fluxhome.app.chip.ChipClient
import com.fluxhome.app.chip.CommissioningException
import com.fluxhome.app.chip.MatterCommissioner
import com.fluxhome.app.chip.SetupPayloadHelper
import com.fluxhome.app.chip.clusters.BasicInfoCluster
import io.flutter.plugin.common.MethodChannel
import matter.onboardingpayload.CommissioningFlow
import matter.onboardingpayload.DiscoveryCapability
import matter.onboardingpayload.ManualOnboardingPayloadGenerator
import matter.onboardingpayload.OnboardingPayload
import matter.onboardingpayload.QRCodeOnboardingPayloadGenerator

class CommissioningBridge(private val core: BridgeCore) {

    fun ping(result: MethodChannel.Result) = result.success(true)

    // ── Commission via BLE ────────────────────────────────────────────────────

    fun commissionDevice(
        payload: String,
        wifiSsid: String?,
        wifiPassword: String?,
        threadDatasetHex: String?,
        nodeId: Long,
        result: MethodChannel.Result,
    ) = core.requireChip(result) {
        val parsed = SetupPayloadHelper.parse(payload)
        val threadDataset = threadDatasetHex
            ?.filter { it.isLetterOrDigit() }
            ?.chunked(2)
            ?.map { it.toInt(16).toByte() }
            ?.toByteArray()
        val commissionedNodeId = MatterCommissioner.commission(
            context          = core.context,
            payload          = parsed,
            wifiSsid         = wifiSsid,
            wifiPassword     = wifiPassword,
            threadDatasetTlv = threadDataset,
            nodeId           = nodeId,
            onEvent          = { msg -> Log.i(TAG, msg); core.emitEvent(msg) },
        )
        val deviceTypeId = readPrimaryDeviceType(core.context, commissionedNodeId)
        core.main.post {
            result.success(mapOf("nodeId" to commissionedNodeId, "deviceTypeId" to deviceTypeId))
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
    ) = core.requireChip(result) {
        val commissionedNodeId = MatterCommissioner.commissionViaIp(
            context       = core.context,
            ipAddress     = ipAddress,
            port          = port,
            discriminator = discriminator,
            setupPinCode  = setupPinCode,
            nodeId        = nodeId,
            onEvent       = { msg -> Log.i(TAG, msg); core.emitEvent(msg) },
        )
        val deviceTypeId = readPrimaryDeviceType(core.context, commissionedNodeId)
        core.main.post {
            result.success(mapOf("nodeId" to commissionedNodeId, "deviceTypeId" to deviceTypeId))
        }
    }

    // ── Commission via on-network DNS-SD (multi-admin / already-provisioned) ─────

    fun commissionViaCode(
        setupCode: String,
        nodeId: Long,
        result: MethodChannel.Result,
    ) = core.requireChip(result) {
        val commissionedNodeId = MatterCommissioner.commissionViaCode(
            context   = core.context,
            setupCode = setupCode,
            nodeId    = nodeId,
            onEvent   = { msg -> Log.i(TAG, msg); core.emitEvent(msg) },
        )
        val deviceTypeId = readPrimaryDeviceType(core.context, commissionedNodeId)
        core.main.post {
            result.success(mapOf("nodeId" to commissionedNodeId, "deviceTypeId" to deviceTypeId))
        }
    }

    // ── Remove ────────────────────────────────────────────────────────────────

    fun removeDevice(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            ChipClient.getController().unpairDevice(nodeId)
            core.main.post { result.success(true) }
        }

    // ── Multi-admin / share ───────────────────────────────────────────────────

    fun openCommissioningWindow(
        nodeId: Long,
        vendorId: Int,
        productId: Int,
        result: MethodChannel.Result,
    ) = core.requireChip(result) {
        val rng           = java.security.SecureRandom()
        val discriminator = rng.nextInt(0x1000)             // 12-bit: 0–4095
        val pin           = generateValidPin(rng)            // 27-bit valid passcode

        val devicePtr = ChipClient.getConnectedDevicePointer(core.context, nodeId)

        // Old CHIP SDK returns Boolean; new SDK returns String (manual pairing code).
        val sdkResult = ChipClient.getController().openPairingWindowWithPIN(
            devicePtr, 300, 1000L, discriminator, pin
        )
        Log.i(TAG, "openPairingWindowWithPIN: nodeId=$nodeId disc=$discriminator " +
                   "pin=$pin sdkResult=$sdkResult (${sdkResult::class.java.simpleName})")
        if (!windowOpened(sdkResult)) {
            throw CommissioningException(
                -5,
                "Device rejected the commissioning window request " +
                "(sdkResult=$sdkResult). The device may be offline, " +
                "already have an open window, or not support multi-admin.",
            )
        }

        // If Flutter didn't supply VID/PID, read them from the device so the
        // QR code carries the real values — some commissioning apps filter by VID.
        val finalVendorId: Int
        val finalProductId: Int
        if (vendorId == 0) {
            val info = try { BasicInfoCluster.readBasicInfo(core.context, nodeId) } catch (_: Exception) { null }
            finalVendorId  = info?.vendorId ?.removePrefix("0x")?.removePrefix("0X")?.toIntOrNull(16) ?: 0
            finalProductId = info?.productId?.removePrefix("0x")?.removePrefix("0X")?.toIntOrNull(16) ?: 0
            Log.i(TAG, "VID/PID read from device: VID=0x%04X PID=0x%04X".format(finalVendorId, finalProductId))
        } else {
            finalVendorId  = vendorId
            finalProductId = productId
        }

        val payload = OnboardingPayload(
            /* version               */ 0,
            /* vendorId              */ finalVendorId,
            /* productId             */ finalProductId,
            /* commissioningFlow     */ CommissioningFlow.STANDARD.value,
            /* discoveryCapabilities */ mutableSetOf(DiscoveryCapability.ON_NETWORK),
            /* discriminator         */ discriminator,
            /* hasShortDiscriminator */ false,
            /* setupPinCode          */ pin,
        )
        val manualCode = ManualOnboardingPayloadGenerator(payload).payloadDecimalStringRepresentation()
        val qrCode     = "MT:" + QRCodeOnboardingPayloadGenerator(payload).payloadBase38Representation()

        Log.i(TAG, "ECM window open: nodeId=$nodeId disc=$discriminator " +
                   "VID=0x%04X PID=0x%04X manual=$manualCode qr=$qrCode".format(finalVendorId, finalProductId))

        core.main.post {
            result.success(mapOf(
                "manualPairingCode" to manualCode,
                "qrCodePayload"     to qrCode,
            ))
        }
    }

    // ── Parse setup payload (for UI pre-fill) ─────────────────────────────────

    fun parsePayload(payload: String, result: MethodChannel.Result) {
        if (!ChipClient.isAvailable) {
            result.error("CHIP_SDK_UNAVAILABLE", "CHIP SDK not loaded", null)
            return
        }
        try {
            val parsed = SetupPayloadHelper.parse(payload)
            val caps = parsed.discoveryCapabilities.map { it.name }
            Log.i(TAG, "parsePayload disc=${parsed.discriminator} " +
                "shortDisc=${parsed.hasShortDiscriminator} caps=$caps " +
                "vid=${parsed.vendorId} pid=${parsed.productId} pin=${parsed.setupPinCode}")
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

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Returns true if the result of [openPairingWindowWithPIN] indicates success.
     *  Handles both SDK variants: Boolean (old) and String manualCode (new). */
    private fun windowOpened(result: Any): Boolean = when (result) {
        is Boolean -> result
        is String  -> result.isNotEmpty()
        else       -> true   // unknown return type: assume success
    }

    /** Generates a cryptographically random valid Matter passcode (1–99999998). */
    private fun generateValidPin(rng: java.security.SecureRandom): Long {
        // Matter spec §5.1.6.1 — invalid passcodes must not be used.
        val invalid = setOf(
            0L, 11111111L, 22222222L, 33333333L, 44444444L,
            55555555L, 66666666L, 77777777L, 88888888L, 99999999L,
            12345678L, 87654321L,
        )
        var pin: Long
        do { pin = (rng.nextLong().and(Long.MAX_VALUE)) % 99_999_998L + 1L }
        while (pin in invalid)
        return pin
    }

    companion object {
        private const val TAG = "CommissioningBridge"
    }
}
