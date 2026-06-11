package com.fluxhome.app.chip

import android.content.Context
import android.util.Base64
import android.util.Log
import chip.devicecontroller.ChipDeviceController
import chip.devicecontroller.OperationalKeyConfig
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.SecureRandom
import java.security.interfaces.ECPrivateKey
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone

private const val TAG = "AppFabricManager"

private const val PREF_NAME   = "flux_fabric"
private const val K_VERSION   = "version"
private const val K_ROOT_TLV  = "root_tlv"
private const val K_ICAC_TLV  = "icac_tlv"
private const val K_APP_NOC   = "app_noc"
private const val K_IPK       = "ipk"
private const val K_FABRIC_ID = "fabric_id"

/**
 * Bump when the cert-minting scheme changes so existing fabrics are regenerated.
 *  v2: 3-tier chain (added ICAC) + back-dated certificate validity.
 */
private const val FABRIC_VERSION = 2

internal const val ALIAS_ROOT_CA  = "flux_root_ca"
internal const val ALIAS_ICAC     = "flux_icac"
internal const val ALIAS_APP_NODE = "flux_app_node"

private const val FABRIC_ID          = 1L
private const val ROOT_ISSUER_ID     = 1L
private const val ICAC_ISSUER_ID     = 2L
private const val APP_NODE_ID        = 0x0001L
private const val CONTROLLER_NODE_ID = 0x0002L

data class ControllerCredentials(
    val rootCaTlv: ByteArray,
    val nocTlv:    ByteArray,
    val opPrivKey: ByteArray,   // raw 32-byte P256 scalar
    val ipk:       ByteArray,   // 16-byte IPK epoch key
    val fabricId:  Long,
)

/**
 * Manages the app's persistent Matter fabric identity.
 *
 * PKI layout (all keys live in Android Keystore, private keys never exported):
 *
 *   Root CA  ([ALIAS_ROOT_CA])
 *     ├── ICAC  ([ALIAS_ICAC])  ──► signs device NOCs issued during commissioning
 *     ├── App node NOC          (signed directly by Root, 2-tier)
 *     └── Controller NOC        (signed directly by Root, 2-tier)
 *
 * Why the ICAC exists: the CHIP Android SDK's [ChipDeviceController.onNOCChainGeneration]
 * JNI path (used by [AppNOCIssuer]) *requires* a non-null intermediate certificate —
 * it returns CHIP_ERROR_BAD_REQUEST (0x92) otherwise.  Device NOCs are therefore
 * issued as a 3-tier chain Root → ICAC → NOC.  The app's own node identity and the
 * flux controller's identity are 2-tier (NOC signed directly by Root); since every
 * NOC chains to the same Root, CASE validation succeeds across all parties.
 *
 * Certificate validity: every cert is back-dated to [CERT_NOT_BEFORE_YEAR] rather than
 * "now".  The flux controller has no RTC/NTP and pins its clock to the firmware build
 * time, which is older than commissioning time — a notBefore of "now" makes certs look
 * CHIP_ERROR_CERT_NOT_VALID_YET (0x4F) to it.  A back-dated notBefore validates against
 * any controller clock at or after that year.
 *
 * [generateControllerCredentials] creates an in-memory keypair for the flux
 * controller (Node 0x0002), signs a NOC for it with the Root CA, and returns the raw
 * private key so [FluxCoapService.provisionFabric] can deliver it over CoAP.
 *
 * Must be called after [chip.devicecontroller.ChipDeviceController.loadJni].
 */
object AppFabricManager {

    private const val CERT_NOT_BEFORE_YEAR = 2020
    private const val CERT_NOT_AFTER_YEAR  = 2099

    private fun notBefore(): Calendar =
        GregorianCalendar(TimeZone.getTimeZone("UTC")).apply {
            clear(); set(CERT_NOT_BEFORE_YEAR, Calendar.JANUARY, 1, 0, 0, 0)
        }

    private fun notAfter(): Calendar =
        GregorianCalendar(TimeZone.getTimeZone("UTC")).apply {
            clear(); set(CERT_NOT_AFTER_YEAR, Calendar.DECEMBER, 31, 23, 59, 59)
        }

    data class FabricIdentity(
        val rootCaTlv: ByteArray,
        val icacTlv:   ByteArray,
        val appNocTlv: ByteArray,
        val ipk:       ByteArray,
        val fabricId:  Long,
    )

    private var cached: FabricIdentity? = null

    fun getOrCreate(context: Context): FabricIdentity =
        cached ?: (load(context) ?: create(context))

    /**
     * The controller's own operational identity (2-tier: Root → App node NOC).
     * No intermediate certificate — the app node NOC is signed directly by the Root.
     */
    fun operationalKeyConfig(context: Context): OperationalKeyConfig {
        val id = getOrCreate(context)
        return OperationalKeyConfig(
            AppKeyPairDelegate(ALIAS_APP_NODE),
            id.rootCaTlv,
            null,           // no ICAC in the controller's own chain
            id.appNocTlv,
            id.ipk,
        )
    }

