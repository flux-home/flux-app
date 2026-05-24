import Foundation
import Matter

// ─────────────────────────────────────────────────────────────────────────────
// MatterCommissioner.swift
//
// Async Matter commissioning using MTRDeviceController.
//
// Three paths (mirroring the Android MatterCommissioner.kt):
//   commission(...)       — BLE. Requires WiFi or Thread credentials.
//   commissionViaIp(...)  — On-network via DNS-SD using discriminator + pin.
//   commissionViaCode(...)— On-network via setup code string (QR / manual).
//
// If no credentials are available, emits "🔌 CREDENTIALS_NEEDED:WIFI" on the
// commission_events channel and suspends until Flutter calls provideCredentials.
//
// One instance per commissioning attempt.  Not reusable.
// ─────────────────────────────────────────────────────────────────────────────

enum CommissionError: LocalizedError {
    case sdkNotAvailable
    case invalidPayload(String)
    case setupFailed(Error?)
    case commissionFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .sdkNotAvailable:       return "Matter SDK is not available"
        case .invalidPayload(let s): return "Invalid payload: \(s)"
        case .setupFailed(let e):    return "PASE setup failed: \(e?.localizedDescription ?? "unknown")"
        case .commissionFailed(let e): return "Commissioning failed: \(e?.localizedDescription ?? "unknown")"
        }
    }
}

final class MatterCommissioner: NSObject {

    private let lock           = NSLock()
    private var onEvent:       (String) -> Void = { _ in }
    private var trackedNodeID: UInt64 = 0

    private var paseCont:  CheckedContinuation<Void, Error>?
    private var commCont:  CheckedContinuation<UInt64, Error>?
    private var credsCont: CheckedContinuation<MTRCommissioningParameters, Error>?

    // ── BLE commissioning ──────────────────────────────────────────────────

    func commission(
        payload:          MTRSetupPayload,
        wifiSsid:         String?,
        wifiPassword:     String?,
        threadDatasetHex: String?,
        nodeId:           UInt64,
        onEvent:          @escaping (String) -> Void
    ) async throws -> UInt64 {

        guard let ctrl = ChipClient.shared.controller else {
            throw CommissionError.sdkNotAvailable
        }
        self.onEvent = onEvent
        self.trackedNodeID = nodeId
        ctrl.setDeviceControllerDelegate(self, queue: .global(qos: .userInitiated))
        onEvent("⚙ Starting BLE commissioning (PASE)…")

        // 1 ── PASE session
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            withLock { paseCont = cont }
            do {
                try ctrl.setupCommissioningSession(with:
                    payload, newNodeID: NSNumber(value: nodeId))
            } catch {
                withLock { paseCont = nil }
                cont.resume(throwing: error)
            }
        }

        // 2 ── Credentials (wait for Flutter if not available)
        let params = try await resolveCommissioningParams(
            wifiSsid: wifiSsid, wifiPassword: wifiPassword,
            threadDatasetHex: threadDatasetHex)

