import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/commission_models.dart';
import '../models/network_diagnostics.dart';
import '../models/thermostat_models.dart';
import '../models/thread_models.dart';
import '../models/wifi_network.dart';

/// Flutter ↔ Android bridge.
class MatterChannel {
  static const _method       = MethodChannel('com.example.matter_home/matter');
  static const _events       = EventChannel('com.example.matter_home/commission_events');
  static const _deviceEvents = EventChannel('com.example.matter_home/device_state');

  // ── Commission progress stream ─────────────────────────────────────────────
  /// Emits plain-text progress lines from the Android commissioning flow.
  Stream<String> get commissionEvents =>
      _events.receiveBroadcastStream().map((e) => e as String);

  // ── Live device state stream ───────────────────────────────────────────────
  /// Emits subscription updates from the Android CHIP SDK for all subscribed
  /// devices.  Each event is a map with at least:
  ///   - `nodeId` (int)
  ///   - `type`   (String): "established" | "update" | "resubscribing" | "error"
  /// Update events also carry any subset of:
  ///   onOff, level, localTempCenti, heatingSetptCenti, coolingSetptCenti,
  ///   systemMode, controlSequence, humidityCenti, tempMeasureCenti,
  ///   batPercentRaw (0–200), batChargeLevel, occupancy, contactState.
  Stream<Map<String, dynamic>> get deviceStateUpdates =>
      _deviceEvents.receiveBroadcastStream().map(
        (e) => Map<String, dynamic>.from(e as Map<Object?, Object?>));

  // ── Subscription control ───────────────────────────────────────────────────

  Future<bool> startSubscription(int nodeId) async {
    try {
      return await _method.invokeMethod<bool>(
              'startSubscription', {'nodeId': nodeId}) ?? false;
    } on PlatformException catch (e) {
      debugPrint('startSubscription error: ${e.message}');
      return false;
    }
  }

  Future<void> stopSubscription(int nodeId) async {
    try {
      await _method.invokeMethod<void>('stopSubscription', {'nodeId': nodeId});
    } on PlatformException catch (e) {
      debugPrint('stopSubscription error: ${e.message}');
    }
  }

  // ── Parse setup payload ────────────────────────────────────────────────────

