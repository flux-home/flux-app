import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:matter_home/models/basic_info.dart';
import 'package:matter_home/models/commissionable_device.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/network_diagnostics.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/models/wifi_network.dart';
import 'package:matter_home/services/matter_port.dart';

/// Flutter ↔ platform MethodChannel bridge.
///
/// Every public method maps 1-to-1 to a handler in MainActivity / MatterBridge.
/// All channel calls are funnelled through [_invoke] which handles the
/// [PlatformException] → fallback value pattern in one place.
///
/// Implements [MatterPort] so callers can depend on the narrower sub-interfaces
/// ([MatterSubscriptionPort], [MatterCommissionPort], [MatterClusterPort],
/// [MatterFabricPort]) and be tested with fakes.
class MatterChannel implements MatterPort {
  static const _method = MethodChannel('com.fluxhome.app/matter');
  static const _events = EventChannel('com.fluxhome.app/commission_events');
  static const _deviceEvents = EventChannel('com.fluxhome.app/device_state');

  // ── Internal helper ────────────────────────────────────────────────────────

  /// Invokes [method] with optional [args], returns [fallback] on any
  /// [PlatformException].  Supply [decode] to transform the raw result into [T].
  Future<T> _invoke<T>(String method, T fallback, {Map<String, dynamic>? args, T Function(dynamic raw)? decode}) async {
    try {
      final raw = await _method.invokeMethod<dynamic>(method, args);
      return decode != null ? decode(raw) : (raw as T? ?? fallback);
    } on PlatformException catch (e) {
      debugPrint('$method error: ${e.message}');
      return fallback;
    }
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Emits plain-text progress lines from the platform commissioning flow.
  @override
  Stream<String> get commissionEvents => _events.receiveBroadcastStream().map((e) => e as String);

  /// Decodes the raw platform-channel map into a typed [DeviceStateEvent].
  ///
  /// This is the single place in Dart that knows about the map's key names.
  /// Every consumer above this layer works with the sealed class instead.
  @override
  Stream<DeviceStateEvent> get deviceStateUpdates =>
      _deviceEvents.receiveBroadcastStream().map((e) {
        final map = Map<String, dynamic>.from(e as Map<Object?, Object?>);
        final nodeId = (map['nodeId'] as num?)?.toInt() ?? 0;
        return switch (map['type'] as String?) {
          'established' => SubscriptionEstablishedEvent(nodeId),
          'resubscribing' => SubscriptionResubscribingEvent(
            nodeId,
            (map['nextMs'] as num?)?.toInt() ?? 0,
          ),
          'error' => SubscriptionErrorEvent(
            nodeId,
            map['message'] as String? ?? 'unknown',
          ),
          'otaProgress' => OtaProgressEvent(
            nodeId,
            phase:    map['phase']    as String? ?? '',
            progress: (map['progress'] as num?)?.toInt(),
            message:  map['message']  as String?,
          ),
          // Default branch covers 'update' and any future attr event types.
          _ => SubscriptionUpdateEvent(nodeId, _stripEnvelope(map)),
        };
      });

  /// Removes the envelope keys so [SubscriptionUpdateEvent.attrs] contains
  /// only the attribute payload (the keys defined in SubscriptionManager.kt).
  static Map<String, dynamic> _stripEnvelope(Map<String, dynamic> m) {
    final attrs = Map<String, dynamic>.from(m);
    attrs.remove('nodeId');
    attrs.remove('type');
    return attrs;
  }

  // ── Subscription control ───────────────────────────────────────────────────

  @override
  Future<bool> startSubscription(int nodeId) => _invoke('startSubscription', false, args: {'nodeId': nodeId});

  @override
  Future<void> stopSubscription(int nodeId) => _invoke('stopSubscription', null, args: {'nodeId': nodeId});

  // ── Parse setup payload ────────────────────────────────────────────────────

  /// Parses a QR code or 11-digit manual pairing code.
  /// Returns null if the payload is invalid or the SDK is unavailable.
  @override
  Future<ParsedPayload?> parsePayload(String payload) => _invoke<ParsedPayload?>(
    'parsePayload',
    null,
    args: {'payload': payload},
    decode: (raw) {
      if (raw == null) return null;
      final map = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
      DiscoveryCapability cap(String s) => switch (s) {
        'BLE' => DiscoveryCapability.ble,
        'ON_NETWORK' => DiscoveryCapability.onNetwork,
        'SOFT_AP' => DiscoveryCapability.softAp,
        'WIFI_PAF' => DiscoveryCapability.wifiPaf,
        'NFC' => DiscoveryCapability.nfc,
        _ => DiscoveryCapability.unknown,
      };
      return ParsedPayload(
        vendorId: map['vendorId'] as int,
        productId: map['productId'] as int,
        discriminator: map['discriminator'] as int,
        hasShortDiscriminator: map['hasShortDiscriminator'] as bool? ?? false,
        setupPinCode: map['setupPinCode'] as int? ?? 0,
        discoveryCapabilities:
            (map['discoveryCapabilities'] as List<dynamic>?)?.map((e) => cap(e as String)).toList() ?? [],
      );
    },
  );

  // ── Commission via BLE ─────────────────────────────────────────────────────

  @override
  Future<CommissionResult> commissionDevice(
    String payload, {
    String? wifiSsid,
    String? wifiPassword,
    String? threadDatasetHex,
  }) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>('commissionDevice', {
        'payload': payload,
        'wifiSsid': wifiSsid,
        'wifiPassword': wifiPassword,
        'threadDatasetHex': threadDatasetHex,
      });
      if (result == null) return CommissionResult.err('No result from channel');
      return CommissionResult.ok(nodeId: result['nodeId'] as int, deviceTypeId: result['deviceTypeId'] as int?);
    } on PlatformException catch (e) {
      return CommissionResult.err(e.message ?? 'Commission failed');
    }
  }

  @override
  Future<CommissionResult> commissionViaIp({
    required String ipAddress,
    required int discriminator,
    required int setupPinCode,
    int port = 5540,
  }) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>('commissionViaIp', {
        'ipAddress': ipAddress,
        'port': port,
        'discriminator': discriminator,
        'setupPinCode': setupPinCode,
      });
      if (result == null) return CommissionResult.err('No result from channel');
      return CommissionResult.ok(nodeId: result['nodeId'] as int, deviceTypeId: result['deviceTypeId'] as int?);
    } on PlatformException catch (e) {
      return CommissionResult.err(e.message ?? 'IP commission failed');
    }
  }

  @override
  Future<CommissionResult> commissionViaCode({required String setupCode}) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
          'commissionViaCode', {'setupCode': setupCode});
      if (result == null) return CommissionResult.err('No result from channel');
      return CommissionResult.ok(
          nodeId: result['nodeId'] as int, deviceTypeId: result['deviceTypeId'] as int?);
    } on PlatformException catch (e) {
      return CommissionResult.err(e.message ?? 'On-network commission failed');
    }
  }

  // ── Device control ─────────────────────────────────────────────────────────

  @override
  Future<bool> toggleDevice(int nodeId, {required bool on}) =>
      _invoke('toggleDevice', false, args: {'nodeId': nodeId, 'on': on});

  @override
  Future<bool> setLevel(int nodeId, int level) => _invoke('setLevel', false, args: {'nodeId': nodeId, 'level': level});

  @override
  Future<bool> stepLevel(int nodeId, {required bool stepUp}) =>
      _invoke('stepLevel', false, args: {'nodeId': nodeId, 'stepUp': stepUp});

  // ── Window Covering ────────────────────────────────────────────────────────

  @override
  Future<bool> coveringUp(int nodeId) => _invoke('coveringUp', false, args: {'nodeId': nodeId});

  @override
  Future<bool> coveringDown(int nodeId) => _invoke('coveringDown', false, args: {'nodeId': nodeId});

  @override
  Future<bool> coveringStop(int nodeId) => _invoke('coveringStop', false, args: {'nodeId': nodeId});

  @override
  Future<bool> coveringGoToLift(int nodeId, int percent100ths) =>
      _invoke('coveringGoToLift', false, args: {'nodeId': nodeId, 'percent100ths': percent100ths});

  // ── Fan Control ────────────────────────────────────────────────────────────

  @override
  Future<bool> setFanMode(int nodeId, int mode) => _invoke('setFanMode', false, args: {'nodeId': nodeId, 'mode': mode});

  @override
  Future<bool> setFanPercent(int nodeId, int percent) =>
      _invoke('setFanPercent', false, args: {'nodeId': nodeId, 'percent': percent});

  // ── Color Control ──────────────────────────────────────────────────────────

  @override
  Future<bool> setColorTemperature(int nodeId, int mireds) =>
      _invoke('setColorTemperature', false, args: {'nodeId': nodeId, 'mireds': mireds});

  // ── Basic information ──────────────────────────────────────────────────────

  /// Reads the BasicInformation cluster (0x0028) from EP0.
  /// Returns null if the device is unreachable.
  @override
  Future<BasicInfo?> readBasicInfo(int nodeId) => _invoke<BasicInfo?>(
    'readBasicInfo',
    null,
    args: {'nodeId': nodeId},
    decode: (raw) {
      if (raw == null) return null;
      final map = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
      String s(String k) => (map[k] as String?) ?? '';
      final rawNum = map['softwareVersionNum'];
      final swNum = rawNum is int && rawNum >= 0 ? rawNum : null;
      return BasicInfo(
        productName: s('productName'),
        vendorName: s('vendorName'),
        vendorId: s('vendorId'),
        productId: s('productId'),
        hwVersion: s('hwVersion'),
        softwareVersion: s('softwareVersion'),
        softwareVersionNum: swNum,
        manufacturingDate: s('manufacturingDate'),
        partNumber: s('partNumber'),
        productUrl: s('productUrl'),
        serialNumber: s('serialNumber'),
        uniqueId: s('uniqueId'),
      );
    },
  );

  /// Reads the ServerList attribute from the Descriptor cluster on [endpoint].
  @override
  Future<List<int>> readServerClusterList(int nodeId, {int endpoint = 0}) => _invoke<List<int>>(
    'readServerClusterList',
    [],
    args: {'nodeId': nodeId, 'endpoint': endpoint},
    decode: (raw) => (raw as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
  );

  /// Reads the PartsList from EP0's Descriptor cluster.
  @override
  Future<List<int>> readPartsList(int nodeId) => _invoke<List<int>>(
    'readPartsList',
    [],
    args: {'nodeId': nodeId},
    decode: (raw) => (raw as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
  );

  // ── Thermostat ─────────────────────────────────────────────────────────────

  @override
  Future<ThermostatState?> readThermostat(int nodeId) => _invoke<ThermostatState?>(
    'readThermostat',
    null,
    args: {'nodeId': nodeId},
    decode: (raw) {
      if (raw == null) return null;
      // Use int? map — Kotlin sends null for attributes not present on the
      // device, and Map<String,int>.from() would silently drop those entries.
      final raw2 = raw as Map<Object?, Object?>;
      int? get(String key) {
        final v = raw2[key];
        if (v == null) return null;
        final i = (v as num).toInt();
        return (i == -32768 || i == -2147483648) ? null : i;
      }

      return ThermostatState(
        localTempCenti: get('localTemp'),
        heatingSetptCenti: get('heatingSetpoint'),
        coolingSetptCenti: get('coolingSetpoint'),
        systemMode: get('systemMode'),
        controlSequence: get('controlSequence'),
        minHeatSetptCenti: get('minHeatSetpt'),
        maxHeatSetptCenti: get('maxHeatSetpt'),
        minCoolSetptCenti: get('minCoolSetpt'),
        maxCoolSetptCenti: get('maxCoolSetpt'),
        absMinHeatSetptCenti: get('absMinHeatSetpt'),
        absMaxHeatSetptCenti: get('absMaxHeatSetpt'),
        absMinCoolSetptCenti: get('absMinCoolSetpt'),
        absMaxCoolSetptCenti: get('absMaxCoolSetpt'),
      );
    },
  );

  @override
  Future<bool> writeHeatingSetpoint(int nodeId, int centidegrees) =>
      _invoke('writeHeatingSetpoint', false, args: {'nodeId': nodeId, 'centidegrees': centidegrees});

  @override
  Future<bool> writeSystemMode(int nodeId, int mode) =>
      _invoke('writeSystemMode', false, args: {'nodeId': nodeId, 'mode': mode});

  // ── Sensors / Battery / Humidity ───────────────────────────────────────────

  @override
  Future<String?> readSystemThreadCredentials() => _invoke<String?>('readSystemThreadCredentials', null);

  @override
  Future<List<ThreadBorderRouter>> discoverThreadNetworks() => _invoke<List<ThreadBorderRouter>>(
    'discoverThreadNetworks',
    [],
    decode: (raw) {
      if (raw == null) return [];
      final list = json.decode(raw as String) as List<dynamic>;
      return list.map((e) => ThreadBorderRouter.fromJson(e as Map<String, dynamic>)).toList();
    },
  );

  @override
  Future<ThreadNetworkDiagnostics?> readThreadNetworkDiagnostics(int nodeId) => _invoke<ThreadNetworkDiagnostics?>(
    'readThreadNetworkDiagnostics',
    null,
    args: {'nodeId': nodeId},
    decode: (raw) {
      if (raw == null) return null;
      return ThreadNetworkDiagnostics.fromJson(json.decode(raw as String) as Map<String, dynamic>);
    },
  );

  @override
  Future<String?> readClusters(int nodeId) => _invoke<String?>('readClusters', null, args: {'nodeId': nodeId});

  @override
  Future<int?> readDeviceTypeId(int nodeId) => _invoke<int?>('readDeviceType', null, args: {'nodeId': nodeId});

  @override
  Future<void> identify(int nodeId, {int seconds = 15}) =>
      _invoke('identify', null, args: {'nodeId': nodeId, 'seconds': seconds});

  @override
  Future<bool> lockDoor(int nodeId, {String? pin}) =>
      _invoke('lockDoor', false, args: {'nodeId': nodeId, if (pin != null) 'pin': pin});

  @override
  Future<bool> unlockDoor(int nodeId, {String? pin}) =>
      _invoke('unlockDoor', false, args: {'nodeId': nodeId, if (pin != null) 'pin': pin});

  Future<DeviceStateResult> readDeviceState(int nodeId) => _invoke(
    'readDeviceState',
    const DeviceStateResult(isOnline: false),
    args: {'nodeId': nodeId},
    decode: (raw) {
      if (raw == null) return const DeviceStateResult(isOnline: false);
      final result = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
      return DeviceStateResult(
        isOnline: result['isOnline'] as bool? ?? false,
        isOn: result['isOn'] as bool?,
        brightnessLevel: result['brightness'] as int?,
      );
    },
  );

  // ── OTA update ─────────────────────────────────────────────────────────────

  /// Downloads the OTA image from [otaUrl] and initiates the Matter BDX transfer.
  /// Progress events arrive on [deviceStateUpdates] as `{type:"otaProgress", ...}`.
  /// [targetVersion] is passed as a String to avoid 32/64-bit channel issues.
  @override
  Future<bool> downloadAndFlash({
    required int nodeId,
    required String otaUrl,
    required int targetVersion,
    required String targetVersionString,
    bool dryRun = false,
    int endpoint = 0,
  }) => _invoke(
    'downloadAndFlash',
    false,
    args: {
      'nodeId': nodeId,
      'otaUrl': otaUrl,
      'targetVersion': targetVersion.toString(),
      'targetVersionString': targetVersionString,
      'dryRun': dryRun,
      'endpoint': endpoint,
    },
  );

  @override
  Future<bool> cancelOta() => _invoke('cancelOta', false);

  // ── Share / remove / fabric ────────────────────────────────────────────────

  @override
  Future<List<WifiNetwork>> scanWifiNetworks() => _invoke<List<WifiNetwork>>(
    'scanWifiNetworks',
    [],
    decode: (raw) =>
        (raw as List<dynamic>?)?.map((e) => WifiNetwork.fromMap(e as Map<Object?, Object?>)).toList() ?? [],
  );

  @override
  Future<void> provideCredentials({String? ssid, String? password, String? threadDatasetHex}) => _invoke<void>(
    'provideCredentials',
    null,
    args: {
      if (ssid != null) 'ssid': ssid,
      if (password != null) 'password': password,
      if (threadDatasetHex != null) 'threadDatasetHex': threadDatasetHex,
    },
  );

  @override
  Future<ShareDeviceResult?> shareDevice(int nodeId, {int vendorId = 0, int productId = 0}) =>
      _invoke<ShareDeviceResult?>(
        'shareDevice',
        null,
        args: {'nodeId': nodeId, 'vendorId': vendorId, 'productId': productId},
        decode: (raw) {
          if (raw == null) return null;
          final map = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
          return ShareDeviceResult(
            qrCodePayload:     map['qrCodePayload']     as String,
            manualPairingCode: map['manualPairingCode'] as String,
          );
        },
      );

  @override
  Future<bool> removeDevice(int nodeId) => _invoke('removeDevice', false, args: {'nodeId': nodeId});

  @override
  Future<NetworkDiagnosticsReport?> runNetworkDiagnostics() => _invoke<NetworkDiagnosticsReport?>(
    'runNetworkDiagnostics',
    null,
    decode: (raw) {
      if (raw == null) return null;
      return NetworkDiagnosticsReport.fromJson(json.decode(raw as String) as Map<String, dynamic>);
    },
  );

  @override
  Future<String?> getFabricId() => _invoke<String?>('getFabricId', null);

  @override
  Future<int?> getVendorId() => _invoke<int?>('getVendorId', null);

  @override
  Future<List<CommissionableDevice>> discoverCommissionableNodes() =>
      _invoke<List<CommissionableDevice>>(
        'discoverCommissionableNodes',
        const [],
        decode: (raw) {
          if (raw == null) return const [];
          return (raw as List<dynamic>)
              .map((e) => CommissionableDevice.fromMap(
                    Map<String, dynamic>.from(e as Map<Object?, Object?>)))
              .toList();
        },
      );
}
