import Foundation
import Matter
import Security

// ─────────────────────────────────────────────────────────────────────────────
// ChipClient.swift
//
// Singleton entry point for the Matter iOS SDK.
//
// Lifecycle:
//   Call ChipClient.shared.start() once from AppDelegate before any bridge
//   calls.  Subsequent calls are no-ops.  isAvailable is false when the SDK
//   is not yet initialised or failed to start.
// ─────────────────────────────────────────────────────────────────────────────

final class ChipClient {

    static let shared = ChipClient()

    /// CSA development VID (0xFFF1).  Change to your production VID before App Store.
    static let kVendorID: UInt32  = 0xFFF1
    /// Our single fabric.  All commissioned devices belong to fabric 1.
    static let kFabricID: UInt64  = 1

    private let lock = NSLock()
    private var _controller: MTRDeviceController?

    private(set) var isAvailable = false

    private init() {}

    // MARK: - Startup

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isAvailable else { return }

        do {
            let ipk     = loadOrCreateIPK()
            let keypair = try MatterKeypair.loadOrCreate()
            let storage = MatterStorage()
            let factory = MTRDeviceControllerFactory.sharedInstance()

            // Start the factory once per process lifetime.
            if !factory.isRunning {
                let fp = MTRDeviceControllerFactoryParams(storage: storage)
                fp.shouldStartServer = true
                try factory.start(fp)
            }

            // Build startup params used for both new-fabric and existing-fabric paths.
            let params = MTRDeviceControllerStartupParams(
                ipk:       ipk,
                fabricID:  NSNumber(value: Self.kFabricID),
                nocSigner: keypair
            )
            params.vendorID = NSNumber(value: Self.kVendorID)

            var ctrl: MTRDeviceController?

            // Try loading an existing fabric from the persistent store first.
            if !(factory.knownFabrics?.isEmpty ?? true) {
                ctrl = try? factory.createController(onExistingFabric: params)
            }
            // First launch — create a new fabric.
            if ctrl == nil {
                ctrl = try factory.createController(onNewFabric: params)
            }

            guard let c = ctrl else {
                throw NSError(domain: "ChipClient", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Controller creation failed"])
            }

            _controller = c
            isAvailable = true
            NSLog("[ChipClient] Matter SDK ready — controllerNodeID=%@",
                  c.controllerNodeID?.description ?? "?")

        } catch {
            NSLog("[ChipClient] Matter SDK unavailable: %@", error.localizedDescription)
            isAvailable = false
        }
    }

    // MARK: - Accessors

    var controller: MTRDeviceController? {
        lock.lock(); defer { lock.unlock() }
        return _controller
    }

    /// Creates an MTRDevice for issuing cluster commands and subscriptions.
    func device(for nodeID: UInt64) -> MTRDevice? {
        guard let c = controller else { return nil }
        return MTRDevice(nodeID: NSNumber(value: nodeID), controller: c)
    }

    // MARK: - IPK persistence

    private func loadOrCreateIPK() -> Data {
        let key = "com.fluxhome.app.matter.ipk"
        if let stored = UserDefaults.standard.data(forKey: key), stored.count == 16 {
            return stored
        }
        var ipk = Data(count: 16)
        ipk.withUnsafeMutableBytes {
            _ = SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        }
        UserDefaults.standard.set(ipk, forKey: key)
        NSLog("[ChipClient] Generated new IPK")
        return ipk
    }
}
