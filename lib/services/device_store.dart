import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/matter_device.dart';
import '../models/persisted_snapshot.dart';

/// Persists the device list and live-state snapshots to SharedPreferences.
class DeviceStore {
  static const _kDevices   = 'matter_devices';
  static const _kSnapshots = 'device_snapshots';

  final SharedPreferences _prefs;

  DeviceStore._(this._prefs);

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
            return MatterDevice.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
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

  // ── Snapshots (last-known live state) ─────────────────────────────────────

  /// Returns a map keyed by [PersistedSnapshot.deviceId].
  Map<String, PersistedSnapshot> loadSnapshots() {
    final raw = _prefs.getStringList(_kSnapshots) ?? [];
    final result = <String, PersistedSnapshot>{};
    for (final s in raw) {
      try {
        final snap = PersistedSnapshot.fromJson(
          jsonDecode(s) as Map<String, dynamic>,
        );
        result[snap.deviceId] = snap;
      } catch (_) {
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
