import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/basic_info.dart';
import '../models/commission_models.dart';
import '../models/network_diagnostics.dart';
import '../models/thermostat_models.dart';
import '../models/thread_models.dart';
import '../models/wifi_network.dart';
import 'matter_port.dart';

/// Flutter ↔ Android MethodChannel bridge.
///
/// Every public method maps 1-to-1 to a handler in [MainActivity] / [MatterBridge].
/// All channel calls are funnelled through [_invoke] which handles the
/// [PlatformException] → fallback value pattern in one place.
///
/// Implements [MatterPort] so callers can depend on the narrower sub-interfaces
/// ([MatterSubscriptionPort], [MatterCommissionPort], [MatterClusterPort],
/// [MatterFabricPort]) and be tested with fakes.
class MatterChannel implements MatterPort {
  static const _method       = MethodChannel('com.example.matter_home/matter');
  static const _events       = EventChannel('com.example.matter_home/commission_events');
  static const _deviceEvents = EventChannel('com.example.matter_home/device_state');

  // ── Internal helper ────────────────────────────────────────────────────────

  /// Invokes [method] with optional [args], returns [fallback] on any
  /// [PlatformException].  Supply [decode] to transform the raw result into [T].
  Future<T> _invoke<T>(
    String method,
    T fallback, {
    Map<String, dynamic>? args,
    T Function(dynamic raw)? decode,
  }) async {
    try {
      final raw = await _method.invokeMethod<dynamic>(method, args);
      return decode != null ? decode(raw) : (raw as T? ?? fallback);
    } on PlatformException catch (e) {
      debugPrint('$method error: ${e.message}');
      return fallback;
    }
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Emits plain-text progress lines from the Android commissioning flow.
  @override
  Stream<String> get commissionEvents =>
      _events.receiveBroadcastStream().map((e) => e as String);

  /// Emits subscription updates from the Android CHIP SDK.
  /// Each event has at least `nodeId` (int) and `type` (String).
  Stream<Map<String, dynamic>> get deviceStateUpdates =>
      _deviceEvents.receiveBroadcastStream().map(
        (e) => Map<String, dynamic>.from(e as Map<Object?, Object?>));

  // ── Subscription control ───────────────────────────────────────────────────

  @override
  Future<bool> startSubscription(int nodeId) =>
      _invoke('startSubscription', false, args: {'nodeId': nodeId});

  @override
  Future<void> stopSubscription(int nodeId) =>
      _invoke('stopSubscription', null, args: {'nodeId': nodeId});

  // ── Parse setup payload ────────────────────────────────────────────────────

  /// Parses a QR code or 11-digit manual pairing code.
  /// Returns null if the payload is invalid or the SDK is unavailable.
  @override
  Future<ParsedPayload?> parsePayload(String payload) =>
      _invoke<ParsedPayload?>('parsePayload', null, args: {'payload': payload},
          decode: (raw) {
            if (raw == null) return null;
            final map = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
            DiscoveryCapability cap(String s) => switch (s) {
              'BLE'        => DiscoveryCapability.ble,
              'ON_NETWORK' => DiscoveryCapability.onNetwork,
              'SOFT_AP'    => DiscoveryCapability.softAp,
              'WIFI_PAF'   => DiscoveryCapability.wifiPaf,
              'NFC'        => DiscoveryCapability.nfc,
              _            => DiscoveryCapability.unknown,
            };
            return ParsedPayload(
              vendorId:              map['vendorId']              as int,
              productId:             map['productId']             as int,
              discriminator:         map['discriminator']         as int,
              hasShortDiscriminator: map['hasShortDiscriminator'] as bool? ?? false,
              setupPinCode:          map['setupPinCode']          as int? ?? 0,
              discoveryCapabilities: (map['discoveryCapabilities'] as List<dynamic>?)
                      ?.map((e) => cap(e as String)).toList() ?? [],
            );
          });

  // ── Commission via BLE ─────────────────────────────────────────────────────

  @override
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

  @override
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

  @override
  Future<bool> toggleDevice(int nodeId, {required bool on}) =>
      _invoke('toggleDevice', false, args: {'nodeId': nodeId, 'on': on});

  @override
  Future<bool> setLevel(int nodeId, int level) =>
      _invoke('setLevel', false, args: {'nodeId': nodeId, 'level': level});

  // ── Basic information ──────────────────────────────────────────────────────

  /// Reads the BasicInformation cluster (0x0028) from EP0.
  /// Returns null if the device is unreachable.
  @override
  Future<BasicInfo?> readBasicInfo(int nodeId) =>
      _invoke<BasicInfo?>('readBasicInfo', null, args: {'nodeId': nodeId},
          decode: (raw) {
            if (raw == null) return null;
            final map = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
            String s(String k) => (map[k] as String?) ?? '';
            final rawNum = map['softwareVersionNum'];
            final swNum  = rawNum is int && rawNum >= 0 ? rawNum : null;
            return BasicInfo(
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
          });

  /// Reads the ServerList attribute from the Descriptor cluster on [endpoint].
  Future<List<int>> readServerClusterList(int nodeId, {int endpoint = 0}) =>
      _invoke<List<int>>('readServerClusterList', [],
          args: {'nodeId': nodeId, 'endpoint': endpoint},
          decode: (raw) => (raw as List<dynamic>?)?.map((e) => e as int).toList() ?? []);

  /// Reads the PartsList from EP0's Descriptor cluster.
  Future<List<int>> readPartsList(int nodeId) =>
      _invoke<List<int>>('readPartsList', [], args: {'nodeId': nodeId},
          decode: (raw) => (raw as List<dynamic>?)?.map((e) => e as int).toList() ?? []);

  // ── Thermostat ─────────────────────────────────────────────────────────────

  @override
  Future<ThermostatState?> readThermostat(int nodeId) =>
      _invoke<ThermostatState?>('readThermostat', null, args: {'nodeId': nodeId},
          decode: (raw) {
            if (raw == null) return null;
            final map = Map<String, int>.from(raw as Map<Object?, Object?>);
            int? orNull(int v) => v == -32768 || v == -2147483648 ? null : v;
            return ThermostatState(
              localTempCenti:    orNull(map['localTemp']    ?? -32768),
              heatingSetptCenti: orNull(map['heatingSetpoint'] ?? -32768),
              coolingSetptCenti: orNull(map['coolingSetpoint'] ?? -32768),
              systemMode:        map['systemMode']      == -1 ? null : map['systemMode'],
              controlSequence:   map['controlSequence'] == -1 ? null : map['controlSequence'],
            );
          });

  @override
  Future<bool> writeHeatingSetpoint(int nodeId, int centidegrees) =>
      _invoke('writeHeatingSetpoint', false,
          args: {'nodeId': nodeId, 'centidegrees': centidegrees});

  @override
  Future<bool> writeSystemMode(int nodeId, int mode) =>
      _invoke('writeSystemMode', false, args: {'nodeId': nodeId, 'mode': mode});

  // ── Sensors / Battery / Humidity ───────────────────────────────────────────

  @override
  Future<String?> readAndroidThreadCredentials() =>
      _invoke<String?>('readAndroidThreadCredentials', null);

  Future<List<ThreadBorderRouter>> discoverThreadNetworks() =>
      _invoke<List<ThreadBorderRouter>>('discoverThreadNetworks', [],
          decode: (raw) {
            if (raw == null) return [];
            final list = json.decode(raw as String) as List<dynamic>;
            return list.map((e) =>
                ThreadBorderRouter.fromJson(e as Map<String, dynamic>)).toList();
          });

  @override
  Future<ThreadNetworkDiagnostics?> readThreadNetworkDiagnostics(int nodeId) =>
      _invoke<ThreadNetworkDiagnostics?>('readThreadNetworkDiagnostics', null,
          args: {'nodeId': nodeId},
          decode: (raw) {
            if (raw == null) return null;
            return ThreadNetworkDiagnostics.fromJson(
                json.decode(raw as String) as Map<String, dynamic>);
          });

  @override
  Future<String?> readClusters(int nodeId) =>
      _invoke<String?>('readClusters', null, args: {'nodeId': nodeId});

  @override
  Future<int?> readDeviceTypeId(int nodeId) =>
      _invoke<int?>('readDeviceType', null, args: {'nodeId': nodeId});

  @override
  Future<void> identify(int nodeId, {int seconds = 15}) =>
      _invoke('identify', null, args: {'nodeId': nodeId, 'seconds': seconds});

  @override
  Future<DeviceStateResult> readDeviceState(int nodeId) =>
      _invoke('readDeviceState', const DeviceStateResult(isOnline: false),
          args: {'nodeId': nodeId},
          decode: (raw) {
            if (raw == null) return const DeviceStateResult(isOnline: false);
            final result = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
            return DeviceStateResult(
              isOnline:        result['isOnline']   as bool? ?? false,
              isOn:            result['isOn']       as bool?,
              brightnessLevel: result['brightness'] as int?,
            );
          });

  // ── OTA update ─────────────────────────────────────────────────────────────

  /// Downloads the OTA image from [otaUrl] and initiates the Matter BDX transfer.
  /// Progress events arrive on [deviceStateUpdates] as `{type:"otaProgress", ...}`.
  /// [targetVersion] is passed as a String to avoid 32/64-bit channel issues.
  @override
  Future<bool> downloadAndFlash({
    required int    nodeId,
    required String otaUrl,
    required int    targetVersion,
    required String targetVersionString,
    bool            dryRun   = false,
    int             endpoint = 0,
  }) =>
      _invoke('downloadAndFlash', false, args: {
        'nodeId':              nodeId,
        'otaUrl':              otaUrl,
        'targetVersion':       targetVersion.toString(),
        'targetVersionString': targetVersionString,
        'dryRun':              dryRun,
        'endpoint':            endpoint,
      });

  @override
  Future<bool> cancelOta() => _invoke('cancelOta', false);

  // ── Share / remove / fabric ────────────────────────────────────────────────

  Future<List<WifiNetwork>> scanWifiNetworks() =>
      _invoke<List<WifiNetwork>>('scanWifiNetworks', [],
          decode: (raw) => (raw as List<dynamic>?)
                  ?.map((e) => WifiNetwork.fromMap(e as Map<Object?, Object?>))
                  .toList() ?? []);

  @override
  Future<bool> shareDevice(int nodeId) =>
      _invoke('shareDevice', false, args: {'nodeId': nodeId});

  @override
  Future<bool> removeDevice(int nodeId) =>
      _invoke('removeDevice', false, args: {'nodeId': nodeId});

  @override
  Future<NetworkDiagnosticsReport?> runNetworkDiagnostics() =>
      _invoke<NetworkDiagnosticsReport?>('runNetworkDiagnostics', null,
          decode: (raw) {
            if (raw == null) return null;
            return NetworkDiagnosticsReport.fromJson(
                json.decode(raw as String) as Map<String, dynamic>);
          });

  @override
  Future<String?> getFabricId() => _invoke<String?>('getFabricId', null);

  @override
  Future<int?> getVendorId() => _invoke<int?>('getVendorId', null);
}
