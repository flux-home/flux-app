package com.fluxhome.app.chip

import android.content.Context
import android.util.Log
import chip.devicecontroller.AttestationInfo
import chip.devicecontroller.CSRInfo
import chip.devicecontroller.ChipDeviceController
import chip.devicecontroller.ControllerParams
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone

private const val TAG = "AppNOCIssuer"

// Back-date device NOCs so they validate against a controller whose clock lags real
// time (the flux controller pins its clock to firmware build time, no RTC/NTP).  A
// notBefore of "now" would be CHIP_ERROR_CERT_NOT_VALID_YET (0x4F) to it.
private fun certNotBefore(): Calendar =
    GregorianCalendar(TimeZone.getTimeZone("UTC")).apply { clear(); set(2020, Calendar.JANUARY, 1, 0, 0, 0) }

private fun certNotAfter(): Calendar =
    GregorianCalendar(TimeZone.getTimeZone("UTC")).apply { clear(); set(2099, Calendar.DECEMBER, 31, 23, 59, 59) }

/**
 * Custom NOC chain issuer that signs device NOCs with the app's own CA.
 *
 * Without this, the CHIP SDK falls back to its internal default CA when generating
 * the device NOC and AddTrustedRootCertificate.  That default CA differs from the
 * Root CA in [AppFabricManager] that the controller uses for its own CASE identity —
 * so CASE later fails with CHIP_ERROR_NO_SHARED_TRUSTED_ROOT (0x32).
 *
 * The device NOC is issued as a 3-tier chain (Root → ICAC → NOC).  This is mandatory:
 * the SDK's [ChipDeviceController.onNOCChainGeneration] JNI requires a non-null
 * intermediate certificate and returns CHIP_ERROR_BAD_REQUEST (0x92) without one.
 *
 * Threading notes:
 *  - [onNOCChainGenerationNeeded] is invoked on the CHIP event-loop thread, which
 *    holds the CHIP stack lock.  [ChipDeviceController.onNOCChainGeneration] acquires
 *    that same (non-recursive) lock, so calling it inline would deadlock.  We hand the
 *    finished chain back from a short-lived background thread instead — the issuer
 *    callback is explicitly allowed to complete asynchronously.
 *  - [controllerNodeId] is cached at construction for the same reason:
 *    [ChipDeviceController.controllerNodeId] is a native call that takes the stack lock.
 */
internal class AppNOCIssuer(
    private val context: Context,
    private val controller: ChipDeviceController,
) : ChipDeviceController.NOCChainIssuer {

    private val controllerNodeId: Long = controller.controllerNodeId

    @Volatile
    var pendingNodeId: Long = 0L

    override fun onNOCChainGenerationNeeded(csrInfo: CSRInfo, attestationInfo: AttestationInfo) {
        val nodeId = pendingNodeId
        check(nodeId != 0L) { "pendingNodeId not set before commissioning" }

        Log.d(TAG, "onNOCChainGenerationNeeded: nodeId=0x%016X".format(nodeId))

        val id           = AppFabricManager.getOrCreate(context)
        val icacKey      = AppKeyPairDelegate(ALIAS_ICAC)
        val devicePubKey = ChipDeviceController.publicKeyFromCSR(csrInfo.csr)

        // Device NOC signed by the ICAC (chain: Root → ICAC → device NOC).
        val deviceNoc = ChipDeviceController.createOperationalCertificate(
            icacKey, id.icacTlv, devicePubKey,
            id.fabricId, nodeId, emptyList(),
            certNotBefore(), certNotAfter(),
        )
        Log.d(TAG, "Issued device NOC (${deviceNoc?.size} bytes) for nodeId=0x%016X".format(nodeId))

        val params = ControllerParams.newBuilder()
            .setRootCertificate(id.rootCaTlv)
            .setIntermediateCertificate(id.icacTlv)   // required by onNOCChainGeneration JNI
            .setOperationalCertificate(deviceNoc)
            .setIpk(id.ipk)
            .setAdminSubject(controllerNodeId)
            .build()

        // Hand the chain back off the CHIP event-loop thread to avoid a stack-lock deadlock.
        Thread {
            try {
                controller.onNOCChainGeneration(params)
                Log.i(TAG, "Device NOC handed to SDK for nodeId=0x%016X".format(nodeId))
            } catch (e: Exception) {
                Log.e(TAG, "onNOCChainGeneration failed: ${e.message}", e)
            }
        }.also { it.name = "noc-issuer"; it.start() }
    }
}
