import Foundation
import Matter

// ─────────────────────────────────────────────────────────────────────────────
// ControllerStorage.swift
//
// MTRDeviceControllerStorageDelegate used by the modern (iOS 17.6+) controller
// path.  Stores NSSecureCoding values keyed by (securityLevel, sharingType,
// key) in a dedicated UserDefaults suite.
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 17.6, *)
final class ControllerStorage: NSObject, MTRDeviceControllerStorageDelegate {

    private static let suiteName = "com.fluxhome.app.matter-ctrl-storage"
    private let defaults: UserDefaults

    override init() {
        defaults = UserDefaults(suiteName: Self.suiteName) ?? UserDefaults.standard
    }

    // MARK: - MTRDeviceControllerStorageDelegate

    func controller(_ controller: MTRDeviceController,
                    valueForKey key: String,
                    securityLevel: MTRStorageSecurityLevel,
                    sharingType: MTRStorageSharingType) -> (any NSSecureCoding)? {
        guard let data = defaults.data(forKey: storageKey(key, securityLevel, sharingType)) else {
            return nil
        }
        let storageClasses = MTRDeviceControllerStorageClasses().compactMap { $0 as? AnyClass }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: storageClasses,
            from: data
        ) as? NSSecureCoding
    }

    func controller(_ controller: MTRDeviceController,
                    storeValue value: any NSSecureCoding,
                    forKey key: String,
                    securityLevel: MTRStorageSecurityLevel,
                    sharingType: MTRStorageSharingType) -> Bool {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: value, requiringSecureCoding: true
        ) else { return false }
        defaults.set(data, forKey: storageKey(key, securityLevel, sharingType))
        return true
    }

    func controller(_ controller: MTRDeviceController,
                    removeValueForKey key: String,
                    securityLevel: MTRStorageSecurityLevel,
                    sharingType: MTRStorageSharingType) -> Bool {
        let k = storageKey(key, securityLevel, sharingType)
        let existed = defaults.data(forKey: k) != nil
        defaults.removeObject(forKey: k)
        return existed
    }

    // MARK: - Helpers

    private func storageKey(_ key: String,
                            _ sec: MTRStorageSecurityLevel,
                            _ share: MTRStorageSharingType) -> String {
        "ctrl.\(sec.rawValue).\(share.rawValue).\(key)"
    }
}
