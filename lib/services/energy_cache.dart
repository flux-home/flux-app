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
    this.spotUeur,
    this.forecastWh,
    this.socs = const {},
  });

  final int epoch;   // UTC seconds at the bucket's START
  final int pvWh;
  final int importWh;
  final int exportWh;
  final int loadWh;
  final int chargeWh;
  final int dischargeWh;
  /// Charge level at the bucket's end, or null if no battery reported.
  ///
  /// The mean across batteries. Kept for rows written before [socs] existed, and
  /// still written so an older build reading this cache sees what it expects.
  /// [socs] is what the chart uses.
  final int? socPct;

  /// Charge level at the bucket's end PER BATTERY, keyed by node id.
  ///
  /// A house can have more than one store, and they do not move together — one
  /// pack can sit full while another is run flat. [socPct] averaged them, which
  /// made the cache lossy in a way the wire format was not: the controller sends
  /// a series per battery and this threw that apart before it reached the chart.
  ///
  /// Empty for rows written by an older build; those fall back to [socPct].
  final Map<int, int> socs;

  /// The wholesale spot price in force during this bucket, in µEUR/kWh — the
  /// wire unit, stored NET.
  ///
  /// Net rather than gross on purpose: markup and VAT come from the controller's
  /// PricingConfig and can be corrected later, and a gross figure would freeze
  /// whatever the tariff happened to say on the day. Null where the curve did not
  /// cover the bucket (the app was not running, or prices are disabled).
  final int? spotUeur;

  /// What the PV forecast predicted for this bucket, in Wh, as it stood while the
  /// bucket was live. Null when no forecast covered it.
  ///
  /// Kept because the interesting comparison is prediction against outcome, and
  /// a forecast re-read later is no longer a prediction — the controller revises
  /// it as the sky changes, so only the value captured at the time can be scored.
  final int? forecastWh;

  /// This row with the two captured-context columns replaced. Used when a
  /// refetch brings the same bucket back without them — see [EnergyCache.merge].
  EnergyBucketRow withContext({int? forecastWh, int? spotUeur}) =>
      EnergyBucketRow(
        epoch: epoch,
        pvWh: pvWh,
        importWh: importWh,
        exportWh: exportWh,
        loadWh: loadWh,
        chargeWh: chargeWh,
        dischargeWh: dischargeWh,
        socPct: socPct,
        spotUeur: spotUeur,
        forecastWh: forecastWh,
        socs: socs,
      );

  /// Node-keyed levels as `1a:73|1c:44` — hex node id, decimal percent.
  ///
  /// A trailing column, because every reader tolerates columns it does not know
  /// (see [decode]): an older build keeps working against a newer cache, and a
  /// newer build keeps working against an older one.
  String _encodeSocs() => socs.isEmpty
      ? ''
      : socs.entries
          .map((e) => '${e.key.toRadixString(16)}:${e.value}')
          .join('|');

  String encode() => '$epoch,$pvWh,$importWh,$exportWh,$loadWh,$chargeWh,'
      '$dischargeWh,${socPct ?? ''},${spotUeur ?? ''},${forecastWh ?? ''},'
      '${_encodeSocs()}';

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
      spotUeur: p.length > 8 ? n(p[8]) : null,
      forecastWh: p.length > 9 ? n(p[9]) : null,
      socs: p.length > 10 ? _decodeSocs(p[10]) : const {},
    );
  }

  static Map<int, int> _decodeSocs(String v) {
    if (v.isEmpty) return const {};
    final out = <int, int>{};
    for (final pair in v.split('|')) {
      final i = pair.indexOf(':');
      if (i <= 0) continue;
      final id = int.tryParse(pair.substring(0, i), radix: 16);
      final pct = int.tryParse(pair.substring(i + 1));
      if (id != null && pct != null) out[id] = pct;
    }
    return out;
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

  /// Bumped to v2 for two reasons at once: the rows gained a price and a
  /// forecast column, and — the reason it could not simply be widened — every
  /// row written before the controller's 2026-09-15 fix carries the old device
  /// classification, which read a sub-meter as the grid connection. Those rows
  /// are wrong, not merely old, and the controller now re-resolves the class on
  /// every query, so dropping them is how the correction reaches the phone.
  /// Bumped to v3 to discard rows written before unsynced log entries were
  /// excluded from the counter diff. Those rows recorded impossible values —
  /// an 18.8 kWh quarter-hour of export, 75 kW — and the cache is preferred
  /// over re-fetching, so a corrupt bucket would have been kept for ever.
  ///
  /// Nothing is lost by dropping them: the controller archives the spot price
  /// and the forecast per bucket, and the app now reads both off the wire, so
  /// a cleared cache refills from the device with better data than it held.
  static const _key = 'energy_buckets_v3';

  /// The pre-2026-09-16 key. Its rows are not migrated — they carry the device
  /// classification the controller has since corrected — but they are ~45 KB of
  /// dead weight in SharedPreferences, so they are dropped once.
  static const _legacyKey = 'energy_buckets_v1';
  static const _maxRows = 24 * 45;

  final SharedPreferences _prefs;

  /// How far past the phone's clock a bucket may be stamped and still be kept.
  ///
  /// Bucket times come from the controller; the window that selects them is the
  /// phone's. The two clocks differ, and a bucket stamped a little ahead is the
  /// newest data rather than a future event. Anything beyond this is a clock
  /// fault, and keeping it wedges the tail fetch for ever — see
  /// DeviceProvider.fetchEnergyHistory.
  static const clockSkew = Duration(hours: 2);

  /// Cached buckets by start epoch, oldest first.
  ///
  /// Rows stamped implausibly far in the future are dropped on the way out: a
  /// single one of them pins `newestEnd` ahead of the window and stops the live
  /// window ever advancing again, which survives restarts because the row is on
  /// disk. Dropping them here self-heals an install that already wedged.
  Map<int, EnergyBucketRow> load() {
    final horizon = DateTime.now().add(clockSkew).millisecondsSinceEpoch ~/ 1000;
    final out = <int, EnergyBucketRow>{};
    for (final line in _prefs.getStringList(_key) ?? const <String>[]) {
      final r = EnergyBucketRow.decode(line);
      if (r != null && r.epoch <= horizon) out[r.epoch] = r;
    }
    return out;
  }

  bool _legacyPruned = false;

  /// Merges [rows] over what is stored and persists the result.
  Future<Map<int, EnergyBucketRow>> merge(Iterable<EnergyBucketRow> rows) async {
    if (!_legacyPruned) {
      _legacyPruned = true;
      if (_prefs.containsKey(_legacyKey)) await _prefs.remove(_legacyKey);
    }
    final all = load();
    for (final r in rows) {
      // Newer wins on the measurements, but never on the two columns that can
      // legitimately arrive empty. The forecast and the price are captured as
      // they stood, and a refetch made when the live forecast no longer reaches
      // back that far carries null for buckets it has already recorded — the
      // old value is the one that was true, and letting a null replace it is
      // how a past day loses the morning of its sun line.
      final prev = all[r.epoch];
      all[r.epoch] = prev == null
          ? r
          : r.withContext(
              forecastWh: r.forecastWh ?? prev.forecastWh,
              spotUeur: r.spotUeur ?? prev.spotUeur,
            );
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
