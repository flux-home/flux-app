import Flutter
import Foundation
import Matter

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionBridge.swift
//
// Maps startSubscription / stopSubscription MethodChannel calls to
// MTRDevice.setDelegate (iOS 16.4) / addDelegate (iOS 18.0+).
//
// Attribute reports are decoded by cluster/attribute ID and emitted as
// device_state events matching the key names in Android's SubscriptionKeys.kt
// (which the Dart DeviceLiveData model reads).
//
// Mirrors Android's SubscriptionBridge.kt + SubscriptionManager.kt.
// ─────────────────────────────────────────────────────────────────────────────

final class SubscriptionBridge {

    private let core: BridgeCore
    /// Active subscriptions: nodeId → DeviceSubscription (holds device + delegate).
    private var subs = [UInt64: DeviceSubscription]()
    private let lock = NSLock()

    init(core: BridgeCore) { self.core = core }

    // MARK: - MethodChannel handlers

    func startSubscription(nodeId: UInt64, result: @escaping FlutterResult) {
        core.requireChip(result: result) { [weak self] in
            guard let self else { return }
            let sub = self.makeSubscription(nodeId: nodeId)
            DispatchQueue.main.async {
                result(true)
                // If the device is already reachable in the MTRDevice cache,
                // fire 'established' immediately so the UI doesn't wait.
                if sub.device.state == .reachable {
                    self.core.emitDeviceState(["nodeId": Int(nodeId), "type": "established"])
                }
            }
        }
    }

    func stopSubscription(nodeId: UInt64, result: @escaping FlutterResult) {
        lock.lock()
        let sub = subs.removeValue(forKey: nodeId)
        lock.unlock()
        sub?.cancel()
        DispatchQueue.main.async { result(nil) }
    }

    // MARK: - Private

