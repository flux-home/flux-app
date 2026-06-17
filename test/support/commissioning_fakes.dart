import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/fabric_descriptor.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/models/wifi_network.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'matter_fakes.dart' show FakeMatterPort;

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

  /// ECM window result returned by [openCommissioningWindow] (null = failure).
  ShareDeviceResult? windowResult = const ShareDeviceResult(
      qrCodePayload: 'MT:FAKE', manualPairingCode: '00000000000',
      passcode: 0x4D2, discriminator: 0x2A);

  /// Fabrics returned by [readFabrics] (the post-handoff safety gate).
  List<FabricDescriptor>? fabricsResult;

  /// Result of [removeFabric].
  bool removeFabricResult = true;

  /// Invoked inside commissionDevice / commissionViaIp / commissionViaCode.
  Future<void> Function()? onCommission;

  // ── Recorded calls ────────────────────────────────────────────────────────
  int parseCallCount = 0;
  int commissionDeviceCalls = 0;
  int commissionViaIpCalls = 0;
  int commissionViaCodeCalls = 0;
  int openWindowCalls = 0;
  int readFabricsCalls = 0;
  final List<({int nodeId, int fabricIndex})> removeFabricCalls = [];

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
  Future<ShareDeviceResult?> openCommissioningWindow(int nodeId) async {
    openWindowCalls++;
    return windowResult;
  }

  @override
  Future<List<FabricDescriptor>?> readFabrics(int nodeId) async {
    readFabricsCalls++;
    return fabricsResult;
  }

  @override
  Future<bool> removeFabric(int nodeId, int fabricIndex) async {
    removeFabricCalls.add((nodeId: nodeId, fabricIndex: fabricIndex));
    return removeFabricResult;
  }
}

/// ── FakeDeviceProvider ──────────────────────────────────────────────────────
///
/// The controller holds [DeviceProvider] by concrete type, so the fake must
/// extend it.  The base constructor runs against a real (empty) [DeviceStore]
/// and a stub channel — both side-effect-free with no persisted devices — and
/// the four members the controller actually touches are overridden so no real
/// persistence or subscription work happens.
class FakeDeviceProvider extends DeviceProvider {
  FakeDeviceProvider(DeviceStore store) : super(store, FakeMatterPort());

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

/// ── FakeFluxCoapService ──────────────────────────────────────────────────────
///
/// Hub-mode controller service.  The base constructor only builds a (lazy,
/// non-connecting) CoAP client against a loopback endpoint, so it is safe to
/// instantiate in tests; the two methods the controller calls are overridden.
class FakeFluxCoapService extends FluxCoapService {
  FakeFluxCoapService()
      : super(const FluxControllerEndpoint(host: '127.0.0.1', port: 5683));

  String? threadDatasetHexResult;

  /// When true, [commission] returns a successful result; otherwise a failure.
  bool commissionSuccess = true;
  /// RAW controller fabric id echoed in the [CommissionResult].
  int commissionFabricId = 0xCAFE;
  String commissionError = '';
  /// When false, [commission] returns null (transport failure).
  bool commissionReturnsResult = true;

  int getThreadDatasetCalls = 0;
  int commissionCalls = 0;
  int? commissionedNodeId;
  String? commissionedName;
  int? commissionedPasscode;
  int? commissionedDiscriminator;
  int? commissionedDeviceType;

  @override
  Future<String?> getThreadDatasetHex() async {
    getThreadDatasetCalls++;
    return threadDatasetHexResult;
  }

  @override
  Future<$proto.CommissionResult?> commission({
    required int passcode,
    required int discriminator,
    int nodeId = 0,
    String name = '',
    int vendorId = 0,
    int productId = 0,
    int deviceType = 0,
  }) async {
    commissionCalls++;
    commissionedNodeId = nodeId;
    commissionedName = name;
    commissionedPasscode = passcode;
    commissionedDiscriminator = discriminator;
    commissionedDeviceType = deviceType;
    if (!commissionReturnsResult) return null;
    return $proto.CommissionResult()
      ..success = commissionSuccess
      ..nodeId = Int64(nodeId)
      ..fabricId = Int64(commissionFabricId)
      ..error = commissionError;
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
