import Foundation
import Matter
import Security

// ─────────────────────────────────────────────────────────────────────────────
// FluxCertIssuer.swift
//
// MTROperationalCertificateIssuer used by the modern (iOS 17.6+) controller
// initialization path.  Signs device NOCs with our root keypair (MatterKeypair).
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 16.4, *)
final class FluxCertIssuer: NSObject, MTROperationalCertificateIssuer {

    private let keypair:  MatterKeypair
    private let rootCert: Data
    private let fabricID: UInt64

    init(keypair: MatterKeypair, rootCert: Data, fabricID: UInt64) {
        self.keypair  = keypair
        self.rootCert = rootCert
        self.fabricID = fabricID
    }

    // Skip Apple's PAA/CD trust-anchor checks — required for dev devices.
    var shouldSkipAttestationCertificateValidation: Bool { true }

    func issueOperationalCertificate(
        forRequest csrInfo: MTROperationalCSRInfo,
        attestationInfo: MTRDeviceAttestationInfo,
        controller: MTRDeviceController,
        completion: @escaping (MTROperationalCertificateChain?, Error?) -> Void
    ) {
        // 1. Extract device public key from DER-encoded CSR.
        let rawPubKey: Data
        do {
            rawPubKey = try MTRCertificates.publicKey(fromCSR: csrInfo.csr)
        } catch {
            completion(nil, makeErr(-1, "publicKey(fromCSR:) failed: \(error)"))
            return
        }
        guard !rawPubKey.isEmpty else {
            completion(nil, makeErr(-1, "publicKey(fromCSR:) returned empty data"))
            return
        }

        // 2. Import raw P-256 uncompressed point into SecKey.
        let keyAttrs: [CFString: Any] = [
            kSecAttrKeyType:  kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
        ]
        var cfErr: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(rawPubKey as CFData,
                                                   keyAttrs as CFDictionary,
                                                   &cfErr) else {
            completion(nil, cfErr?.takeRetainedValue() as Error?
                           ?? makeErr(-2, "SecKeyCreateWithData failed"))
            return
        }

        // 3. Random operational node ID for this device.
        var nodeIDBytes: UInt64 = 0
        withUnsafeMutableBytes(of: &nodeIDBytes) {
            _ = SecRandomCopyBytes(kSecRandomDefault, 8, $0.baseAddress!)
        }
        let nodeID = max(1, nodeIDBytes & 0xFFFFFFEFFFFFFFFF)

        // 4. Issue the operational certificate (NOC).
        do {
            let noc = try MTRCertificates.createOperationalCertificate(
                keypair,
                signingCertificate:    rootCert,
                operationalPublicKey:  publicKey,
                fabricID:              NSNumber(value: fabricID),
                nodeID:                NSNumber(value: nodeID),
                caseAuthenticatedTags: nil
            )
            NSLog("[FluxCertIssuer] Issued NOC — nodeID=0x%016llX", nodeID)
            let chain = MTROperationalCertificateChain(
                operationalCertificate:  noc,
                intermediateCertificate: nil,
                rootCertificate:         rootCert,
                adminSubject:            nil
            )
            completion(chain, nil)
        } catch {
            completion(nil, error)
        }
    }

    private func makeErr(_ code: Int, _ msg: String) -> NSError {
        NSError(domain: "FluxCertIssuer", code: code,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
