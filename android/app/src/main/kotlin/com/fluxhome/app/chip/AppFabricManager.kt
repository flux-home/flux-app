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

// ── Adopted identity (controller-owned fabric the app enrolled onto) ──────────
// When present these take precedence over the locally-generated fabric above:
// the app operates as a leaf node whose NOC was issued by the controller (CA).
private const val K_AD_ROOT     = "ad_root_tlv"
private const val K_AD_ICAC     = "ad_icac_tlv"   // may be absent (single-level CA)
private const val K_AD_NOC      = "ad_noc_tlv"
private const val K_AD_IPK      = "ad_ipk"
private const val K_AD_FABRIC   = "ad_fabric_id"
private const val K_AD_NODE     = "ad_node_id"
private const val K_AD_OP_PRIV  = "ad_op_priv"    // operational key, PKCS#8 (software)
private const val K_AD_OP_PUB   = "ad_op_pub"     // operational key, X.509
// Pending operational keypair: generated for a CSR, kept until the controller
// returns the matching signed NOC via importAdoptedIdentity.
private const val K_PEND_PRIV   = "pending_op_priv"
private const val K_PEND_PUB    = "pending_op_pub"

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

    /** Controller-issued operational identity installed via [importAdoptedIdentity]. */
    data class AdoptedIdentity(
        val rootCaTlv: ByteArray,
        val icacTlv:   ByteArray?,
        val nocTlv:    ByteArray,
        val ipk:       ByteArray,
        val fabricId:  Long,
        val nodeId:    Long,
        val opPrivPkcs8: ByteArray,
        val opPubX509:   ByteArray,
    )

    /**
     * The app's operational identity for the CHIP controller.
     *
     * Prefers an [AdoptedIdentity] (the app joined a controller-owned fabric:
     * software operational key + controller-issued NOC).  Falls back to the
     * locally-generated fabric (legacy / standalone, app-as-CA) otherwise.
     */
    fun operationalKeyConfig(context: Context): OperationalKeyConfig {
        val adopted = adoptedIdentity(context)
        if (adopted != null) {
            val kp = SoftwareKeyPairDelegate.fromEncoded(adopted.opPrivPkcs8, adopted.opPubX509)
            return OperationalKeyConfig(
                kp,
                adopted.rootCaTlv,
                adopted.icacTlv,        // may be null (single-level CA)
                adopted.nocTlv,
                adopted.ipk,
            )
        }
        val id = getOrCreate(context)
        return OperationalKeyConfig(
            AppKeyPairDelegate(ALIAS_APP_NODE),
            id.rootCaTlv,
            null,           // no ICAC in the controller's own chain
            id.appNocTlv,
            id.ipk,
        )
    }

    // ── Controller-owned fabric: enrollment (CSR) + adoption (import) ──────────

    fun hasAdopted(context: Context): Boolean = adoptedIdentity(context) != null

    /**
     * The app's current operational **raw** fabric id (NOT compressed): the
     * controller-issued fabric id when adopted, else the local fabric's id.
     * The controller's `/info.fabric_id` reports this same raw value, so this
     * is what [FabricSyncService] compares for membership.
     */
    fun operationalRawFabricId(context: Context): Long =
        adoptedIdentity(context)?.fabricId ?: getOrCreate(context).fabricId

    /**
     * Generates a fresh operational keypair, persists it as *pending*, and
     * returns its DER PKCS#10 CSR for [FluxCoapService.enrollFabric].  The
     * matching signed NOC arrives later in [importAdoptedIdentity].
     */
    fun generateOperationalCsr(context: Context): ByteArray {
        val kp  = SoftwareKeyPairDelegate.generate()
        val csr = kp.createCertificateSigningRequest()
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE).edit().run {
            putString(K_PEND_PRIV, Base64.encodeToString(kp.keyPair.private.encoded, Base64.DEFAULT))
            putString(K_PEND_PUB,  Base64.encodeToString(kp.keyPair.public.encoded,  Base64.DEFAULT))
            apply()
        }
        Log.i(TAG, "Generated operational CSR (${csr.size} bytes) for fabric enrollment")
        return csr
    }

    /**
     * Installs the controller-issued credentials ([nocTlv] signed by the
     * controller CA for the pending operational key) as the app's adopted
     * identity.  Returns false if there is no pending keypair to match.
     */
    fun importAdoptedIdentity(
        context: Context,
        rootCaTlv: ByteArray,
        icacTlv:   ByteArray?,
        nocTlv:    ByteArray,
        ipk:       ByteArray,
        fabricId:  Long,
        nodeId:    Long,
    ): Boolean {
        val p = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val priv = p.getString(K_PEND_PRIV, null) ?: run {
            Log.e(TAG, "importAdoptedIdentity: no pending operational keypair")
            return false
        }
        val pub = p.getString(K_PEND_PUB, null) ?: return false

        p.edit().run {
            putString(K_AD_ROOT,   Base64.encodeToString(rootCaTlv, Base64.DEFAULT))
            if (icacTlv != null && icacTlv.isNotEmpty()) {
                putString(K_AD_ICAC, Base64.encodeToString(icacTlv, Base64.DEFAULT))
            } else {
                remove(K_AD_ICAC)
            }
            putString(K_AD_NOC,    Base64.encodeToString(nocTlv, Base64.DEFAULT))
            putString(K_AD_IPK,    Base64.encodeToString(ipk,    Base64.DEFAULT))
            putLong  (K_AD_FABRIC, fabricId)
            putLong  (K_AD_NODE,   nodeId)
            putString(K_AD_OP_PRIV, priv)
            putString(K_AD_OP_PUB,  pub)
            remove(K_PEND_PRIV)
            remove(K_PEND_PUB)
            apply()
        }
        Log.i(TAG, "Imported adopted identity: fabricId=0x%016X node=0x%016X".format(fabricId, nodeId))
        return true
    }

    /** Removes the adopted identity so the app reverts to its local fabric.
     *  Uses commit() (synchronous) so it is durable before a relaunch. */
    fun clearAdopted(context: Context) {
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE).edit().run {
            remove(K_AD_ROOT); remove(K_AD_ICAC); remove(K_AD_NOC); remove(K_AD_IPK)
            remove(K_AD_FABRIC); remove(K_AD_NODE); remove(K_AD_OP_PRIV); remove(K_AD_OP_PUB)
            commit()
        }
        Log.w(TAG, "Cleared adopted identity — reverted to local fabric")
    }

    fun adoptedIdentity(context: Context): AdoptedIdentity? {
        val p = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val root = p.getString(K_AD_ROOT, null) ?: return null
        val noc  = p.getString(K_AD_NOC,  null) ?: return null
        val ipk  = p.getString(K_AD_IPK,  null) ?: return null
        val priv = p.getString(K_AD_OP_PRIV, null) ?: return null
        val pub  = p.getString(K_AD_OP_PUB,  null) ?: return null
        val icac = p.getString(K_AD_ICAC, null)
        return AdoptedIdentity(
            rootCaTlv   = Base64.decode(root, Base64.DEFAULT),
            icacTlv     = icac?.let { Base64.decode(it, Base64.DEFAULT) },
            nocTlv      = Base64.decode(noc, Base64.DEFAULT),
            ipk         = Base64.decode(ipk, Base64.DEFAULT),
            fabricId    = p.getLong(K_AD_FABRIC, 0L),
            nodeId      = p.getLong(K_AD_NODE, 0L),
            opPrivPkcs8 = Base64.decode(priv, Base64.DEFAULT),
            opPubX509   = Base64.decode(pub, Base64.DEFAULT),
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
