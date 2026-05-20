import 'dart:async';

import 'package:matter_home/models/energy_bucket.dart';
import 'package:matter_home/services/device_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EnergyHistoryRecorder
//
// Integrates per-second activePower (mW) samples into 15-minute buckets.
//
// Why activePower instead of cumulativeEnergyWh:
//   activePower arrives every ~1 s from the subscription.
//   CumulativeEnergyImported is only sent by devices when the attribute
//   value changes, which can be once every few minutes — too infrequent
//   to compute a non-zero 15-min delta reliably.
//   By integrating power ourselves we get accurate Wh per bucket regardless
//   of how often the device pushes its odometer.
//
// Sealing strategy:
//   Each bucket accumulates E += P × Δt.  When the first sample of a new
//   15-min slot arrives the current bucket is sealed, rounded to whole Wh,
//   and persisted.  One disk write per 15 minutes.
//   Buckets with 0 Wh are stored (device was truly idle during that window).
//
// Retention: 7 days, pruned on each seal.
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

  static const _kRetention = Duration(days: 7);

  final String       _deviceId;
  final DeviceStore  _store;
  final void Function() _onUpdated;

  List<EnergyBucket> _history = [];

  // ── Open bucket state ─────────────────────────────────────────────────────
  DateTime? _openBucketStart;
  double    _accumulatedWh = 0;      // fractional Wh accumulated in open bucket
  int?      _lastSampleMs;           // epoch ms of the previous power sample

  // ── Live estimate state ──────────────────────────────────────────────────
  // Tracks the device-reported baseline + power-integrated delta so the
  // odometer display updates every ~1 s without waiting for a new device report.
  int?   _baselineMwh;               // last value pushed by the device
  double _liveAccumulatedMwh = 0;    // mWh integrated since last device report

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Immutable view of sealed buckets, oldest first.
  List<EnergyBucket> get history => List.unmodifiable(_history);

  /// Live odometer estimate: device baseline + power integrated since then.
  /// Updates every ~1 s as [recordPower] is called.  Returns null until the
  /// device has sent at least one [updateDeviceReport].
  int? get estimatedCumulativeMwh {
    final b = _baselineMwh;
    if (b == null) return null;
    return b + _liveAccumulatedMwh.round();
  }

  /// Called whenever the device pushes a new [CumulativeEnergyImported] value.
  /// Resets the integration accumulator to avoid double-counting.
  void updateDeviceReport(int mwh) {
    if (_baselineMwh == mwh) return;
    _baselineMwh           = mwh;
    _liveAccumulatedMwh    = 0;
  }

  /// Feed a new active-power reading.
  ///
  /// [milliwatts] is the instantaneous active power in mW from the
  /// ElectricalPowerMeasurement cluster.  Call this on every
  /// [SubscriptionUpdateEvent] that contains `'activePower'`.
  void recordPower(DateTime now, int milliwatts) {
    final bucketStart = _floorToBucket(now);
    final nowMs       = now.millisecondsSinceEpoch;

    if (_openBucketStart == null) {
      // First sample — open the first bucket, no energy to accumulate yet.
      _openBucketStart = bucketStart;
      _lastSampleMs    = nowMs;
      return;
    }

    final dtSeconds = (nowMs - _lastSampleMs!) / 1000.0;
    final watts     = milliwatts / 1000.0;

    if (bucketStart == _openBucketStart) {
      // Same slot: integrate both accumulators.
      final deltaWh        = (watts * dtSeconds) / 3600.0;
      _accumulatedWh      += deltaWh;
      _liveAccumulatedMwh += deltaWh * 1000.0;
      _lastSampleMs        = nowMs;
      return;
    }

    // ── New slot: split energy at the bucket boundary, then seal ─────────────
    final boundaryMs     = bucketStart.millisecondsSinceEpoch;
    final dtToSeal       = ((boundaryMs - _lastSampleMs!) / 1000.0).clamp(0.0, dtSeconds);
    final dtFromBoundary = (dtSeconds - dtToSeal).clamp(0.0, dtSeconds);

    // Energy that belongs to the OLD bucket.
    final sealDeltaWh    = (watts * dtToSeal) / 3600.0;
    _accumulatedWh      += sealDeltaWh;
    _liveAccumulatedMwh += sealDeltaWh * 1000.0;

    final sealedWh = _accumulatedWh.round();
    _history.add(EnergyBucket(time: _openBucketStart!, wh: sealedWh));
    _prune();
    unawaited(_store.saveEnergyHistory(_deviceId, _history));
    _onUpdated();

    // Energy that belongs to the NEW bucket.
    final newDeltaWh     = (watts * dtFromBoundary) / 3600.0;
    _openBucketStart     = bucketStart;
    _accumulatedWh       = newDeltaWh;
    _liveAccumulatedMwh += newDeltaWh * 1000.0;
    _lastSampleMs        = nowMs;
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
