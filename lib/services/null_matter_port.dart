import 'package:matter_home/models/basic_info.dart';
import 'package:matter_home/models/matter_device.dart' show DeviceKind;
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/fabric_descriptor.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/wifi_network.dart';
import 'package:matter_home/services/matter_port.dart';

/// Inert [MatterPort] placeholder for "no controller connected yet".
///
/// Device control is controller-proxied only (see
/// `docs/controller-only-control.md`) — there is no local-CHIP fallback.
/// [DeviceProvider] is constructed with this before a hub is found and
/// swaps to the real [FluxCoapService] once one connects; every method here
/// is a safe no-op so the app simply shows no live control until then.
class NullMatterPort implements MatterPort {
  @override
  Stream<DeviceStateEvent> get deviceStateUpdates => const Stream.empty();

  @override
  Future<bool> startSubscription(int nodeId, {DeviceKind kind = DeviceKind.matter}) async => false;

  @override
  Future<void> stopSubscription(int nodeId, {DeviceKind kind = DeviceKind.matter}) async {}

  @override
  Stream<String> get commissionEvents => const Stream.empty();

  @override
  Future<ParsedPayload?> parsePayload(String payload) async => null;

  @override
  Future<CommissionResult> commissionDevice(
    String payload, {
    String? wifiSsid,
    String? wifiPassword,
    String? threadDatasetHex,
  }) async => CommissionResult.err('no controller connected');

  @override
  Future<List<WifiNetwork>> scanWifiNetworks() async => const [];

  @override
  Future<void> provideCredentials({
    String? ssid,
    String? password,
    String? threadDatasetHex,
  }) async {}

  @override
  Future<ShareDeviceResult?> openCommissioningWindow(int nodeId) async => null;

  @override
  Future<List<FabricDescriptor>?> readFabrics(int nodeId) async => null;

  @override
  Future<bool> removeFabric(int nodeId, int fabricIndex) async => false;

  @override
  Future<DeviceStateResult> readDeviceState(int nodeId) async =>
      const DeviceStateResult(isOnline: false);

  @override
  Future<int?> readDeviceTypeId(int nodeId) async => null;

  @override
  Future<BasicInfo?> readBasicInfo(int nodeId) async => null;

  @override
  Future<ThermostatState?> readThermostat(int nodeId) async => null;

  @override
  Future<List<int>> readServerClusterList(int nodeId, {int endpoint = 0}) async => const [];

  @override
  Future<List<int>> readPartsList(int nodeId) async => const [];

  @override
  Future<String?> readClusters(int nodeId, {bool full = false}) async => null;

  @override
  Future<bool> toggleDevice(int nodeId, {required bool on}) async => false;

  @override
  Future<bool> setLevel(int nodeId, int level) async => false;

  @override
  Future<bool> stepLevel(int nodeId, {required bool stepUp}) async => false;

  @override
  Future<bool> coveringUp(int nodeId) async => false;

  @override
  Future<bool> coveringDown(int nodeId) async => false;

  @override
  Future<bool> coveringStop(int nodeId) async => false;

  @override
  Future<bool> coveringGoToLift(int nodeId, int percent100ths) async => false;

  @override
  Future<bool> setFanMode(int nodeId, int mode) async => false;

  @override
  Future<bool> setFanPercent(int nodeId, int percent) async => false;

  @override
  Future<bool> setColorTemperature(int nodeId, int mireds) async => false;

  @override
  Future<bool> writeHeatingSetpoint(int nodeId, int centidegrees) async => false;

  @override
  Future<bool> writeSystemMode(int nodeId, int mode) async => false;

  @override
  Future<void> identify(int nodeId, {int seconds = 15}) async {}

  @override
  Future<bool> lockDoor(int nodeId, {String? pin}) async => false;

  @override
  Future<bool> unlockDoor(int nodeId, {String? pin}) async => false;

  @override
  Future<bool> removeDevice(int nodeId, {DeviceKind kind = DeviceKind.matter}) async => false;

  @override
  Future<String?> getFabricId() async => null;

  @override
  Future<String?> readSystemThreadCredentials() async => null;

}
