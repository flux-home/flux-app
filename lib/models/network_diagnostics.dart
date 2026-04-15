List<String> _strList(dynamic v) =>
    (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [];

class PhoneIpv6Check {

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
  final bool         hasRoutableIpv6;
  final List<String> guaAddresses;
  final List<String> ulaAddresses;
  final List<String> linkLocalAddresses;
}

class StateBitmapInfo {

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
  final int    raw;
  final int    connectionMode;
  final String connectionModeLabel;
  final int    threadInterfaceStatus;
  final String threadInterfaceLabel;
  final int    availability;
  final bool   bbrActive;
  final bool   bbrIsPrimary;

  bool get threadInterfaceActive   => threadInterfaceStatus == 2;
  bool get hasExternalConnectivity => connectionMode != 0;
}

class WifiBandInfo {

  const WifiBandInfo({
    required this.frequencyMhz,
    required this.band,
    required this.ssid,
    required this.hasBandSuffix,
  });

  factory WifiBandInfo.fromJson(Map<String, dynamic> j) => WifiBandInfo(
        frequencyMhz:  j['frequencyMhz']  as int?    ?? -1,
        band:          j['band']          as String? ?? 'unknown',
        ssid:          j['ssid']          as String? ?? '',
        hasBandSuffix: j['hasBandSuffix'] as bool?   ?? false,
      );
  final int    frequencyMhz;
  final String band;
  final String ssid;
  final bool   hasBandSuffix;

  bool get is24Ghz     => band == '2.4 GHz';
  bool get is5Ghz      => band == '5 GHz';
  bool get is6Ghz      => band == '6 GHz';
  bool get isHigherBand => is5Ghz || is6Ghz;
}

class VpnInfo {
  const VpnInfo({required this.isActive});
  factory VpnInfo.fromJson(Map<String, dynamic> j) =>
      VpnInfo(isActive: j['isActive'] as bool? ?? false);
  final bool isActive;
}

class BorderRouterDiagnostic {

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

  factory BorderRouterDiagnostic.fromJson(Map<String, dynamic> j) =>
      BorderRouterDiagnostic(
        serviceName:            j['serviceName']  as String? ?? '',
        networkName:            j['networkName']  as String? ?? '',
        extPanId:               j['extPanId']     as String? ?? '',
        vendorName:             j['vendorName']   as String? ?? '',
        modelName:              j['modelName']    as String? ?? '',
        port:                   j['port']         as int?    ?? 0,
        hostsV4:                _strList(j['hostsV4']),
        hostsV6LinkLocal:       _strList(j['hostsV6LinkLocal']),
        hostsV6Ula:             _strList(j['hostsV6Ula']),
        hostsV6Gua:             _strList(j['hostsV6Gua']),
        tcpReachable:           j['tcpReachable']            as bool?,
        sameSubnetAsPhone:      j['sameSubnetAsPhone']       as bool?,
        ipv6PrefixMatchesPhone: j['ipv6PrefixMatchesPhone']  as bool?,
        stateBitmap: j['stateBitmap'] != null
            ? StateBitmapInfo.fromJson(
                Map<String, dynamic>.from(j['stateBitmap'] as Map))
            : null,
      );
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
  final bool?   tcpReachable;
  final bool?   sameSubnetAsPhone;
  final bool?   ipv6PrefixMatchesPhone;

  bool get hasIpv4         => hostsV4.isNotEmpty;
  bool get hasRoutableIpv6 => hostsV6Ula.isNotEmpty || hostsV6Gua.isNotEmpty;
  bool get hasAnyIpv6      => hostsV6LinkLocal.isNotEmpty || hasRoutableIpv6;
}

class NetworkDiagnosticsReport {

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
        phoneIpv6: PhoneIpv6Check.fromJson(
            Map<String, dynamic>.from(j['phoneIpv6'] as Map)),
        multicastLockAcquired: j['multicastLockAcquired'] as bool? ?? false,
        wifi: WifiBandInfo.fromJson(
            Map<String, dynamic>.from(j['wifi'] as Map? ?? {})),
        vpn: VpnInfo.fromJson(
            Map<String, dynamic>.from(j['vpn'] as Map? ?? {})),
        borderRouters: (j['borderRouters'] as List<dynamic>?)
                ?.map((e) => BorderRouterDiagnostic.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        matterTcpServices: _strList(j['matterTcpServices']),
      );
  final PhoneIpv6Check               phoneIpv6;
  final bool                         multicastLockAcquired;
  final WifiBandInfo                 wifi;
  final VpnInfo                      vpn;
  final List<BorderRouterDiagnostic> borderRouters;
  final List<String>                 matterTcpServices;
}
