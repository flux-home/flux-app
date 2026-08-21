import 'package:shared_preferences/shared_preferences.dart';

/// One complete energy bucket, as cached. Wh, exactly as the controller reports.
class EnergyBucketRow {
  const EnergyBucketRow({
    required this.epoch,
    required this.pvWh,
    required this.importWh,
    required this.exportWh,
    required this.loadWh,
    required this.chargeWh,
    required this.dischargeWh,
    this.socPct,
  });

  final int epoch;   // UTC seconds at the bucket's START
  final int pvWh;
  final int importWh;
  final int exportWh;
  final int loadWh;
  final int chargeWh;
  final int dischargeWh;
  /// Charge level at the bucket's end, or null if no battery reported.
  final int? socPct;

  String encode() => '$epoch,$pvWh,$importWh,$exportWh,$loadWh,$chargeWh,'
      '$dischargeWh,${socPct ?? ''}';

  static EnergyBucketRow? decode(String s) {
    final p = s.split(',');
    if (p.length < 7) return null;
    int? n(String v) => v.isEmpty ? null : int.tryParse(v);
    final e = n(p[0]);
    if (e == null) return null;
    return EnergyBucketRow(
      epoch: e,
      pvWh: n(p[1]) ?? 0,
      importWh: n(p[2]) ?? 0,
      exportWh: n(p[3]) ?? 0,
      loadWh: n(p[4]) ?? 0,
      chargeWh: n(p[5]) ?? 0,
      dischargeWh: n(p[6]) ?? 0,
      socPct: p.length > 7 ? n(p[7]) : null,
    );
  }
}

/// A local store of completed hourly energy buckets.
///
/// Exists because a finished bucket never changes. The controller was being asked
/// for the same 24 hours on every launch — a slow round trip to re-learn facts
/// the phone already knew — when all that is genuinely unknown is whatever
/// happened since the last time the app looked.
///
/// Two rules keep it honest:
///
///  * **Only complete buckets are stored.** The bucket containing "now" is still
///    filling, so caching it would freeze a low reading forever. The caller drops
///    it before handing rows here.
///  * **Newer always wins.** A re-fetched bucket overwrites the cached one rather
///    than being skipped, so a controller correction (a meter reset, a late
///    device) reaches the cache instead of being permanently shadowed.
///
/// Storage is SharedPreferences because that is what this app has. One CSV line
/// per bucket, capped at [_maxRows] — about six weeks of hours, roughly 45 KB.
/// If history ever needs months rather than weeks, this is the thing to replace,
/// and the interface is small on purpose.
class EnergyCache {
  EnergyCache(this._prefs);

  static const _key = 'energy_buckets_v1';
  static const _maxRows = 24 * 45;

  final SharedPreferences _prefs;

  /// Cached buckets by start epoch, oldest first.
  Map<int, EnergyBucketRow> load() {
    final out = <int, EnergyBucketRow>{};
    for (final line in _prefs.getStringList(_key) ?? const <String>[]) {
      final r = EnergyBucketRow.decode(line);
      if (r != null) out[r.epoch] = r;
    }
    return out;
  }

  /// Merges [rows] over what is stored and persists the result.
  Future<Map<int, EnergyBucketRow>> merge(Iterable<EnergyBucketRow> rows) async {
    final all = load();
    for (final r in rows) {
      all[r.epoch] = r;   // newer wins
    }
    final keys = all.keys.toList()..sort();
    final kept = keys.length > _maxRows
        ? keys.sublist(keys.length - _maxRows)
        : keys;
    await _prefs.setStringList(
        _key, [for (final k in kept) all[k]!.encode()]);
    return {for (final k in kept) k: all[k]!};
  }

  /// The end of the newest cached bucket, or null when nothing is cached.
  DateTime? newestEnd(Map<int, EnergyBucketRow> rows, Duration bucket) {
    if (rows.isEmpty) return null;
    final newest = rows.keys.reduce((a, b) => a > b ? a : b);
    return DateTime.fromMillisecondsSinceEpoch(newest * 1000, isUtc: true)
        .toLocal()
        .add(bucket);
  }

  Future<void> clear() => _prefs.remove(_key);
}