        // 3 ── Full commissioning
        onEvent("🔗 PASE established — commissioning…")
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UInt64, Error>) in
            withLock { commCont = cont }
            do {
                try ctrl.commissionNode(withID:
                    NSNumber(value: nodeId), commissioningParams: params)
            } catch {
                withLock { commCont = nil }
                cont.resume(throwing: error)
            }
        }
    }

    // ── On-network commissioning via discriminator + pin ──────────────────

    func commissionViaIp(
        ipAddress:     String,
        port:          UInt16,
        discriminator: Int,
        setupPinCode:  UInt32,
        nodeId:        UInt64,
        onEvent:       @escaping (String) -> Void
    ) async throws -> UInt64 {

        guard let ctrl = ChipClient.shared.controller else {
            throw CommissionError.sdkNotAvailable
        }
        self.onEvent = onEvent
        self.trackedNodeID = nodeId

        onEvent("🌐 Commissioning via IP \(ipAddress):\(port)…")
        onEvent("⚙ Starting CHIP commissioning (on-network PASE)…")

        // Build an ON_NETWORK payload from pin + long discriminator.
        // The SDK will use DNS-SD to discover the device.
        let payload = MTRSetupPayload(
            setupPasscode: NSNumber(value: setupPinCode),
            discriminator: NSNumber(value: discriminator))
        payload.discoveryCapabilities = .onNetwork

        ctrl.setDeviceControllerDelegate(self, queue: .global(qos: .userInitiated))

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            withLock { paseCont = cont }
            do {
                try ctrl.setupCommissioningSession(with:
                    payload, newNodeID: NSNumber(value: nodeId))
            } catch {
                withLock { paseCont = nil }
                cont.resume(throwing: error)
            }
        }

        let params = MTRCommissioningParameters()
        params.failSafeTimeout = NSNumber(value: 600)
        onEvent("🔗 PASE established — commissioning…")

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UInt64, Error>) in
            withLock { commCont = cont }
            do {
                try ctrl.commissionNode(withID:
                    NSNumber(value: nodeId), commissioningParams: params)
            } catch {
                withLock { commCont = nil }
                cont.resume(throwing: error)
            }
        }
    }

    // ── On-network commissioning via setup code string ─────────────────────

    func commissionViaCode(
        setupCode: String,
        nodeId:    UInt64,
        onEvent:   @escaping (String) -> Void
    ) async throws -> UInt64 {

        guard let ctrl = ChipClient.shared.controller else {
            throw CommissionError.sdkNotAvailable
        }
        self.onEvent = onEvent
        self.trackedNodeID = nodeId

        onEvent("🔍 Discovering device via DNS-SD…")
        onEvent("⚙ Starting on-network commissioning (PASE)…")

        let payload: MTRSetupPayload
        if #available(iOS 17.6, *) {
            guard let p = try? MTRSetupPayload(payload: setupCode) else {
                throw CommissionError.invalidPayload(setupCode)
            }
            payload = p
        } else {
            guard let p = try? MTRSetupPayload(onboardingPayload:  setupCode) else {
                throw CommissionError.invalidPayload(setupCode)
            }
            payload = p
        }

        ctrl.setDeviceControllerDelegate(self, queue: .global(qos: .userInitiated))

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            withLock { paseCont = cont }
            do {
                try ctrl.setupCommissioningSession(with:
                    payload, newNodeID: NSNumber(value: nodeId))
            } catch {
                withLock { paseCont = nil }
                cont.resume(throwing: error)
            }
        }

        let params = MTRCommissioningParameters()
        params.failSafeTimeout = NSNumber(value: 600)
        onEvent("🔗 PASE established — commissioning…")

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UInt64, Error>) in
            withLock { commCont = cont }
            do {
                try ctrl.commissionNode(withID:
                    NSNumber(value: nodeId), commissioningParams: params)
            } catch {
                withLock { commCont = nil }
                cont.resume(throwing: error)
            }
        }
    }

    // ── Deferred credentials ───────────────────────────────────────────────

    func provideCredentials(ssid: String?, password: String?, threadTlv: Data?) {
        withLock {
            guard let cont = credsCont else { return }
            credsCont = nil
            let params = buildParams(wifiSsid: ssid, wifiPassword: password, threadTlv: threadTlv)
            cont.resume(returning: params)
        }
    }

    // ── Private helpers ────────────────────────────────────────────────────

    private func resolveCommissioningParams(
        wifiSsid:         String?,
        wifiPassword:     String?,
        threadDatasetHex: String?
    ) async throws -> MTRCommissioningParameters {

        let safeSsid = wifiSsid?.trimmingCharacters(in: .whitespaces)
        let hasWifi  = safeSsid?.isEmpty == false
        let tlv      = threadDatasetHex.flatMap { Data(hexStr: $0) }
        let hasTlv   = tlv.map { !$0.isEmpty } ?? false

        if hasWifi || hasTlv {
            return buildParams(wifiSsid: safeSsid, wifiPassword: wifiPassword, threadTlv: tlv)
        }

        onEvent("🔌 CREDENTIALS_NEEDED:WIFI")
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<MTRCommissioningParameters, Error>) in
            withLock { credsCont = cont }
        }
    }

    private func buildParams(wifiSsid: String?, wifiPassword: String?,
                             threadTlv: Data?) -> MTRCommissioningParameters {
        let params = MTRCommissioningParameters()
        params.failSafeTimeout = NSNumber(value: 600)
        if let ssid = wifiSsid, !ssid.isEmpty {
            params.wifiSSID        = ssid.data(using: .utf8)
            params.wifiCredentials = (wifiPassword ?? "").data(using: .utf8)
            onEvent("📶 Using Wi-Fi SSID: \(ssid)")
        }
        if let data = threadTlv, !data.isEmpty {
            params.threadOperationalDataset = data
            onEvent("🧵 Using Thread operational dataset (\(data.count) bytes)")
        }
        return params
    }

    private func withLock(_ body: () -> Void) { lock.lock(); body(); lock.unlock() }
}

// ── MTRDeviceControllerDelegate ────────────────────────────────────────────

extension MatterCommissioner: MTRDeviceControllerDelegate {

    func controller(_ controller: MTRDeviceController,
                    statusUpdate status: MTRCommissioningStatus) {
        switch status {
        case .success: onEvent("✓ Status: success")
        case .failed:  onEvent("✗ Status: failed")
        default: break
        }
    }

    func controller(_ controller: MTRDeviceController,
                    commissioningSessionEstablishmentDone error: Error?) {
        withLock {
            guard let cont = paseCont else { return }
            paseCont = nil
            if let error { onEvent("✗ PASE failed: \(error.localizedDescription)"); cont.resume(throwing: error) }
            else         { onEvent("✓ PASE session established"); cont.resume() }
        }
    }

    // iOS 17.6+ — most specific, called in preference to the two below.
    @available(iOS 17.6, *)
    func controller(_ controller: MTRDeviceController,
                    commissioningComplete error: Error?,
                    nodeID: NSNumber?,
                    metrics: MTRMetrics) {
        finishCommissioning(error: error, nodeID: nodeID?.uint64Value)
    }

    // iOS 17.0–17.5.
    @available(iOS 17.0, *)
    func controller(_ controller: MTRDeviceController,
                    commissioningComplete error: Error?,
                    nodeID: NSNumber?) {
        if #available(iOS 17.6, *) { return }
        finishCommissioning(error: error, nodeID: nodeID?.uint64Value)
    }

    // iOS 16.4 fallback — nodeID not available, use trackedNodeID.
    func controller(_ controller: MTRDeviceController,
                    commissioningComplete error: Error?) {
        if #available(iOS 17.0, *) { return }
        finishCommissioning(error: error, nodeID: nil)
    }

    private func finishCommissioning(error: Error?, nodeID: UInt64?) {
        withLock {
            guard let cont = commCont else { return }
            commCont = nil
            if let err = error {
                onEvent("✗ Commissioning failed: \(err.localizedDescription)")
                cont.resume(throwing: err)
            } else {
                let nid = nodeID ?? trackedNodeID
                onEvent("🎉 Done! Node 0x\(String(format: "%016X", nid))")
                cont.resume(returning: nid)
            }
        }
    }
}
