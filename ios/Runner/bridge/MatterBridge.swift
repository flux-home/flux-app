import Flutter
import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// MatterBridge.swift
//
// Main MethodChannel coordinator.  Replaces StubBridge.
//
// Owns BridgeCore + all sub-bridges.  Routes every MethodChannel call to the
// appropriate bridge.  Methods not yet ported return stub/empty values — these
// will be replaced task by task (Tasks 5–7).
//
// Channel names must match matter_channel.dart exactly.
// ─────────────────────────────────────────────────────────────────────────────

final class MatterBridge {

    private static let kMethod  = "com.fluxhome.app/matter"
    private static let kCommEvt = "com.fluxhome.app/commission_events"
    private static let kDevEvt  = "com.fluxhome.app/device_state"

    private let core          = BridgeCore()
    private let commissioning: CommissioningBridge

    init() {
        commissioning = CommissioningBridge(core: core)
    }

    // ── Channel registration ──────────────────────────────────────────────────

    static func register(messenger: FlutterBinaryMessenger) {
        let bridge = MatterBridge()

        // MethodChannel
        FlutterMethodChannel(name: kMethod, binaryMessenger: messenger)
            .setMethodCallHandler { call, result in
                bridge.handle(call, result: result)
            }

        // commission_events EventChannel
        FlutterEventChannel(name: kCommEvt, binaryMessenger: messenger)
            .setStreamHandler(SinkHolder { bridge.core.commissionEventSink = $0 })

        // device_state EventChannel
        FlutterEventChannel(name: kDevEvt, binaryMessenger: messenger)
            .setStreamHandler(SinkHolder { bridge.core.deviceStateSink = $0 })
    }

    // ── Method call router ────────────────────────────────────────────────────

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args   = call.arguments as? [String: Any]
        let nodeId = nodeIdFrom(args)

        switch call.method {

        // ── Commissioning ──────────────────────────────────────────────────
        case "commissionDevice":
            commissioning.commissionDevice(
                payload:          args?["payload"]          as? String ?? "",
                wifiSsid:         args?["wifiSsid"]         as? String,
                wifiPassword:     args?["wifiPassword"]      as? String,
                threadDatasetHex: args?["threadDatasetHex"] as? String,
                result:           result
            )

        case "commissionViaIp":
            commissioning.commissionViaIp(
                ipAddress:     args?["ipAddress"]     as? String ?? "",
                port:          args?["port"]          as? Int    ?? 5540,
                discriminator: args?["discriminator"] as? Int    ?? 0,
                setupPinCode:  args?["setupPinCode"]  as? Int    ?? 0,
                result:        result
            )

        case "commissionViaCode":
            commissioning.commissionViaCode(
                setupCode: args?["setupCode"] as? String ?? "",
                result:    result
            )

        case "provideCredentials":
            commissioning.provideCredentials(
                ssid:             args?["ssid"]             as? String,
                password:         args?["password"]         as? String,
                threadDatasetHex: args?["threadDatasetHex"] as? String,
                result:           result
            )

        case "parsePayload":
            commissioning.parsePayload(args?["payload"] as? String ?? "", result: result)

        case "removeDevice":
            commissioning.removeDevice(nodeId: UInt64(bitPattern: Int64(nodeId)), result: result)

        case "shareDevice":
            commissioning.shareDevice(
                nodeId:    UInt64(bitPattern: Int64(nodeId)),
                vendorId:  args?["vendorId"]  as? Int ?? 0,
                productId: args?["productId"] as? Int ?? 0,
                result:    result
            )

        // ── Subscriptions (stub — Task 5) ──────────────────────────────────
        case "startSubscription":
            result(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.core.emitDeviceState(["nodeId": nodeId, "type": "established"])
            }

        case "stopSubscription":
            result(nil)

        // ── Device info (stub — Task 7) ────────────────────────────────────
        case "readDeviceState":
            result(["isOnline": false, "isOn": nil, "brightness": nil] as [String: Any?])

        case "readDeviceType":
            result(nil)

        case "readBasicInfo":
            result(nil)

        case "readServerClusterList":
            result([Int]())

        case "readPartsList":
            result([Int]())

        case "readClusters":
            result(nil)

        case "getFabricId":
            result(ChipClient.shared.isAvailable ? "1" : nil)

        case "getVendorId":
            result(ChipClient.shared.isAvailable ? Int(ChipClient.kVendorID) : nil)

        case "discoverCommissionableNodes":
            result([Any]())

        // ── Thermostat (stub — Task 6) ─────────────────────────────────────
        case "readThermostat":
            result(nil)

        // ── Network (stub — Task 7) ────────────────────────────────────────
        case "scanWifiNetworks":
            result([["ssid": "Home Network", "signalStrength": -55]])

        case "discoverThreadNetworks":
            result("[]")

        case "readSystemThreadCredentials":
            result(nil)  // iOS v1: deferred to v2 (ThreadNetwork.framework)

        // ── Diagnostics (stub — Task 7) ────────────────────────────────────
        case "readThreadNetworkDiagnostics":
            result(nil)

        case "runNetworkDiagnostics":
            result(nil)

        // ── Cluster commands (stub — Task 6) ──────────────────────────────
        case "toggleDevice", "setLevel", "stepLevel",
             "coveringUp", "coveringDown", "coveringStop", "coveringGoToLift",
             "setFanMode", "setFanPercent",
             "setColorTemperature",
             "writeHeatingSetpoint", "writeSystemMode",
             "lockDoor", "unlockDoor",
             "downloadAndFlash", "cancelOta":
            result(false)

        case "identify":
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /// Extracts nodeId from args, handling both Int32 and Int64 codec encoding.
    private func nodeIdFrom(_ args: [String: Any]?) -> Int {
        guard let args else { return 0 }
        switch args["nodeId"] {
        case let v as Int:   return v
        case let v as Int32: return Int(v)
        default:             return 0
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SinkHolder — FlutterStreamHandler that forwards the event sink via closure.
// (Shared by StubBridge and MatterBridge; keeping both in sync.)
// ─────────────────────────────────────────────────────────────────────────────

final class SinkHolder: NSObject, FlutterStreamHandler {
    private let onSink: (FlutterEventSink?) -> Void

    init(_ onSink: @escaping (FlutterEventSink?) -> Void) {
        self.onSink = onSink
    }

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onSink(nil)
        return nil
    }
}
