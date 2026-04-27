import 'package:flutter/foundation.dart' show immutable;

/// A named group that devices can be assigned to.
///
/// "No Room" is a built-in sentinel ([noRoom]) that always exists and is never
/// persisted — the provider injects it as the first entry on every load.
/// All devices that have not been explicitly assigned to a user-created room
/// carry [noRoomId] as their [MatterDevice.roomId].
@immutable
class Room {
  static const noRoomId = 'no-room';
  static const noRoom   = Room(id: noRoomId, name: 'No Room');

  const Room({required this.id, required this.name});

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id:   json['id']   as String,
    name: json['name'] as String,
  );

  final String id;
  final String name;

  bool get isNoRoom => id == noRoomId;

  Room copyWith({String? id, String? name}) =>
      Room(id: id ?? this.id, name: name ?? this.name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Room && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Room($id, $name)';
}
