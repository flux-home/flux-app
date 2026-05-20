import 'dart:async';

import 'package:matter_home/models/energy_bucket.dart';
import 'package:matter_home/services/device_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EnergyHistoryRecorder
//
// Receives a stream of (timestamp, cumulativeWh) readings from the live
// subscription and folds them into 15-minute sealed buckets.
//
// Sealing strategy — seal-on-next-slot:
//   • The current (open) bucket is kept in memory only.
//   • When the first sample of a *new* slot arrives, the previous slot is
//     sealed: delta = currentWh − startWh, appended to history, persisted.
//   • One disk write per 15 minutes per device.
//
// Retention: 7 days. Buckets older than that are pruned on each seal.
//
// Pure Dart — no Flutter imports, no ChangeNotifier.
// ─────────────────────────────────────────────────────────────────────────────

class EnergyHistoryRecorder {
  EnergyHistoryRecorder({
    required String       deviceId,
    required DeviceStore  store,
    required void Function() onUpdated,
  })  : _deviceId  = deviceId,
        _store     = store,
        _onUpdated = onUpdated {
    _history = store.loadEnergyHistory(deviceId);
  }

  // _kBucketDuration is kept for documentation purposes; the 15-min
  // boundary logic uses arithmetic directly for clarity.
  // ignore: unused_field
  static const _kBucketDuration = Duration(minutes: 15);
  static const _kRetention      = Duration(days: 7);

  final String       _deviceId;
  final DeviceStore  _store;
  final void Function() _onUpdated;

  List<EnergyBucket> _history = [];

  // ── Open bucket state (in memory only until sealed) ───────────────────────
  DateTime? _openBucketStart;
  int?      _openBucketStartWh;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Immutable view of sealed buckets, oldest first.
  List<EnergyBucket> get history => List.unmodifiable(_history);

  /// Feed a new cumulative-energy reading.
  ///
  /// [cumulativeWh] is the device odometer value in whole watt-hours.
  /// Call this every time a [SubscriptionUpdateEvent] contains
  /// `'cumulativeEnergyWh'`.
  void record(DateTime now, int cumulativeWh) {
    final bucketStart = _floorToBucket(now);

    if (_openBucketStart == null) {
      // First reading ever — open the first bucket.
      _openBucketStart   = bucketStart;
      _openBucketStartWh = cumulativeWh;
      return;
    }

    if (bucketStart == _openBucketStart) {
      // Still within the current slot — nothing to seal yet.
      return;
    }

    // ── New slot arrived: seal the previous bucket ────────────────────────
    final deltaWh = cumulativeWh - _openBucketStartWh!;
    if (deltaWh > 0) {
      _history.add(EnergyBucket(time: _openBucketStart!, wh: deltaWh));
      _prune();
      unawaited(_store.saveEnergyHistory(_deviceId, _history));
      _onUpdated();
    }

    // Open the new bucket.
    _openBucketStart   = bucketStart;
    _openBucketStartWh = cumulativeWh;
  }

  // ── Private ────────────────────────────────────────────────────────────────

  static DateTime _floorToBucket(DateTime dt) {
    final m = (dt.minute ~/ 15) * 15;
    return DateTime(dt.year, dt.month, dt.day, dt.hour, m);
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(_kRetention);
    _history.removeWhere((b) => b.time.isBefore(cutoff));
  }
}
