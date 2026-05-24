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
//   is not yet initialised or failed to start.  startupError holds the
//   reason for inspection by the Matter settings screen.
// ─────────────────────────────────────────────────────────────────────────────

final class ChipClient {

    static let shared = ChipClient()

    /// CSA development VID (0xFFF1).  Change to your production VID before App Store.
    static let kVendorID: UInt32 = 0xFFF1
    /// Our single fabric.  All commissioned devices belong to fabric 1.
    static let kFabricID: UInt64 = 1

    private let lock = NSLock()
    private var _controller: MTRDeviceController?

    private(set) var isAvailable = false
    /// Human-readable reason for the last startup failure, or nil on success.
    private(set) var startupError: String?

    private init() {}

    // MARK: - Startup

    func start() {
        // Run on a background queue — factory init does network/BLE setup
        // that must not block the main thread.
        DispatchQueue.global(qos: .userInitiated).async { self._start() }
    }

    /// Waits up to `timeout` seconds for the SDK to become available.
    /// Returns true if available, false if timed out or failed.
    func waitUntilReady(timeout: TimeInterval = 8.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !isAvailable && startupError == nil && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        return isAvailable
    }

    private func _start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isAvailable else { return }

        func fail(_ reason: String, _ error: Error? = nil) {
            let msg = error.map { "\(reason): \($0.localizedDescription)" } ?? reason
            startupError = msg
            NSLog("[ChipClient] ❌ \(msg)")
            isAvailable = false
        }

        NSLog("[ChipClient] Starting Matter SDK…")

        // ── 1. IPK ──────────────────────────────────────────────────────────
        let ipk = loadOrCreateIPK()
        NSLog("[ChipClient]  ✓ IPK ready (\(ipk.count) bytes)")

        // ── 2. Keypair ───────────────────────────────────────────────────────
        let keypair: MatterKeypair
        do {
            keypair = try MatterKeypair.loadOrCreate()
            NSLog("[ChipClient]  ✓ Keypair ready")
        } catch {
            fail("Keypair init failed", error); return
        }

        // ── 3. Storage ───────────────────────────────────────────────────────
        let storage = MatterStorage()
        NSLog("[ChipClient]  ✓ Storage ready")

        // ── 4. Factory ───────────────────────────────────────────────────────
        let factory = MTRDeviceControllerFactory.sharedInstance()
        if !factory.isRunning {
            let fp = MTRDeviceControllerFactoryParams(storage: storage)
            // shouldStartServer enables the device to accept CASE connections
            // (useful for subscriptions / being a border router).
            // Try without it first — safer on restrictive OS environments.
            fp.shouldStartServer = false
            do {
                try factory.start(fp)
                NSLog("[ChipClient]  ✓ Factory started (shouldStartServer=false)")
            } catch {
                // Retry with server enabled — some SDK versions require it.
                fp.shouldStartServer = true
                do {
                    try factory.start(fp)
                    NSLog("[ChipClient]  ✓ Factory started (shouldStartServer=true)")
                } catch {
                    fail("Factory start failed", error); return
                }
            }
        } else {
            NSLog("[ChipClient]  ✓ Factory already running")
        }

        // ── 5. Controller ────────────────────────────────────────────────────
        let params = MTRDeviceControllerStartupParams(
            ipk:       ipk,
            fabricID:  NSNumber(value: Self.kFabricID),
            nocSigner: keypair
        )
        params.vendorID = NSNumber(value: Self.kVendorID)

        var ctrl: MTRDeviceController?

        let knownFabrics = factory.knownFabrics ?? []
        NSLog("[ChipClient]  knownFabrics count: \(knownFabrics.count)")

        if !knownFabrics.isEmpty {
            ctrl = try? factory.createController(onExistingFabric: params)
            if ctrl != nil {
                NSLog("[ChipClient]  ✓ Loaded existing fabric")
            } else {
                NSLog("[ChipClient]  ℹ Existing fabric load failed — creating new")
            }
        }

        if ctrl == nil {
            do {
                ctrl = try factory.createController(onNewFabric: params)
                NSLog("[ChipClient]  ✓ Created new fabric")
            } catch {
                fail("createController(onNewFabric:) failed", error); return
            }
        }

        guard let c = ctrl else {
            fail("Controller is nil after create"); return
        }

        _controller = c
        isAvailable = true
        startupError = nil
        NSLog("[ChipClient] ✅ Matter SDK ready — controllerNodeID=\(c.controllerNodeID?.description ?? "?")")
    }

    // MARK: - Accessors

    var controller: MTRDeviceController? {
        lock.lock(); defer { lock.unlock() }
        return _controller
    }

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
