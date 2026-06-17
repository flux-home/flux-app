import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/fabric_descriptor.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/providers/commissioning_controller.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/commissioning_fakes.dart';

/// Builds a FabricDescriptor with the given index + raw fabric-id hex.
FabricDescriptor _fab(int index, String fabricIdHex) => FabricDescriptor(
      fabricIndex: index,
      fabricId: fabricIdHex,
      nodeId: '0x0000000000000000',
      vendorId: '0xFFF1',
      label: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMatterCommissionPort port;
  late FakeDeviceProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    port = FakeMatterCommissionPort();
    provider = FakeDeviceProvider(await DeviceStore.open());
  });

  /// Builds a controller wired to [port] / [provider].
  ///
  /// [controllerService] is the connected hub (null = no hub).  [creds] is
  /// returned by onNeedsCredentials; [blePermitted] is returned by
  /// requestBlePermissions; [threadDataset] seeds the local dataset getter.
  CommissioningController build({
    FakeFluxCoapService? controllerService,
    CommissionCredentials? creds,
    bool blePermitted = true,
    String threadDataset = '',
  }) {
    return CommissioningController(
      port: port,
      provider: provider,
      requestBlePermissions: () async => blePermitted,
      onNeedsCredentials: (_) async => creds,
      threadDataset: () => threadDataset,
      controllerService: controllerService,
    );
  }

  Future<void> setParsed(CommissioningController c) async {
    port.parsedResult = fakeParsedPayload();
    await c.setPayload('MT:FAKE');
  }

  // ── setPayload ──────────────────────────────────────────────────────────────

  group('setPayload', () {
    test('successful parse → phase parsed and payload persisted', () async {
      final c = build();
      port.parsedResult = fakeParsedPayload();

      await c.setPayload('MT:ABC');

      expect(c.phase, CommissionPhase.parsed);
      expect(c.parsed, isNotNull);
      expect(c.parseError, isNull);
      expect(port.parseCallCount, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_matter_qr_payload'), 'MT:ABC');
    });

    test('failed parse → phase idle with error, nothing persisted', () async {
      final c = build();
      port.parsedResult = null;

      await c.setPayload('garbage');

      expect(c.phase, CommissionPhase.idle);
      expect(c.parsed, isNull);
      expect(c.parseError, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_matter_qr_payload'), isNull);
    });
  });

  // ── No hub → no commissioning ─────────────────────────────────────────────────

  test('no hub connected → fails fast without commissioning', () async {
    final c = build(); // controllerService == null
    await setParsed(c);

    await c.start(const CommissionConfig(
      method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

    expect(port.commissionDeviceCalls, 0);
    expect(c.phase, CommissionPhase.failed);
    expect(c.error, isNotNull);
  });

  // ── Commission-then-handoff happy path + gate ─────────────────────────────────

  group('start (BLE handoff)', () {
    test('happy path: commission, handoff, gate passes, removes phone fabric', () async {
      final svc = FakeFluxCoapService()..commissionFabricId = 0xCAFE;
      // Device ends with two fabrics: controller (0xCAFE @ idx 2) + phone (0x1 @ idx 1).
      port.fabricsResult = [_fab(2, '0xCAFE'), _fab(1, '0x0000000000000001')];
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ble, netType: 1, wifiSsid: 'home', wifiPassword: 'pw'));

      // BLE commission onto the throwaway fabric.
      expect(port.commissionDeviceCalls, 1);
      // ECM window opened, passcode/discriminator forwarded to the hub.
      expect(port.openWindowCalls, 1);
      expect(svc.commissionCalls, 1);
      expect(svc.commissionedPasscode, 0x4D2);
      expect(svc.commissionedDiscriminator, 0x2A);
      expect(svc.commissionedNodeId, 0x1234);
      // Safety gate read the fabrics, then removed the phone's own fabric (idx 1).
      expect(port.readFabricsCalls, 1);
      expect(port.removeFabricCalls, [(nodeId: 0x1234, fabricIndex: 1)]);
      expect(provider.registeredManagedBy, ManagedBy.controller);
      expect(c.phase, CommissionPhase.done);
      expect(c.result, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_matter_qr_payload'), isNull);
    });

    test('window open fails → no handoff, phase failed', () async {
      final svc = FakeFluxCoapService();
      port.windowResult = null;
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

      expect(port.openWindowCalls, 1);
      expect(svc.commissionCalls, 0);
      expect(port.removeFabricCalls, isEmpty);
      expect(c.phase, CommissionPhase.failed);
      expect(provider.registerCalls, 0);
    });

    test('orphan gate: handoff fails → fabric never removed, device kept on phone', () async {
      final svc = FakeFluxCoapService()
        ..commissionSuccess = false
        ..commissionError = 'PASE timeout';
      port.fabricsResult = [_fab(2, '0xCAFE'), _fab(1, '0x0000000000000001')];
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

      expect(svc.commissionCalls, 1);
      // Never reads fabrics or removes anything when the hub did not commission.
      expect(port.readFabricsCalls, 0);
      expect(port.removeFabricCalls, isEmpty);
      expect(c.phase, CommissionPhase.failed);
      expect(c.error, contains('PASE timeout'));
      expect(provider.registerCalls, 0);
    });

    test('orphan gate: hub returns no result → fabric never removed', () async {
      final svc = FakeFluxCoapService()..commissionReturnsResult = false;
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

      expect(svc.commissionCalls, 1);
      expect(port.removeFabricCalls, isEmpty);
      expect(c.phase, CommissionPhase.failed);
    });

    test('controller fabric not visible → keep phone fabric, still managed by hub', () async {
      final svc = FakeFluxCoapService()..commissionFabricId = 0xCAFE;
      // Gate fails safe: only the phone fabric is visible, not the controller's.
      port.fabricsResult = [_fab(1, '0x0000000000000001')];
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

      expect(svc.commissionCalls, 1);
      expect(port.readFabricsCalls, 1);
      expect(port.removeFabricCalls, isEmpty); // never remove our only fabric
      expect(provider.registeredManagedBy, ManagedBy.controller);
      expect(c.phase, CommissionPhase.done);
    });

    test('ambiguous phone fabric (multiple candidates) → no removal', () async {
      final svc = FakeFluxCoapService()..commissionFabricId = 0xCAFE;
      port.fabricsResult = [
        _fab(2, '0xCAFE'),
        _fab(1, '0x0000000000000001'),
        _fab(3, '0x0000000000000002'),
      ];
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

      expect(port.removeFabricCalls, isEmpty);
      expect(provider.registeredManagedBy, ManagedBy.controller);
      expect(c.phase, CommissionPhase.done);
    });

    test('commission (BLE pass) failure → phase failed, no handoff', () async {
      final svc = FakeFluxCoapService();
      port.commissionResult = CommissionResult.err('BLE PASE failed');
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

      expect(c.phase, CommissionPhase.failed);
      expect(c.error, 'BLE PASE failed');
      expect(port.openWindowCalls, 0);
      expect(svc.commissionCalls, 0);
      expect(provider.failCalled, isTrue);
    });
  });

  // ── Thread network selection ──────────────────────────────────────────────────

  group('Thread network selection', () {
    test('uses the hub Thread network in hub mode', () async {
      final svc = FakeFluxCoapService()..threadDatasetHexResult = 'AABBCCDD';
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(method: CommissionMethod.ble, netType: 0));

      expect(svc.getThreadDatasetCalls, 1);
      expect(port.lastThreadDatasetHex, 'AABBCCDD');
      expect(c.phase, CommissionPhase.done);
    });

    test('hub Thread network is preferred over the app\'s local dataset', () async {
      final svc = FakeFluxCoapService()..threadDatasetHexResult = 'AABBCCDD';
      final c = build(controllerService: svc, threadDataset: 'DEAD');
      await setParsed(c);

      await c.start(const CommissionConfig(method: CommissionMethod.ble, netType: 0));

      expect(svc.getThreadDatasetCalls, 1);
      expect(port.lastThreadDatasetHex, 'AABBCCDD'); // hub's, not 'DEAD'
    });

    test('falls back to the app dataset when the hub has no Thread network', () async {
      final svc = FakeFluxCoapService(); // threadDatasetHexResult = null
      final c = build(controllerService: svc, threadDataset: 'DEAD');
      await setParsed(c);

      await c.start(const CommissionConfig(method: CommissionMethod.ble, netType: 0));

      expect(svc.getThreadDatasetCalls, 1);
      expect(port.lastThreadDatasetHex, 'DEAD'); // hub had none → app dataset
    });
  });

  // ── BLE permission + pre-collection gates ─────────────────────────────────────

  group('start gates', () {
    test('denied BLE permission aborts before commissioning', () async {
      final svc = FakeFluxCoapService();
      final c = build(controllerService: svc, blePermitted: false);
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

      expect(port.commissionDeviceCalls, 0);
      expect(c.phase, CommissionPhase.parsed); // unchanged
    });

    test('Wi-Fi pre-collection cancelled (creds null) → idle, no commission', () async {
      final svc = FakeFluxCoapService();
      final c = build(controllerService: svc, creds: null);
      await setParsed(c);

      // BLE + WiFi (netType 1) with empty ssid triggers pre-collection.
      await c.start(const CommissionConfig(method: CommissionMethod.ble, netType: 1));

      expect(port.commissionDeviceCalls, 0);
      expect(c.phase, CommissionPhase.idle);
    });
  });

  // ── CREDENTIALS_NEEDED handshake ──────────────────────────────────────────────

  group('CREDENTIALS_NEEDED handshake', () {
    test('THREAD event → provideCredentials with thread dataset', () async {
      final svc = FakeFluxCoapService()..threadDatasetHexResult = 'AABB';
      final c = build(controllerService: svc, creds: const CommissionCredentials.thread('FEED'));
      await setParsed(c);
      port.onCommission = () async {
        port.emit('CREDENTIALS_NEEDED:THREAD');
        await port.provideCredentialsCalled.future;
      };

      await c.start(const CommissionConfig(method: CommissionMethod.ble, netType: 0));

      expect(port.provideCredentialsCalls, 1);
      expect(port.providedThreadDatasetHex, 'FEED');
      expect(port.providedSsid, isNull);
    });

    test('WIFI event → provideCredentials with ssid/password', () async {
      final svc = FakeFluxCoapService();
      final c = build(controllerService: svc, creds: const CommissionCredentials.wifi('net', 'pw'));
      await setParsed(c);
      port.onCommission = () async {
        port.emit('CREDENTIALS_NEEDED:WIFI');
        await port.provideCredentialsCalled.future;
      };

      // netType 1 with ssid filled skips pre-collection so the in-flight
      // event is what triggers provideCredentials.
      await c.start(const CommissionConfig(
        method: CommissionMethod.ble, netType: 1, wifiSsid: 'seed'));

      expect(port.provideCredentialsCalls, 1);
      expect(port.providedSsid, 'net');
      expect(port.providedPassword, 'pw');
    });
  });

  // ── IP / on-network paths ─────────────────────────────────────────────────────

  group('start (IP)', () {
    test('no IP address → commissionViaCode (DNS-SD discovery)', () async {
      final svc = FakeFluxCoapService();
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(method: CommissionMethod.ip));

      expect(port.commissionViaCodeCalls, 1);
      expect(port.commissionViaIpCalls, 0);
      expect(provider.registeredNetworkType, NetworkType.ethernet);
      expect(c.phase, CommissionPhase.done);
    });

    test('explicit IP → commissionViaIp with discriminator/pin', () async {
      final svc = FakeFluxCoapService();
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ip,
        ipAddress: '10.0.0.5',
        discriminator: 1234,
        setupPinCode: 11223344,
      ));

      expect(port.commissionViaIpCalls, 1);
      expect(port.lastIpAddress, '10.0.0.5');
      expect(port.lastDiscriminator, 1234);
      expect(port.lastSetupPinCode, 11223344);
    });
  });

  // ── Session invalidation ──────────────────────────────────────────────────────

  test('reset() mid-flight discards a late success', () async {
    final svc = FakeFluxCoapService();
    final c = build(controllerService: svc);
    await setParsed(c);
    port.onCommission = () async {
      // Cancel the session while the commission is still running.
      c.reset();
    };

    await c.start(const CommissionConfig(
      method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

    // reset() left phase idle; the stale success must not register a device.
    expect(c.phase, CommissionPhase.idle);
    expect(provider.registerCalls, 0);
    expect(c.result, isNull);
  });

  // ── Name generation ───────────────────────────────────────────────────────────

  test('generated name is de-duplicated against existing devices', () async {
    final now = DateTime.now();
    MatterDevice dev(String name) => MatterDevice(
          id: name,
          name: name,
          deviceType: DeviceType.onOffLight,
          nodeId: 1,
          commissionedAt: now,
          lastModified: now,
        );
    final svc = FakeFluxCoapService();
    final c = build(controllerService: svc);
    await setParsed(c);
    final base = c.parsed!.suggestedName; // vendor-derived suggested name
    provider.seededDevices = [dev(base), dev('$base 2')];

    await c.start(const CommissionConfig(method: CommissionMethod.ip));

    expect(provider.registeredName, '$base 3');
  });

  // ── Static decision helpers (pure) ────────────────────────────────────────────

  group('suggestMethod / suggestNetType', () {
    test('BLE-capable payload suggests BLE', () {
      final p = fakeParsedPayload(capabilities: const [DiscoveryCapability.ble]);
      expect(CommissioningController.suggestMethod(p), CommissionMethod.ble);
    });

    test('on-network payload suggests IP and netType None', () {
      final p = fakeParsedPayload(capabilities: const [DiscoveryCapability.onNetwork]);
      expect(CommissioningController.suggestMethod(p), CommissionMethod.ip);
      expect(CommissioningController.suggestNetType(p), 2);
    });

    test('wifiPaf capability suggests Wi-Fi netType', () {
      final p = fakeParsedPayload(capabilities: const [DiscoveryCapability.wifiPaf]);
      expect(CommissioningController.suggestNetType(p), 1);
    });

    test('selected Thread dataset overrides default for BLE device', () {
      final p = fakeParsedPayload(capabilities: const [DiscoveryCapability.ble]);
      expect(CommissioningController.suggestNetType(p, threadSelected: true), 0);
      expect(CommissioningController.suggestNetType(p, threadDataset: 'AABB'), 0);
      // No thread info → None (learned later from onReadCommissioningInfo).
      expect(CommissioningController.suggestNetType(p), 2);
    });
  });
}
