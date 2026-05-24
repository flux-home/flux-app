import Flutter

// ─────────────────────────────────────────────────────────────────────────────
// StubBridge.swift
//
// iOS stub bridge — returns safe empty/hardcoded responses for every
// MethodChannel call so the full Dart UI can run in the iOS Simulator without
// Matter.xcframework wired up.
//
// Replace individual cases with real bridge calls task by task:
//   Task 3: ChipClient + BridgeCore + channel infrastructure
//   Task 4: CommissioningBridge (commission*, parsePayload, removeDevice, shareDevice)
//   Task 5: SubscriptionBridge (startSubscription, stopSubscription)
//   Task 6: Cluster command bridges
//   Task 7: DeviceInfo, Network, Diagnostics bridges
//
// Registered in AppDelegate.swift:
//   StubBridge.register(messenger: engineBridge.applicationRegistrar.messenger())
// ─────────────────────────────────────────────────────────────────────────────

final class StubBridge: NSObject {

    // Channel names must match matter_channel.dart exactly.
    private static let kMethod  = "com.fluxhome.app/matter"
    private static let kCommEvt = "com.fluxhome.app/commission_events"
    private static let kDevEvt  = "com.fluxhome.app/device_state"

    private var commissionEventSink: FlutterEventSink?
    private var deviceStateSink:     FlutterEventSink?

    // ── Registration ──────────────────────────────────────────────────────────

    /// Creates a `StubBridge` and registers it on all three Flutter channels.
    /// Must be called from the main thread (i.e. from `didInitializeImplicitFlutterEngine`).
    static func register(messenger: FlutterBinaryMessenger) {
        let stub = StubBridge()

        FlutterMethodChannel(name: kMethod, binaryMessenger: messenger)
            .setMethodCallHandler { call, result in
                stub.handle(call, result: result)
            }

        FlutterEventChannel(name: kCommEvt, binaryMessenger: messenger)
            .setStreamHandler(SinkHolder { stub.commissionEventSink = $0 })

        FlutterEventChannel(name: kDevEvt, binaryMessenger: messenger)
            .setStreamHandler(SinkHolder { stub.deviceStateSink = $0 })
    }

    // ── Method call handler ───────────────────────────────────────────────────

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args   = call.arguments as? [String: Any]
        let nodeId = nodeIdFrom(args)

        switch call.method {

        // ── Subscriptions ──────────────────────────────────────────────────
        case "startSubscription":
            result(true)
            // Emit a fake 'established' event so DeviceProvider marks the
            // device as reachable and stops showing the connecting banner.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.deviceStateSink?(["nodeId": nodeId, "type": "established"])
            }

        case "stopSubscription":
            result(nil)

        // ── Commissioning ──────────────────────────────────────────────────
        case "parsePayload":
            result([
                "vendorId":              0,
                "productId":             0,
                "discriminator":         0,
                "hasShortDiscriminator": false,
                "setupPinCode":          0,
                "discoveryCapabilities": ["BLE"],
            ] as [String: Any])

        case "commissionDevice", "commissionViaIp", "commissionViaCode":
            fakeCommission(result: result)

        case "provideCredentials":
            result(nil)

        case "removeDevice":
            result(false)

        case "shareDevice":
            result([
                "qrCodePayload":     "MT:Y.K908SE0100000000",
                "manualPairingCode": "12345678901",
            ])

        // ── Device info ────────────────────────────────────────────────────
        case "readDeviceState":
            result(["isOnline": false, "isOn": nil, "brightness": nil] as [String: Any?])

        case "readDeviceType":
            result(nil)

        case "readBasicInfo":
            result([
                "productName":       "Stub Device",
                "vendorName":        "Stub Inc",
                "vendorId":          "0xFFF1",
                "productId":         "0x8000",
                "hwVersion":         "1",
                "softwareVersion":   "1.0.0",
                "softwareVersionNum": 1,
                "manufacturingDate": "",
                "partNumber":        "",
                "productUrl":        "",
                "serialNumber":      "STUB-0001",
                "uniqueId":          "stub",
            ])

        case "readServerClusterList":
            result([Int]())

        case "readPartsList":
            result([Int]())

        case "readClusters":
            result(nil)

        case "readThermostat":
            result(nil)

        case "getFabricId":
            result("1")

        case "getVendorId":
            result(0xFFF1)

        case "discoverCommissionableNodes":
            result([Any]())

        // ── Network ────────────────────────────────────────────────────────
        case "scanWifiNetworks":
            // Return one stub network so the Wi-Fi picker isn't empty.
            result([["ssid": "Home Network", "signalStrength": -55]])

        case "discoverThreadNetworks":
            result("[]")   // JSON-encoded empty array (matches Android contract)

        case "readSystemThreadCredentials":
            // iOS v1: Thread credential import from OS not implemented.
            result(nil)

        // ── Diagnostics ────────────────────────────────────────────────────
        case "readThreadNetworkDiagnostics":
            result(nil)

        case "runNetworkDiagnostics":
            result(nil)

        // ── Cluster commands — all return false in the stub ────────────────
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

    /// Emits fake commissioning progress events, then returns a stub success
    /// result matching the shape Dart expects: `{nodeId: Int, deviceTypeId: Int}`.
    private func fakeCommission(result: @escaping FlutterResult) {
        let steps: [(delay: Double, msg: String)] = [
            (0.0, "🔍 [Stub] Scanning for device…"),
            (0.5, "📡 [Stub] Device found"),
            (1.0, "⚙ [Stub] PASE session established"),
            (1.5, "✓ [Stub] Done! Node 0x0000000000000001"),
        ]
        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) { [weak self] in
                self?.commissionEventSink?(step.msg)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // deviceTypeId 256 = OnOff Light (0x0100) — gives the UI something to show.
            result(["nodeId": 1, "deviceTypeId": 256])
        }
    }

    /// Extracts nodeId from the method-call args map.
    /// Handles both Int32 and Int64 encoding from the Flutter standard codec.
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
// SinkHolder — minimal FlutterStreamHandler that forwards the event sink.
// ─────────────────────────────────────────────────────────────────────────────

private final class SinkHolder: NSObject, FlutterStreamHandler {
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