    /**
     * Generates a one-time in-memory keypair for the controller (Node 0x0002),
     * signs a NOC for it using the stored Root CA, and returns the credentials
     * to send via POST /fabric/provision.
     */
    fun generateControllerCredentials(context: Context): ControllerCredentials {
        val id = getOrCreate(context)
        val rootCaDelegate = AppKeyPairDelegate(ALIAS_ROOT_CA)

        val kp    = KeyPairGenerator.getInstance("EC")
            .apply { initialize(ECGenParameterSpec("secp256r1")) }
            .generateKeyPair()
        val pub   = kp.public  as ECPublicKey
        val priv  = kp.private as ECPrivateKey

        val pubBytes = pubToUncompressed(pub)

        val noc = ChipDeviceController.createOperationalCertificate(
            rootCaDelegate, id.rootCaTlv, pubBytes,
            id.fabricId, CONTROLLER_NODE_ID, emptyList(),
            notBefore(), notAfter(),
        )

        val rawPriv = priv.s.toByteArray().let {
            val t = if (it.size > 32 && it[0] == 0.toByte()) it.drop(1).toByteArray() else it
            ByteArray((32 - t.size).coerceAtLeast(0)) + t
        }

        Log.i(TAG, "Generated controller NOC: fabricId=0x%016X node=0x%016X"
            .format(id.fabricId, CONTROLLER_NODE_ID))

        return ControllerCredentials(id.rootCaTlv, noc, rawPriv, id.ipk, id.fabricId)
    }

    // ── Private ───────────────────────────────────────────────────────────────

    private fun create(context: Context): FabricIdentity {
        Log.i(TAG, "Generating new app fabric identity…")

        // Start from a clean slate so cert validity/scheme changes take effect.
        wipeKeystore()

        val rootCa  = AppKeyPairDelegate(ALIAS_ROOT_CA).also  { it.generatePrivateKey() }
        val icac    = AppKeyPairDelegate(ALIAS_ICAC).also     { it.generatePrivateKey() }
        val appNode = AppKeyPairDelegate(ALIAS_APP_NODE).also { it.generatePrivateKey() }

        val rootCaTlv = ChipDeviceController.createRootCertificate(
            rootCa, ROOT_ISSUER_ID, null, notBefore(), notAfter(),
        )
        val icacTlv   = ChipDeviceController.createIntermediateCertificate(
            rootCa, rootCaTlv, icac.getPublicKey(), ICAC_ISSUER_ID, null,
            notBefore(), notAfter(),
        )
        val appNocTlv = ChipDeviceController.createOperationalCertificate(
            rootCa, rootCaTlv, appNode.getPublicKey(),
            FABRIC_ID, APP_NODE_ID, emptyList(),
            notBefore(), notAfter(),
        )
        val ipk = ByteArray(16).also { SecureRandom().nextBytes(it) }

        val identity = FabricIdentity(rootCaTlv, icacTlv, appNocTlv, ipk, FABRIC_ID)
        save(context, identity)
        cached = identity
        Log.i(TAG, "Fabric created: fabricId=0x%016X".format(FABRIC_ID))
        return identity
    }

    private fun load(context: Context): FabricIdentity? {
        val p = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

        // Regenerate when the stored fabric predates the current cert-minting scheme.
        if (p.getInt(K_VERSION, 1) != FABRIC_VERSION) {
            Log.w(TAG, "Stored fabric is v${p.getInt(K_VERSION, 1)} (want v$FABRIC_VERSION) — regenerating")
            return null
        }

        val rootB64 = p.getString(K_ROOT_TLV, null) ?: return null
        val icacB64 = p.getString(K_ICAC_TLV, null) ?: return null
        val nocB64  = p.getString(K_APP_NOC,  null) ?: return null
        val ipkB64  = p.getString(K_IPK,      null) ?: return null
        val fabId   = p.getLong(K_FABRIC_ID, 0L)
        if (fabId == 0L) return null

        // If Keystore keys were wiped (e.g. after factory reset), regenerate.
        if (!AppKeyPairDelegate(ALIAS_ROOT_CA).exists ||
            !AppKeyPairDelegate(ALIAS_ICAC).exists ||
            !AppKeyPairDelegate(ALIAS_APP_NODE).exists) {
            Log.w(TAG, "Keystore keys missing — regenerating fabric identity")
            return null
        }

        return FabricIdentity(
            rootCaTlv = Base64.decode(rootB64, Base64.DEFAULT),
            icacTlv   = Base64.decode(icacB64, Base64.DEFAULT),
            appNocTlv = Base64.decode(nocB64,  Base64.DEFAULT),
            ipk       = Base64.decode(ipkB64,  Base64.DEFAULT),
            fabricId  = fabId,
        ).also { cached = it; Log.d(TAG, "Loaded fabric: fabricId=0x%016X".format(fabId)) }
    }

    private fun save(context: Context, id: FabricIdentity) {
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE).edit().run {
            putInt   (K_VERSION,   FABRIC_VERSION)
            putString(K_ROOT_TLV,  Base64.encodeToString(id.rootCaTlv, Base64.DEFAULT))
            putString(K_ICAC_TLV,  Base64.encodeToString(id.icacTlv,   Base64.DEFAULT))
            putString(K_APP_NOC,   Base64.encodeToString(id.appNocTlv, Base64.DEFAULT))
            putString(K_IPK,       Base64.encodeToString(id.ipk,       Base64.DEFAULT))
            putLong  (K_FABRIC_ID, id.fabricId)
            apply()
        }
    }

    /** Deletes the fabric's Keystore keys so [create] starts from clean key material. */
    private fun wipeKeystore() {
        val ks = KeyStore.getInstance("AndroidKeyStore").also { it.load(null) }
        for (alias in listOf(ALIAS_ROOT_CA, ALIAS_ICAC, ALIAS_APP_NODE)) {
            if (ks.containsAlias(alias)) ks.deleteEntry(alias)
        }
    }

    private fun pubToUncompressed(pub: ECPublicKey): ByteArray {
        fun ByteArray.pad32(): ByteArray {
            val t = if (size > 32 && first() == 0.toByte()) drop(1).toByteArray() else this
            return ByteArray((32 - t.size).coerceAtLeast(0)) + t
        }
        return byteArrayOf(0x04.toByte()) +
            pub.w.affineX.toByteArray().pad32() +
            pub.w.affineY.toByteArray().pad32()
    }
}
