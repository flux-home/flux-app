import Foundation
import Matter
import Security

// ─────────────────────────────────────────────────────────────────────────────
// ChipClient.swift
//
// Singleton entry point for the Matter iOS SDK.
//
// Two initialization paths:
//   Modern (iOS 17.6+): MTRDeviceController(parameters:) with manually
//     generated root cert + NOC.  Bypasses MTRDeviceControllerFactory entirely.
//     Required on iOS 26+ where createControllerOnNewFabric: is broken.
//
//   Legacy (iOS 16.4 – 17.5): MTRDeviceControllerFactory +
//     createControllerOnNewFabric: — kept as fallback.
// ─────────────────────────────────────────────────────────────────────────────

final class ChipClient {

    static let shared = ChipClient()

    static let kVendorID: UInt32 = 0xFFF1   // CSA dev VID — change for production
    static let kFabricID: UInt64 = 1

    private let lock = NSLock()
    private var _controller: MTRDeviceController?

    private(set) var isAvailable  = false
    private(set) var startupError: String?

    private init() {}

    // MARK: - Startup

    func start() {
        DispatchQueue.global(qos: .userInitiated).async { self._start() }
    }

    /// Spin-wait up to `timeout` seconds for the SDK to become ready.
    func waitUntilReady(timeout: TimeInterval = 8.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !isAvailable && startupError == nil && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        return isAvailable
    }

    // MARK: - Private startup

    private func _start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isAvailable else { return }

        func fail(_ reason: String, _ error: Error? = nil) {
            let msg = error.map { "\(reason): \($0.localizedDescription)" } ?? reason
            startupError = msg
            NSLog("[ChipClient] ❌ %@", msg)
            isAvailable = false
        }

        NSLog("[ChipClient] Starting Matter SDK…")

        let ipk = loadOrCreateIPK()
        NSLog("[ChipClient]  ✓ IPK ready")

        let keypair: MatterKeypair
        do {
            keypair = try MatterKeypair.loadOrCreate()
            NSLog("[ChipClient]  ✓ Keypair ready")
        } catch {
            fail("Keypair failed", error); return
        }

