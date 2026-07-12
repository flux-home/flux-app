import 'package:flutter/foundation.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;

/// One time bucket of the energy-history chart, expressed as **average power in
/// watts** over the bucket (so lines read as instantaneous-ish power, kW).
///
/// The controller reports watt-hours accumulated per bucket; average power is
/// `Wh / (bucketSeconds / 3600)`.
@immutable
class EnergyHistoryPoint {
  const EnergyHistoryPoint({
    required this.time,
    required this.pvW,
    required this.gridImportW,
    required this.gridExportW,
    required this.loadW,
  });

  final DateTime time;
  final double pvW;         // PV generation
  final double gridImportW; // drawn from the grid
  final double gridExportW; // fed to the grid
  final double loadW;       // home consumption

  double get maxSeries =>
      [pvW, gridImportW, gridExportW, loadW].reduce((a, b) => a > b ? a : b);
}

/// A decoded, chart-ready energy history: the per-bucket power series plus the
/// window totals (kWh) and derived KPIs. Built from the controller's
/// [$proto.EnergyHistory]; the UI never sees raw protobuf.
@immutable
class EnergyHistoryData {
  const EnergyHistoryData({
    required this.points,
    required this.bucket,
    required this.timeSynced,
    required this.truncated,
    required this.pvKwh,
    required this.gridImportKwh,
    required this.gridExportKwh,
    required this.loadKwh,
  });

  final List<EnergyHistoryPoint> points;
  final Duration bucket;
  final bool timeSynced; // false → times approximate (pre-SNTP rows)
  final bool truncated;  // true → range exceeded the per-response cap

  final double pvKwh;
  final double gridImportKwh;
  final double gridExportKwh;
  final double loadKwh;

  bool get isEmpty => points.isEmpty;

  /// Peak power across every series — drives the chart's Y scale.
  double get peakW =>
      points.isEmpty ? 0 : points.map((p) => p.maxSeries).reduce((a, b) => a > b ? a : b);

  /// Share of consumption covered without buying from the grid, 0–100.
  /// `(consumed − imported) / consumed`. Null when there was no consumption.
  int? get selfSufficiencyPercent {
    if (loadKwh <= 0) return null;
    final ratio = (loadKwh - gridImportKwh) / loadKwh;
    return (ratio.clamp(0.0, 1.0) * 100).round();
  }

  factory EnergyHistoryData.fromProto($proto.EnergyHistory h) {
    final bucketSec = h.bucketSeconds == 0 ? 900 : h.bucketSeconds;
    final start = h.start.toInt(); // epoch seconds of bucket 0
    final perHour = bucketSec / 3600.0; // fraction of an hour per bucket

    // Wh → average W over the bucket.
    double watts(int wh) => wh / perHour;

    final points = <EnergyHistoryPoint>[];
    var pvWh = 0, impWh = 0, expWh = 0, loadWh = 0;
    for (final b in h.buckets) {
      pvWh += b.pvWh;
      impWh += b.gridImportWh;
      expWh += b.gridExportWh;
      loadWh += b.loadWh;
      points.add(EnergyHistoryPoint(
        time: DateTime.fromMillisecondsSinceEpoch(
            (start + b.index * bucketSec) * 1000),
        pvW: watts(b.pvWh),
        gridImportW: watts(b.gridImportWh),
        gridExportW: watts(b.gridExportWh),
        loadW: watts(b.loadWh),
      ));
    }
    return EnergyHistoryData(
      points: points,
      bucket: Duration(seconds: bucketSec),
      timeSynced: h.timeSynced,
      truncated: h.truncated,
      pvKwh: pvWh / 1000.0,
      gridImportKwh: impWh / 1000.0,
      gridExportKwh: expWh / 1000.0,
      loadKwh: loadWh / 1000.0,
    );
  }
}
