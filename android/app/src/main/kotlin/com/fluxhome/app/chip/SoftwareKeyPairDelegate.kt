package com.fluxhome.app.chip

import chip.devicecontroller.KeypairDelegate
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec
import javax.security.auth.x500.X500Principal
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import org.bouncycastle.pkcs.jcajce.JcaPKCS10CertificationRequestBuilder

/**
 * [KeypairDelegate] backed by an in-memory (software) P256 keypair.
 *
 * Unlike [AppKeyPairDelegate] (Android Keystore, non-exportable, can't CSR), this
 * holds the key material in process so it can:
 *   - produce a PKCS#10 CSR for fabric enrollment ([createCertificateSigningRequest]),
 *   - be persisted (PKCS#8 / X.509 encoded) and reloaded across restarts.
 *
 * Used for the app's operational identity when the app joins a controller-owned
 * fabric: the controller is the CA and signs this key's CSR (see
 * [AppFabricManager.generateOperationalCsr] / [AppFabricManager.importAdoptedIdentity]).
 *
 * Security note: the operational private key is NOT hardware-backed.  That is an
 * accepted trade-off — Android Keystore keys cannot generate a CSR, which the
 * controller-as-CA enrollment flow requires.  It is an *operational* node key
 * (a leaf identity the controller can revoke), never a root CA key.
 */
class SoftwareKeyPairDelegate private constructor(val keyPair: KeyPair) : KeypairDelegate {

    override fun generatePrivateKey() { /* key already supplied at construction */ }

    /** Uncompressed SEC1 point: 04 || X(32) || Y(32). */
    override fun getPublicKey(): ByteArray {
        val pub = keyPair.public as ECPublicKey
        val x = pub.w.affineX.toByteArray().pad32()
        val y = pub.w.affineY.toByteArray().pad32()
        return byteArrayOf(0x04.toByte()) + x + y
    }

    /** DER-encoded PKCS#10 CSR signed by the operational key. */
    override fun createCertificateSigningRequest(): ByteArray {
        val signer = JcaContentSignerBuilder("SHA256withECDSA").build(keyPair.private)
        return JcaPKCS10CertificationRequestBuilder(X500Principal("CN=Flux"), keyPair.public)
            .build(signer)
            .encoded
    }

    override fun ecdsaSignMessage(message: ByteArray): ByteArray =
        Signature.getInstance("SHA256withECDSA").run {
            initSign(keyPair.private)
            update(message)
            sign()
        }

    companion object {
        /** Generates a fresh secp256r1 keypair. */
        fun generate(): SoftwareKeyPairDelegate =
            SoftwareKeyPairDelegate(
                KeyPairGenerator.getInstance("EC")
                    .apply { initialize(ECGenParameterSpec("secp256r1")) }
                    .generateKeyPair(),
            )

        /** Reconstructs a delegate from persisted PKCS#8 private + X.509 public bytes. */
        fun fromEncoded(pkcs8Priv: ByteArray, x509Pub: ByteArray): SoftwareKeyPairDelegate {
            val kf = KeyFactory.getInstance("EC")
            return SoftwareKeyPairDelegate(
                KeyPair(
                    kf.generatePublic(X509EncodedKeySpec(x509Pub)),
                    kf.generatePrivate(PKCS8EncodedKeySpec(pkcs8Priv)),
                ),
            )
        }

        private fun ByteArray.pad32(): ByteArray {
            val t = if (size > 32 && first() == 0.toByte()) copyOfRange(1, size) else this
            return if (t.size < 32) ByteArray(32 - t.size) + t else t
        }
    }
}
