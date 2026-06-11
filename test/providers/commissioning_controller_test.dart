import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/providers/commissioning_controller.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/commissioning_fakes.dart';

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
  /// [creds] is returned by onNeedsCredentials; [blePermitted] is returned by
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

  // ── BLE happy paths ───────────────────────────────────────────────────────────

  group('start (BLE)', () {
    test('Wi-Fi happy path (phone mode) commissions and registers', () async {
      final c = build();
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ble,
        netType: 1,
        wifiSsid: 'home',
        wifiPassword: 'secret',
      ));

      expect(port.commissionDeviceCalls, 1);
      expect(port.lastWifiSsid, 'home');
      expect(port.lastWifiPassword, 'secret');
      expect(provider.beganCommissioning, isTrue);
      expect(provider.registerCalls, 1);
      expect(provider.registeredNetworkType, NetworkType.wifi);
      expect(provider.registeredManagedBy, ManagedBy.phone);
      expect(c.phase, CommissionPhase.done);
      expect(c.result, isNotNull);
      // Saved payload cleared on success.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_matter_qr_payload'), isNull);
    });

    test('Thread dataset auto-fetched from controller when empty (hub mode)', () async {
      final svc = FakeFluxCoapService()..threadDatasetHexResult = 'AABBCCDD';
      final c = build(controllerService: svc);
      await setParsed(c);

      await c.start(const CommissionConfig(
        method: CommissionMethod.ble,
        netType: 0, // Thread
      ));

      expect(svc.getThreadDatasetCalls, 1);
      expect(port.lastThreadDatasetHex, 'AABBCCDD');
      expect(port.grantAclCalls, 1);
      expect(svc.registerNodeCalls, 1);
      expect(provider.registeredManagedBy, ManagedBy.controller);
      expect(c.phase, CommissionPhase.done);
    });

    test('grantControllerAccess failure → failed, node not registered', () async {
      final svc = FakeFluxCoapService();
      port.aclGrantResult = false;
      final c = build(controllerService: svc, threadDataset: 'DEAD');
      await setParsed(c);

      await c.start(const CommissionConfig(method: CommissionMethod.ble, netType: 0));

      expect(port.grantAclCalls, 1);
      expect(svc.registerNodeCalls, 0);
      expect(provider.registerCalls, 0);
      expect(provider.failCalled, isTrue);
      expect(c.phase, CommissionPhase.failed);
      expect(c.error, isNotNull);
    });

    test('commission failure → phase failed with error', () async {
      final c = build();
      port.commissionResult = CommissionResult.err('PASE timeout');
      await setParsed(c);

      await c.start(const CommissionConfig(method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

      expect(c.phase, CommissionPhase.failed);
      expect(c.error, 'PASE timeout');
      expect(provider.failCalled, isTrue);
      expect(provider.registerCalls, 0);
    });
  });

  // ── BLE permission + pre-collection gates ─────────────────────────────────────

  group('start gates', () {
    test('denied BLE permission aborts before commissioning', () async {
      final c = build(blePermitted: false);
      await setParsed(c);

      await c.start(const CommissionConfig(method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

      expect(port.commissionDeviceCalls, 0);
      expect(c.phase, CommissionPhase.parsed); // unchanged
    });

    test('Wi-Fi pre-collection cancelled (creds null) → idle, no commission', () async {
      final c = build(creds: null); // onNeedsCredentials returns null
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
      final c = build(creds: const CommissionCredentials.thread('FEED'));
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
      final c = build(creds: const CommissionCredentials.wifi('net', 'pw'));
      await setParsed(c);
      port.onCommission = () async {
        port.emit('CREDENTIALS_NEEDED:WIFI');
        await port.provideCredentialsCalled.future;
      };

      // netType 1 with ssid filled skips pre-collection so the in-flight
      // event is what triggers provideCredentials.
      await c.start(const CommissionConfig(method: CommissionMethod.ble, netType: 1, wifiSsid: 'seed'));

      expect(port.provideCredentialsCalls, 1);
      expect(port.providedSsid, 'net');
      expect(port.providedPassword, 'pw');
    });
  });

  // ── IP / on-network paths ─────────────────────────────────────────────────────

  group('start (IP)', () {
    test('no IP address → commissionViaCode (DNS-SD discovery)', () async {
      final c = build();
      await setParsed(c);

      await c.start(const CommissionConfig(method: CommissionMethod.ip));

      expect(port.commissionViaCodeCalls, 1);
      expect(port.commissionViaIpCalls, 0);
      expect(provider.registeredNetworkType, NetworkType.ethernet);
      expect(c.phase, CommissionPhase.done);
    });

    test('explicit IP → commissionViaIp with discriminator/pin', () async {
      final c = build();
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
    final c = build();
    await setParsed(c);
    port.onCommission = () async {
      // Cancel the session while the commission is still running.
      c.reset();
    };

    await c.start(const CommissionConfig(method: CommissionMethod.ble, netType: 1, wifiSsid: 'x'));

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
    final c = build();
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
