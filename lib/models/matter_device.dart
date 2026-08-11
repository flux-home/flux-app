import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:matter_home/models/device_live_data.dart' show DeviceLiveData;
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart' show DeviceView;
import 'package:matter_home/models/energy_role.dart';
import 'package:matter_home/models/room.dart';

// ── Network transport type ────────────────────────────────────────────────────

enum NetworkType {
  wifi,
  thread,
  ethernet,
  modbus,
  unknown;

  String get label => switch (this) {
    NetworkType.wifi => 'Wi-Fi',
    NetworkType.thread => 'Thread',
    NetworkType.ethernet => 'Ethernet',
    NetworkType.modbus => 'Modbus',
    NetworkType.unknown => 'Unknown',
  };

  /// Icon codepoint from MaterialIcons — used in the settings label.
  String get icon => switch (this) {
    NetworkType.wifi => 'wifi',
    NetworkType.thread => 'memory',
    NetworkType.ethernet => 'settings_ethernet',
    NetworkType.modbus => 'cable',
    NetworkType.unknown => 'device_unknown',
  };
}

// ── Who manages the device ──────────────────────────────────────────────────────

/// Indicates which port is responsible for sending commands to this device
/// and receiving its subscription events.
enum ManagedBy {
  /// Commands go through the local phone SDK ([MatterChannel]).
  phone,
  /// Commands go through the Flux Controller ([FluxCoapService]).
  controller;

  String get label => switch (this) {
    ManagedBy.phone      => 'Phone',
    ManagedBy.controller => 'Controller',
  };

  IconData get icon => switch (this) {
    ManagedBy.phone      => Icons.smartphone_outlined,
    ManagedBy.controller => Icons.hub_outlined,
  };
}

/// Stable commissioning record for a Matter device in our local fabric.
///
/// Contains only identity and topology facts that never change without an
/// explicit user action (rename, re-commission, room change).
///
/// All live state — on/off, brightness, temperature, battery, product info —
/// lives exclusively in [DeviceLiveData] and is accessed through [DeviceView].
/// What kind of thing a device is, and therefore what [MatterDevice.nodeId]
/// means for it. Mirrors `flux.DeviceKind` on the wire.
///
/// A device is identified by the PAIR (kind, nodeId): nodeId is scoped to its
/// kind's namespace, so a Matter node 5 and a Modbus device 5 are different
/// devices. This replaces reading the kind out of the *magnitude* of nodeId
/// (`nodeId >= 0x0100000000000000`), a constant that was duplicated here, in
/// the device provider, in flux-ctl and in the firmware — and was already stale and
/// wrong in the integration tests.
enum DeviceKind {
  /// Never assume Matter here: an unset wire field decodes as this, so treating
  /// it as Matter would silently mis-route anything that forgot to set it.
  unknown,
  matter,
  modbus,
  cloud;

  static DeviceKind fromWire(int v) => switch (v) {
        1 => DeviceKind.matter,
        2 => DeviceKind.modbus,
        3 => DeviceKind.cloud,
        _ => DeviceKind.unknown,
      };

  int get wire => switch (this) {
        DeviceKind.matter => 1,
        DeviceKind.modbus => 2,
        DeviceKind.cloud  => 3,
        DeviceKind.unknown => 0,
      };

  static DeviceKind fromName(String? n) =>
      DeviceKind.values.firstWhere((e) => e.name == n,
          orElse: () => DeviceKind.unknown);
}