    private func makeSubscription(nodeId: UInt64) -> DeviceSubscription {
        lock.lock()
        if let existing = subs[nodeId] { lock.unlock(); return existing }
        lock.unlock()

        guard let device = ChipClient.shared.device(for: nodeId) else {
            // Shouldn't happen if requireChip passed, but guard defensively.
            fatalError("ChipClient.device(for:) returned nil while SDK is available")
        }

        let sub = DeviceSubscription(device: device, nodeId: nodeId) { [weak self] event in
            self?.core.emitDeviceState(event)
        }

        lock.lock()
        subs[nodeId] = sub
        lock.unlock()

        sub.start()
        return sub
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// DeviceSubscription — holds one MTRDevice + its delegate.
// ─────────────────────────────────────────────────────────────────────────────

private final class DeviceSubscription {

    let device: MTRDevice
    private let nodeId:    UInt64
    private let onEvent:   ([String: Any?]) -> Void
    // MTRDevice holds a weak ref to delegates, so we must keep a strong ref here.
    private let delegate:  DeviceDelegate

    init(device: MTRDevice, nodeId: UInt64, onEvent: @escaping ([String: Any?]) -> Void) {
        self.device  = device
        self.nodeId  = nodeId
        self.onEvent = onEvent
        self.delegate = DeviceDelegate(nodeId: nodeId, onEvent: onEvent)
    }

    func start() {
        let q = DispatchQueue.global(qos: .utility)
        if #available(iOS 18.0, *) {
            device.add(delegate, queue: q)
        } else {
            device.setDelegate(delegate, queue: q)
        }
    }

    func cancel() {
        if #available(iOS 18.0, *) {
            device.remove(delegate)
        }
        // On iOS 16/17, MTRDevice has no remove API. The delegate object will
        // go away when DeviceSubscription is deallocated; MTRDevice holds weak refs.
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// DeviceDelegate — MTRDeviceDelegate implementation.
// Decodes attribute reports → device_state event map.
// ─────────────────────────────────────────────────────────────────────────────

private final class DeviceDelegate: NSObject, MTRDeviceDelegate {

    private let nodeId:  UInt64
    private let onEvent: ([String: Any?]) -> Void

    init(nodeId: UInt64, onEvent: @escaping ([String: Any?]) -> Void) {
        self.nodeId  = nodeId
        self.onEvent = onEvent
    }

    // ── State changes ────────────────────────────────────────────────────────

    func device(_ device: MTRDevice, stateChanged state: MTRDeviceState) {
        switch state {
        case .reachable:
            onEvent(["nodeId": Int(nodeId), "type": "established"])
        case .unreachable:
            // MTRDevice handles resubscription internally; we just notify Dart.
            onEvent(["nodeId": Int(nodeId), "type": "resubscribing", "nextMs": 0])
        case .unknown:
            break  // Initial state — no event yet.
        @unknown default:
            break
        }
    }

    // ── Attribute reports ────────────────────────────────────────────────────

    func device(_ device: MTRDevice,
                receivedAttributeReport attributeReport: [[String: Any]]) {
        var attrs = [String: Any?]()

        for item in attributeReport {
            guard let path = item[MTRAttributePathKey] as? MTRAttributePath else { continue }
            guard let data = item[MTRDataKey] as? [String: Any]             else { continue }

            let cluster   = path.cluster.uint32Value
            let attribute = path.attribute.uint32Value
            let typeStr   = data[MTRTypeKey]  as? String
            let value     = data[MTRValueKey]

            // Helper closures
            func intVal()    -> Int?    { (value as? NSNumber)?.intValue }
            func boolVal()   -> Bool?   { (value as? NSNumber)?.boolValue }
            func doubleVal() -> Double? { (value as? NSNumber)?.doubleValue }
            func int64Val()  -> Int64?  { (value as? NSNumber)?.int64Value }

            // Skip null / unknown values
            guard typeStr != nil, value != nil else { continue }
            let isNull = (typeStr == MTRNullValueType)

            switch (cluster, attribute) {

            // ── OnOff (0x0006) ─────────────────────────────────────────────
            case (0x0006, 0x0000): attrs["onOff"]              = isNull ? nil : boolVal()

            // ── LevelControl (0x0008) ──────────────────────────────────────
            case (0x0008, 0x0000): attrs["level"]              = isNull ? nil : intVal()

            // ── Thermostat (0x0201) ────────────────────────────────────────
            case (0x0201, 0x0000): attrs["localTempCenti"]     = isNull ? nil : intVal()
            case (0x0201, 0x0012): attrs["heatingSetptCenti"]  = isNull ? nil : intVal()
            case (0x0201, 0x0011): attrs["coolingSetptCenti"]  = isNull ? nil : intVal()
            case (0x0201, 0x001C): attrs["systemMode"]         = isNull ? nil : intVal()
            case (0x0201, 0x001B): attrs["controlSequence"]    = isNull ? nil : intVal()

            // ── RelativeHumidityMeasurement (0x0405) ───────────────────────
            case (0x0405, 0x0000): attrs["humidityCenti"]      = isNull ? nil : intVal()

            // ── TemperatureMeasurement (0x0402) ────────────────────────────
            case (0x0402, 0x0000): attrs["tempMeasureCenti"]   = isNull ? nil : intVal()

            // ── PowerSource (0x002F) ───────────────────────────────────────
            case (0x002F, 0x000C): attrs["batPercentRaw"]      = isNull ? nil : intVal()
            case (0x002F, 0x000E): attrs["batChargeLevel"]     = isNull ? nil : intVal()

            // ── OccupancySensing (0x0406) ──────────────────────────────────
            case (0x0406, 0x0000): attrs["occupancy"]          = isNull ? nil : intVal()

            // ── BooleanState (0x0045) ──────────────────────────────────────
            case (0x0045, 0x0000): attrs["contactState"]       = isNull ? nil : boolVal()

            // ── AirQuality (0x005B) ────────────────────────────────────────
            case (0x005B, 0x0000): attrs["airQuality"]         = isNull ? nil : intVal()

            // ── PM2.5 Concentration (0x042A) ───────────────────────────────
            case (0x042A, 0x0000):
                if !isNull, let d = doubleVal() { attrs["pm25"] = Int(d * 10) }
                else { attrs["pm25"] = nil }

            // ── CO2 Concentration (0x040D) ─────────────────────────────────
            case (0x040D, 0x0000):
                if !isNull, let d = doubleVal() { attrs["co2Ppm"] = Int(d) }
                else { attrs["co2Ppm"] = nil }

            // ── CO Concentration (0x040C) ──────────────────────────────────
            case (0x040C, 0x0000):
                if !isNull, let d = doubleVal() { attrs["coPpm"] = Int(d * 10) }
                else { attrs["coPpm"] = nil }

            // ── WindowCovering (0x0102) ────────────────────────────────────
            case (0x0102, 0x000E): attrs["liftPercent100ths"]  = isNull ? nil : intVal()

            // ── FanControl (0x0202) ────────────────────────────────────────
            case (0x0202, 0x0000): attrs["fanMode"]            = isNull ? nil : intVal()
            case (0x0202, 0x0003): attrs["fanPercent"]         = isNull ? nil : intVal()

            // ── ColorControl (0x0300) ──────────────────────────────────────
            case (0x0300, 0x0007): attrs["colorTempMireds"]    = isNull ? nil : intVal()

            // ── SmokeCOAlarm (0x005C) ──────────────────────────────────────
            case (0x005C, 0x0001): attrs["smokeState"]         = isNull ? nil : intVal()
            case (0x005C, 0x0002): attrs["coState"]            = isNull ? nil : intVal()

            // ── Switch (0x003B) ────────────────────────────────────────────
            case (0x003B, 0x0001): attrs["switchCurrentPosition"] = isNull ? nil : intVal()

            // ── DoorLock (0x0101) ──────────────────────────────────────────
            case (0x0101, 0x0000): attrs["lockState"]          = isNull ? nil : intVal()
            case (0x0101, 0x0003): attrs["doorState"]          = isNull ? nil : intVal()

            // ── ElectricalPowerMeasurement (0x0090) ────────────────────────
            case (0x0090, 0x0004): attrs["voltage"]            = isNull ? nil : int64Val()
            case (0x0090, 0x0005): attrs["activeCurrent"]      = isNull ? nil : int64Val()
            case (0x0090, 0x0008): attrs["activePower"]        = isNull ? nil : int64Val()

            // ── ElectricalEnergyMeasurement (0x0091) ───────────────────────
            // CumulativeEnergyImported/Exported are structs with an `energy` field (mWh).
            case (0x0091, 0x0001):
                if !isNull { attrs["cumulativeEnergyWh"] = extractEnergyWh(value) }
            case (0x0091, 0x0002):
                if !isNull { attrs["cumulativeEnergyExportedWh"] = extractEnergyWh(value) }

            default:
                break
            }
        }

        guard !attrs.isEmpty else { return }

        var payload: [String: Any?] = ["nodeId": Int(nodeId), "type": "update"]
        payload.merge(attrs) { _, new in new }
        onEvent(payload)
    }

    // ── Event reports (Switch cluster buttons) ───────────────────────────────

    func device(_ device: MTRDevice,
                receivedEventReport eventReport: [[String: Any]]) {
        // TODO Task 6: decode Switch InitialPress / ShortRelease events to
        // switchCurrentEndpoint / switchCurrentPosition / switchPressTime keys.
    }

    // ── Optional: device became active ──────────────────────────────────────

    func deviceBecameActive(_ device: MTRDevice) {
        onEvent(["nodeId": Int(nodeId), "type": "established"])
    }

    // MARK: - Helpers

    /// Extract the `energy` field (mWh) from an EnergyMeasurementStruct.
    /// The struct is decoded as a nested [String:Any] dict by the Matter SDK.
    private func extractEnergyWh(_ raw: Any?) -> Int64? {
        guard let dict = raw as? [String: Any] else { return nil }
        // The struct's fields come wrapped in Matter TLV format.
        // The SDK decodes the struct as a list of context-tag dicts:
        //   [{MTRContextTagKey: <tag>, MTRDataKey: {MTRTypeKey:..., MTRValueKey:...}}, ...]
        // Tag 0 = energy (int64, mWh), Tag 1 = startTimestamp, Tag 2 = endTimestamp, Tag 3 = apparentEnergy
        if let list = dict[MTRValueKey] as? [[String: Any]] {
            for field in list {
                if let tag = field[MTRContextTagKey] as? NSNumber, tag.intValue == 0,
                   let fieldData = field[MTRDataKey] as? [String: Any],
                   let mwh = (fieldData[MTRValueKey] as? NSNumber)?.int64Value {
                    return mwh / 1000  // convert mWh → Wh
                }
            }
        }
        // Fallback: some SDK versions may decode as a plain number.
        if let n = dict[MTRValueKey] as? NSNumber { return n.int64Value / 1000 }
        return nil
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MTRNullValueType — constant exposed by the Matter framework for the
// null TLV type.  Declared here to avoid importing the full header.
// ─────────────────────────────────────────────────────────────────────────────
private let MTRNullValueType = "Null"
private let MTRContextTagKey = "contextTag"
