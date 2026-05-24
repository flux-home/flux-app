import Flutter
import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// BridgeCore.swift
//
// Shared infrastructure injected into every sub-bridge.
//
// Mirrors Android's BridgeCore.kt: owns the background dispatch queue,
// event-channel sinks, and the requireChip guard used by every bridge method.
// ─────────────────────────────────────────────────────────────────────────────

final class BridgeCore {

    /// Background queue used for all CHIP SDK calls.
    /// Must not be used for Flutter method-channel result calls (use main queue).
    let chipQueue = DispatchQueue(
        label: "com.fluxhome.app.matter.bridge",
        qos: .userInitiated
    )

    // ── EventChannel sinks ────────────────────────────────────────────────────

    /// Set by MatterBridge when the Dart side starts listening on
    /// `com.fluxhome.app/commission_events`.
    var commissionEventSink: FlutterEventSink?

    /// Set by MatterBridge when the Dart side starts listening on
    /// `com.fluxhome.app/device_state`.
    var deviceStateSink: FlutterEventSink?

    /// Emit a plain-text commissioning progress line to Flutter.
    func emitEvent(_ msg: String) {
        DispatchQueue.main.async { [self] in
            commissionEventSink?(msg)
        }
    }

    /// Emit a device-state payload to Flutter.
    /// Keys must match the shape decoded by MatterChannel.deviceStateUpdates.
    func emitDeviceState(_ payload: [String: Any?]) {
        DispatchQueue.main.async { [self] in
            // FlutterEventSink accepts Any?, cast through AnyHashable.
            deviceStateSink?(payload as [AnyHashable: Any?])
        }
    }

    // ── Guard ─────────────────────────────────────────────────────────────────

    /// Checks that the Matter SDK is available, then runs `block` on `chipQueue`.
    /// Reports CHIP_SDK_UNAVAILABLE or CHIP_ERROR back to Flutter if anything
    /// goes wrong.
    func requireChip(result: @escaping FlutterResult,
                     block: @escaping () async throws -> Void) {
        guard ChipClient.shared.isAvailable else {
            result(FlutterError(
                code:    "CHIP_SDK_UNAVAILABLE",
                message: "Matter SDK not ready — ChipClient.start() must succeed first.",
                details: nil
            ))
            return
        }
        Task {
            do {
                try await block()
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code:    "CHIP_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
}
