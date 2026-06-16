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
        val csr = csrInfo.csr

        Log.d(TAG, "onNOCChainGenerationNeeded: nodeId=0x%016X".format(nodeId))

        // All work runs off the CHIP event-loop thread: it must not block on the
        // network (controller path), and onNOCChainGeneration takes the same
        // (non-recursive) stack lock the callback holds, so calling it inline
        // would deadlock.
        Thread {
            try {
                val params = if (AppFabricManager.hasAdopted(context)) {
                    buildFromController(csr, nodeId)
                } else {
                    buildLocally(csr, nodeId)
                }
                if (params == null) {
                    // We can't produce a device NOC (hub unreachable / refused signing).
                    // Abort the commissioning so it fails fast — otherwise the CHIP
                    // state machine waits at GenerateNOCChain until the failsafe
                    // timer expires (the app appears "stuck").
                    Log.e(TAG, "No NOC chain for nodeId=0x%016X — aborting commissioning".format(nodeId))
                    try { controller.stopDevicePairing(nodeId) } catch (e: Exception) {
                        Log.e(TAG, "stopDevicePairing failed: ${e.message}")
                    }
                    return@Thread
                }
                controller.onNOCChainGeneration(params)
                Log.i(TAG, "Device NOC handed to SDK for nodeId=0x%016X".format(nodeId))
            } catch (e: Exception) {
                Log.e(TAG, "onNOCChainGeneration failed: ${e.message}", e)
                try { controller.stopDevicePairing(nodeId) } catch (_: Exception) {}
            }
        }.also { it.name = "noc-issuer"; it.start() }
    }

    /** Legacy / standalone (app is the CA): sign the device NOC with the app's ICAC. */
    private fun buildLocally(csr: ByteArray, nodeId: Long): ControllerParams {
        val id           = AppFabricManager.getOrCreate(context)
        val icacKey      = AppKeyPairDelegate(ALIAS_ICAC)
        val devicePubKey = ChipDeviceController.publicKeyFromCSR(csr)

        // Device NOC signed by the ICAC (chain: Root → ICAC → device NOC).
        val deviceNoc = ChipDeviceController.createOperationalCertificate(
            icacKey, id.icacTlv, devicePubKey,
            id.fabricId, nodeId, emptyList(),
            certNotBefore(), certNotAfter(),
        )
        Log.d(TAG, "Issued device NOC locally (${deviceNoc?.size} bytes) for nodeId=0x%016X".format(nodeId))

        return ControllerParams.newBuilder()
            .setRootCertificate(id.rootCaTlv)
            .setIntermediateCertificate(id.icacTlv)   // required by onNOCChainGeneration JNI
            .setOperationalCertificate(deviceNoc)
            .setIpk(id.ipk)
            .setAdminSubject(controllerNodeId)
            .build()
    }

    /**
     * Controller-owned fabric: the phone holds no CA key, so forward the device
     * CSR to the controller (`POST /fabric/sign-noc`) and install the returned
     * NOC.
     *
     * NOTE: [ChipDeviceController.onNOCChainGeneration] historically requires a
     * non-null intermediate cert (see AppFabricManager docs).  This path passes
     * the controller-issued ICAC when the controller returns one; if the
     * controller signs device NOCs directly with its root (no ICAC), this is a
     * known integration risk to verify on-device.
     */
    private fun buildFromController(csr: ByteArray, nodeId: Long): ControllerParams? {
        val signer  = ChipClient.deviceNocSigner ?: run {
            Log.e(TAG, "adopted fabric but no deviceNocSigner set"); return null
        }
        val adopted = AppFabricManager.adoptedIdentity(context) ?: return null

        Log.d(TAG, "Forwarding device CSR to controller for nodeId=0x%016X".format(nodeId))
        val signed = signer.sign(csr, nodeId) ?: run {
            Log.e(TAG, "controller did not sign device NOC for nodeId=0x%016X".format(nodeId)); return null
        }
        // The intermediate must be the ICAC that signed THIS device NOC (from the
        // sign-noc response), not the phone's own adopted ICAC.  onNOCChainGeneration
        // rejects a null intermediate (CHIP_ERROR_BAD_REQUEST 0x92), so the controller
        // must return a 3-tier chain (root → ICAC → device NOC) with icac_der set.
        val icac = signed.icacDer ?: adopted.icacTlv
        if (icac == null) {
            Log.e(TAG, "device NOC has no intermediate cert — controller must return "
                + "icac_der (3-tier chain); onNOCChainGeneration will reject 2-tier")
        }
        Log.d(TAG, "Controller signed device NOC (${signed.nocDer.size} bytes, "
            + "icac=${signed.icacDer?.size ?: 0} bytes)")

        return ControllerParams.newBuilder()
            .setRootCertificate(adopted.rootCaTlv)
            .apply { icac?.let { setIntermediateCertificate(it) } }
            .setOperationalCertificate(signed.nocDer)
            .setIpk(adopted.ipk)
            .setAdminSubject(controllerNodeId)
            .build()
    }
}
