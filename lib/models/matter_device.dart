import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:matter_home/models/device_live_data.dart' show DeviceLiveData;
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart' show DeviceView;
import 'package:matter_home/models/room.dart';

// ── Network transport type ────────────────────────────────────────────────────

enum NetworkType {
  wifi,
  thread,
  ethernet,
  unknown;

  String get label => switch (this) {
    NetworkType.wifi => 'Wi-Fi',
    NetworkType.thread => 'Thread',
    NetworkType.ethernet => 'Ethernet',
    NetworkType.unknown => 'Unknown',
  };

  /// Icon codepoint from MaterialIcons — used in the settings label.
  String get icon => switch (this) {
    NetworkType.wifi => 'wifi',
    NetworkType.thread => 'memory',
    NetworkType.ethernet => 'settings_ethernet',
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
    ManagedBy.controller => 'Hub',
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
@immutable
class MatterDevice {
  const MatterDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.nodeId,
    required this.commissionedAt,
    required this.lastModified,
    this.isOnline = true,
    this.sharedWithGoogleHome = false,
    this.networkType = NetworkType.unknown,
    this.managedBy = ManagedBy.phone,
    this.roomId = Room.noRoomId,
  });

  factory MatterDevice.fromJson(Map<String, dynamic> json) {
    final commissionedAt = DateTime.parse(json['commissionedAt'] as String);
    return MatterDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceType: DeviceType.values.firstWhere((e) => e.name == json['deviceType'], orElse: () => DeviceType.unknown),
      nodeId: json['nodeId'] as int,
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
      roomId: json['roomId'] as String? ?? Room.noRoomId,
    );
  }
  final String id;
  final String name;
  final DeviceType deviceType;
  final int nodeId;
  final bool isOnline;
  final bool sharedWithGoogleHome;
  final DateTime commissionedAt;
  /// Updated on every user edit (rename etc.). Used for last-write-wins sync.
  final DateTime lastModified;
  final NetworkType networkType;
  final ManagedBy   managedBy;
  final String roomId;

  MatterDevice copyWith({
    String? id,
    String? name,
    DeviceType? deviceType,
    int? nodeId,
    bool? isOnline,
    bool? sharedWithGoogleHome,
    DateTime? commissionedAt,
    DateTime? lastModified,
    NetworkType? networkType,
    ManagedBy?   managedBy,
    String? roomId,
  }) => MatterDevice(
    id: id ?? this.id,
    name: name ?? this.name,
    deviceType: deviceType ?? this.deviceType,
    nodeId: nodeId ?? this.nodeId,
    isOnline: isOnline ?? this.isOnline,
    sharedWithGoogleHome: sharedWithGoogleHome ?? this.sharedWithGoogleHome,
    commissionedAt: commissionedAt ?? this.commissionedAt,
    lastModified: lastModified ?? this.lastModified,
    networkType: networkType ?? this.networkType,
    managedBy: managedBy ?? this.managedBy,
    roomId: roomId ?? this.roomId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'deviceType': deviceType.name,
    'nodeId': nodeId,
    'isOnline': isOnline,
    'sharedWithGoogleHome': sharedWithGoogleHome,
    'commissionedAt': commissionedAt.toIso8601String(),
    'lastModified': lastModified.toIso8601String(),
    'networkType': networkType.name,
    'managedBy':   managedBy.name,
    'roomId': roomId,
  };

  @override
  bool operator ==(Object other) => identical(this, other) || (other is MatterDevice && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
