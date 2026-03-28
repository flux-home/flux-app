import '../models/basic_info.dart';
import '../models/commission_models.dart';
import '../models/network_diagnostics.dart';
import '../models/thermostat_models.dart';
import '../models/thread_models.dart';
import '../models/wifi_network.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Four focused port interfaces — each caller depends only on what it uses
// ─────────────────────────────────────────────────────────────────────────────

/// Subscription lifecycle and live-state event stream.
/// Used by [DeviceProvider].
abstract interface class MatterSubscriptionPort {
  /// Emits subscription updates from the Android CHIP SDK.
  /// Each event has at least `nodeId` (int) and `type` (String).
  Stream<Map<String, dynamic>> get deviceStateUpdates;

  Future<bool> startSubscription(int nodeId);
  Future<void> stopSubscription(int nodeId);
}

/// Commissioning a new device into the fabric.
/// Used by [DeviceProvider] and [CommissionScreen].
abstract interface class MatterCommissionPort {
  /// Emits plain-text progress lines from the Android commissioning flow.
  Stream<String> get commissionEvents;

  Future<ParsedPayload?> parsePayload(String payload);

  Future<CommissionResult> commissionDevice(
    String payload, {
    String? wifiSsid,
    String? wifiPassword,
    String? threadDatasetHex,
  });

  Future<CommissionResult> commissionViaIp({
    required String ipAddress,
    int port,
    required int discriminator,
    required int setupPinCode,
  });

  Future<List<WifiNetwork>> scanWifiNetworks();
}

/// Per-device cluster reads, attribute writes, and control commands.
/// Used by [DeviceProvider], [DeviceDetailScreen], [DeviceSettingsScreen],
/// and [ClusterInspectorScreen].
abstract interface class MatterClusterPort {
  Future<DeviceStateResult>  readDeviceState(int nodeId);
  Future<int?>               readDeviceTypeId(int nodeId);
  Future<BasicInfo?>         readBasicInfo(int nodeId);
  Future<ThermostatState?>   readThermostat(int nodeId);
  Future<List<int>>          readServerClusterList(int nodeId, {int endpoint = 0});
  Future<List<int>>          readPartsList(int nodeId);
  Future<String?>            readClusters(int nodeId);

  Future<bool> toggleDevice(int nodeId, {required bool on});
  Future<bool> setLevel(int nodeId, int level);
  Future<bool> writeHeatingSetpoint(int nodeId, int centidegrees);
  Future<bool> writeSystemMode(int nodeId, int mode);
  Future<void> identify(int nodeId, {int seconds = 15});
}

/// Fabric-level operations: OTA, share/remove, diagnostics, fabric identity.
/// Used by [DeviceProvider], [DeviceSettingsScreen], [MatterSettingsScreen],
/// [ThreadSettingsScreen], [ThreadDiagScreen], and [NetworkCheckScreen].
abstract interface class MatterFabricPort {
  Future<bool>  shareDevice(int nodeId);
  Future<bool>  removeDevice(int nodeId);

  Future<bool>  downloadAndFlash({
    required int    nodeId,
    required String otaUrl,
    required int    targetVersion,
    required String targetVersionString,
    bool            dryRun   = false,
    int             endpoint = 0,
  });
  Future<bool>  cancelOta();

  Future<String?> getFabricId();
  Future<int?>    getVendorId();

  Future<List<ThreadBorderRouter>>  discoverThreadNetworks();
  Future<String?>                   readAndroidThreadCredentials();
  Future<ThreadNetworkDiagnostics?> readThreadNetworkDiagnostics(int nodeId);
  Future<NetworkDiagnosticsReport?> runNetworkDiagnostics();
}

// ─────────────────────────────────────────────────────────────────────────────
// Combined interface — used by modules that span all four domains (DeviceProvider)
// ─────────────────────────────────────────────────────────────────────────────

/// Combines all four port interfaces.  [MatterChannel] implements this.
/// [DeviceProvider] depends on this combined type; individual screens depend
/// on the narrower sub-interfaces above.
abstract interface class MatterPort
    implements
        MatterSubscriptionPort,
        MatterCommissionPort,
        MatterClusterPort,
        MatterFabricPort {}
