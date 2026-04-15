import 'dart:convert';

import 'package:matter_home/models/thread_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── TLV decoder ───────────────────────────────────────────────────────────────

/// Decodes a Thread Active Operational Dataset TLV hex string into
/// human-readable field pairs.  Pure — no state, no I/O.
class ThreadTlvDecoder {
  /// Decodes all recognised fields.  Returns an empty list on error or when
  /// [hex] is empty (e.g. the "Empty dataset" option).
  static List<({String label, String value})> decode(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s'), '');
    if (clean.length < 4 || clean.length.isOdd) return [];

    final bytes = <int>[];
    for (var i = 0; i + 1 < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }

    final tlvs = <int, List<int>>{};
    var i = 0;
    while (i + 1 < bytes.length) {
      final type = bytes[i];
      final len = bytes[i + 1];
      if (i + 2 + len > bytes.length) break;
      tlvs[type] = bytes.sublist(i + 2, i + 2 + len);
      i += 2 + len;
    }

    final out = <({String label, String value})>[];
    void add(String label, String value) => out.add((label: label, value: value));

    // 1. Network Name (0x03)
    if (tlvs.containsKey(0x03)) add('Network Name', String.fromCharCodes(tlvs[0x03]!));

    // 2. Network Key (0x05)
    if (tlvs.containsKey(0x05)) add('Network Key', _hex(tlvs[0x05]!));

    // 3. Channel (0x00) + Channel Page
    if (tlvs.containsKey(0x00)) {
      final v = tlvs[0x00]!;
      if (v.length >= 3) {
        add('Channel', '${(v[1] << 8) | v[2]}');
        add('Channel Page', '${v[0]}');
      }
    }

    // 4. Channel Mask (0x35)
    if (tlvs.containsKey(0x35)) {
      final v = tlvs[0x35]!;
      if (v.length >= 2) {
        final page = v[0];
        final maskLen = v[1];
        if (v.length >= 2 + maskLen) {
          add('Channel Masks', '{Page: $page, Mask: ${_hex(v.sublist(2, 2 + maskLen)).toUpperCase()}}');
        }
      }
    }

    // 5. PAN ID (0x01)
    if (tlvs.containsKey(0x01)) {
      final v = tlvs[0x01]!;
      if (v.length >= 2) add('PAN ID', '${(v[0] << 8) | v[1]}');
    }

    // 6. Extended PAN ID (0x02)
    if (tlvs.containsKey(0x02)) add('Ext PAN ID', _hex(tlvs[0x02]!));

    // 7. Mesh-Local Prefix (0x07)
    if (tlvs.containsKey(0x07)) add('Mesh Local Prefix', _hex(tlvs[0x07]!));

    // 8. PSKc (0x04)
    if (tlvs.containsKey(0x04)) add('PSKc', _hex(tlvs[0x04]!));

    // 9. Security Policy (0x0C)
    if (tlvs.containsKey(0x0C)) {
      final v = tlvs[0x0C]!;
      if (v.length >= 4) {
        add('Security Policy', '{Rotation: ${(v[0] << 8) | v[1]}h, Flags: ${_hexUpper(v.sublist(2, 4))}}');
      }
    }

    // 10. Active Timestamp (0x0E)
    if (tlvs.containsKey(0x0E)) {
      final v = tlvs[0x0E]!;
      if (v.length >= 8) {
        var secs = 0;
        for (var j = 0; j < 6; j++) {
          secs = (secs << 8) | v[j];
        }
        final last2 = (v[6] << 8) | v[7];
        add('Active Timestamp', '{Seconds: $secs, Ticks: ${last2 >> 1}, IsAuthoritativeSource: ${(last2 & 1) == 1}}');
      }
    }

    // 11. Pending Timestamp (0x0F)
    if (tlvs.containsKey(0x0F)) {
      final v = tlvs[0x0F]!;
      if (v.length >= 8) {
        var secs = 0;
        for (var j = 0; j < 6; j++) {
          secs = (secs << 8) | v[j];
        }
        add('Pending Timestamp', 'Seconds: $secs');
      }
    }

    return out;
  }

  /// Extracts just the Network Name from [hex], or null if not present.
  static String? networkName(String hex) =>
      decode(hex).where((f) => f.label == 'Network Name').map((f) => f.value).firstOrNull;