        do {
            let ctrl: MTRDeviceController
            if #available(iOS 17.6, *) {
                NSLog("[ChipClient]  → Taking modern path (iOS 17.6+, running %@)",
                      ProcessInfo.processInfo.operatingSystemVersionString)
                ctrl = try _startModern(ipk: ipk, keypair: keypair)
            } else {
                NSLog("[ChipClient]  → Taking legacy path (< iOS 17.6)")
                ctrl = try _startLegacy(ipk: ipk, keypair: keypair)
            }
            _controller = ctrl
            isAvailable  = true
            startupError = nil
            NSLog("[ChipClient] ✅ Matter SDK ready — controllerNodeID=%@",
                  ctrl.controllerNodeID?.description ?? "?")
        } catch {
            fail("Controller init failed", error)
        }
    }

    // MARK: - Modern path (iOS 17.6+)

    @available(iOS 17.6, *)
    private func _startModern(ipk: Data, keypair: MatterKeypair) throws -> MTRDeviceController {
        NSLog("[ChipClient]  Using modern initWithParameters: path")

        // 1. Root certificate
        let rootCert: Data
        do {
            rootCert = try MTRCertificates.createRootCertificate(
                keypair, issuerID: nil, fabricID: nil
            )
        } catch {
            throw NSError(domain: "ChipClient", code: -10,
                userInfo: [NSLocalizedDescriptionKey: "Root cert generation failed: \(error)"])
        }
        NSLog("[ChipClient]   ✓ Root cert generated (%d bytes)", rootCert.count)

        // 2. Controller operational certificate (controller acts as node 1 on fabric)
        let controllerNoc: Data
        do {
            controllerNoc = try MTRCertificates.createOperationalCertificate(
                keypair,
                signingCertificate:    rootCert,
                operationalPublicKey:  keypair.copyPublicKey(),
                fabricID:              NSNumber(value: Self.kFabricID),
                nodeID:                NSNumber(value: UInt64(1)),
                caseAuthenticatedTags: nil
            )
        } catch {
            throw NSError(domain: "ChipClient", code: -11,
                userInfo: [NSLocalizedDescriptionKey: "Controller NOC generation failed: \(error)"])
        }
        NSLog("[ChipClient]   ✓ Controller NOC generated (%d bytes)", controllerNoc.count)

        // 3. Cert issuer + per-controller storage
        let certIssuer   = FluxCertIssuer(keypair: keypair, rootCert: rootCert,
                                           fabricID: Self.kFabricID)
        let storage      = ControllerStorage()
        let storageQueue = DispatchQueue(label: "com.fluxhome.app.matter.ctrl-storage", qos: .utility)
        let issuerQueue  = DispatchQueue(label: "com.fluxhome.app.matter.cert-issuer", qos: .userInitiated)

        // 4. Persistent controller UUID (stable across launches)
        let uid = loadOrCreateControllerID()
        NSLog("[ChipClient]   controllerUID=%@", uid.uuidString)

        // 5. Parameters
        let params = MTRDeviceControllerExternalCertificateParameters(
            storageDelegate:         storage,
            storageDelegateQueue:    storageQueue,
            uniqueIdentifier:        uid,
            ipk:                     ipk,
            vendorID:                NSNumber(value: Self.kVendorID),
            operationalKeypair:      keypair,
            operationalCertificate:  controllerNoc,
            intermediateCertificate: nil,
            rootCertificate:         rootCert
        )
        params.setOperationalCertificateIssuer(certIssuer, queue: issuerQueue)

        // 6. Initialise — auto-starts factory in per-controller mode
        let ctrl = try MTRDeviceController(parameters: params)
        NSLog("[ChipClient]   ✓ MTRDeviceController initialised")
        return ctrl
    }

    // MARK: - Legacy path (iOS 16.4 – 17.5)

    private func _startLegacy(ipk: Data, keypair: MatterKeypair) throws -> MTRDeviceController {
        NSLog("[ChipClient]  Using legacy factory path")

        let storage = MatterStorage()
        let factory = MTRDeviceControllerFactory.sharedInstance()

        if !factory.isRunning {
            let fp = MTRDeviceControllerFactoryParams(storage: storage)
            fp.shouldStartServer = false
            do {
                try factory.start(fp)
                NSLog("[ChipClient]   ✓ Factory started (shouldStartServer=false)")
            } catch {
                fp.shouldStartServer = true
                try factory.start(fp)
                NSLog("[ChipClient]   ✓ Factory started (shouldStartServer=true)")
            }
        }

        let params = MTRDeviceControllerStartupParams(
            ipk:       ipk,
            fabricID:  NSNumber(value: Self.kFabricID),
            nocSigner: keypair
        )
        params.vendorID = NSNumber(value: Self.kVendorID)

        let knownFabrics = factory.knownFabrics ?? []
        NSLog("[ChipClient]   knownFabrics: %d", knownFabrics.count)

        if !knownFabrics.isEmpty,
           let ctrl = try? factory.createController(onExistingFabric: params) {
            NSLog("[ChipClient]   ✓ Loaded existing fabric")
            return ctrl
        }

        let ctrl = try factory.createController(onNewFabric: params)
        NSLog("[ChipClient]   ✓ Created new fabric")
        return ctrl
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

    // MARK: - Persistence helpers

    private func loadOrCreateIPK() -> Data {
        let key = "com.fluxhome.app.matter.ipk"
        if let stored = UserDefaults.standard.data(forKey: key), stored.count == 16 {
            return stored
        }
        var ipk = Data(count: 16)
        ipk.withUnsafeMutableBytes { _ = SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        UserDefaults.standard.set(ipk, forKey: key)
        NSLog("[ChipClient] Generated new IPK")
        return ipk
    }

    private func loadOrCreateControllerID() -> UUID {
        let key = "com.fluxhome.app.matter.controllerUUID"
        if let s = UserDefaults.standard.string(forKey: key), let u = UUID(uuidString: s) {
            return u
        }
        let u = UUID()
        UserDefaults.standard.set(u.uuidString, forKey: key)
        NSLog("[ChipClient] Generated new controller UUID")
        return u
    }
}
