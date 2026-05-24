import CoreBluetooth
import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// BluetoothPrewarm.swift
//
// Creates a CBCentralManager at app launch purely to trigger the
// NSBluetoothAlwaysUsageDescription permission dialog.
//
// iOS only shows the Bluetooth permission prompt when CBCentralManager is
// first instantiated.  The Matter SDK creates its own CBCentralManager
// internally, but that happens inside setupCommissioningSession — too late
// to gracefully handle the "denied" case.  By pre-warming here the user
// sees the dialog on first launch, well before they attempt commissioning.
// ─────────────────────────────────────────────────────────────────────────────

final class BluetoothPrewarm: NSObject, CBCentralManagerDelegate {

    static let shared = BluetoothPrewarm()
    private var manager: CBCentralManager?

    private override init() {}

    func start() {
        // CBCentralManagerOptionShowPowerAlertKey: show system dialog if BT is off.
        manager = CBCentralManager(
            delegate: self,
            queue:    .global(qos: .background),
            options:  [CBCentralManagerOptionShowPowerAlertKey: false]
        )
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            NSLog("[BT] Bluetooth is on and authorized ✓")
        case .unauthorized:
            NSLog("[BT] Bluetooth permission denied — commissioning over BLE will not work")
        case .poweredOff:
            NSLog("[BT] Bluetooth is off — user must enable it for BLE commissioning")
        default:
            NSLog("[BT] Bluetooth state: %ld", central.state.rawValue)
        }
    }
}
