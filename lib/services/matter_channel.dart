import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'matter_vendors.dart';

// ── Battery info ────────────────────────────────────────────────────────────

/// Data returned by [MatterChannel.readBattery].
class BatteryInfo {
  /// 0–100 % derived from BatPercentRemaining, or null if not reported.
  final int? percent;
  /// BatChargeLevel: 0 = OK, 1 = Warning, 2 = Critical. Null if not reported.
  final int? chargeLevel;
  /// BatVoltage in mV, or null if not reported.
  final int? voltageMilliV;

  const BatteryInfo({this.percent, this.chargeLevel, this.voltageMilliV});

  /// True when there is at least something to display.
  bool get hasData => percent != null || chargeLevel != null || voltageMilliV != null;
}

// ── Parsed setup payload ───────────────────────────────────────────────────

enum DiscoveryCapability { ble, onNetwork, softAp, wifiPaf, nfc, unknown }

class ParsedPayload {
  final int vendorId;
  final int productId;
  final int discriminator;
  final bool hasShortDiscriminator;
  final List<DiscoveryCapability> discoveryCapabilities;
  /// Setup PIN code encoded in the QR payload (up to 27 bits).
  final int setupPinCode;

  const ParsedPayload({
    required this.vendorId,
    required this.productId,
    required this.discriminator,
    required this.hasShortDiscriminator,
    required this.discoveryCapabilities,
    required this.setupPinCode,
  });

  /// True when the device can be commissioned over BLE.
  bool get hasBle => discoveryCapabilities.contains(DiscoveryCapability.ble);

  /// True when the device is already on the network (IP commissioning).
  bool get hasOnNetwork =>
      discoveryCapabilities.contains(DiscoveryCapability.onNetwork);

  /// Whether BLE is the preferred commissioning transport.
  bool get prefersBle => hasBle;

  /// Suggested device name derived from the vendor ID.
  /// Returns the vendor name from the CSA registry, or 'Unknown' if the VID
  /// is not in the list.
  String get suggestedName =>
      kMatterVendors[vendorId] ?? 'Unknown';
}

/// Result returned after a commissioning attempt.
class CommissionResult {
  final bool success;
  final int? nodeId;
  final int? deviceTypeId;
  final String? error;

  const CommissionResult._({
    required this.success,
    this.nodeId,
    this.deviceTypeId,
    this.error,
  });

  factory CommissionResult.ok({required int nodeId, int? deviceTypeId}) =>
      CommissionResult._(success: true, nodeId: nodeId, deviceTypeId: deviceTypeId);

  factory CommissionResult.err(String error) =>
      CommissionResult._(success: false, error: error);
}

/// Result of a device-state read.
class DeviceStateResult {
  final bool isOnline;
  final bool? isOn;
  final int? brightnessLevel;

  const DeviceStateResult({
    required this.isOnline,
    this.isOn,
    this.brightnessLevel,
  });
}

class ThermostatState {
  /// All temperatures in centidegrees (0.01 °C). Null = not available.
  final int? localTempCenti;
  final int? heatingSetptCenti;
  final int? coolingSetptCenti;
  /// 0=Off 1=Auto 3=Cool 4=Heat 5=EmergencyHeat 6=Precooling 7=FanOnly
  final int? systemMode;
  /// ControlSequenceOfOperation (0x001B):
  ///   0/1 = CoolingOnly, 2/3 = HeatingOnly, 4/5 = CoolingAndHeating
  final int? controlSequence;

  const ThermostatState({
    this.localTempCenti,
    this.heatingSetptCenti,
    this.coolingSetptCenti,
    this.systemMode,
    this.controlSequence,
  });

  double? get localTempC =>
      localTempCenti != null ? localTempCenti! / 100.0 : null;
  double? get heatingSetptC =>
      heatingSetptCenti != null ? heatingSetptCenti! / 100.0 : null;
  double? get coolingSetptC =>
      coolingSetptCenti != null ? coolingSetptCenti! / 100.0 : null;

