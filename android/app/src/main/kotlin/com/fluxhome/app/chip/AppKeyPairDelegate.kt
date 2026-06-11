package com.fluxhome.app.chip

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import chip.devicecontroller.KeypairDelegate
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec

/**
 * [KeypairDelegate] backed by Android Keystore.
 *
 * The private key never leaves secure hardware.  Used for the app's Root CA
 * (signing certs) and for the app's own operational node key (CASE sessions).
 *
 * [generatePrivateKey] is idempotent — it is safe to call on every app start.
 */
class AppKeyPairDelegate(private val alias: String) : KeypairDelegate {

    private val ks: KeyStore = KeyStore.getInstance("AndroidKeyStore").also { it.load(null) }

    val exists: Boolean get() = ks.containsAlias(alias)

    override fun generatePrivateKey() {
        if (ks.containsAlias(alias)) return
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
            .apply {
                initialize(
                    KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
                        .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                        .setDigests(KeyProperties.DIGEST_SHA256)
                        .build()
                )
            }
            .generateKeyPair()
    }

    // Returns uncompressed SEC1 point: 04 || X (32 bytes) || Y (32 bytes).
    override fun getPublicKey(): ByteArray {
        val pub = ks.getCertificate(alias)?.publicKey as? ECPublicKey
            ?: error("Key '$alias' not in Keystore — call generatePrivateKey() first")
        val x = pub.w.affineX.toByteArray().trimAndPad32()
        val y = pub.w.affineY.toByteArray().trimAndPad32()
        return byteArrayOf(0x04.toByte()) + x + y
    }

    override fun createCertificateSigningRequest(): ByteArray =
        throw KeypairDelegate.KeypairException("CSR not supported for KeyStore-backed key")

    override fun ecdsaSignMessage(message: ByteArray): ByteArray {
        val key = ks.getKey(alias, null) as java.security.PrivateKey
        return Signature.getInstance("SHA256withECDSA").run {
            initSign(key)
            update(message)
            sign()
        }
    }

    private companion object {
        // BigInteger.toByteArray() may have a leading 0x00 sign byte; P-256 coords are 32 bytes.
        fun ByteArray.trimAndPad32(): ByteArray {
            val trimmed = if (size > 32 && this[0] == 0.toByte()) copyOfRange(1, size) else this
            return if (trimmed.size < 32) ByteArray(32 - trimmed.size) + trimmed else trimmed
        }
    }
}
