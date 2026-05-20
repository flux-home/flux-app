import 'dart:async';

import 'package:matter_home/models/energy_bucket.dart';
import 'package:matter_home/services/device_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EnergyHistoryRecorder
//
// Consumes periodic one-shot reads of CumulativeEnergyImported (mWh) and
// computes per-15-min consumption as the delta between consecutive readings.
//
// Why reads instead of subscription:
//   The Matter device only pushes ActivePower (EPM 0x90) via the subscription
//   stream.  CumulativeEnergyImported (EEM 0x91) is available only via direct
//   attribute reads.  DeviceProvider polls it every second.
//
// Sealing strategy — cumulative delta:
//   _bucketStartMwh  = device reading at the start of the current 15-min slot.
//   On each new reading in the same slot: update _latestMwh only.
//   On the first reading of a NEW slot: seal = latestMwh − bucketStartMwh.
//   One disk write per 15 minutes.
//
// Live odometer:
//   Returns the latest known cumulative reading directly — no estimation.
//
// Retention: 7 days, pruned on each seal.
// ─────────────────────────────────────────────────────────────────────────────

class EnergyHistoryRecorder {
  EnergyHistoryRecorder({
    required String          deviceId,
    required DeviceStore     store,
    required void Function() onUpdated,
  })  : _deviceId  = deviceId,
        _store     = store,
        _onUpdated = onUpdated {
    _history = store.loadEnergyHistory(deviceId);
  }

  static const _kRetention = Duration(days: 7);

  final String          _deviceId;
  final DeviceStore     _store;
  final void Function() _onUpdated;

  List<EnergyBucket> _history = [];

  // ── Bucket state ──────────────────────────────────────────────────────────
  DateTime? _openBucketStart;  // floored to 15-min boundary
  int?      _bucketStartMwh;   // device reading when bucket opened
  int?      _latestMwh;        // most recent device reading

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Immutable view of sealed buckets, oldest first.
  List<EnergyBucket> get history => List.unmodifiable(_history);

  /// Latest known cumulative reading from the device in mWh.
  /// Null until the first successful read arrives.
  int? get latestCumulativeMwh => _latestMwh;

  /// Called on every periodic read of CumulativeEnergyImported.
  ///
  /// [cumulativeMwh] is the absolute device odometer value in mWh.
  void record(DateTime now, int cumulativeMwh) {
    _latestMwh = cumulativeMwh;

    final bucketStart = _floorToBucket(now);

    if (_openBucketStart == null) {
      _openBucketStart = bucketStart;
      _bucketStartMwh  = cumulativeMwh;
      _onUpdated();   // first reading — refresh odometer display
      return;
    }

    if (bucketStart == _openBucketStart) {
      // Still within the current slot — update odometer display.
      _onUpdated();
      return;
    }

    // ── New slot: seal the previous bucket ────────────────────────────────────
    final deltaMwh = cumulativeMwh - _bucketStartMwh!;
    final sealedWh = (deltaMwh / 1000.0).round().clamp(0, deltaMwh ~/ 1000 + 1);
    _history.add(EnergyBucket(time: _openBucketStart!, wh: sealedWh));
    _prune();
    unawaited(_store.saveEnergyHistory(_deviceId, _history));

    _openBucketStart = bucketStart;
    _bucketStartMwh  = cumulativeMwh;
    _onUpdated();
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