  /// True when the device supports heating (CSO 2, 3, 4, 5; or unknown).
  bool get supportsHeating {
    if (controlSequence == null) return true; // assume heating if unknown
    return const {2, 3, 4, 5}.contains(controlSequence);
  }

  /// True only when the device explicitly advertises cooling (CSO 0, 1, 4, 5).
  bool get supportsCooling {
    if (controlSequence == null) return false; // don't show if unknown
    return const {0, 1, 4, 5}.contains(controlSequence);
  }

  static const _modeNames = <int, String>{
    0: 'Off', 1: 'Auto', 3: 'Cool', 4: 'Heat',
    5: 'Emergency Heat', 6: 'Precooling', 7: 'Fan Only', 8: 'Dry', 9: 'Sleep',
  };
  String get systemModeName =>
      systemMode != null ? (_modeNames[systemMode!] ?? 'Mode $systemMode') : '—';

  /// The mode buttons to show, derived from ControlSequenceOfOperation.
  List<({int mode, String label})> get availableModes {
    const off  = (mode: 0, label: 'Off');
    const auto = (mode: 1, label: 'Auto');
    const cool = (mode: 3, label: 'Cool');
    const heat = (mode: 4, label: 'Heat');
    return switch (controlSequence) {
      0 || 1 => [off, cool],          // cooling only
      2 || 3 => [off, heat],          // heating only
      4 || 5 => [off, heat, cool, auto], // both
      _      => [off, heat, cool, auto], // unknown — show all
    };
  }
}

/// A Thread Border Router discovered via mDNS (_meshcop._udp).
class ThreadBorderRouter {
  final String serviceName;
  final String networkName;
  final String extPanId;
  final String vendorName;
  final String modelName;
  final String host;
  final int    port;
  /// Raw TXT record key→value pairs (values decoded as UTF-8 or hex).
  final Map<String, String> txt;

  const ThreadBorderRouter({
    required this.serviceName,
    required this.networkName,
    required this.extPanId,
    required this.vendorName,
    required this.modelName,
    required this.host,
    required this.port,
    this.txt = const {},
  });

  factory ThreadBorderRouter.fromJson(Map<String, dynamic> j) =>
      ThreadBorderRouter(
        serviceName: j['serviceName'] as String? ?? '',
        networkName: j['networkName'] as String? ?? '',
        extPanId:    j['extPanId']    as String? ?? '',
        vendorName:  j['vendorName']  as String? ?? '',
        modelName:   j['modelName']   as String? ?? '',
        host:        j['host']        as String? ?? '',
        port:        j['port']        as int?    ?? 0,
        txt: (j['txt'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())),
      );
}

// ── Network diagnostics models ─────────────────────────────────────────────

class PhoneIpv6Check {
  final bool hasRoutableIpv6;
  final List<String> guaAddresses;
  final List<String> ulaAddresses;
  final List<String> linkLocalAddresses;

  const PhoneIpv6Check({
    required this.hasRoutableIpv6,
    required this.guaAddresses,
    required this.ulaAddresses,
    required this.linkLocalAddresses,
  });

  factory PhoneIpv6Check.fromJson(Map<String, dynamic> j) => PhoneIpv6Check(
        hasRoutableIpv6:    j['hasRoutableIpv6'] as bool? ?? false,
        guaAddresses:       _strList(j['guaAddresses']),
        ulaAddresses:       _strList(j['ulaAddresses']),
        linkLocalAddresses: _strList(j['linkLocalAddresses']),
      );
}

class StateBitmapInfo {
  final int    raw;
  /// bits [2:0] — 0=none 1=UDP 2=TCP
  final int    connectionMode;
  final String connectionModeLabel;
  /// bits [4:3] — 0=not-initialised 1=initialised 2=active/attached
  final int    threadInterfaceStatus;
  final String threadInterfaceLabel;
  /// bits [6:5] — 0=infrequent 1=high
  final int    availability;
  final bool   bbrActive;
  final bool   bbrIsPrimary;

