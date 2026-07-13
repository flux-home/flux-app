import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;

void main() {
  group('EnergyHistoryData.fromProto', () {
    test('converts Wh buckets to average watts and sums kWh totals', () {
      // 15-min buckets → a full-bucket 250 Wh = 1000 W average.
      final h = $proto.EnergyHistory(
        start: Int64(1_000_000),
        bucketSeconds: 900,
        timeSynced: true,
        buckets: [
          $proto.EnergyBucket(index: 0, pvWh: 250, loadWh: 125),
          $proto.EnergyBucket(index: 1, gridImportWh: 250, gridExportWh: 0),
        ],
      );

      final d = EnergyHistoryData.fromProto(h);

      expect(d.points.length, 2);
      // 250 Wh over a 900 s bucket = 1000 W average.
      expect(d.points[0].pvW, closeTo(1000, 0.001));
      expect(d.points[0].loadW, closeTo(500, 0.001));
      expect(d.points[1].gridImportW, closeTo(1000, 0.001));

      // Bucket 1 sits 900 s after bucket 0.
      expect(d.points[1].time.difference(d.points[0].time),
          const Duration(seconds: 900));

      // Totals in kWh.
      expect(d.pvKwh, closeTo(0.250, 0.0001));
      expect(d.loadKwh, closeTo(0.125, 0.0001));
      expect(d.gridImportKwh, closeTo(0.250, 0.0001));
      expect(d.peakW, closeTo(1000, 0.001));
    });

    test('self-sufficiency: none imported → 100%, all imported → 0%', () {
      // All consumption from own PV (no import) → 100%.
      final selfSufficient = EnergyHistoryData.fromProto($proto.EnergyHistory(
        bucketSeconds: 900,
        buckets: [$proto.EnergyBucket(index: 0, pvWh: 400)],
      ));
      expect(selfSufficient.consumptionKwh, closeTo(0.4, 0.0001));
      expect(selfSufficient.selfSufficiencyPercent, 100);

      // All consumption from the grid (no generation) → 0%.
      final fromGrid = EnergyHistoryData.fromProto($proto.EnergyHistory(
        bucketSeconds: 900,
        buckets: [$proto.EnergyBucket(index: 0, gridImportWh: 400)],
      ));
      expect(fromGrid.consumptionKwh, closeTo(0.4, 0.0001));
      expect(fromGrid.selfSufficiencyPercent, 0);
    });

    test('consumption + self-sufficiency use the energy balance', () {
      // Generated 1000, exported 600, imported 200, battery charge 100:
      //   consumption = 1000 + 200 + 0 − 600 − 100 = 500 Wh
      //   self-consumed = 500 − 200 = 300 → 60%.
      final d = EnergyHistoryData.fromProto($proto.EnergyHistory(
        bucketSeconds: 900,
        buckets: [
          $proto.EnergyBucket(
            index: 0,
            pvWh: 1000,
            gridExportWh: 600,
            gridImportWh: 200,
            batteryChargeWh: 100,
          ),
        ],
      ));
      expect(d.consumptionKwh, closeTo(0.5, 0.0001));
      expect(d.selfSufficiencyPercent, 60);
    });

    test('per-PV device series decode: aligned watts, totals, and names', () {
      final h = $proto.EnergyHistory(
        start: Int64(1_000_000),
        bucketSeconds: 900,
        buckets: [
          $proto.EnergyBucket(index: 0, pvWh: 500),
          $proto.EnergyBucket(index: 1, pvWh: 250),
        ],
        deviceSeries: [
          $proto.EnergyDeviceSeries(
            nodeId: Int64(0x0100000000000002),
            cls: $proto.EnergyClass.ENERGY_CLASS_PV,
            name: 'Roof East',
            wh: [250, 250], // 250 Wh/bucket = 1000 W avg
          ),
          $proto.EnergyDeviceSeries(
            nodeId: Int64(0x0100000000000003),
            cls: $proto.EnergyClass.ENERGY_CLASS_PV,
            name: 'Roof West',
            wh: [250, 0],
          ),
        ],
      );

      final d = EnergyHistoryData.fromProto(h);
      expect(d.hasPvBreakdown, isTrue);
      expect(d.pvSeries.map((s) => s.name), ['Roof East', 'Roof West']);
      expect(d.pvSeries[0].wattsPerBucket, [closeTo(1000, 0.001), closeTo(1000, 0.001)]);
      expect(d.pvSeries[1].wattsPerBucket, [closeTo(1000, 0.001), 0]);
      expect(d.pvSeries[0].kwh, closeTo(0.5, 0.0001));
      expect(d.pvSeries[1].kwh, closeTo(0.25, 0.0001));
      // Per-device series sum matches the summed PV total.
      expect(d.pvSeries.fold<double>(0, (a, s) => a + s.kwh),
          closeTo(d.pvKwh, 0.0001));
    });

    test('no device_series → no breakdown (older firmware)', () {
      final d = EnergyHistoryData.fromProto($proto.EnergyHistory(
        bucketSeconds: 900,
        buckets: [$proto.EnergyBucket(index: 0, pvWh: 100)],
      ));
      expect(d.hasPvBreakdown, isFalse);
      expect(d.pvSeries, isEmpty);
    });

    test('no consumption → null self-sufficiency, empty history is empty', () {
      // Everything generated was exported → zero net consumption → null.
      final none = EnergyHistoryData.fromProto($proto.EnergyHistory(
        bucketSeconds: 900,
        buckets: [$proto.EnergyBucket(index: 0, pvWh: 100, gridExportWh: 100)],
      ));
      expect(none.consumptionKwh, 0);
      expect(none.selfSufficiencyPercent, isNull);

      final empty = EnergyHistoryData.fromProto($proto.EnergyHistory());
      expect(empty.isEmpty, isTrue);
      expect(empty.peakW, 0);
    });
  });
}