  static String _hex(List<int> b) => b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  static String _hexUpper(List<int> b) => _hex(b).toUpperCase();
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Persists Thread Operational Datasets and border-router discovery results.
///
/// ## Storage layout (SharedPreferences keys)
///
/// | Key                    | Type   | Meaning                                      |
/// |------------------------|--------|----------------------------------------------|
/// | `thread_datasets_v2`   | String | JSON array of `{label, hex}` objects         |
/// | `thread_active_hex_v2` | String | Active hex: '' = Empty dataset; absent = unset |
/// | `thread_dataset_hex`   | String | Legacy single-dataset key (migration source) |
/// | `thread_discovered_routers` | String | Cached border-router list (JSON)        |
///
/// The "Empty dataset" option (empty hex) is always implicitly available and
/// is never stored in `thread_datasets_v2`.
class ThreadSettingsService {
  static const _keyDataset = 'thread_dataset_hex'; // legacy
  static const _keyRouters = 'thread_discovered_routers';
  static const _keyDatasets = 'thread_datasets_v2';
  static const _keyActiveHex = 'thread_active_hex_v2';

  static const defaultDataset =
      '35060004001fffc0020812f209ab410ad778'
      '0708fd0e736aab8a000005101821a78a600f'
      '096682821720a51fd913030d4e4553542d50'
      '414e2d32364241010226ba0410f377af82aa'
      '453bb24d2e2b6fd2324e650c0402a0fff800'
      '0300000f0e080000690ddc3ed1a8';

  // ── Active dataset ──────────────────────────────────────────────────────────