  /// Parses a QR code or manual pairing code string and returns device metadata.
  /// Returns null if the payload is invalid or the SDK is unavailable.
  Future<ParsedPayload?> parsePayload(String payload) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
        'parsePayload', {'payload': payload},
      );
      if (result == null) return null;

      DiscoveryCapability cap(String s) => switch (s) {
            'BLE'        => DiscoveryCapability.ble,
            'ON_NETWORK' => DiscoveryCapability.onNetwork,
            'SOFT_AP'    => DiscoveryCapability.softAp,
            'WIFI_PAF'   => DiscoveryCapability.wifiPaf,
            'NFC'        => DiscoveryCapability.nfc,
            _            => DiscoveryCapability.unknown,
          };

      return ParsedPayload(
        vendorId:              result['vendorId']              as int,
        productId:             result['productId']             as int,
        discriminator:         result['discriminator']         as int,
        hasShortDiscriminator: result['hasShortDiscriminator'] as bool? ?? false,
        setupPinCode:          result['setupPinCode']          as int? ?? 0,
        discoveryCapabilities: (result['discoveryCapabilities'] as List<dynamic>?)
                ?.map((e) => cap(e as String))
                .toList() ??
            [],
      );
    } on PlatformException {
      return null;
    }
  }

  // ── Commission via BLE ─────────────────────────────────────────────────────

  Future<CommissionResult> commissionDevice(
    String payload, {
    String? wifiSsid,
    String? wifiPassword,
    String? threadDatasetHex,
  }) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
        'commissionDevice',
        {
          'payload':          payload,
          'wifiSsid':         wifiSsid,
          'wifiPassword':     wifiPassword,
          'threadDatasetHex': threadDatasetHex,
        },
      );
      if (result == null) return CommissionResult.err('No result from channel');
      return CommissionResult.ok(
        nodeId:       result['nodeId']       as int,
        deviceTypeId: result['deviceTypeId'] as int?,
      );
    } on PlatformException catch (e) {
      return CommissionResult.err(e.message ?? 'Commission failed');
    }
  }

  Future<CommissionResult> commissionViaIp({
    required String ipAddress,
    int port = 5540,
    required int discriminator,
    required int setupPinCode,
  }) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
        'commissionViaIp',
        {
          'ipAddress':     ipAddress,
          'port':          port,
          'discriminator': discriminator,
          'setupPinCode':  setupPinCode,
        },
      );
      if (result == null) return CommissionResult.err('No result from channel');
      return CommissionResult.ok(
        nodeId:       result['nodeId']       as int,
        deviceTypeId: result['deviceTypeId'] as int?,
      );
    } on PlatformException catch (e) {
      return CommissionResult.err(e.message ?? 'IP commission failed');
    }
  }

  // ── Device control ─────────────────────────────────────────────────────────

  Future<bool> toggleDevice(int nodeId, {required bool on}) async {
    try {
      return await _method.invokeMethod<bool>(
            'toggleDevice', {'nodeId': nodeId, 'on': on}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> setLevel(int nodeId, int level) async {
    try {
      return await _method.invokeMethod<bool>(
            'setLevel', {'nodeId': nodeId, 'level': level}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  // ── Thermostat ─────────────────────────────────────────────────────────────

  /// Reads LocalTemperature, OccupiedHeatingSetpoint, OccupiedCoolingSetpoint
  /// and SystemMode from the Thermostat cluster.
  /// All temperatures are in centidegrees (divide by 100 for °C).
  /// Returns null if the call fails.
  Future<({
    String productName,
    String vendorName,
    String vendorId,
    String productId,
    String hwVersion,
    String softwareVersion,
    int?   softwareVersionNum,
    String manufacturingDate,
    String partNumber,
    String productUrl,
    String serialNumber,
    String uniqueId,
  })?> readBasicInfo(int nodeId) async {
    try {
      final map = await _method
          .invokeMapMethod<String, dynamic>('readBasicInfo', {'nodeId': nodeId});
      if (map == null) return null;
      String s(String k) => (map[k] as String?) ?? '';
      final rawNum = map['softwareVersionNum'];
      final swNum  = rawNum is int && rawNum >= 0 ? rawNum : null;
      return (
        productName:        s('productName'),
        vendorName:         s('vendorName'),
        vendorId:           s('vendorId'),
        productId:          s('productId'),
        hwVersion:          s('hwVersion'),
        softwareVersion:    s('softwareVersion'),
        softwareVersionNum: swNum,
        manufacturingDate:  s('manufacturingDate'),
        partNumber:         s('partNumber'),
        productUrl:         s('productUrl'),
        serialNumber:       s('serialNumber'),
        uniqueId:           s('uniqueId'),
      );
    } on PlatformException catch (e) {
      debugPrint('readBasicInfo error: ${e.message}');
      return null;
    }
  }

  /// Reads the Descriptor cluster's ServerList attribute from [endpoint] and returns
  /// the list of server cluster IDs present on that endpoint.
  Future<List<int>> readServerClusterList(int nodeId, {int endpoint = 0}) async {
    try {
      final raw = await _method.invokeMethod<List<dynamic>>(
          'readServerClusterList', {'nodeId': nodeId, 'endpoint': endpoint});
      return raw?.map((e) => (e as int)).toList() ?? [];
    } on PlatformException catch (e) {
      debugPrint('readServerClusterList error: ${e.message}');
      return [];
    }
  }

  /// Reads EP0's Descriptor PartsList (attribute 0x0003) and returns the list
  /// of non-root endpoint numbers the device exposes.
  Future<List<int>> readPartsList(int nodeId) async {
    try {
      final raw = await _method.invokeMethod<List<dynamic>>(
          'readPartsList', {'nodeId': nodeId});
      return raw?.map((e) => (e as int)).toList() ?? [];
    } on PlatformException catch (e) {
      debugPrint('readPartsList error: ${e.message}');
      return [];
    }
  }

  Future<ThermostatState?> readThermostat(int nodeId) async {
    try {
      final map = await _method.invokeMapMethod<String, int>(
          'readThermostat', {'nodeId': nodeId});
      if (map == null) return null;
      int? orNull(int v) => v == -32768 || v == -2147483648 ? null : v;
      return ThermostatState(
        localTempCenti:    orNull(map['localTemp'] ?? -32768),
        heatingSetptCenti: orNull(map['heatingSetpoint'] ?? -32768),
        coolingSetptCenti: orNull(map['coolingSetpoint'] ?? -32768),
        systemMode:        map['systemMode'] == -1 ? null : map['systemMode'],
        controlSequence:   map['controlSequence'] == -1 ? null : map['controlSequence'],
      );
    } on PlatformException catch (e) {
      debugPrint('readThermostat error: ${e.message}');
      return null;
    }
  }

  /// Writes [centidegrees] to OccupiedHeatingSetpoint (int16, 0.01 °C units).
  Future<bool> writeHeatingSetpoint(int nodeId, int centidegrees) async {
    try {
      await _method.invokeMethod<bool>(
          'writeHeatingSetpoint', {'nodeId': nodeId, 'centidegrees': centidegrees});
      return true;
    } on PlatformException catch (e) {
      debugPrint('writeHeatingSetpoint error: ${e.message}');
      return false;
    }
  }

  /// Writes [mode] to SystemMode (0=Off 1=Auto 3=Cool 4=Heat 7=FanOnly).
  Future<bool> writeSystemMode(int nodeId, int mode) async {
    try {
      await _method.invokeMethod<bool>(
          'writeSystemMode', {'nodeId': nodeId, 'mode': mode});
      return true;
    } on PlatformException catch (e) {
      debugPrint('writeSystemMode error: ${e.message}');
      return false;
    }
  }

  /// Opens the Android Thread credential picker (system consent UI).
  /// Returns the selected hex dataset string, or empty string if cancelled.
  Future<String?> readAndroidThreadCredentials() async {
    try {
      return await _method.invokeMethod<String>('readAndroidThreadCredentials');
    } on PlatformException catch (e) {
      debugPrint('readAndroidThreadCredentials error: ${e.message}');
      return null;
    }
  }

  /// Scans the local network for Thread Border Routers via mDNS (_meshcop._udp).
  /// Returns a list of [ThreadBorderRouter] records (may take up to 6 s).
  Future<List<ThreadBorderRouter>> discoverThreadNetworks() async {
    try {
      final jsonStr = await _method.invokeMethod<String>('discoverThreadNetworks');
      if (jsonStr == null || jsonStr == '[]') return [];
      final list = json.decode(jsonStr) as List<dynamic>;
      return list
          .map((e) => ThreadBorderRouter.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('discoverThreadNetworks error: ${e.message}');
      return [];
    }
  }

  /// Reads Thread Network Diagnostics cluster (0x0035) from the device.
  /// Returns null if the cluster is absent (device is not on Thread).
  Future<ThreadNetworkDiagnostics?> readThreadNetworkDiagnostics(int nodeId) async {
    try {
      final jsonStr = await _method.invokeMethod<String>(
          'readThreadNetworkDiagnostics', {'nodeId': nodeId});
      if (jsonStr == null) return null;
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      return ThreadNetworkDiagnostics.fromJson(decoded);
    } on PlatformException catch (e) {
      debugPrint('readThreadNetworkDiagnostics: ${e.code} ${e.message}');
      return null;
    }
  }

  Future<String?> readClusters(int nodeId) async {
    try {
      return await _method.invokeMethod<String>('readClusters', {'nodeId': nodeId});
    } on PlatformException catch (e) {
      debugPrint('readClusters error: ${e.message}');
      return null;
    }
  }

  Future<int?> readDeviceTypeId(int nodeId) async {
    try {
      return await _method.invokeMethod<int>(
          'readDeviceType', {'nodeId': nodeId});
    } on PlatformException {
      return null;
    }
  }

  Future<void> identify(int nodeId) async {
    try {
      await _method.invokeMethod<void>('identify', {'nodeId': nodeId});
    } on PlatformException catch (e) {
      debugPrint('identify error: ${e.message}');
    }
  }

  Future<DeviceStateResult> readDeviceState(int nodeId) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
        'readDeviceState', {'nodeId': nodeId},
      );
      if (result == null) return const DeviceStateResult(isOnline: false);
      return DeviceStateResult(
        isOnline:        result['isOnline']   as bool? ?? false,
        isOn:            result['isOn']       as bool?,
        brightnessLevel: result['brightness'] as int?,
      );
    } on PlatformException {
      return const DeviceStateResult(isOnline: false);
    }
  }

  // ── OTA update ─────────────────────────────────────────────────────────────

  /// Downloads the OTA image from [otaUrl] to device cache and initiates the
  /// Matter BDX transfer to [nodeId]. Progress events arrive on the
  /// [deviceStateUpdates] stream as `{type:"otaProgress", phase:..., ...}`.
  ///
  /// [targetVersion] is passed as a String to avoid 32/64-bit channel issues.
  Future<bool> downloadAndFlash({
    required int    nodeId,
    required String otaUrl,
    required int    targetVersion,
    required String targetVersionString,
    bool            dryRun   = false,
    int             endpoint = 0,
  }) async {
    try {
      return await _method.invokeMethod<bool>('downloadAndFlash', {
        'nodeId':              nodeId,
        'otaUrl':              otaUrl,
        'targetVersion':       targetVersion.toString(),
        'targetVersionString': targetVersionString,
        'dryRun':              dryRun,
        'endpoint':            endpoint,
      }) ?? false;
    } on PlatformException catch (e) {
      debugPrint('downloadAndFlash error: ${e.message}');
      return false;
    }
  }

  Future<bool> cancelOta() async {
    try {
      return await _method.invokeMethod<bool>('cancelOta') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ── Share / remove / fabric ────────────────────────────────────────────────

  /// Returns nearby Wi-Fi networks visible to Android, sorted by signal
  /// strength, with the currently connected network first.
  /// Falls back to an empty list if location permission is denied or the
  /// system has no cached scan results.
  Future<List<WifiNetwork>> scanWifiNetworks() async {
    try {
      final raw = await _method.invokeMethod<List<dynamic>>('scanWifiNetworks');
      if (raw == null) return [];
      return raw
          .map((e) => WifiNetwork.fromMap(e as Map<Object?, Object?>))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('scanWifiNetworks error: ${e.message}');
      return [];
    }
  }

  Future<bool> shareDevice(int nodeId) async {
    try {
      return await _method.invokeMethod<bool>(
            'shareDevice', {'nodeId': nodeId}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> removeDevice(int nodeId) async {
    try {
      return await _method.invokeMethod<bool>(
            'removeDevice', {'nodeId': nodeId}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Runs all passive network checks (takes ~6 s) and returns a structured
  /// [NetworkDiagnosticsReport].  Returns null on error.
  Future<NetworkDiagnosticsReport?> runNetworkDiagnostics() async {
    try {
      final jsonStr =
          await _method.invokeMethod<String>('runNetworkDiagnostics');
      if (jsonStr == null) return null;
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      return NetworkDiagnosticsReport.fromJson(decoded);
    } on PlatformException catch (e) {
      debugPrint('runNetworkDiagnostics error: ${e.message}');
      return null;
    }
  }

  Future<String?> getFabricId() async {
    try {
      return await _method.invokeMethod<String>('getFabricId');
    } on PlatformException {
      return null;
    }
  }

  /// Returns the controller vendor ID used to create the fabric.
  /// This is a compile-time constant from ChipClient — currently a test VID
  /// (range 0xFFF1–0xFFF4 is reserved by the Matter spec for testing only).
  Future<int?> getVendorId() async {
    try {
      return await _method.invokeMethod<int>('getVendorId');
    } on PlatformException {
      return null;
    }
  }
}
