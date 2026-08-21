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
  static const _kLayoutUp  = 'layout_uploaded_v1';
  static const _kNamesUp   = 'names_uploaded_v1';
  static const _kSeries    = 'chart_series_v1';
  static const _kCardOrder = 'energy_card_order_v1';

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
          // Catches Error too, not just Exception: rooms persisted before the
          // controller owned them carry a UUID string id, and `as int` on those
          // throws a TypeError — an Error, which `on Exception` would let
          // escape and take the whole load with it.
          try { return Room.fromJson(jsonDecode(s) as Map<String, dynamic>); }
          catch (_) { return null; }
        })
        .whereType<Room>()
        .toList();
  }

  /// Rooms persisted before the controller owned them, as (uuid, name).
  ///
  /// Read raw rather than through [Room], which cannot represent them: their ids
  /// are UUIDs. Used once, to re-create the layout on the controller — see
  /// DeviceProvider.migrateLocalLayout.
  List<(String, String)> loadLegacyRooms() {
    final out = <(String, String)>[];
    for (final s in _prefs.getStringList(_kRooms) ?? <String>[]) {
      try {
        final j = jsonDecode(s) as Map<String, dynamic>;
        final id = j['id'], name = j['name'];
        if (id is String && name is String) out.add((id, name));
      } catch (_) { /* skip unreadable entry */ }
    }
    return out;
  }

  /// Device-id → legacy room UUID, for devices assigned before the move.
  /// [MatterDevice] drops the string form, so this reads the raw records.
  Map<String, String> loadLegacyRoomAssignments() {
    final out = <String, String>{};
    for (final s in _prefs.getStringList(_kDevices) ?? <String>[]) {
      try {
        final j = jsonDecode(s) as Map<String, dynamic>;
        final id = j['id'], room = j['roomId'];
        if (id is String && room is String && room != 'no-room') out[id] = room;
      } catch (_) { /* skip unreadable entry */ }
    }
    return out;
  }

  Future<void> saveRooms(List<Room> rooms) async {
    final raw = rooms
        .where((r) => !r.isNoRoom)
        .map((r) => jsonEncode(r.toJson()))
        .toList();
    await _prefs.setStringList(_kRooms, raw);
  }

  /// Whether this phone's pre-existing rooms and energy roles have already been
  /// uploaded to a controller. One-way and permanent: re-running it after the
  /// user has edited the layout on the controller would resurrect deleted rooms.
  bool get layoutUploaded => _prefs.getBool(_kLayoutUp) ?? false;
  Future<void> markLayoutUploaded() => _prefs.setBool(_kLayoutUp, true);

  /// Whether this phone's device names have been handed to the controller.
  ///
  /// Deliberately a SEPARATE flag from [layoutUploaded]: phones that already ran
  /// the rooms/roles hand-off must still upload their names, and sharing the
  /// flag would skip them — silently replacing the user's names with the
  /// vendor-derived ones the controller learned at commissioning.
  bool get namesUploaded => _prefs.getBool(_kNamesUp) ?? false;
  Future<void> markNamesUploaded() => _prefs.setBool(_kNamesUp, true);

  /// Which series the energy timeline shows. Absent means "not chosen yet", so
  /// the chart falls back to its own defaults rather than to an empty plot — an
  /// empty stored list is a real choice and must survive.
  List<String>? loadChartSeries() => _prefs.getStringList(_kSeries);
  Future<void> saveChartSeries(List<String> keys) =>
      _prefs.setStringList(_kSeries, keys);

  /// The order of the Energy view's cards, by key. Null until the user has
  /// dragged one — a stored list is their arrangement and must not be
  /// second-guessed, but a key added by a later app version is simply appended
  /// rather than dropping the card.
  List<String>? loadEnergyCardOrder() => _prefs.getStringList(_kCardOrder);
  Future<void> saveEnergyCardOrder(List<String> keys) =>
      _prefs.setStringList(_kCardOrder, keys);

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
