import 'dart:async';

import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/wifi_network.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/matter_port.dart';

/// ── FakeMatterCommissionPort ────────────────────────────────────────────────
///
/// Drop-in [MatterCommissionPort] for CommissioningController tests.
///
/// Exposes a controllable [commissionEvents] stream, records every call with
/// its arguments, and returns canned results.  The optional [onCommission]
/// hook runs *inside* the commission* methods, so a test can emit events (e.g.
/// CREDENTIALS_NEEDED) and wait for the controller to react before the
/// commission future completes.
class FakeMatterCommissionPort implements MatterCommissionPort {
  final _events = StreamController<String>.broadcast();

  /// Pushes a progress line onto [commissionEvents] (as the native layer would).
  void emit(String event) => _events.add(event);

  // ── Configurable results ──────────────────────────────────────────────────
  ParsedPayload? parsedResult;
  CommissionResult commissionResult = CommissionResult.ok(nodeId: 0x1234, deviceTypeId: 0x0101);
  bool aclGrantResult = true;

  /// Invoked inside commissionDevice / commissionViaIp / commissionViaCode.
  Future<void> Function()? onCommission;

  // ── Recorded calls ────────────────────────────────────────────────────────
  int parseCallCount = 0;
  int commissionDeviceCalls = 0;
  int commissionViaIpCalls = 0;
  int commissionViaCodeCalls = 0;
  int grantAclCalls = 0;

  String? lastWifiSsid;
  String? lastWifiPassword;
  String? lastThreadDatasetHex;
  String? lastIpAddress;
  int? lastDiscriminator;
  int? lastSetupPinCode;

  // provideCredentials capture + a future tests can await.
  int provideCredentialsCalls = 0;
  String? providedSsid;
  String? providedPassword;
  String? providedThreadDatasetHex;
  final Completer<void> provideCredentialsCalled = Completer<void>();

  @override
  Stream<String> get commissionEvents => _events.stream;

  @override
  Future<ParsedPayload?> parsePayload(String payload) async {
    parseCallCount++;
    return parsedResult;
  }

  @override
  Future<CommissionResult> commissionDevice(
    String payload, {
    String? wifiSsid,
    String? wifiPassword,
    String? threadDatasetHex,
  }) async {
    commissionDeviceCalls++;
    lastWifiSsid = wifiSsid;
    lastWifiPassword = wifiPassword;
    lastThreadDatasetHex = threadDatasetHex;
    if (onCommission != null) await onCommission!();
    return commissionResult;
  }

  @override
  Future<CommissionResult> commissionViaIp({
    required String ipAddress,
    required int discriminator,
    required int setupPinCode,
    int port = 5540,
  }) async {
    commissionViaIpCalls++;
    lastIpAddress = ipAddress;
    lastDiscriminator = discriminator;
    lastSetupPinCode = setupPinCode;
    if (onCommission != null) await onCommission!();
    return commissionResult;
  }

  @override
  Future<CommissionResult> commissionViaCode({required String setupCode}) async {
    commissionViaCodeCalls++;
    if (onCommission != null) await onCommission!();
    return commissionResult;
  }

  @override
  Future<List<WifiNetwork>> scanWifiNetworks() async => const [];

  @override
  Future<void> provideCredentials({
    String? ssid,
    String? password,
    String? threadDatasetHex,
  }) async {
    provideCredentialsCalls++;
    providedSsid = ssid;
    providedPassword = password;
    providedThreadDatasetHex = threadDatasetHex;
    if (!provideCredentialsCalled.isCompleted) provideCredentialsCalled.complete();
  }

  @override
  Future<bool> grantControllerAccess(int nodeId) async {
    grantAclCalls++;
    return aclGrantResult;
  }

  @override
  Future<String> readAcl(int nodeId) async => '';
}

