import Flutter
import Foundation

/// MethodChannel/EventChannel handler for the flux-ice remote-access tunnel,
/// mirroring `MatterBridge`. Thin control plane only — the packet data plane
/// stays in native C (app ADR-0001). ICE state is polled (not pushed via a C
/// callback), matching the Android bridge, to keep threading simple.
///
/// The C API (`flux_ice_mobile_*`) is exposed to Swift via
/// `Runner-Bridging-Header.h`. Build wiring: see ios/README-flux-ice.md.
/// NOTE: written for a later macOS build; not compiled on the Linux dev host.
final class FluxIceBridge: NSObject {

  private static let methodName = "com.fluxhome.app/flux_ice"
  private static let eventName  = "com.fluxhome.app/flux_ice_events"

  /// Dart gets a stable Int key; Swift keeps the opaque native pointer.
  private var sessions: [Int: OpaquePointer] = [:]
  private var nextHandle = 1

  private var stateSink: FlutterEventSink?
  private var pollTimer: DispatchSourceTimer?

  static func register(messenger: FlutterBinaryMessenger) {
    let instance = FluxIceBridge()
    let method = FlutterMethodChannel(name: methodName, binaryMessenger: messenger)
    method.setMethodCallHandler { call, result in instance.handle(call, result) }
    let events = FlutterEventChannel(name: eventName, binaryMessenger: messenger)
    events.setStreamHandler(instance)
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "start":
      let stun = args["stunHost"] as? String
      let port = UInt16(truncatingIfNeeded: (args["stunPort"] as? Int) ?? 0)
      // flux_ice_mobile_start blocks ~3 s (gather) — run off the platform thread.
      DispatchQueue.global(qos: .userInitiated).async {
        var offer = [CChar](repeating: 0, count: 4096)
        let s = flux_ice_mobile_start(stun, port, &offer, 4096, nil, nil)
        let offerStr = String(cString: offer)
        DispatchQueue.main.async {
          guard let s = s else {
            result(FlutterError(code: "start_failed",
                                message: "flux_ice_mobile_start returned null", details: nil))
            return
          }
          let key = self.nextHandle
          self.nextHandle += 1
          self.sessions[key] = s
          result(["handle": key, "offer": offerStr])
        }
      }
    case "setAnswer":
      let h = args["handle"] as? Int ?? 0
      let ans = args["answer"] as? String ?? ""
      result(Int(flux_ice_mobile_set_answer(sessions[h], ans)))
    case "localPort":
      let h = args["handle"] as? Int ?? 0
      result(Int(flux_ice_mobile_local_port(sessions[h])))
    case "stop":
      let h = args["handle"] as? Int ?? 0
      pollTimer?.cancel(); pollTimer = nil
      flux_ice_mobile_stop(sessions[h])
      sessions.removeValue(forKey: h)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

extension FluxIceBridge: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stateSink = events
    let handle = (arguments as? Int) ?? 0
    guard let s = sessions[handle] else { return nil }
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now(), repeating: .milliseconds(200))
    var last = -1
    timer.setEventHandler { [weak self] in
      let st = Int(flux_ice_mobile_state(s))
      if st != last { last = st; self?.stateSink?(st) }
      if st == 4 || st == 5 { self?.pollTimer?.cancel() }   // FAILED / CLOSED
    }
    timer.resume()
    pollTimer = timer
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    pollTimer?.cancel(); pollTimer = nil; stateSink = nil
    return nil
  }
}
