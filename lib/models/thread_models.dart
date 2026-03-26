/// A Thread Border Router discovered via mDNS (_meshcop._udp).
class ThreadBorderRouter {
  final String serviceName;
  final String networkName;
  final String extPanId;
  final String vendorName;
  final String modelName;
  final String host;
  final int    port;
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

/// One entry from the NeighborTable attribute (cluster 0x0035, attr 0x0007).
class ThreadNeighborInfo {
  final String extAddress;
  final int    age;
  final int    rloc16;
  final int    lqi;
  final int?   averageRssi;
  final int?   lastRssi;
  final int    frameErrorRate;
  final int    messageErrorRate;
  final bool   rxOnWhenIdle;
  final bool   fullThreadDevice;
  final bool   isChild;

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
        extAddress:       j['extAddress']        as String? ?? '?',
        age:              (j['age']              as num?)?.toInt() ?? 0,
        rloc16:           (j['rloc16']           as num?)?.toInt() ?? 0,
        lqi:              (j['lqi']              as num?)?.toInt() ?? 0,
        averageRssi:      (j['averageRssi']      as num?)?.toInt(),
        lastRssi:         (j['lastRssi']         as num?)?.toInt(),
        frameErrorRate:   (j['frameErrorRate']   as num?)?.toInt() ?? 0,
        messageErrorRate: (j['messageErrorRate'] as num?)?.toInt() ?? 0,
        rxOnWhenIdle:     j['rxOnWhenIdle']      as bool? ?? false,
        fullThreadDevice: j['fullThreadDevice']  as bool? ?? false,
        isChild:          j['isChild']           as bool? ?? false,
      );
}

/// One entry from the RouteTable attribute (cluster 0x0035, attr 0x0008).
class ThreadRouteInfo {
  final int  rloc16;
  final int  routerId;
  final int  nextHop;
  final int  pathCost;
  final int  lqiIn;
  final int  lqiOut;
  final int  age;
  final bool allocated;
  final bool linkEstablished;

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
  final int?    routingRole;
  final String  routingRoleLabel;
  final String? networkName;
  final int?    panId;
  final String? extendedPanId;
  final String? meshLocalPrefix;
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
