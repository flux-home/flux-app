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

    test('import cost + export revenue over the covered window', () {
      // Price: 20 ct/kWh for a full hour starting at T.
      final prices = EnergyPrices.fromProto($proto.PriceCurve(
        startEpoch: Int64(1_000_000),
        resolutionSeconds: 3600,
        unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
        prices: [200000],
      ));
      // Bucket 0 (priced): import 250 Wh, export 500 Wh. Bucket 4 is one hour
      // later — OUTSIDE the single-hour price coverage — exporting 500 Wh.
      final history = EnergyHistoryData.fromProto($proto.EnergyHistory(
        start: Int64(1_000_000),
        bucketSeconds: 900,
        buckets: [
          $proto.EnergyBucket(index: 0, gridImportWh: 250, gridExportWh: 500),
          $proto.EnergyBucket(index: 4, gridImportWh: 250, gridExportWh: 500),
        ],
      ));
      // Import cost is priced-only: just bucket 0 → 0.25 kWh × 20 ct = 5 ct.
      expect(prices.importCostCents(history), closeTo(5.0, 0.001));
      // Feed-in covers the FULL window (flat rate): (0.5 + 0.5) kWh × 6.7 ct
      // = 6.7 ct — bucket 4 counts even though it has no spot price.
      expect(prices.exportRevenueCents(history, 6.7), closeTo(6.7, 0.001));
      expect(prices.importCostCents(null), isNull);
    });

    test('markup + VAT yield the gross consumer price', () {
      // Spot 11.31 ct/kWh (=113100 µEUR/kWh), + 11.04 ct fees, × 1.19 VAT
      // = 26.60 ct/kWh — matches the awattar bill's Arbeitspreis.
      final p = EnergyPrices.fromProto(
        $proto.PriceCurve(
          resolutionSeconds: 3600,
          unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
          prices: [113100],
        ),
        markupUeurPerKwh: 110400, // 11.04 ct/kWh
        vatPercent: 19,
      );
      expect(p.points.first.ctPerKwh, closeTo(26.60, 0.02));
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

    test('self-consumption saving values pv−export at the hour it happened', () {
      // Two priced hours: 10 ct then 40 ct. Same 1 kWh self-consumed in each,
      // so the saving must be 10 + 40 = 50 ct — NOT 2 × the 25 ct mean applied
      // uniformly. This is the whole reason it's priced per bucket.
      const t0 = 1_000_000;
      final prices = EnergyPrices.fromProto($proto.PriceCurve(
        startEpoch: Int64(t0),
        resolutionSeconds: 3600,
        unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
        prices: [100000, 400000], // 10, 40 ct/kWh
      ));
      // Hourly buckets: 1000 Wh pv, no export → 1 kWh self-consumed per hour.
      final history = EnergyHistoryData.fromProto($proto.EnergyHistory(
        start: Int64(t0),
        bucketSeconds: 3600,
        buckets: [
          $proto.EnergyBucket(index: 0, pvWh: 1000),
          $proto.EnergyBucket(index: 1, pvWh: 1000),
        ],
      ));
      expect(prices.selfConsumptionSavingCents(history), closeTo(50.0, 0.001));
    });

    test('self-consumption saving excludes exported energy', () {
      const t0 = 1_000_000;
      final prices = EnergyPrices.fromProto($proto.PriceCurve(
        startEpoch: Int64(t0),
        resolutionSeconds: 3600,
        unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
        prices: [200000], // 20 ct/kWh
      ));
      // 1000 Wh generated, 750 Wh exported → only 0.25 kWh was self-consumed.
      final history = EnergyHistoryData.fromProto($proto.EnergyHistory(
        start: Int64(t0),
        bucketSeconds: 3600,
        buckets: [$proto.EnergyBucket(index: 0, pvWh: 1000, gridExportWh: 750)],
      ));
      expect(prices.selfConsumptionSavingCents(history), closeTo(5.0, 0.001));

      // Exporting everything saves nothing, and must not go negative.
      final allOut = EnergyHistoryData.fromProto($proto.EnergyHistory(
        start: Int64(t0),
        bucketSeconds: 3600,
        buckets: [$proto.EnergyBucket(index: 0, pvWh: 500, gridExportWh: 900)],
      ));
      expect(prices.selfConsumptionSavingCents(allOut), isNull);
      expect(prices.selfConsumptionSavingCents(null), isNull);
    });

    test('self-consumption saving is worth more than feed-in for the same kWh',
        () {
      // The point of showing both: avoided purchase is valued at the gross
      // consumer price, feed-in at the flat export rate.
      const t0 = 1_000_000;
      final prices = EnergyPrices.fromProto(
        $proto.PriceCurve(
          startEpoch: Int64(t0),
          resolutionSeconds: 3600,
          unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
          prices: [113100], // 11.31 ct spot
        ),
        markupUeurPerKwh: 110400, // + 11.04 ct fees
        vatPercent: 19,           // × 1.19  → 26.60 ct gross
      );
      final history = EnergyHistoryData.fromProto($proto.EnergyHistory(
        start: Int64(t0),
        bucketSeconds: 3600,
        buckets: [$proto.EnergyBucket(index: 0, pvWh: 1000)],
      ));
      final saved = prices.selfConsumptionSavingCents(history)!;
      expect(saved, closeTo(26.60, 0.02));
      // Same 1 kWh fed in at 8.2 ct would earn far less.
      expect(saved, greaterThan(8.2 * 3));
    });

    test('avgCtIn averages only the intervals overlapping the window', () {
      // Four hourly intervals: 10, 20, 30, 40 ct/kWh from T.
      const t0 = 1_000_000;
      final p = EnergyPrices.fromProto($proto.PriceCurve(
        startEpoch: Int64(t0),
        resolutionSeconds: 3600,
        unit: $enum.PriceUnit.PRICE_UNIT_UEUR_PER_KWH,
        prices: [100000, 200000, 300000, 400000],
      ));
      DateTime at(int offsetSeconds) =>
          DateTime.fromMillisecondsSinceEpoch((t0 + offsetSeconds) * 1000);

      // First two hours → Ø 15. Partial overlap counts the interval.
      expect(p.avgCtIn(at(0), at(2 * 3600)), closeTo(15, 0.001));
      expect(p.avgCtIn(at(1800), at(2 * 3600 + 60)), closeTo(20, 0.001));
      // Whole curve.
      expect(p.avgCtIn(at(-9999), at(99999)), closeTo(25, 0.001));
      // No overlap → null, so callers can fall back instead of showing 0.
      expect(p.avgCtIn(at(-7200), at(-3600)), isNull);
    });

    test('empty curve is empty', () {
      final p = EnergyPrices.fromProto($proto.PriceCurve());
      expect(p.isEmpty, isTrue);
    });
  });
}
