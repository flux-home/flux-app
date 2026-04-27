import 'dart:convert';

import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/persisted_snapshot.dart';
import 'package:matter_home/models/room.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the device list and live-state snapshots to SharedPreferences.
class DeviceStore {
  DeviceStore._(this._prefs);
  static const _kDevices   = 'matter_devices';
  static const _kSnapshots = 'device_snapshots';
  static const _kRooms     = 'rooms';

  final SharedPreferences _prefs;

  static Future<DeviceStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return DeviceStore._(prefs);
  }

  // ── Devices (commissioning records) ───────────────────────────────────────

  List<MatterDevice> loadDevices() {
    final raw = _prefs.getStringList(_kDevices) ?? [];
    return raw
        .map((s) {
          try {
            return MatterDevice.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } on Exception catch (_) {
            return null;
          }
        })
        .whereType<MatterDevice>()
        .toList();
  }

  Future<void> saveDevices(List<MatterDevice> devices) async {
    final raw = devices.map((d) => jsonEncode(d.toJson())).toList();
    await _prefs.setStringList(_kDevices, raw);
  }

  // ── Rooms ─────────────────────────────────────────────────────────────────

  /// Returns persisted user-created rooms in creation order.
  /// The "No Room" sentinel is never stored — the provider injects it.
  List<Room> loadRooms() {
    final raw = _prefs.getStringList(_kRooms) ?? [];
    return raw
        .map((s) {
          try {
            return Room.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } on Exception catch (_) {
            return null;
          }
        })
        .whereType<Room>()
        .toList();
  }

  Future<void> saveRooms(List<Room> rooms) async {
    // Never persist the sentinel.
    final raw = rooms
        .where((r) => !r.isNoRoom)
        .map((r) => jsonEncode(r.toJson()))
        .toList();
    await _prefs.setStringList(_kRooms, raw);
  }

  // ── Snapshots (last-known live state) ─────────────────────────────────────

  /// Returns a map keyed by [PersistedSnapshot.deviceId].
  Map<String, PersistedSnapshot> loadSnapshots() {
    final raw = _prefs.getStringList(_kSnapshots) ?? [];
    final result = <String, PersistedSnapshot>{};
    for (final s in raw) {
      try {
        final snap = PersistedSnapshot.fromJson(jsonDecode(s) as Map<String, dynamic>);
        result[snap.deviceId] = snap;
      } on Exception catch (_) {
        // Corrupt entry — skip silently.
      }
    }
    return result;
  }

  Future<void> saveSnapshots(Map<String, PersistedSnapshot> snapshots) async {
    final raw = snapshots.values.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs.setStringList(_kSnapshots, raw);
  }
}