@immutable
class MatterDevice {
  const MatterDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.nodeId,
    required this.commissionedAt,
    required this.lastModified,
    this.kind = DeviceKind.matter,
    this.isOnline = true,
    this.sharedWithGoogleHome = false,
    this.networkType = NetworkType.unknown,
    this.managedBy = ManagedBy.phone,
    this.roomId = Room.noRoomId,
    this.energyRole = EnergyRole.none,
  });

  factory MatterDevice.fromJson(Map<String, dynamic> json) {
    final commissionedAt = DateTime.parse(json['commissionedAt'] as String);
    return MatterDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceType: DeviceType.values.firstWhere((e) => e.name == json['deviceType'], orElse: () => DeviceType.unknown),
      nodeId: json['nodeId'] as int,
      // Records written before kind existed: recover it the only way the old
      // format allowed — the reserved synthetic range. This is the one place
      // that inference is still the truth, because it IS the old format.
      kind: json['kind'] != null
          ? DeviceKind.fromName(json['kind'] as String?)
          : ((json['nodeId'] as int) >= 0x0100000000000000
              ? DeviceKind.modbus
              : DeviceKind.matter),
      isOnline: json['isOnline'] as bool? ?? true,
      sharedWithGoogleHome: json['sharedWithGoogleHome'] as bool? ?? false,
      commissionedAt: commissionedAt,
      // Fall back to commissionedAt for records persisted before lastModified existed.
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : commissionedAt,
      networkType: NetworkType.values.firstWhere(
        (e) => e.name == (json['networkType'] as String?),
        orElse: () => NetworkType.unknown,
      ),
      managedBy: ManagedBy.values.firstWhere(
        (e) => e.name == (json['managedBy'] as String?),
        orElse: () => ManagedBy.phone,
      ),
      // Pre-rooms-on-controller records held a UUID string here. There is no
      // way to map one to a controller id locally, so it resolves to No Room;
      // the one-time upload in DeviceProvider re-creates the layout instead.
      roomId: json['roomId'] is int ? json['roomId'] as int : Room.noRoomId,
      energyRole: EnergyRole.fromName(json['energyRole'] as String?),
    );
  }
  final String id;
  final String name;
  final DeviceType deviceType;
  final int nodeId;

  /// With [nodeId], identifies the device. See [DeviceKind].
  final DeviceKind kind;
  final bool isOnline;
  final bool sharedWithGoogleHome;
  final DateTime commissionedAt;
  /// Updated on every user edit (rename etc.). Used for last-write-wins sync.
  final DateTime lastModified;
  final NetworkType networkType;
  final ManagedBy   managedBy;
  final int roomId;
  final EnergyRole energyRole;

  /// True for controller-side Modbus devices — read from [kind], not inferred
  /// from the size of [nodeId].
  bool get isModbus => kind == DeviceKind.modbus;

  MatterDevice copyWith({
    String? id,
    String? name,
    DeviceType? deviceType,
    int? nodeId,
    DeviceKind? kind,
    bool? isOnline,
    bool? sharedWithGoogleHome,
    DateTime? commissionedAt,
    DateTime? lastModified,
    NetworkType? networkType,
    ManagedBy?   managedBy,
    int? roomId,
    EnergyRole? energyRole,
  }) => MatterDevice(
    id: id ?? this.id,
    name: name ?? this.name,
    deviceType: deviceType ?? this.deviceType,
    nodeId: nodeId ?? this.nodeId,
    kind: kind ?? this.kind,
    isOnline: isOnline ?? this.isOnline,
    sharedWithGoogleHome: sharedWithGoogleHome ?? this.sharedWithGoogleHome,
    commissionedAt: commissionedAt ?? this.commissionedAt,
    lastModified: lastModified ?? this.lastModified,
    networkType: networkType ?? this.networkType,
    managedBy: managedBy ?? this.managedBy,
    roomId: roomId ?? this.roomId,
    energyRole: energyRole ?? this.energyRole,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'deviceType': deviceType.name,
    'nodeId': nodeId,
    'kind': kind.name,
    'isOnline': isOnline,
    'sharedWithGoogleHome': sharedWithGoogleHome,
    'commissionedAt': commissionedAt.toIso8601String(),
    'lastModified': lastModified.toIso8601String(),
    'networkType': networkType.name,
    'managedBy':   managedBy.name,
    'roomId': roomId,
    'energyRole': energyRole.name,
  };

  @override
  bool operator ==(Object other) => identical(this, other) || (other is MatterDevice && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
