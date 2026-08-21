import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/services/energy_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The cache exists to avoid re-learning finished facts. These pin the two
/// properties that make that safe: a re-fetch corrects a bucket rather than
/// being ignored, and a round trip through storage changes nothing.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  EnergyBucketRow row(int epoch, {int pv = 0, int imp = 0, int? soc}) =>
      EnergyBucketRow(epoch: epoch, pvWh: pv, importWh: imp, exportWh: 0,
          loadWh: 0, chargeWh: 0, dischargeWh: 0, socPct: soc);

  test('a re-fetched bucket overwrites the cached one', () async {
    final cache = EnergyCache(await SharedPreferences.getInstance());
    await cache.merge([row(1000, pv: 100)]);
    final merged = await cache.merge([row(1000, pv: 250)]);
    expect(merged[1000]!.pvWh, 250);
  });

  test('survives encode/decode unchanged, including a null charge level',
      () async {
    final cache = EnergyCache(await SharedPreferences.getInstance());
    await cache.merge([row(2000, pv: 7, imp: 3, soc: 64), row(2001)]);
    final back = EnergyCache(await SharedPreferences.getInstance()).load();
    expect(back[2000]!.pvWh, 7);
    expect(back[2000]!.importWh, 3);
    expect(back[2000]!.socPct, 64);
    expect(back[2001]!.socPct, isNull);   // absent, not zero
  });

  test('keeps the newest buckets when it overflows', () async {
    final cache = EnergyCache(await SharedPreferences.getInstance());
    // 24*45 is the cap; push past it and the oldest must go, not the newest.
    await cache.merge([for (var i = 0; i < 24 * 45 + 50; i++) row(i * 3600)]);
    final rows = cache.load();
    expect(rows.length, 24 * 45);
    expect(rows.containsKey(0), isFalse);
    expect(rows.containsKey((24 * 45 + 49) * 3600), isTrue);
  });

  test('newestEnd is the end of the last bucket, not its start', () async {
    final cache = EnergyCache(await SharedPreferences.getInstance());
    final rows = await cache.merge([row(0), row(3600)]);
    final end = cache.newestEnd(rows, const Duration(hours: 1))!;
    expect(end.toUtc().millisecondsSinceEpoch ~/ 1000, 7200);
  });

  test('rows rebuild a window that matches what was cached', () {
    final data = EnergyHistoryData.fromRows(
      [row(0, pv: 1000, imp: 200, soc: 50), row(3600, pv: 2000, soc: 60)],
      bucket: const Duration(hours: 1),
    );
    expect(data.points.length, 2);
    expect(data.pvKwh, closeTo(3.0, 0.001));
    expect(data.gridImportKwh, closeTo(0.2, 0.001));
    expect(data.socPerBucket, [50.0, 60.0]);
    // An hourly bucket of 1000 Wh is a mean of 1000 W.
    expect(data.points.first.pvW, closeTo(1000, 0.01));
  });

  test('a window survives a cache round trip byte for byte', () {
    final original = EnergyHistoryData.fromRows(
      [row(0, pv: 1234, imp: 56, soc: 41)],
      bucket: const Duration(hours: 1),
    );
    final again = EnergyHistoryData.fromRows(original.toRows(),
        bucket: const Duration(hours: 1));
    expect(again.pvKwh, original.pvKwh);
    expect(again.gridImportKwh, original.gridImportKwh);
    expect(again.socPerBucket, original.socPerBucket);
  });
}
