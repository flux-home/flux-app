package com.fluxhome.app.chip

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import chip.devicecontroller.ChipDeviceController
import chip.devicecontroller.ControllerParams
import chip.devicecontroller.GetConnectedDeviceCallbackJni.GetConnectedDeviceCallback
import chip.platform.AndroidBleManager
import chip.platform.AndroidChipPlatform
import chip.platform.AndroidNfcCommissioningManager
import chip.platform.ChipMdnsCallbackImpl
import chip.platform.DiagnosticDataProviderImpl
import chip.platform.NsdManagerServiceBrowser
import chip.platform.NsdManagerServiceResolver
import chip.platform.PreferencesConfigurationManager
import chip.platform.PreferencesKeyValueStoreManager
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Singleton CHIP SDK entry point, ported from CHIPTool's ChipClient.kt.
 *
 * Lifecycle:
 *  - Call [init] once in Application.onCreate() or MainActivity.onCreate().
 *  - [isAvailable] is false when running with the chip-stub (simulation mode).
 */
object ChipClient {
    private const val TAG = "ChipClient"

    /** Vendor ID used when creating the fabric.  0xFFF1 = CHIP test VID (range 0xFFF1–0xFFF4 reserved by CSA for development). */
    const val VENDOR_ID = 0xFFF1

    private lateinit var _controller: ChipDeviceController
    private lateinit var _platform: AndroidChipPlatform
    private lateinit var _nocIssuer: AppNOCIssuer
    private var _multicastLock: WifiManager.MulticastLock? = null

    /** True when the real CHIPController.aar is loaded. */
    var isAvailable: Boolean = false
        private set

    // ── Initialisation ───────────────────────────────────────────────────────

    /**
     * Initialises the CHIP platform. Safe to call multiple times.
     * Throws nothing – on failure [isAvailable] stays false.
     */
    fun init(context: Context) {
        if (isAvailable) return
        try {
            ChipDeviceController.loadJni()      // loads the native .so
            _platform = AndroidChipPlatform(
                AndroidBleManager(context),
                AndroidNfcCommissioningManager(),
                PreferencesKeyValueStoreManager(context),
                PreferencesConfigurationManager(context),
                NsdManagerServiceResolver(
                    context,
                    NsdManagerServiceResolver.NsdManagerResolverAvailState(),
                ),
                // Increase browse timeout to 30 s (default is 5 s).
                // The CHIP SDK browses for sub-typed mDNS records such as
                // _matterc._udp,_S2 (short discriminator filter).  Some
                // devices are slow to advertise these sub-types and 5 s
                // is not enough to reliably find them before commission.
                NsdManagerServiceBrowser(context, 30_000L),
                ChipMdnsCallbackImpl(),
                DiagnosticDataProviderImpl(context),
            )
            val opKeyConfig = AppFabricManager.operationalKeyConfig(context)
            _controller = ChipDeviceController(
                ControllerParams.newBuilder(opKeyConfig)
                    .setControllerVendorId(VENDOR_ID)
                    .setEnableServerInteractions(true)
                    .setSkipAttestationCertificateValidation(true)
                    .setCASEFailsafeTimerSeconds(600)
                    .build(),
            )
            // Install the custom NOC chain issuer so device NOCs are signed with the
            // app's root CA — matching the controller's own CASE identity.  Without
            // this, the SDK falls back to its internal test CA for AddTrustedRootCert,
            // which differs from id.rootCaTlv and causes CASE to fail (0x32).
            _nocIssuer = AppNOCIssuer(context, _controller)
            _controller.setNOCChainIssuer(_nocIssuer)

            isAvailable = true
            Log.i(TAG, "CHIP SDK initialised – fabric 0x${_controller.compressedFabricId.toULong().toString(16)}")

            // Acquire a Wi-Fi multicast lock so Android delivers mDNS multicast
            // packets to the CHIP SDK.  Without this, DNS-SD discovery (both
            // commissioning _matterc._udp and operational _matter._tcp) is silently
            // suppressed by the OS, even though CHANGE_WIFI_MULTICAST_STATE is
            // declared in the manifest.
            val wifiMgr = context.applicationContext
                .getSystemService(Context.WIFI_SERVICE) as? WifiManager
            _multicastLock = wifiMgr
                ?.createMulticastLock("chip_matter")
                ?.also {
                    it.setReferenceCounted(false)
                    it.acquire()
                    Log.i(TAG, "Wi-Fi multicast lock acquired")
                }
        } catch (e: Exception) {
            Log.w(TAG, "CHIP SDK not available (${e.javaClass.simpleName}): simulation mode")
            isAvailable = false
        }
    }

    // ── Accessors ────────────────────────────────────────────────────────────

    /** Returns the [ChipDeviceController] or throws [IllegalStateException] if not initialised. */
    fun getController(): ChipDeviceController {
        check(isAvailable) { "CHIP SDK is not available" }
        return _controller
    }

    fun getPlatform(): AndroidChipPlatform {
        check(isAvailable) { "CHIP SDK is not available" }
        return _platform
    }

    val fabricId: Long
        get() = if (isAvailable) _controller.compressedFabricId else 0L

    val fabricIndex: Int
        get() = if (isAvailable) _controller.getFabricIndex() else 0

    /** Must be called with the target node ID before each pairDevice* call. */
    fun setPendingNodeId(nodeId: Long) {
        if (isAvailable) _nocIssuer.pendingNodeId = nodeId
    }

    // ── CASE session helper ──────────────────────────────────────────────────

    /**
     * Establishes a CASE session with [nodeId] and returns the native device
     * pointer.  Suspends until connected or throws on failure.
     */
    suspend fun getConnectedDevicePointer(context: Context, nodeId: Long): Long =
        suspendCancellableCoroutine { cont ->
            getController().getConnectedDevicePointer(
                nodeId,
                object : GetConnectedDeviceCallback {
                    override fun onDeviceConnected(devicePointer: Long) {
                        Log.d(TAG, "CASE session established for nodeId=$nodeId")
                        cont.resume(devicePointer)
                    }

                    override fun onConnectionFailure(nodeId: Long, error: Exception) {
                        Log.e(TAG, "CASE session failed for nodeId=$nodeId", error)
                        cont.resumeWithException(error)
                    }
                },
            )
        }
}
