import Foundation
import Matter
import Security

// ─────────────────────────────────────────────────────────────────────────────
// MatterKeypair.swift
//
// P-256 ECDSA keypair stored in the Keychain, used as the NOC signer (root CA)
// for the Matter fabric.
//
// The private key is stored with kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
// so subscriptions continue to function while the screen is locked.
// ─────────────────────────────────────────────────────────────────────────────

final class MatterKeypair: NSObject, MTRKeypair {

    private static let appTag = "com.fluxhome.app.matter.noc-signer"
                                    .data(using: .utf8)!

    private let privateKey: SecKey

    // MARK: - Factory

    static func loadOrCreate() throws -> MatterKeypair {
        if let key = loadFromKeychain() {
            NSLog("[MatterKeypair] Loaded existing key from Keychain")
            return MatterKeypair(privateKey: key)
        }
        NSLog("[MatterKeypair] Generating new P-256 key pair")
        return MatterKeypair(privateKey: try generateAndStore())
    }

    private init(privateKey: SecKey) {
        self.privateKey = privateKey
    }

    // MARK: - MTRKeypair

    /// Returns the public key.  CF_RETURNS_RETAINED — caller owns the +1 ref.
    func copyPublicKey() -> SecKey {
        SecKeyCopyPublicKey(privateKey)!
    }

    /// Signs a message with ECDSA-SHA256 and returns the signature in raw
    /// P1363 format (r || s, each 32 bytes zero-padded), as required by
    /// the Matter SDK.
    func signMessageECDSA_RAW(_ message: Data) -> Data {
        var cfErr: Unmanaged<CFError>?
        guard let derSig = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            message as CFData,
            &cfErr
        ) as Data? else {
            NSLog("[MatterKeypair] signMessageECDSA_RAW failed: %@",
                  cfErr?.takeRetainedValue().localizedDescription ?? "unknown")
            return Data()
        }
        return derToRaw(derSig) ?? Data()
    }

    // MARK: - Keychain

    private static func loadFromKeychain() -> SecKey? {
        let query: [CFString: Any] = [
            kSecClass:              kSecClassKey,
            kSecAttrApplicationTag: appTag,
            kSecAttrKeyType:        kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass:       kSecAttrKeyClassPrivate,   // must load private key, not public
            kSecReturnRef:          true,
        ]
        var ref: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &ref) == errSecSuccess else {
            return nil
        }
        return (ref as! SecKey)
    }

    private static func generateAndStore() throws -> SecKey {
        let params: [CFString: Any] = [
            kSecAttrKeyType:        kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits:  256,
            kSecAttrIsPermanent:    true,
            kSecAttrApplicationTag: appTag,
            kSecAttrAccessible:     kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var cfErr: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(params as CFDictionary, &cfErr) else {
            throw cfErr!.takeRetainedValue() as Error
        }
        return key
    }

    // MARK: - DER → raw (r || s) conversion

    /// Converts an X9.62 DER ECDSA signature (SEQUENCE { INTEGER r, INTEGER s })
    /// to raw P1363 form (r and s each zero-padded to 32 bytes).
    private func derToRaw(_ der: Data) -> Data? {
        var bytes = [UInt8](der)
        // Must start with SEQUENCE (0x30)
        guard bytes.count > 4, bytes[0] == 0x30 else { return nil }

        // Skip SEQUENCE tag + length (support both short and long form)
        var offset = 2
        if bytes[1] == 0x81 { offset = 3 }

        func nextInteger() -> [UInt8]? {
            guard offset < bytes.count, bytes[offset] == 0x02 else { return nil }
            offset += 1
            guard offset < bytes.count else { return nil }
            let len = Int(bytes[offset]); offset += 1
            guard offset + len <= bytes.count else { return nil }
            defer { offset += len }
            return Array(bytes[offset ..< offset + len])
        }

        guard let r = nextInteger(), let s = nextInteger() else { return nil }

        func pad32(_ v: [UInt8]) -> [UInt8] {
            var a = v
            while a.count > 32 { a.removeFirst() }   // strip excess leading zeros
            while a.count < 32 { a.insert(0, at: 0) } // zero-pad left to 32 bytes
            return a
        }

        return Data(pad32(r) + pad32(s))
    }
}
