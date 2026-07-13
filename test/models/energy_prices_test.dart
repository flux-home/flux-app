import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/energy_history.dart';
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

    test('consumptionCostCents values each bucket at its covering price', () {
      // Price: 20 ct/kWh for a full hour starting at T.
      final prices = EnergyPrices.fromProto($proto.PriceCurve(
        startEpoch: Int64(1_000_000),
        resolutionSeconds: 3600,
        unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
        prices: [200000],
      ));
      // Consumption: one 15-min bucket importing 250 Wh = 1000 W avg = 0.25 kWh
      // (whole-home consumption from the balance = import here).
      final history = EnergyHistoryData.fromProto($proto.EnergyHistory(
        start: Int64(1_000_000),
        bucketSeconds: 900,
        buckets: [$proto.EnergyBucket(index: 0, gridImportWh: 250)],
      ));
      // 0.25 kWh × 20 ct/kWh = 5 ct.
      expect(prices.consumptionCostCents(history), closeTo(5.0, 0.001));
      // No history → null.
      expect(prices.consumptionCostCents(null), isNull);
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