  const StateBitmapInfo({
    required this.raw,
    required this.connectionMode,
    required this.connectionModeLabel,
    required this.threadInterfaceStatus,
    required this.threadInterfaceLabel,
    required this.availability,
    required this.bbrActive,
    required this.bbrIsPrimary,
  });

  /// Thread interface fully active and attached to a Thread mesh.
  bool get threadInterfaceActive  => threadInterfaceStatus == 2;
  bool get hasExternalConnectivity => connectionMode != 0;

  factory StateBitmapInfo.fromJson(Map<String, dynamic> j) => StateBitmapInfo(
        raw:                    (j['raw'] as num).toInt(),
        connectionMode:         j['connectionMode']        as int?    ?? 0,
        connectionModeLabel:    j['connectionModeLabel']   as String? ?? 'none',
        threadInterfaceStatus:  j['threadInterfaceStatus'] as int?    ?? 0,
        threadInterfaceLabel:   j['threadInterfaceLabel']  as String? ?? 'Not initialised',
        availability:           j['availability']          as int?    ?? 0,
        bbrActive:              j['bbrActive']             as bool?   ?? false,
        bbrIsPrimary:           j['bbrIsPrimary']          as bool?   ?? false,
      );
}

class WifiBandInfo {
  final int    frequencyMhz;
  final String band;           // "2.4 GHz" | "5 GHz" | "6 GHz" | "unknown"
  final String ssid;
  final bool   hasBandSuffix;  // SSID ends with _5G, _5GHz, _6G, etc.

  const WifiBandInfo({
    required this.frequencyMhz,
    required this.band,
    required this.ssid,
    required this.hasBandSuffix,
  });

  bool get is24Ghz => band == '2.4 GHz';
  bool get is5Ghz  => band == '5 GHz';
  bool get is6Ghz  => band == '6 GHz';
  bool get isHigherBand => is5Ghz || is6Ghz;

  factory WifiBandInfo.fromJson(Map<String, dynamic> j) => WifiBandInfo(
        frequencyMhz:  j['frequencyMhz']  as int?    ?? -1,
        band:          j['band']          as String? ?? 'unknown',
        ssid:          j['ssid']          as String? ?? '',
        hasBandSuffix: j['hasBandSuffix'] as bool?   ?? false,
      );
}

class VpnInfo {
  final bool isActive;
  const VpnInfo({required this.isActive});

  factory VpnInfo.fromJson(Map<String, dynamic> j) =>
      VpnInfo(isActive: j['isActive'] as bool? ?? false);
}

class BorderRouterDiagnostic {
  final String  serviceName;
  final String  networkName;
  final String  extPanId;
  final String  vendorName;
  final String  modelName;
  final int     port;
  final List<String> hostsV4;
  final List<String> hostsV6LinkLocal;
  final List<String> hostsV6Ula;
  final List<String> hostsV6Gua;
  final StateBitmapInfo? stateBitmap;
  /// null = no address available to probe
  final bool?   tcpReachable;
  /// null = IPv4 unavailable on phone or BR
  final bool?   sameSubnetAsPhone;
  /// null = no ULA address on phone or BR
  final bool?   ipv6PrefixMatchesPhone;

  const BorderRouterDiagnostic({
    required this.serviceName,
    required this.networkName,
    required this.extPanId,
    required this.vendorName,
    required this.modelName,
    required this.port,
    required this.hostsV4,
    required this.hostsV6LinkLocal,
    required this.hostsV6Ula,
    required this.hostsV6Gua,
    required this.stateBitmap,
    required this.tcpReachable,
    required this.sameSubnetAsPhone,
    required this.ipv6PrefixMatchesPhone,
  });

