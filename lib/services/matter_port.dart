import 'package:matter_home/models/basic_info.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/matter_device.dart' show DeviceKind;
import 'package:matter_home/models/fabric_descriptor.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/wifi_network.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Four focused port interfaces — each caller depends only on what it uses
// ─────────────────────────────────────────────────────────────────────────────

/// Subscription lifecycle and live-state event stream.
/// Used by [DeviceProvider].
abstract interface class MatterSubscriptionPort {
  /// Typed events emitted by the platform CHIP SDK subscription layer.
  /// Decoded from the raw platform-channel map by [MatterChannel].
  Stream<DeviceStateEvent> get deviceStateUpdates;

  /// A device is identified by (kind, nodeId). [kind] defaults to matter
  /// because the local CHIP fabric can only ever address Matter devices; only
  /// the controller port acts on it.
  Future<bool> startSubscription(int nodeId, {DeviceKind kind});
  Future<void> stopSubscription(int nodeId, {DeviceKind kind});
}

/// Commissioning a new device into the fabric.
/// Used by [CommissioningController].
abstract interface class MatterCommissionPort {
  /// Emits plain-text progress lines from the platform commissioning flow.
  Stream<String> get commissionEvents;

  Future<ParsedPayload?> parsePayload(String payload);

  /// BLE-commissions a device onto the phone's throwaway fabric (Pass 1 of
  /// commission-then-handoff).  Devices already on the network never touch the
  /// phone SDK — their pairing code is forwarded to the controller directly
  /// (FluxCoapService.commission).
  Future<CommissionResult> commissionDevice(
    String payload, {
    String? wifiSsid,
    String? wifiPassword,
    String? threadDatasetHex,
  });

  Future<List<WifiNetwork>> scanWifiNetworks();

  /// Responds to a CREDENTIALS_NEEDED event emitted during BLE commissioning.
  /// Pass [ssid]+[password] for WiFi, [threadDatasetHex] for Thread, or all null to cancel.
  Future<void> provideCredentials({
    String? ssid,
    String? password,
    String? threadDatasetHex,
  });

  /// Opens an Enhanced Commissioning Method (ECM) window on [nodeId] (already
  /// commissioned onto the phone's throwaway fabric) and returns the generated
  /// setup [ShareDeviceResult.passcode] + [ShareDeviceResult.discriminator] for
  /// the controller's `POST /commission` handoff.  Returns null on failure.
  Future<ShareDeviceResult?> openCommissioningWindow(int nodeId);

  /// Reads the device's OperationalCredentials Fabrics attribute over the
  /// phone's (throwaway-fabric) CASE session.  Used as the post-handoff safety
  /// gate: the controller's fabric id must be present before the phone removes
  /// its own fabric.  Null on failure.
  Future<List<FabricDescriptor>?> readFabrics(int nodeId);

  /// Removes the fabric at [fabricIndex] from [nodeId] (OperationalCredentials
  /// RemoveFabric).  The phone calls this on its OWN throwaway fabric index once
  /// the controller fabric is confirmed present.  Returns false on failure.
  Future<bool> removeFabric(int nodeId, int fabricIndex);
}

/// Per-device cluster reads, attribute writes, and control commands.
/// Screens import this interface file; this file does not import screens.
abstract interface class MatterClusterPort {
  Future<DeviceStateResult>  readDeviceState(int nodeId);
  Future<int?>               readDeviceTypeId(int nodeId);
  Future<BasicInfo?>         readBasicInfo(int nodeId);
  Future<List<FabricDescriptor>?> readFabrics(int nodeId);
  Future<ThermostatState?>   readThermostat(int nodeId);
  Future<List<int>>          readServerClusterList(int nodeId, {int endpoint = 0});
  Future<List<int>>          readPartsList(int nodeId);
  /// [full] true = whole tree (Cluster Inspector); false = static metadata only
  /// (BasicInfo + Descriptor + OnOff), with live readings coming via the
  /// subscription. See [FluxCoapService.readClusters].
  Future<String?>            readClusters(int nodeId, {bool full});

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

/// Fabric-level operations: remove, fabric identity, Thread credentials.
abstract interface class MatterFabricPort {
  Future<bool>  removeDevice(int nodeId, {DeviceKind kind});

  Future<String?> getFabricId();

  Future<String?> readSystemThreadCredentials();
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
