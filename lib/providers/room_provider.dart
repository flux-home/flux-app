import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:matter_home/models/room.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:uuid/uuid.dart';

class RoomProvider extends ChangeNotifier {
  RoomProvider(this._store);

  final DeviceStore _store;
  DeviceProvider? _deviceProvider;
  
  List<Room> _rooms = [];
  final _uuid = const Uuid();

  List<Room> get rooms => List.unmodifiable(_rooms);

  void update(DeviceProvider deviceProvider) {
    _deviceProvider = deviceProvider;
    if (_rooms.isEmpty) _load();
    notifyListeners();
  }

  /// Devices grouped by room, in room creation order.
  /// Every room appears in the list regardless of whether it has devices,
  /// so the home screen always renders the section header.
  List<(Room, List<DeviceView>)> get deviceViewsByRoom {
    final provider = _deviceProvider;
    if (provider == null) return [];
    
    return _rooms.map((room) {
      final views = provider.devices
          .where((d) => d.roomId == room.id)
          .map((d) => provider.viewFor(d.id)!)
          .toList();
      return (room, views);
    }).toList();
  }

  void _load() {
    _rooms = [Room.noRoom, ..._store.loadRooms()];
    notifyListeners();
  }

  Future<void> _persist() => _store.saveRooms(_rooms.where((r) => r != Room.noRoom).toList());

  Future<Room> createRoom(String name) async {
    final room = Room(id: _uuid.v4(), name: name);
    _rooms.add(room);
    await _persist();
    notifyListeners();
    return room;
  }

  Future<void> assignRoom(String deviceId, String roomId) async {
    final provider = _deviceProvider;
    if (provider == null) return;
    
    final device = provider.findById(deviceId);
    if (device == null) return;

    provider.updateDevice(device.copyWith(roomId: roomId));
  }

  Future<void> removeRoom(String roomId) async {
    if (roomId == Room.noRoom.id) return;
    
    final provider = _deviceProvider;
    if (provider != null) {
      // Reassign devices in this room to "No Room"
      for (final device in provider.devices) {
        if (device.roomId == roomId) {
          provider.updateDevice(device.copyWith(roomId: Room.noRoom.id));
        }
      }
    }

    _rooms.removeWhere((r) => r.id == roomId);
    await _persist();
    notifyListeners();
  }
}
