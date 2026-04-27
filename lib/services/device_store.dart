import 'dart:convert';

import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/persisted_snapshot.dart';
import 'package:matter_home/models/room.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the device list, live-state snapshots, rooms, and automation rules
/// to SharedPreferences.
class DeviceStore {
  DeviceStore._(this._prefs);
  static const _kDevices   = 'matter_devices';
  static const _kSnapshots = 'device_snapshots';
  static const _kRooms     = 'rooms';
  static const _kRules     = 'automation_rules_v1';

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
          } on Exception catch (_) { return null; }
        })
        .whereType<MatterDevice>()
        .toList();
  }

  Future<void> saveDevices(List<MatterDevice> devices) async {
    final raw = devices.map((d) => jsonEncode(d.toJson())).toList();
    await _prefs.setStringList(_kDevices, raw);
  }

  // ── Rooms ─────────────────────────────────────────────────────────────────

  List<Room> loadRooms() {
    final raw = _prefs.getStringList(_kRooms) ?? [];
    return raw
        .map((s) {
          try { return Room.fromJson(jsonDecode(s) as Map<String, dynamic>); }
          on Exception catch (_) { return null; }
        })
        .whereType<Room>()
        .toList();
  }

  Future<void> saveRooms(List<Room> rooms) async {
    final raw = rooms
        .where((r) => !r.isNoRoom)
        .map((r) => jsonEncode(r.toJson()))
        .toList();
    await _prefs.setStringList(_kRooms, raw);
  }

  // ── Automation rules ───────────────────────────────────────────────────────

  List<AutomationRule> loadRules() {
    final raw = _prefs.getStringList(_kRules) ?? [];
    return raw
        .map((s) {
          try { return AutomationRule.fromJson(jsonDecode(s) as Map<String, dynamic>); }
          on Exception catch (_) { return null; }
        })
        .whereType<AutomationRule>()
        .toList();
  }

  Future<void> saveRules(List<AutomationRule> rules) async {
    await _prefs.setStringList(
        _kRules, rules.map((r) => jsonEncode(r.toJson())).toList());
  }

  // ── Snapshots (last-known live state) ─────────────────────────────────────

  Map<String, PersistedSnapshot> loadSnapshots() {
    final raw = _prefs.getStringList(_kSnapshots) ?? [];
    final result = <String, PersistedSnapshot>{};
    for (final s in raw) {
      try {
        final snap = PersistedSnapshot.fromJson(jsonDecode(s) as Map<String, dynamic>);
        result[snap.deviceId] = snap;
      } on Exception catch (_) {}
    }
    return result;
  }

  Future<void> saveSnapshots(Map<String, PersistedSnapshot> snapshots) async {
    final raw = snapshots.values.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs.setStringList(_kSnapshots, raw);
  }
}
