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

/// One PV inverter's generation over the same time base — average power (W) per
/// bucket, index-aligned to [EnergyHistoryData.points].
@immutable
class PvDeviceSeries {
  const PvDeviceSeries({
    required this.nodeId,
    required this.name,
    required this.wattsPerBucket,
    required this.kwh,
  });

  final int nodeId;
  final String name;
  final List<double> wattsPerBucket;
  final double kwh; // window total

  double get peakW =>
      wattsPerBucket.isEmpty ? 0 : wattsPerBucket.reduce((a, b) => a > b ? a : b);
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
    this.batteryChargeKwh = 0,
    this.batteryDischargeKwh = 0,
    this.pvSeries = const [],
  });

  final List<EnergyHistoryPoint> points;
  final Duration bucket;
  final bool timeSynced; // false → times approximate (pre-SNTP rows)
  final bool truncated;  // true → range exceeded the per-response cap

  final double pvKwh;
  final double gridImportKwh;
  final double gridExportKwh;
  /// Sum of load-classed devices' consumption (monitored appliances only — not
  /// necessarily whole-home; prefer [consumptionKwh] for totals).
  final double loadKwh;
  final double batteryChargeKwh;
  final double batteryDischargeKwh;

  /// Per-inverter PV breakdown, when the controller reports it. Empty → only the
  /// summed PV total ([pvKwh] / [EnergyHistoryPoint.pvW]) is available.
  final List<PvDeviceSeries> pvSeries;

  /// True when the controller reported a per-device PV breakdown — then the
  /// individual inverter lines are drawn (by device name) instead of the summed
  /// "Solar" total. Older firmware reports none → the total line is used.
  bool get hasPvBreakdown => pvSeries.isNotEmpty;
  bool get isEmpty => points.isEmpty;

  /// Peak power across every drawn series — drives the chart's Y scale. When a
  /// PV breakdown exists the individual inverter lines (not the summed total)
  /// are what's drawn, so scale to those.
  double get peakW {
    if (points.isEmpty) return 0;
    var peak = 0.0;
    for (final p in points) {
      final consumptionSide =
          [p.gridImportW, p.gridExportW, p.loadW].reduce((a, b) => a > b ? a : b);
      if (consumptionSide > peak) peak = consumptionSide;
      if (!hasPvBreakdown && p.pvW > peak) peak = p.pvW;
    }
    if (hasPvBreakdown) {
      for (final s in pvSeries) {
        if (s.peakW > peak) peak = s.peakW;
      }
    }
    return peak;
  }

  /// Whole-home consumption over the window, from the energy balance:
  ///   consumption = generated + imported + battery discharge
  ///               − exported − battery charge
  /// This is grounded in the grid + PV (+ battery) meters, so it's robust even
  /// when individual loads aren't metered (unlike [loadKwh]). Clamped ≥ 0.
  double get consumptionKwh {
    final c = pvKwh +
        gridImportKwh +
        batteryDischargeKwh -
        gridExportKwh -
        batteryChargeKwh;
    return c > 0 ? c : 0;
  }

  /// Share of consumption met from own generation/storage rather than bought
  /// from the grid, 0–100: `(consumed − imported) / consumed`. Null when there
  /// was no consumption.
  int? get selfSufficiencyPercent {
    final c = consumptionKwh;
    if (c <= 0) return null;
    final selfConsumed = c - gridImportKwh;
    return ((selfConsumed / c).clamp(0.0, 1.0) * 100).round();
  }

  factory EnergyHistoryData.fromProto($proto.EnergyHistory h) {
    final bucketSec = h.bucketSeconds == 0 ? 900 : h.bucketSeconds;
    final start = h.start.toInt(); // epoch seconds of bucket 0
    final perHour = bucketSec / 3600.0; // fraction of an hour per bucket

    // Wh → average W over the bucket.
    double watts(int wh) => wh / perHour;

    final points = <EnergyHistoryPoint>[];
    var pvWh = 0, impWh = 0, expWh = 0, loadWh = 0, batChgWh = 0, batDisWh = 0;
    for (final b in h.buckets) {
      pvWh += b.pvWh;
      impWh += b.gridImportWh;
      expWh += b.gridExportWh;
      loadWh += b.loadWh;
      batChgWh += b.batteryChargeWh;
      batDisWh += b.batteryDischargeWh;
      points.add(EnergyHistoryPoint(
        time: DateTime.fromMillisecondsSinceEpoch(
            (start + b.index * bucketSec) * 1000),
        pvW: watts(b.pvWh),
        gridImportW: watts(b.gridImportWh),
        gridExportW: watts(b.gridExportWh),
        loadW: watts(b.loadWh),
      ));
    }
    // Per-device PV breakdown (index-aligned to buckets), if the controller
    // reported it. Each series' wh[] is dense and aligned to h.buckets by index.
    final pvSeries = <PvDeviceSeries>[];
    for (final s in h.deviceSeries) {
      if (s.cls != $proto.EnergyClass.ENERGY_CLASS_PV) continue;
      var total = 0;
      final watts = <double>[];
      for (var i = 0; i < points.length; i++) {
        final wh = i < s.wh.length ? s.wh[i] : 0;
        total += wh;
        watts.add(wh / perHour);
      }
      pvSeries.add(PvDeviceSeries(
        nodeId: s.nodeId.toInt(),
        name: s.name.isNotEmpty ? s.name : 'PV ${s.nodeId.toInt()}',
        wattsPerBucket: watts,
        kwh: total / 1000.0,
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
      batteryChargeKwh: batChgWh / 1000.0,
      batteryDischargeKwh: batDisWh / 1000.0,
      pvSeries: pvSeries,
    );
  }
}
