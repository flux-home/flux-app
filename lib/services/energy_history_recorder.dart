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
  DateTime? _openBucketStart;
  int?      _bucketStartMwh;          // imported baseline for open bucket
  int?      _latestMwh;               // latest imported cumulative
  int?      _exportedBucketStartMwh;  // exported baseline for open bucket
  int?      _latestExportedMwh;       // latest exported cumulative

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Immutable view of sealed buckets, oldest first.
  List<EnergyBucket> get history => List.unmodifiable(_history);

  /// Energy accumulated in the current (unsealed) 15-min bucket, in Wh.
  int get currentBucketWh {
    if (_bucketStartMwh == null || _latestMwh == null) return 0;
    return ((_latestMwh! - _bucketStartMwh!).clamp(0, 999999999) / 1000).round();
  }

  /// Exported energy accumulated in the current (unsealed) 15-min bucket, Wh.
  int get currentExportedBucketWh {
    if (_exportedBucketStartMwh == null || _latestExportedMwh == null) return 0;
    return ((_latestExportedMwh! - _exportedBucketStartMwh!).clamp(0, 999999999) / 1000).round();
  }

  /// Called on every cumulative-energy update from the device.
  /// [exportedMwh] is null if the device doesn't report exported energy.
  void record(DateTime now, int importedMwh, {int? exportedMwh}) {
    _latestMwh = importedMwh;
    if (exportedMwh != null) _latestExportedMwh = exportedMwh;

    final bucketStart = _floorToBucket(now);

    if (_openBucketStart == null) {
      _openBucketStart        = bucketStart;
      _bucketStartMwh         = importedMwh;
      _exportedBucketStartMwh = exportedMwh;
      _onUpdated();
      return;
    }

    if (bucketStart == _openBucketStart) {
      _onUpdated();
      return;
    }

    // ── New slot: seal the previous bucket ────────────────────────────────────
    final deltaImportedMwh = importedMwh - _bucketStartMwh!;
    final sealedImportedWh = (deltaImportedMwh / 1000.0).round()
        .clamp(0, deltaImportedMwh ~/ 1000 + 1);

    int sealedExportedWh = 0;
    if (_exportedBucketStartMwh != null && _latestExportedMwh != null) {
      final deltaExportedMwh = _latestExportedMwh! - _exportedBucketStartMwh!;
      sealedExportedWh = (deltaExportedMwh / 1000.0).round()
          .clamp(0, deltaExportedMwh ~/ 1000 + 1);
    }

    _history.add(EnergyBucket(
      time:       _openBucketStart!,
      wh:         sealedImportedWh,
      exportedWh: sealedExportedWh,
    ));
    _prune();
    unawaited(_store.saveEnergyHistory(_deviceId, _history));

    _openBucketStart        = bucketStart;
    _bucketStartMwh         = importedMwh;
    _exportedBucketStartMwh = exportedMwh ?? _exportedBucketStartMwh;
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
