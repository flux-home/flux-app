import 'package:matter_home/models/basic_info.dart';
import 'package:matter_home/models/commissionable_device.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/network_diagnostics.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/models/wifi_network.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Four focused port interfaces — each caller depends only on what it uses
// ─────────────────────────────────────────────────────────────────────────────

/// Subscription lifecycle and live-state event stream.
/// Used by [DeviceProvider].
abstract interface class MatterSubscriptionPort {
  /// Typed events emitted by the Android CHIP SDK subscription layer.
  /// Decoded from the raw platform-channel map by [MatterChannel].
  Stream<DeviceStateEvent> get deviceStateUpdates;

  Future<bool> startSubscription(int nodeId);
  Future<void> stopSubscription(int nodeId);
}

/// Commissioning a new device into the fabric.
/// Used by [CommissioningController].
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
    required int discriminator, required int setupPinCode, int port,
  });

  /// Commissions a device already on the network using DNS-SD discovery.
  /// [setupCode] is the raw QR payload ("MT:…") or 11-digit manual pairing code.
  /// No IP address required — the SDK discovers the device via [_matterc._udp].
  Future<CommissionResult> commissionViaCode({required String setupCode});

  Future<List<WifiNetwork>> scanWifiNetworks();

  /// Responds to a CREDENTIALS_NEEDED event emitted during BLE commissioning.
  /// Pass [ssid]+[password] for WiFi, [threadDatasetHex] for Thread, or all null to cancel.
  Future<void> provideCredentials({
    String? ssid,
    String? password,
    String? threadDatasetHex,
  });
}

/// Per-device cluster reads, attribute writes, and control commands.
/// Screens import this interface file; this file does not import screens.
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
  Future<bool> stepLevel(int nodeId, {required bool stepUp});
  Future<bool> coveringUp(int nodeId);
  Future<bool> coveringDown(int nodeId);
  Future<bool> coveringStop(int nodeId);
  Future<bool> coveringGoToLift(int nodeId, int percent100ths);
  Future<bool> setFanMode(int nodeId, int mode);
  Future<bool> setFanPercent(int nodeId, int percent);
  Future<bool> setColorTemperature(int nodeId, int mireds);
  Future<bool> writeHeatingSetpoint(int nodeId, int centidegrees);
  Future<bool> writeSystemMode(int nodeId, int mode);
  Future<void> identify(int nodeId, {int seconds = 15});

  Future<bool> lockDoor(int nodeId, {String? pin});
  Future<bool> unlockDoor(int nodeId, {String? pin});
}

/// Fabric-level operations: OTA, share/remove, diagnostics, fabric identity.
abstract interface class MatterFabricPort {
  Future<ShareDeviceResult?> shareDevice(int nodeId, {int vendorId = 0, int productId = 0});
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
  Future<List<CommissionableDevice>> discoverCommissionableNodes();

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
