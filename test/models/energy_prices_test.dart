import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/energy_prices.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'package:matter_home/services/proto/flux.pbenum.dart' as $enum;

void main() {
  group('EnergyPrices.fromProto', () {
    test('converts µEUR/kWh to ct/kWh, times, and stats', () {
      // 200000 µEUR/kWh = 20 ct/kWh; hourly.
      final c = $proto.PriceCurve(
        startEpoch: Int64(1_000_000),
        resolutionSeconds: 3600,
        currency: 'EUR',
        unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
        prices: [100000, 200000, 300000], // 10, 20, 30 ct/kWh
      );
      final p = EnergyPrices.fromProto(c);

      expect(p.points.length, 3);
      expect(p.points[0].ctPerKwh, closeTo(10, 0.001));
      expect(p.points[2].ctPerKwh, closeTo(30, 0.001));
      expect(p.points[1].time.difference(p.points[0].time),
          const Duration(hours: 1));
      expect(p.minCt, closeTo(10, 0.001));
      expect(p.maxCt, closeTo(30, 0.001));
      expect(p.avgCt, closeTo(20, 0.001));
    });

    test('tercile bands: cheapest→cheap, dearest→expensive', () {
      final c = $proto.PriceCurve(
        resolutionSeconds: 3600,
        unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
        prices: [50000, 100000, 150000, 200000, 250000, 300000],
      );
      final p = EnergyPrices.fromProto(c);
      expect(p.points.first.level, PriceLevel.cheap);
      expect(p.points.last.level, PriceLevel.expensive);
    });

    test('negative prices convert and stay negative', () {
      final c = $proto.PriceCurve(
        resolutionSeconds: 3600,
        unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
        prices: [-50000, 100000], // -5, 10 ct/kWh
      );
      final p = EnergyPrices.fromProto(c);
      expect(p.points[0].ctPerKwh, closeTo(-5, 0.001));
      expect(p.minCt, closeTo(-5, 0.001));
    });

    test('currentAt picks the covering interval', () {
      final c = $proto.PriceCurve(
        startEpoch: Int64(1_000_000),
        resolutionSeconds: 3600,
        unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
        prices: [100000, 200000],
      );
      final p = EnergyPrices.fromProto(c);
      // 30 min into the second interval.
      final t = DateTime.fromMillisecondsSinceEpoch((1_000_000 + 3600 + 1800) * 1000);
      expect(p.currentAt(t)!.ctPerKwh, closeTo(20, 0.001));
    });

    test('empty curve is empty', () {
      final p = EnergyPrices.fromProto($proto.PriceCurve());
      expect(p.isEmpty, isTrue);
    });
  });
}