  bool get hasIpv4         => hostsV4.isNotEmpty;
  bool get hasRoutableIpv6 => hostsV6Ula.isNotEmpty || hostsV6Gua.isNotEmpty;
  bool get hasAnyIpv6      => hostsV6LinkLocal.isNotEmpty || hasRoutableIpv6;

  factory BorderRouterDiagnostic.fromJson(Map<String, dynamic> j) =>
      BorderRouterDiagnostic(
        serviceName:           j['serviceName']  as String? ?? '',
        networkName:           j['networkName']  as String? ?? '',
        extPanId:              j['extPanId']     as String? ?? '',
        vendorName:            j['vendorName']   as String? ?? '',
        modelName:             j['modelName']    as String? ?? '',
        port:                  j['port']         as int?    ?? 0,
        hostsV4:               _strList(j['hostsV4']),
        hostsV6LinkLocal:      _strList(j['hostsV6LinkLocal']),
        hostsV6Ula:            _strList(j['hostsV6Ula']),
        hostsV6Gua:            _strList(j['hostsV6Gua']),
        tcpReachable:          j['tcpReachable']           as bool?,
        sameSubnetAsPhone:     j['sameSubnetAsPhone']      as bool?,
        ipv6PrefixMatchesPhone: j['ipv6PrefixMatchesPhone'] as bool?,
        stateBitmap: j['stateBitmap'] != null
            ? StateBitmapInfo.fromJson(
                Map<String, dynamic>.from(j['stateBitmap'] as Map))
            : null,
      );
}

class NetworkDiagnosticsReport {
  final PhoneIpv6Check              phoneIpv6;
  final bool                        multicastLockAcquired;
  final WifiBandInfo                wifi;
  final VpnInfo                     vpn;
  final List<BorderRouterDiagnostic> borderRouters;
  final List<String>                matterTcpServices;

  const NetworkDiagnosticsReport({
    required this.phoneIpv6,
    required this.multicastLockAcquired,
    required this.wifi,
    required this.vpn,
    required this.borderRouters,
    required this.matterTcpServices,
  });

