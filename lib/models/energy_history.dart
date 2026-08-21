import 'package:flutter/foundation.dart';
import 'package:matter_home/models/matter_device.dart' show DeviceKind;
import 'package:matter_home/services/energy_cache.dart';
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
    this.batteryChargeW = 0,
    this.batteryDischargeW = 0,
  });

  final DateTime time;
  final double pvW;         // PV generation
  final double gridImportW; // drawn from the grid
  final double gridExportW; // fed to the grid
  final double loadW;       // home consumption
  final double batteryChargeW;    // into the battery
  final double batteryDischargeW; // out of the battery

  double get maxSeries =>
      [pvW, gridImportW, gridExportW, loadW].reduce((a, b) => a > b ? a : b);

  /// Whole-home consumption for this bucket (average W), from the energy
  /// balance: everything arriving minus everything leaving.
  ///
  /// The battery belongs on both sides — a discharge feeds the house, a charge
  /// consumes from it — and omitting it does not merely lose detail, it makes the
  /// figure wrong in opposite directions at different times of day: consumption
  /// reads high while the battery charges on solar, and low while it carries the
  /// house through the evening.
  double get consumptionW {
    final c = pvW + gridImportW + batteryDischargeW - gridExportW - batteryChargeW;
    return c > 0 ? c : 0;
  }

  /// Energy the house used in this bucket that it did not buy (average W).
  ///
  /// Equal to [consumptionW] − import, which expands to
  /// `pv + discharge − export − charge`. Charging subtracts here and discharging
  /// adds later, so a kWh that goes PV → battery → house is counted once, when it
  /// is actually used, rather than at both ends.
  double get selfSuppliedW {
    final s = pvW + batteryDischargeW - gridExportW - batteryChargeW;
    return s > 0 ? s : 0;
  }
}

/// One battery's state of charge over the same time base — the level at each
/// bucket's end, index-aligned to [EnergyHistoryData.points].
///
/// A level, not a flow: it is carried forward across gaps rather than summed, and
/// a bucket with no sample is null rather than zero. Zero would draw an empty
/// battery where the truth is "we did not hear from it".
@immutable
class BatterySocSeries {
  const BatterySocSeries({
    required this.kind,
    required this.nodeId,
    required this.name,
    required this.percentPerBucket,
  });

  final DeviceKind kind;
  final int nodeId;
  final String name;
  final List<int?> percentPerBucket;

  int? get latest {
    for (var i = percentPerBucket.length - 1; i >= 0; i--) {
      if (percentPerBucket[i] != null) return percentPerBucket[i];
    }
    return null;
  }
}

/// One PV inverter's generation over the same time base — average power (W) per
/// bucket, index-aligned to [EnergyHistoryData.points].
@immutable
class PvDeviceSeries {
  const PvDeviceSeries({
    required this.kind,
    required this.nodeId,
    required this.name,
    required this.wattsPerBucket,
    required this.kwh,
  });

  /// Identity is (kind, nodeId) — a PV inverter is usually Modbus, so nodeId
  /// alone does not name it.
  final DeviceKind kind;
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
    this.batterySoc = const [],
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

  /// Per-battery charge level over the window. Empty when the controller reported
  /// none (older firmware, or no battery).
  final List<BatterySocSeries> batterySoc;

  /// Charge level per bucket averaged across batteries, or null where no battery
  /// reported in that bucket. Most houses have one battery, in which case this is
  /// simply that battery's line.
  List<double?> get socPerBucket {
    if (batterySoc.isEmpty) return const [];
    return [
      for (var i = 0; i < points.length; i++)
        () {
          var sum = 0, n = 0;
          for (final s in batterySoc) {
            final v = i < s.percentPerBucket.length ? s.percentPerBucket[i] : null;
            if (v != null) { sum += v; n++; }
          }
          return n == 0 ? null : sum / n;
        }(),
    ];
  }

  bool get hasSoc => batterySoc.isNotEmpty;

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

  /// Convert a bucket's **average power (W)** into the **energy (kWh)** it
  /// represents over one bucket's duration — the unit the history chart plots
  /// (kWh per bucket = avg-kW × bucket-hours).
  double kwhFromW(double avgW) => avgW * bucket.inSeconds / 3600000.0;

  /// Consumption energy (kWh) in bucket [i].
  double bucketConsumptionKwh(int i) => kwhFromW(points[i].consumptionW);

  /// Largest single-bucket value (kWh) across every drawn series — drives the
  /// chart's Y scale. Mirrors [peakW] but in per-bucket energy.
  double get peakKwh => kwhFromW(peakW);

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

