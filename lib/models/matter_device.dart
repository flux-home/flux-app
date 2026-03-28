import 'device_type.dart';

// ── Network transport type ────────────────────────────────────────────────────

enum NetworkType {
  wifi,
  thread,
  ethernet,
  unknown;

  String get label => switch (this) {
    NetworkType.wifi     => 'Wi-Fi',
    NetworkType.thread   => 'Thread',
    NetworkType.ethernet => 'Ethernet',
    NetworkType.unknown  => 'Unknown',
  };

  /// Icon codepoint from MaterialIcons — used in the settings label.
  String get icon => switch (this) {
    NetworkType.wifi     => 'wifi',
    NetworkType.thread   => 'memory',
    NetworkType.ethernet => 'settings_ethernet',
    NetworkType.unknown  => 'device_unknown',
  };
}

/// Stable commissioning record for a Matter device in our local fabric.
///
/// Contains only identity and topology facts that never change without an
/// explicit user action (rename, re-commission, room change).
///
/// All live state — on/off, brightness, temperature, battery, product info —
/// lives exclusively in [DeviceLiveData] and is accessed through [DeviceView].
class MatterDevice {
  final String      id;
  final String      name;
  final DeviceType  deviceType;
  final int         nodeId;
  final String      room;
  final bool        isOnline;
  final bool        sharedWithGoogleHome;
  final DateTime    commissionedAt;
  final NetworkType networkType;

  const MatterDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.nodeId,
    this.room                = 'Unassigned',
    this.isOnline            = true,
    this.sharedWithGoogleHome = false,
    required this.commissionedAt,
    this.networkType         = NetworkType.unknown,
  });

  MatterDevice copyWith({
    String?      id,
    String?      name,
    DeviceType?  deviceType,
    int?         nodeId,
    String?      room,
    bool?        isOnline,
    bool?        sharedWithGoogleHome,
    DateTime?    commissionedAt,
    NetworkType? networkType,
  }) => MatterDevice(
    id:                   id                   ?? this.id,
    name:                 name                 ?? this.name,
    deviceType:           deviceType           ?? this.deviceType,
    nodeId:               nodeId               ?? this.nodeId,
    room:                 room                 ?? this.room,
    isOnline:             isOnline             ?? this.isOnline,
    sharedWithGoogleHome: sharedWithGoogleHome ?? this.sharedWithGoogleHome,
    commissionedAt:       commissionedAt       ?? this.commissionedAt,
    networkType:          networkType          ?? this.networkType,
  );

  Map<String, dynamic> toJson() => {
        'id':                   id,
        'name':                 name,
        'deviceType':           deviceType.name,
        'nodeId':               nodeId,
        'room':                 room,
        'isOnline':             isOnline,
        'sharedWithGoogleHome': sharedWithGoogleHome,
        'commissionedAt':       commissionedAt.toIso8601String(),
        'networkType':          networkType.name,
      };

  factory MatterDevice.fromJson(Map<String, dynamic> json) => MatterDevice(
        id:         json['id']         as String,
        name:       json['name']       as String,
        deviceType: DeviceType.values.firstWhere(
          (e) => e.name == json['deviceType'],
          orElse: () => DeviceType.unknown,
        ),
        nodeId:     json['nodeId']     as int,
        room:       json['room']       as String? ?? 'Unassigned',
        isOnline:   json['isOnline']   as bool?   ?? true,
        sharedWithGoogleHome:
            json['sharedWithGoogleHome'] as bool? ?? false,
        commissionedAt: DateTime.parse(json['commissionedAt'] as String),
        networkType: NetworkType.values.firstWhere(
          (e) => e.name == (json['networkType'] as String?),
          orElse: () => NetworkType.unknown,
        ),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MatterDevice && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