  factory NetworkDiagnosticsReport.fromJson(Map<String, dynamic> j) =>
      NetworkDiagnosticsReport(
        phoneIpv6:            PhoneIpv6Check.fromJson(
            Map<String, dynamic>.from(j['phoneIpv6'] as Map)),
        multicastLockAcquired: j['multicastLockAcquired'] as bool? ?? false,
        wifi:                 WifiBandInfo.fromJson(
            Map<String, dynamic>.from(j['wifi'] as Map? ?? {})),
        vpn:                  VpnInfo.fromJson(
            Map<String, dynamic>.from(j['vpn'] as Map? ?? {})),
        borderRouters:        (j['borderRouters'] as List<dynamic>?)
                ?.map((e) => BorderRouterDiagnostic.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        matterTcpServices:    _strList(j['matterTcpServices']),
      );
}

List<String> _strList(dynamic v) =>
    (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [];

// ── Thread Network Diagnostics models ─────────────────────────────────────

/// One entry from the NeighborTable attribute (cluster 0x0035, attr 0x0007).
class ThreadNeighborInfo {
  final String  extAddress;      // 16-char hex, IEEE 802.15.4 extended MAC
  final int     age;             // seconds since last communication
  final int     rloc16;          // 16-bit routing locator
  final int     lqi;             // link quality index 0–255
  final int?    averageRssi;     // dBm (nullable int8)
  final int?    lastRssi;        // dBm (nullable int8)
  final int     frameErrorRate;  // %
  final int     messageErrorRate;// %
  final bool    rxOnWhenIdle;
  final bool    fullThreadDevice;
  final bool    isChild;

  const ThreadNeighborInfo({
    required this.extAddress,
    required this.age,
    required this.rloc16,
    required this.lqi,
    required this.averageRssi,
    required this.lastRssi,
    required this.frameErrorRate,
    required this.messageErrorRate,
    required this.rxOnWhenIdle,
    required this.fullThreadDevice,
    required this.isChild,
  });

  factory ThreadNeighborInfo.fromJson(Map<String, dynamic> j) =>
      ThreadNeighborInfo(
        extAddress:       j['extAddress']       as String? ?? '?',
        age:              (j['age']             as num?)?.toInt() ?? 0,
        rloc16:           (j['rloc16']          as num?)?.toInt() ?? 0,
        lqi:              (j['lqi']             as num?)?.toInt() ?? 0,
        averageRssi:      (j['averageRssi']     as num?)?.toInt(),
        lastRssi:         (j['lastRssi']        as num?)?.toInt(),
        frameErrorRate:   (j['frameErrorRate']  as num?)?.toInt() ?? 0,
        messageErrorRate: (j['messageErrorRate'] as num?)?.toInt() ?? 0,
        rxOnWhenIdle:     j['rxOnWhenIdle']     as bool? ?? false,
        fullThreadDevice: j['fullThreadDevice'] as bool? ?? false,
        isChild:          j['isChild']          as bool? ?? false,
      );
}

/// One entry from the RouteTable attribute (cluster 0x0035, attr 0x0008).
class ThreadRouteInfo {
  final int   rloc16;         // 16-bit routing locator of this router
  final int   routerId;       // 6-bit router ID
  final int   nextHop;        // router ID of next hop (0xFF = no route)
  final int   pathCost;       // path cost metric
  final int   lqiIn;          // incoming link quality 0–3
  final int   lqiOut;         // outgoing link quality 0–3
  final int   age;            // seconds since last update (wraps at 255)
  final bool  allocated;      // router ID is allocated
  final bool  linkEstablished;// direct link is established

  const ThreadRouteInfo({
    required this.rloc16,
    required this.routerId,
    required this.nextHop,
    required this.pathCost,
    required this.lqiIn,
    required this.lqiOut,
    required this.age,
    required this.allocated,
    required this.linkEstablished,
  });

  factory ThreadRouteInfo.fromJson(Map<String, dynamic> j) => ThreadRouteInfo(
        rloc16:          (j['rloc16']          as num?)?.toInt() ?? 0,
        routerId:        (j['routerId']         as num?)?.toInt() ?? 0,
        nextHop:         (j['nextHop']          as num?)?.toInt() ?? 0xFF,
        pathCost:        (j['pathCost']         as num?)?.toInt() ?? 0,
        lqiIn:           (j['lqiIn']            as num?)?.toInt() ?? 0,
        lqiOut:          (j['lqiOut']           as num?)?.toInt() ?? 0,
        age:             (j['age']              as num?)?.toInt() ?? 0,
        allocated:       j['allocated']         as bool? ?? false,
        linkEstablished: j['linkEstablished']   as bool? ?? false,
      );
}

/// Full snapshot from the Thread Network Diagnostics cluster (0x0035).
class ThreadNetworkDiagnostics {
  final int?    channel;
  /// RoutingRole enum: 0=Unspecified 1=Unassigned 2=SleepyEndDevice
  ///   3=EndDevice 4=REED 5=Router 6=Leader
  final int?    routingRole;
  final String  routingRoleLabel;
  final String? networkName;
  final int?    panId;
  final String? extendedPanId;  // 16-char hex
  final String? meshLocalPrefix;// e.g. "fd12:3456:789a:0001::/64"
  final int?    partitionId;
  final int?    weighting;
  final int?    leaderRouterId;
  final List<ThreadNeighborInfo> neighbors;
  final List<ThreadRouteInfo>    routes;

  const ThreadNetworkDiagnostics({
    required this.channel,
    required this.routingRole,
    required this.routingRoleLabel,
    required this.networkName,
    required this.panId,
    required this.extendedPanId,
    required this.meshLocalPrefix,
    required this.partitionId,
    required this.weighting,
    required this.leaderRouterId,
    required this.neighbors,
    required this.routes,
  });

  factory ThreadNetworkDiagnostics.fromJson(Map<String, dynamic> j) =>
      ThreadNetworkDiagnostics(
        channel:          (j['channel']        as num?)?.toInt(),
        routingRole:      (j['routingRole']     as num?)?.toInt(),
        routingRoleLabel: j['routingRoleLabel'] as String? ?? 'Unknown',
        networkName:      j['networkName']      as String?,
        panId:            (j['panId']           as num?)?.toInt(),
        extendedPanId:    j['extendedPanId']    as String?,
        meshLocalPrefix:  j['meshLocalPrefix']  as String?,
        partitionId:      (j['partitionId']     as num?)?.toInt(),
        weighting:        (j['weighting']       as num?)?.toInt(),
        leaderRouterId:   (j['leaderRouterId']  as num?)?.toInt(),
        neighbors: (j['neighbors'] as List<dynamic>?)
                ?.map((e) => ThreadNeighborInfo.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        routes: (j['routes'] as List<dynamic>?)
                ?.map((e) => ThreadRouteInfo.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

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
    String manufacturingDate,
    String partNumber,
    String productUrl,
    String serialNumber,
    String uniqueId,
  })?> readBasicInfo(int nodeId) async {
    try {
      final map = await _method
          .invokeMapMethod<String, String>('readBasicInfo', {'nodeId': nodeId});
      if (map == null) return null;
      return (
        productName:       map['productName']       ?? '',
        vendorName:        map['vendorName']        ?? '',
        vendorId:          map['vendorId']          ?? '',
        productId:         map['productId']         ?? '',
        hwVersion:         map['hwVersion']         ?? '',
        softwareVersion:   map['softwareVersion']   ?? '',
        manufacturingDate: map['manufacturingDate'] ?? '',
        partNumber:        map['partNumber']        ?? '',
        productUrl:        map['productUrl']        ?? '',
        serialNumber:      map['serialNumber']      ?? '',
        uniqueId:          map['uniqueId']          ?? '',
      );
    } on PlatformException catch (e) {
      debugPrint('readBasicInfo error: ${e.message}');
      return null;
    }
  }

  Future<ThermostatState?> readThermostat(int nodeId) async {
    try {
      final map = await _method.invokeMapMethod<String, int>(
          'readThermostat', {'nodeId': nodeId});
      if (map == null) return null;
      int? orNull(int v) => v == -32768 || v == 0x80000000 ? null : v;
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

  /// Reads MeasuredValue from the Relative Humidity Measurement cluster (0x0405).
  /// Returns humidity in units of 0.01 % RH (e.g. 5723 → 57.23 %), or null
  /// when the cluster is absent or the device reports a null sentinel.
  Future<int?> readHumidity(int nodeId) async {
    try {
      final raw = await _method.invokeMethod<int>('readHumidity', {'nodeId': nodeId});
      return raw; // null means cluster not present / attribute null
    } on PlatformException catch (e) {
      debugPrint('readHumidity error: ${e.message}');
      return null;
    }
  }

  /// Reads the Power Source cluster (0x002F) — all attributes, wildcard endpoint.
  /// Returns a [BatteryInfo] with whatever the device exposes, or null if the
  /// cluster is absent.
  Future<BatteryInfo?> readBattery(int nodeId) async {
    try {
      final raw = await _method.invokeMapMethod<String, int>(
          'readBattery', {'nodeId': nodeId});
      if (raw == null || raw.isEmpty) return null;
      return BatteryInfo(
        percent:       raw['percent'],
        chargeLevel:   raw['chargeLevel'],
        voltageMilliV: raw['voltageMilliV'],
      );
    } on PlatformException catch (e) {
      debugPrint('readBattery error: ${e.message}');
      return null;
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

  // ── Share / remove / fabric ────────────────────────────────────────────────

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
}