  /// Builds a window from cached rows — the same shape [fromProto] produces, so
  /// nothing downstream can tell whether the data came off the wire or off disk.
  ///
  /// The per-inverter PV breakdown is deliberately absent: it is not cached
  /// (nothing reads it today), and inventing an empty series is more honest than
  /// implying the breakdown was unavailable for this window.
  factory EnergyHistoryData.fromRows(
    Iterable<EnergyBucketRow> rows, {
    required Duration bucket,
    bool timeSynced = true,
  }) {
    final sorted = rows.toList()
      ..sort((a, b) => a.epoch.compareTo(b.epoch));
    final perHour = bucket.inSeconds / 3600.0;
    double watts(int wh) => wh / perHour;

    final points = <EnergyHistoryPoint>[];
    var pvWh = 0, impWh = 0, expWh = 0, loadWh = 0, chgWh = 0, disWh = 0;
    final soc = <int?>[];
    for (final r in sorted) {
      pvWh += r.pvWh; impWh += r.importWh; expWh += r.exportWh;
      loadWh += r.loadWh; chgWh += r.chargeWh; disWh += r.dischargeWh;
      soc.add(r.socPct);
      points.add(EnergyHistoryPoint(
        time: DateTime.fromMillisecondsSinceEpoch(r.epoch * 1000, isUtc: true)
            .toLocal(),
        pvW: watts(r.pvWh),
        gridImportW: watts(r.importWh),
        gridExportW: watts(r.exportWh),
        loadW: watts(r.loadWh),
        batteryChargeW: watts(r.chargeWh),
        batteryDischargeW: watts(r.dischargeWh),
      ));
    }

    return EnergyHistoryData(
      points: points,
      bucket: bucket,
      timeSynced: timeSynced,
      truncated: false,
      pvKwh: pvWh / 1000.0,
      gridImportKwh: impWh / 1000.0,
      gridExportKwh: expWh / 1000.0,
      loadKwh: loadWh / 1000.0,
      batteryChargeKwh: chgWh / 1000.0,
      batteryDischargeKwh: disWh / 1000.0,
      batterySoc: soc.any((v) => v != null)
          ? [
              BatterySocSeries(
                kind: DeviceKind.modbus,
                nodeId: 0,
                name: 'Battery',
                percentPerBucket: soc,
              ),
            ]
          : const [],
    );
  }

  /// The completed buckets of this window, for the cache. The in-progress bucket
  /// is already excluded by [fromProto], which is what makes caching safe.
  List<EnergyBucketRow> toRows() {
    final perHour = bucket.inSeconds / 3600.0;
    int wh(double w) => (w * perHour).round();
    final soc = socPerBucket;
    return [
      for (var i = 0; i < points.length; i++)
        EnergyBucketRow(
          epoch: points[i].time.toUtc().millisecondsSinceEpoch ~/ 1000,
          pvWh: wh(points[i].pvW),
          importWh: wh(points[i].gridImportW),
          exportWh: wh(points[i].gridExportW),
          loadWh: wh(points[i].loadW),
          chargeWh: wh(points[i].batteryChargeW),
          dischargeWh: wh(points[i].batteryDischargeW),
          socPct: i < soc.length && soc[i] != null ? soc[i]!.round() : null,
        ),
    ];
  }

  factory EnergyHistoryData.fromProto($proto.EnergyHistory h) {
    final bucketSec = h.bucketSeconds == 0 ? 900 : h.bucketSeconds;
    final start = h.start.toInt(); // epoch seconds of bucket 0
    final perHour = bucketSec / 3600.0; // fraction of an hour per bucket

    // The bucket containing the query's end time is still in progress: it holds
    // only the energy accrued so far this interval, so it always reads low and
    // climbs as the interval fills. Drop it (and anything at/after it) so the
    // chart and totals reflect complete buckets only. `to` and `start` share the
    // controller's clock, so this needs no local wall-clock. Guard against `to`
    // being unset/pre-start (older responses / tests) → no cutoff.
    final to = h.to.toInt();
    final inProgressIndex =
        to > start ? (to - start) ~/ bucketSec : 1 << 30;
    final buckets = [
      for (final b in h.buckets)
        if (b.index < inProgressIndex) b,
    ];

    // Wh → average W over the bucket.
    double watts(int wh) => wh / perHour;

    final points = <EnergyHistoryPoint>[];
    var pvWh = 0, impWh = 0, expWh = 0, loadWh = 0, batChgWh = 0, batDisWh = 0;
    for (final b in buckets) {
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
        batteryChargeW: watts(b.batteryChargeWh),
        batteryDischargeW: watts(b.batteryDischargeWh),
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
        kind: DeviceKind.fromWire(s.kind.value),
        nodeId: s.nodeId.toInt(),
        name: s.name.isNotEmpty ? s.name : 'PV ${s.nodeId.toInt()}',
        wattsPerBucket: watts,
        kwh: total / 1000.0,
      ));
    }

    // Per-battery SOC. One byte per bucket; 255 means "no sample", which must
    // stay distinguishable from 0% — an empty battery and an unheard-from battery
    // are different facts.
    final socSeries = <BatterySocSeries>[];
    for (final s in h.batterySoc) {
      final pct = <int?>[
        for (var i = 0; i < points.length; i++)
          (i < s.socPct.length && s.socPct[i] != 255) ? s.socPct[i] : null,
      ];
      if (pct.every((v) => v == null)) continue;
      socSeries.add(BatterySocSeries(
        kind: DeviceKind.fromWire(s.kind.value),
        nodeId: s.nodeId.toInt(),
        name: s.name.isNotEmpty ? s.name : 'Battery ${s.nodeId.toInt()}',
        percentPerBucket: pct,
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
      batterySoc: socSeries,
    );
  }
}