/// ── FakeDeviceProvider ──────────────────────────────────────────────────────
///
/// The controller holds [DeviceProvider] by concrete type, so the fake must
/// extend it.  The base constructor runs against a real (empty) [DeviceStore]
/// and a stub channel — both side-effect-free with no persisted devices — and
/// the four members the controller actually touches are overridden so no real
/// persistence or subscription work happens.
class FakeDeviceProvider extends DeviceProvider {
  FakeDeviceProvider(DeviceStore store) : super(store, _StubChannel());

  /// Seedable device list returned to the controller for name generation.
  List<MatterDevice> seededDevices = [];

  bool beganCommissioning = false;
  String? failError;
  bool failCalled = false;

  int registerCalls = 0;
  CommissionResult? registeredResult;
  String? registeredName;
  NetworkType? registeredNetworkType;
  ManagedBy? registeredManagedBy;

  @override
  List<MatterDevice> get devices => List.unmodifiable(seededDevices);

  @override
  void beginCommissioning() => beganCommissioning = true;

  @override
  void failCommissioning(String? error) {
    failCalled = true;
    failError = error;
  }

  @override
  Future<MatterDevice> registerCommissionedDevice(
    CommissionResult result,
    String name,
    NetworkType networkType, {
    ManagedBy managedBy = ManagedBy.phone,
  }) async {
    registerCalls++;
    registeredResult = result;
    registeredName = name;
    registeredNetworkType = networkType;
    registeredManagedBy = managedBy;
    final now = DateTime.now();
    return MatterDevice(
      id: 'fake-${result.nodeId}',
      name: name,
      deviceType: DeviceType.onOffLight,
      nodeId: result.nodeId ?? 0,
      commissionedAt: now,
      lastModified: now,
      networkType: networkType,
      managedBy: managedBy,
    );
  }
}

/// Minimal [MatterPort] for the [DeviceProvider] base constructor: only
/// [deviceStateUpdates] is read during construction; every other member is
/// unused and routed through [noSuchMethod].
class _StubChannel implements MatterPort {
  final _ctrl = StreamController<DeviceStateEvent>.broadcast();

  @override
  Stream<DeviceStateEvent> get deviceStateUpdates => _ctrl.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// ── FakeFluxCoapService ──────────────────────────────────────────────────────
///
/// Hub-mode controller service.  The base constructor only builds a (lazy,
/// non-connecting) CoAP client against a loopback endpoint, so it is safe to
/// instantiate in tests; the two methods the controller calls are overridden.
class FakeFluxCoapService extends FluxCoapService {
  FakeFluxCoapService()
      : super(const FluxControllerEndpoint(host: '127.0.0.1', port: 5683));

  String? threadDatasetHexResult;
  bool registerNodeResult = true;

  int getThreadDatasetCalls = 0;
  int registerNodeCalls = 0;
  int? registeredNodeId;
  String? registeredName;
  int? registeredDeviceType;

  @override
  Future<String?> getThreadDatasetHex() async {
    getThreadDatasetCalls++;
    return threadDatasetHexResult;
  }

  @override
  Future<bool> registerNode({
    required int nodeId,
    required String name,
    int fabricId = 0,
    int vendorId = 0,
    int productId = 0,
    int deviceType = 0,
  }) async {
    registerNodeCalls++;
    registeredNodeId = nodeId;
    registeredName = name;
    registeredDeviceType = deviceType;
    return registerNodeResult;
  }
}

/// Builds a [ParsedPayload] with sensible defaults for tests.
ParsedPayload fakeParsedPayload({
  int vendorId = 0xFFF1,
  int productId = 0x8000,
  int discriminator = 3840,
  int setupPinCode = 20202021,
  List<DiscoveryCapability> capabilities = const [DiscoveryCapability.ble],
}) =>
    ParsedPayload(
      vendorId: vendorId,
      productId: productId,
      discriminator: discriminator,
      hasShortDiscriminator: false,
      discoveryCapabilities: capabilities,
      setupPinCode: setupPinCode,
    );
