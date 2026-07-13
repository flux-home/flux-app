import 'package:flutter/foundation.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'package:matter_home/services/proto/flux.pbenum.dart' as $enum;

/// One price interval: its start time and the price in ct/kWh (may be negative —
/// day-ahead spot prices can go below zero).
@immutable
class PricePoint {
  const PricePoint({required this.time, required this.ctPerKwh});
  final DateTime time;
  final double ctPerKwh;
}

/// Decoded day-ahead price curve: per-interval ct/kWh plus the min/max/avg for
/// the covered window. Built from [$proto.PriceCurve]; the UI never sees raw
/// protobuf. Prices are the wholesale spot curve.
@immutable
class EnergyPrices {
  const EnergyPrices({
    required this.points,
    required this.resolution,
    required this.currency,
    required this.stale,
    required this.minCt,
    required this.maxCt,
    required this.avgCt,
  });

  final List<PricePoint> points;
  final Duration resolution;
  final String currency;
  final bool stale;
  final double minCt;
  final double maxCt;
  final double avgCt;

  bool get isEmpty => points.isEmpty;

  /// The interval covering [now], or null if outside coverage.
  PricePoint? currentAt(DateTime now) {
    for (final p in points) {
      if (!now.isBefore(p.time) && now.isBefore(p.time.add(resolution))) return p;
    }
    return null;
  }

  /// Total cost (in cents) of the consumed energy in [history], each bucket
  /// valued at the spot price covering its time. Null when there's no overlap
  /// between consumption and price coverage.
  double? consumptionCostCents(EnergyHistoryData? history) {
    if (history == null || history.points.isEmpty || points.isEmpty) return null;
    final bucketHours = history.bucket.inSeconds / 3600.0;
    var cents = 0.0;
    var any = false;
    for (final p in history.points) {
      final price = currentAt(p.time);
      if (price == null) continue;
      final kwh = p.consumptionW * bucketHours / 1000.0;
      cents += kwh * price.ctPerKwh;
      any = true;
    }
    return any ? cents : null;
  }

  factory EnergyPrices.fromProto($proto.PriceCurve c) {
    final res = c.resolutionSeconds == 0 ? 3600 : c.resolutionSeconds;
    final start = c.startEpoch.toInt();

    // Convert the stored unit to ct/kWh. Canonical is µEUR/kWh (÷10000);
    // EUR/MWh (informational) is ÷10.
    final divisor =
        c.unit == $enum.PriceUnit.PRICE_UNIT_EUR_PER_MWH ? 10.0 : 10000.0;
    final cts = c.prices.map((p) => p / divisor).toList(growable: false);

    final currency = c.currency.isNotEmpty ? c.currency : 'EUR';
    if (cts.isEmpty) {
      return EnergyPrices(
        points: const [],
        resolution: Duration(seconds: res),
        currency: currency,
        stale: c.stale,
        minCt: 0, maxCt: 0, avgCt: 0,
      );
    }

    final minCt = cts.reduce((a, b) => a < b ? a : b);
    final maxCt = cts.reduce((a, b) => a > b ? a : b);
    final avgCt = cts.reduce((a, b) => a + b) / cts.length;

    final points = <PricePoint>[
      for (var i = 0; i < cts.length; i++)
        PricePoint(
          time: DateTime.fromMillisecondsSinceEpoch((start + i * res) * 1000),
          ctPerKwh: cts[i],
        ),
    ];

    return EnergyPrices(
      points: points,
      resolution: Duration(seconds: res),
      currency: currency,
      stale: c.stale,
      minCt: minCt,
      maxCt: maxCt,
      avgCt: avgCt,
    );
  }
}
