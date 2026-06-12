import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/basic_info.dart';
import 'package:matter_home/models/commissionable_device.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/fabric_descriptor.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/network_diagnostics.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/models/wifi_network.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full recordable fake for [MatterPort].
///
/// Push subscription events via [emit]. Every channel method is recorded so
/// tests can assert what the provider actually sent.
class FakeMatterPort implements MatterPort {
  final _stateCtrl = StreamController<DeviceStateEvent>.broadcast();
  final _commCtrl  = StreamController<String>.broadcast();

  void emit(DeviceStateEvent e) => _stateCtrl.add(e);
  void emitCommission(String s)  => _commCtrl.add(s);

  void dispose() {
    _stateCtrl.close();
    _commCtrl.close();
  }

  // ── Configurable results ──────────────────────────────────────────────────

  bool startSubscriptionResult = true;

  /// When set, [toggleDevice] calls this instead of returning [defaultCommandResult].
  /// Lets tests throw to exercise rollback.
  Future<bool> Function(int nodeId, {required bool on})? toggleOverride;

  bool defaultCommandResult = true;

  DeviceStateResult readDeviceStateResult =
      const DeviceStateResult(isOnline: true, isOn: true, brightnessLevel: null);

  int? readDeviceTypeIdResult;

  // ── Call recorders ────────────────────────────────────────────────────────

  final List<int> startedSubscriptions = [];
  final List<int> stoppedSubscriptions = [];
  final List<({int nodeId, bool on})>   toggleCalls               = [];
  final List<({int nodeId, int level})> setLevelCalls             = [];
  final List<({int nodeId, int mode})>  writeSystemModeCalls      = [];
  final List<({int nodeId, int centi})> writeHeatingSetpointCalls = [];
  final List<int>                        removeDeviceCalls         = [];

  // ── MatterSubscriptionPort ────────────────────────────────────────────────

  @override
  Stream<DeviceStateEvent> get deviceStateUpdates => _stateCtrl.stream;

  @override
  Future<bool> startSubscription(int nodeId) async {
    startedSubscriptions.add(nodeId);
    return startSubscriptionResult;
  }

  @override
  Future<void> stopSubscription(int nodeId) async {
    stoppedSubscriptions.add(nodeId);
  }

  // ── MatterClusterPort ─────────────────────────────────────────────────────

  @override
  Future<DeviceStateResult> readDeviceState(int nodeId) async => readDeviceStateResult;

  @override
  Future<int?> readDeviceTypeId(int nodeId) async => readDeviceTypeIdResult;

  @override
  Future<bool> toggleDevice(int nodeId, {required bool on}) async {
    toggleCalls.add((nodeId: nodeId, on: on));
    if (toggleOverride != null) return toggleOverride!(nodeId, on: on);
    return defaultCommandResult;
  }

  @override
  Future<bool> setLevel(int nodeId, int level) async {
    setLevelCalls.add((nodeId: nodeId, level: level));
    return defaultCommandResult;
  }

  @override
  Future<bool> writeSystemMode(int nodeId, int mode) async {
    writeSystemModeCalls.add((nodeId: nodeId, mode: mode));
    return defaultCommandResult;
  }

  @override
  Future<bool> writeHeatingSetpoint(int nodeId, int centidegrees) async {
    writeHeatingSetpointCalls.add((nodeId: nodeId, centi: centidegrees));
    return defaultCommandResult;
  }

  @override
  Future<bool> removeDevice(int nodeId) async {
    removeDeviceCalls.add(nodeId);
    return true;
  }

  // ── MatterCommissionPort ──────────────────────────────────────────────────

  @override
  Stream<String> get commissionEvents => _commCtrl.stream;

  @override
  Future<ParsedPayload?> parsePayload(String payload) async => null;

  @override
  Future<CommissionResult> commissionDevice(String payload,
          {String? wifiSsid, String? wifiPassword, String? threadDatasetHex}) async =>
      CommissionResult.ok(nodeId: 0, deviceTypeId: 0);

  @override
  Future<CommissionResult> commissionViaIp({
    required String ipAddress,
    required int discriminator,
    required int setupPinCode,
    int port = 5540,
  }) async =>
      CommissionResult.ok(nodeId: 0, deviceTypeId: 0);

  @override
  Future<CommissionResult> commissionViaCode({required String setupCode}) async =>
      CommissionResult.ok(nodeId: 0, deviceTypeId: 0);

