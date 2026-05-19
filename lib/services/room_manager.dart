import 'dart:async';

import 'package:matter_home/models/room.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RoomManager
//
// Owns the in-memory room list and all CRUD operations on it.
// Device-room assignment (changing device.roomId on delete) is the
// caller's responsibility — this class only manages the room data.
// ─────────────────────────────────────────────────────────────────────────────

class RoomManager {
  RoomManager({
    required Future<void> Function() onPersistRooms,
    required void Function() onNotify,
    required Uuid uuid,
  })  : _onPersistRooms = onPersistRooms,
        _onNotify       = onNotify,
        _uuid           = uuid;

  final Future<void> Function() _onPersistRooms;
  final void         Function() _onNotify;
  final Uuid                    _uuid;
  List<Room>                    _rooms = [Room.noRoom];

  // ── Initialisation ─────────────────────────────────────────────────────────

  void loadRooms(List<Room> persisted) {
    _rooms = [Room.noRoom, ...persisted];
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  List<Room> get rooms => List.unmodifiable(_rooms);

  Future<Room> createRoom(String name) async {
    final room = Room(id: _uuid.v4(), name: name);
    _rooms = [..._rooms, room];
    await _onPersistRooms();
    _onNotify();
    return room;
  }

  Future<void> renameRoom(String roomId, String name) async {
    if (roomId == Room.noRoomId) return;
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx < 0) return;
    _rooms = [..._rooms]..[idx] = _rooms[idx].copyWith(name: name);
    await _onPersistRooms();
    _onNotify();
  }

  /// Removes [roomId] from the list.
  /// The caller is responsible for reassigning any devices in that room.
  void removeRoom(String roomId) {
    if (roomId == Room.noRoomId) return;
    _rooms = _rooms.where((r) => r.id != roomId).toList();
  }
}
