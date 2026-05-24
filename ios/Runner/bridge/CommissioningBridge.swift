import Flutter
import Foundation
import Matter
import Security

// ─────────────────────────────────────────────────────────────────────────────
// CommissioningBridge.swift
//
// Handles commissioning MethodChannel calls and routes them to
// MatterCommissioner.  Mirrors Android's CommissioningBridge.kt.
// ─────────────────────────────────────────────────────────────────────────────

final class CommissioningBridge {

    private let core: BridgeCore
    private var activeCommissioner: MatterCommissioner?

    init(core: BridgeCore) { self.core = core }

    // MARK: - Commission via BLE

    func commissionDevice(
        payload:          String,
        wifiSsid:         String?,
        wifiPassword:     String?,
        threadDatasetHex: String?,
        result:           @escaping FlutterResult
    ) {
        core.requireChip(result: result) { [weak self] in
            guard let self else { return }

            let mtrPayload: MTRSetupPayload
            if #available(iOS 17.6, *) {
                guard let p = try? MTRSetupPayload(payload: payload) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "PARSE_ERROR",
                                            message: "Invalid payload: \(payload)",
                                            details: nil))
                    }
                    return
                }
                mtrPayload = p
            } else {
                guard let p = try? MTRSetupPayload(onboardingPayload:  payload) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "PARSE_ERROR",
                                            message: "Invalid payload: \(payload)",
                                            details: nil))
                    }
                    return
                }
                mtrPayload = p
            }

            let nodeId      = Self.randomNodeID()
            let commissioner = MatterCommissioner()
            self.activeCommissioner = commissioner

            let commissionedNodeId = try await commissioner.commission(
                payload:          mtrPayload,
                wifiSsid:         wifiSsid,
                wifiPassword:     wifiPassword,
                threadDatasetHex: threadDatasetHex,
                nodeId:           nodeId,
                onEvent:          { [weak self] msg in self?.core.emitEvent(msg) }
            )
            self.activeCommissioner = nil

            let deviceTypeId = await self.readPrimaryDeviceType(nodeId: commissionedNodeId)
            DispatchQueue.main.async {
                result(["nodeId": Int(commissionedNodeId), "deviceTypeId": deviceTypeId as Any])
            }
        }
    }

    // MARK: - Commission via IP / on-network

    func commissionViaIp(
        ipAddress:     String,
        port:          Int,
        discriminator: Int,
        setupPinCode:  Int,
        result:        @escaping FlutterResult
    ) {
        core.requireChip(result: result) { [weak self] in
            guard let self else { return }
            let nodeId       = Self.randomNodeID()
            let commissioner = MatterCommissioner()
            self.activeCommissioner = commissioner

            let commissionedNodeId = try await commissioner.commissionViaIp(
                ipAddress:     ipAddress,
                port:          UInt16(clamping: port),
                discriminator: discriminator,
                setupPinCode:  UInt32(clamping: setupPinCode),
                nodeId:        nodeId,
                onEvent:       { [weak self] msg in self?.core.emitEvent(msg) }
            )
            self.activeCommissioner = nil

            let deviceTypeId = await self.readPrimaryDeviceType(nodeId: commissionedNodeId)
            DispatchQueue.main.async {
                result(["nodeId": Int(commissionedNodeId), "deviceTypeId": deviceTypeId as Any])
            }
        }
    }

    func commissionViaCode(setupCode: String, result: @escaping FlutterResult) {
        core.requireChip(result: result) { [weak self] in
            guard let self else { return }
            let nodeId       = Self.randomNodeID()
            let commissioner = MatterCommissioner()
            self.activeCommissioner = commissioner

            let commissionedNodeId = try await commissioner.commissionViaCode(
                setupCode: setupCode,
                nodeId:    nodeId,
                onEvent:   { [weak self] msg in self?.core.emitEvent(msg) }
            )
            self.activeCommissioner = nil

            let deviceTypeId = await self.readPrimaryDeviceType(nodeId: commissionedNodeId)
            DispatchQueue.main.async {
                result(["nodeId": Int(commissionedNodeId), "deviceTypeId": deviceTypeId as Any])
            }
        }
    }

    // MARK: - Deferred credentials

    func provideCredentials(ssid: String?, password: String?,
                            threadDatasetHex: String?, result: @escaping FlutterResult) {
        let tlv = threadDatasetHex.flatMap { Data(hexStr: $0) }
        activeCommissioner?.provideCredentials(ssid: ssid, password: password, threadTlv: tlv)
        DispatchQueue.main.async { result(nil) }
    }

    // MARK: - Parse payload

    func parsePayload(_ payloadStr: String, result: @escaping FlutterResult) {
        Task {
            // Wait up to 8 s in case the SDK is still starting.
            if !ChipClient.shared.isAvailable {
                _ = await Task.detached(priority: .userInitiated) {
                    ChipClient.shared.waitUntilReady(timeout: 8.0)
                }.value
            }
            guard ChipClient.shared.isAvailable else {
                let reason = ChipClient.shared.startupError ?? "SDK startup timed out"
                DispatchQueue.main.async {
                    result(FlutterError(code: "CHIP_SDK_UNAVAILABLE",
                                        message: reason, details: nil))
                }
                return
            }

            let payload: MTRSetupPayload?
            if #available(iOS 17.6, *) {
                payload = try? MTRSetupPayload(payload: payloadStr)
            } else {
                payload = try? MTRSetupPayload(onboardingPayload: payloadStr)
            }

            guard let p = payload else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "PARSE_ERROR",
                                        message: "Invalid payload: \(payloadStr)",
                                        details: nil))
                }
                return
            }

            DispatchQueue.main.async {
                result([
                    "vendorId":              p.vendorID.intValue,
                    "productId":             p.productID.intValue,
                    "discriminator":         p.discriminator.intValue,
                    "hasShortDiscriminator": p.hasShortDiscriminator,
                    "setupPinCode":          p.setUpPINCode.intValue,
                    "discoveryCapabilities": self.capStrings(p.discoveryCapabilities),
                ] as [String: Any])
            }
        }
    }

    // MARK: - Remove / share (stubs — Task 7)

    func removeDevice(nodeId: UInt64, result: @escaping FlutterResult) {
        // TODO Task 7: MTRBaseClusterOperationalCredentials.removeFabric
        DispatchQueue.main.async { result(false) }
    }

    func shareDevice(nodeId: UInt64, vendorId: Int, productId: Int,
                     result: @escaping FlutterResult) {
        // TODO Task 7: MTRBaseDevice.openCommissioningWindowWithSetupPasscode
        DispatchQueue.main.async {
            result(FlutterError(code: "NOT_IMPLEMENTED",
                                message: "shareDevice not yet implemented on iOS",
                                details: nil))
        }
    }

    // MARK: - Helpers

    private func readPrimaryDeviceType(nodeId: UInt64) async -> Int? {
        // TODO Task 7: read DeviceTypeList from Descriptor cluster.
        return nil
    }

    static func randomNodeID() -> UInt64 {
        var bytes: UInt64 = 0
        withUnsafeMutableBytes(of: &bytes) {
            _ = SecRandomCopyBytes(kSecRandomDefault, 8, $0.baseAddress!)
        }
        return max(1, bytes & 0xFFFFFFEFFFFFFFFF)
    }

    private func capStrings(_ caps: MTRDiscoveryCapabilities) -> [String] {
        var result = [String]()
        if caps.contains(.onNetwork) { result.append("ON_NETWORK") }
        if caps.contains(.BLE)       { result.append("BLE") }
        if caps.contains(.softAP)    { result.append("SOFT_AP") }
        return result.isEmpty ? ["BLE"] : result
    }
}

// MARK: - Data hex helper

extension Data {
    /// Initialise from a hex string.  Returns nil for odd-length or non-hex input.
    init?(hexStr raw: String) {
        let hex = raw.filter(\.isHexDigit)
        guard !hex.isEmpty, hex.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            guard let byte = UInt8(hex[idx..<next], radix: 16) else { return nil }
            bytes.append(byte)
            idx = next
        }
        self = Data(bytes)
    }
}
