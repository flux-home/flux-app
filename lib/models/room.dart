import 'package:flutter/foundation.dart' show immutable;

/// A named group that devices can be assigned to.
///
/// The **controller owns the room list and the membership**; the app caches it
/// for offline display. Rooms used to be phone-local, which meant two phones
/// disagreed forever, a reinstall lost the layout, and re-adding a device
/// dropped it back to "No Room".
///
/// [id] is issued by the controller and is never reused, so a device pointing at
/// a deleted room can never be silently adopted by a new one — it resolves to
/// nothing and falls back to [noRoom].
///
/// "No Room" is a built-in sentinel ([noRoom]) that always exists and is never
/// persisted — the provider injects it as the first entry on every load.
/// All devices that have not been explicitly assigned to a user-created room
/// carry [noRoomId] as their [MatterDevice.roomId].
@immutable
class Room {
  static const noRoomId = 0;
  static const noRoom   = Room(id: noRoomId, name: 'No Room');

  const Room({required this.id, required this.name});

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id:   json['id']   as int,
    name: json['name'] as String,
  );

  final int id;
  final String name;

  bool get isNoRoom => id == noRoomId;

  Room copyWith({int? id, String? name}) =>
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