  /// Returns the active hex string.
  /// - Returns '' if "Empty dataset" is explicitly selected.
  /// - Falls back to [defaultDataset] if nothing has been configured yet.
  static Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyActiveHex)) {
      return prefs.getString(_keyActiveHex) ?? '';
    }
    // Migrate from old single-dataset key.
    if (prefs.containsKey(_keyDataset)) {
      final hex = prefs.getString(_keyDataset) ?? defaultDataset;
      await _migrate(prefs, hex);
      return hex;
    }
    return defaultDataset;
  }

  /// True if the user has explicitly chosen an active dataset (even empty).
  static Future<bool> hasActiveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyActiveHex)) return true;
    if (prefs.containsKey(_keyDataset)) {
      final hex = prefs.getString(_keyDataset) ?? defaultDataset;
      await _migrate(prefs, hex);
      return true;
    }
    return false;
  }

  /// Returns the active [ThreadDataset], or null if nothing is configured.
  static Future<ThreadDataset?> loadActive() async {
    final prefs = await SharedPreferences.getInstance();
    // Migrate if needed.
    if (!prefs.containsKey(_keyActiveHex) && prefs.containsKey(_keyDataset)) {
      final hex = prefs.getString(_keyDataset) ?? defaultDataset;
      await _migrate(prefs, hex);
    }
    if (!prefs.containsKey(_keyActiveHex)) return null;

    final hex = prefs.getString(_keyActiveHex) ?? '';
    if (hex.isEmpty) return ThreadDataset.empty;

    // Try to find by hex in the list so we return the user's label.
    final datasets = await loadDatasets();
    final name = ThreadTlvDecoder.networkName(hex) ?? hex.substring(0, 8.clamp(0, hex.length));
    return datasets.firstWhere(
      (d) => d.hex == hex,
      orElse: () => ThreadDataset(label: name, hex: hex),
    );
  }

  /// Sets the active dataset.
  /// - Pass null to clear the selection.
  /// - Pass '' to select "Empty dataset".
  /// - Pass a TLV hex string to select that dataset.
  static Future<void> setActive(String? hex) async {
    final prefs = await SharedPreferences.getInstance();
    if (hex == null) {
      await prefs.remove(_keyActiveHex);
    } else {
      await prefs.setString(_keyActiveHex, hex);
    }
  }

  // ── Dataset list ────────────────────────────────────────────────────────────

  /// Returns all saved non-empty datasets.
  /// The "Empty dataset" option ([ThreadDataset.empty]) is always available
  /// as a choice but is never stored in this list.
  static Future<List<ThreadDataset>> loadDatasets() async {
    final prefs = await SharedPreferences.getInstance();
    // Migrate if needed.
    if (!prefs.containsKey(_keyDatasets) && prefs.containsKey(_keyDataset)) {
      final hex = prefs.getString(_keyDataset) ?? defaultDataset;
      await _migrate(prefs, hex);
    }
    final raw = prefs.getString(_keyDatasets);
    if (raw == null) {
      // No datasets saved yet; seed with the default.
      final name = ThreadTlvDecoder.networkName(defaultDataset) ?? 'Default';
      return [ThreadDataset(label: name, hex: defaultDataset)];
    }
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => ThreadDataset.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } on Exception catch (_) {
      return [];
    }
  }

  /// Persists the full dataset list (non-empty entries only).
  static Future<void> saveDatasets(List<ThreadDataset> datasets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDatasets, json.encode(datasets.map((d) => d.toJson()).toList()));
  }

  /// Adds [dataset] to the list if not already present (matched by hex).
  static Future<void> addDataset(ThreadDataset dataset) async {
    if (dataset.isEmpty) return; // "Empty dataset" is never stored
    final datasets = await loadDatasets();
    if (datasets.every((d) => d.hex != dataset.hex)) {
      datasets.add(dataset);
      await saveDatasets(datasets);
    }
  }

  /// Removes the dataset with [hex] from the list.
  /// If it was the active dataset, the active selection is cleared.
  static Future<void> removeDataset(String hex) async {
    final datasets = await loadDatasets();
    datasets.removeWhere((d) => d.hex == hex);
    await saveDatasets(datasets);
    // Clear active if it was pointing at this dataset.
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_keyActiveHex) ?? '') == hex) {
      await prefs.remove(_keyActiveHex);
    }
  }

  /// Updates an existing dataset in place (matched by [originalHex]).
  /// If [originalHex] was the active dataset, the active hex is updated to
  /// `updated.hex`.
  static Future<void> updateDataset(String originalHex, ThreadDataset updated) async {
    final datasets = await loadDatasets();
    final idx = datasets.indexWhere((d) => d.hex == originalHex);
    if (idx == -1) {
      // Not found — add as new.
      if (!updated.isEmpty) datasets.add(updated);
    } else {
      datasets[idx] = updated;
    }
    await saveDatasets(datasets);
    // If this was the active dataset, update the active hex.
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_keyActiveHex) ?? '') == originalHex) {
      await prefs.setString(_keyActiveHex, updated.hex);
    }
  }

  // ── Backward-compatible save ────────────────────────────────────────────────

  /// Saves [hex] as the active dataset and adds it to the list if not already
  /// present.  Strips whitespace before saving.
  static Future<void> save(String hex) async {
    final clean = hex.replaceAll(RegExp(r'\s'), '');
    if (clean.isNotEmpty) {
      final datasets = await loadDatasets();
      if (datasets.every((d) => d.hex != clean)) {
        final name = ThreadTlvDecoder.networkName(clean) ?? clean.substring(0, 8.clamp(0, clean.length));
        datasets.add(ThreadDataset(label: name, hex: clean));
        await saveDatasets(datasets);
      }
    }
    await setActive(clean);
  }

  // ── Border routers ──────────────────────────────────────────────────────────

  static Future<void> saveRouters(List<ThreadBorderRouter> routers) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      routers
          .map(
            (r) => {
              'serviceName': r.serviceName,
              'networkName': r.networkName,
              'extPanId': r.extPanId,
              'vendorName': r.vendorName,
              'modelName': r.modelName,
              'host': r.host,
              'port': r.port,
              'txt': r.txt,
            },
          )
          .toList(),
    );
    await prefs.setString(_keyRouters, encoded);
  }

  static Future<List<ThreadBorderRouter>> loadRouters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRouters);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => ThreadBorderRouter.fromJson(e as Map<String, dynamic>)).toList();
    } on Exception catch (_) {
      return [];
    }
  }

  // ── Migration ───────────────────────────────────────────────────────────────

  static Future<void> _migrate(SharedPreferences prefs, String hex) async {
    final clean = hex.replaceAll(RegExp(r'\s'), '');
    final name = ThreadTlvDecoder.networkName(clean) ?? clean.substring(0, 8.clamp(0, clean.length));
    await prefs.setString(_keyDatasets, json.encode([ThreadDataset(label: name, hex: clean).toJson()]));
    await prefs.setString(_keyActiveHex, clean);
  }
}