  @override
  Future<List<WifiNetwork>> scanWifiNetworks() async => const [];

  @override
  Future<void> provideCredentials(
      {String? ssid, String? password, String? threadDatasetHex}) async {}

  @override
  Future<bool> grantControllerAccess(int nodeId) async => true;

  @override
  Future<String> readAcl(int nodeId) async => '';

  // ── MatterFabricPort ──────────────────────────────────────────────────────

  @override
  Future<ShareDeviceResult?> shareDevice(int nodeId,
          {int vendorId = 0, int productId = 0}) async =>
      null;

  @override
  Future<FabricExportData?> exportFabricForController() async => null;

  @override
  Future<bool> downloadAndFlash({
    required int nodeId,
    required String otaUrl,
    required int targetVersion,
    required String targetVersionString,
    bool dryRun = false,
    int endpoint = 0,
  }) async =>
      false;

  @override
  Future<bool> cancelOta() async => false;

  @override
  Future<String?> getFabricId() async => null;

  @override
  Future<int?> getVendorId() async => null;

  @override
  Future<List<CommissionableDevice>> discoverCommissionableNodes() async => const [];

  @override
  Future<List<ThreadBorderRouter>> discoverThreadNetworks() async => const [];

  @override
  Future<String?> readSystemThreadCredentials() async => null;

  @override
  Future<ThreadNetworkDiagnostics?> readThreadNetworkDiagnostics(int nodeId) async => null;

  @override
  Future<NetworkDiagnosticsReport?> runNetworkDiagnostics() async => null;

  @override
  Future<BasicInfo?> readBasicInfo(int nodeId) async => null;

  @override
  Future<List<FabricDescriptor>?> readFabrics(int nodeId) async => null;

  @override
  Future<ThermostatState?> readThermostat(int nodeId) async => null;

  @override
  Future<List<int>> readServerClusterList(int nodeId, {int endpoint = 0}) async => const [];

  @override
  Future<List<int>> readPartsList(int nodeId) async => const [];

  @override
  Future<String?> readClusters(int nodeId) async => null;

  @override
  Future<bool> stepLevel(int nodeId, {required bool stepUp}) async =>
      defaultCommandResult;

  @override
  Future<bool> coveringUp(int nodeId) async => defaultCommandResult;

  @override
  Future<bool> coveringDown(int nodeId) async => defaultCommandResult;

  @override
  Future<bool> coveringStop(int nodeId) async => defaultCommandResult;

  @override
  Future<bool> coveringGoToLift(int nodeId, int percent100ths) async =>
      defaultCommandResult;

  @override
  Future<bool> setFanMode(int nodeId, int mode) async => defaultCommandResult;

  @override
  Future<bool> setFanPercent(int nodeId, int percent) async => defaultCommandResult;

  @override
  Future<bool> setColorTemperature(int nodeId, int mireds) async =>
      defaultCommandResult;

  @override
  Future<bool> lockDoor(int nodeId, {String? pin}) async => defaultCommandResult;

  @override
  Future<bool> unlockDoor(int nodeId, {String? pin}) async => defaultCommandResult;

  @override
  Future<({int? importedMwh, int? exportedMwh})> readCumulativeEnergy(
    int nodeId, {
    int endpoint = 1,
  }) async =>
      (importedMwh: null, exportedMwh: null);

  @override
  Future<void> identify(int nodeId, {int seconds = 15}) async {}
}

/// Builds a [DeviceProvider] backed by [FakeMatterPort] and an in-memory store.
///
/// [devices] is pre-seeded into the store's commissioning-records slot.
/// [snapshots] maps deviceId → attribute map (as [PersistedSnapshot] state).
Future<(DeviceProvider, FakeMatterPort)> buildProvider({
  List<MatterDevice> devices = const [],
  Map<String, Map<String, dynamic>> snapshots = const {},
}) async {
  final prefs = <String, Object>{};
  if (devices.isNotEmpty) {
    prefs['matter_devices'] =
        devices.map((d) => jsonEncode(d.toJson())).toList();
  }
  if (snapshots.isNotEmpty) {
    prefs['device_snapshots'] = snapshots.entries
        .map((e) => jsonEncode({'deviceId': e.key, 'state': e.value}))
        .toList();
  }
  SharedPreferences.setMockInitialValues(prefs);
  final store   = await DeviceStore.open();
  final fake    = FakeMatterPort();
  final provider = DeviceProvider(store, fake);
  await pumpEventQueue();
  return (provider, fake);
}
