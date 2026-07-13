import 'package:flutter/foundation.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'package:matter_home/services/proto/flux.pbenum.dart' as $enum;

/// Relative price band for an interval, from the day's own distribution
/// (terciles). Drives the chart colours — "cheap / normal / expensive".
enum PriceLevel { cheap, normal, expensive }

/// One price interval: its start time and the price in ct/kWh (may be negative —
/// day-ahead spot prices can go below zero).
@immutable
class PricePoint {
  const PricePoint({required this.time, required this.ctPerKwh, required this.level});
  final DateTime time;
  final double ctPerKwh;
  final PriceLevel level;
}

/// Decoded day-ahead price curve: per-interval ct/kWh with cheap/normal/expensive
/// bands, plus the min/max/avg for the covered window. Built from [$proto.PriceCurve];
/// the UI never sees raw protobuf. Prices shown are the wholesale spot curve.
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

  factory EnergyPrices.fromProto($proto.PriceCurve c) {
    final res = c.resolutionSeconds == 0 ? 3600 : c.resolutionSeconds;
    final start = c.startEpoch.toInt();

    // Convert the stored unit to ct/kWh. Canonical is µEUR/kWh (÷10000);
    // EUR/MWh (informational) is ÷10.
    final divisor =
        c.unit == $enum.PriceUnit.PRICE_UNIT_EUR_PER_MWH ? 10.0 : 10000.0;
    final cts = c.prices.map((p) => p / divisor).toList(growable: false);

    if (cts.isEmpty) {
      return EnergyPrices(
        points: const [],
        resolution: Duration(seconds: res),
        currency: c.currency.isNotEmpty ? c.currency : 'EUR',
        stale: c.stale,
        minCt: 0, maxCt: 0, avgCt: 0,
      );
    }

    final minCt = cts.reduce((a, b) => a < b ? a : b);
    final maxCt = cts.reduce((a, b) => a > b ? a : b);
    final avgCt = cts.reduce((a, b) => a + b) / cts.length;

    // Tercile thresholds over the covered window → cheap / normal / expensive.
    final sorted = [...cts]..sort();
    final loCut = sorted[(sorted.length / 3).floor().clamp(0, sorted.length - 1)];
    final hiCut = sorted[(sorted.length * 2 / 3).floor().clamp(0, sorted.length - 1)];

    PriceLevel levelOf(double ct) {
      if (ct <= loCut) return PriceLevel.cheap;
      if (ct >= hiCut) return PriceLevel.expensive;
      return PriceLevel.normal;
    }

    final points = <PricePoint>[
      for (var i = 0; i < cts.length; i++)
        PricePoint(
          time: DateTime.fromMillisecondsSinceEpoch((start + i * res) * 1000),
          ctPerKwh: cts[i],
          level: levelOf(cts[i]),
        ),
    ];

    return EnergyPrices(
      points: points,
      resolution: Duration(seconds: res),
      currency: c.currency.isNotEmpty ? c.currency : 'EUR',
      stale: c.stale,
      minCt: minCt,
      maxCt: maxCt,
      avgCt: avgCt,
    );
  }
}
