import Foundation
import Matter

// ─────────────────────────────────────────────────────────────────────────────
// MatterStorage.swift
//
// MTRStorage implementation backed by UserDefaults.
//
// The Matter SDK calls these methods from arbitrary threads to persist fabric
// data, session resumption tokens, etc.  UserDefaults is thread-safe.
// ─────────────────────────────────────────────────────────────────────────────

final class MatterStorage: NSObject, MTRStorage {

    private static let suiteName = "com.fluxhome.app.matter-sdk"
    private let defaults: UserDefaults

    override init() {
        defaults = UserDefaults(suiteName: Self.suiteName) ?? UserDefaults.standard
    }

    func storageData(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func setStorageData(_ value: Data, forKey key: String) -> Bool {
        defaults.set(value, forKey: key)
        return true
    }

    func removeStorageData(forKey key: String) -> Bool {
        let existed = defaults.data(forKey: key) != nil
        defaults.removeObject(forKey: key)
        return existed
    }
}
