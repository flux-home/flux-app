import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/services/energy_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The cache exists to avoid re-learning finished facts. These pin the two
/// properties that make that safe: a re-fetch corrects a bucket rather than
/// being ignored, and a round trip through storage changes nothing.
void main() {
  _mergeKeepsContext();

  test('per-battery levels survive a row round trip', () {
    const row = EnergyBucketRow(
      epoch: 1000, pvWh: 1, importWh: 2, exportWh: 3,
      loadWh: 4, chargeWh: 5, dischargeWh: 6,
      socPct: 58,                       // the legacy mean
      socs: {0x1A: 73, 0x1C: 44},       // what actually happened
    );
    final back = EnergyBucketRow.decode(row.encode())!;
    expect(back.socs, {0x1A: 73, 0x1C: 44});
    expect(back.socPct, 58);
  });

  test('a row written before the per-battery column still decodes', () {
    // Exactly what the old encoder produced: ten columns, no levels map.
    final back = EnergyBucketRow.decode('1000,1,2,3,4,5,6,58,,')!;
    expect(back.socPct, 58);
    expect(back.socs, isEmpty);
  });

  test('no batteries encodes an empty column rather than junk', () {
    const row = EnergyBucketRow(
      epoch: 1000, pvWh: 0, importWh: 0, exportWh: 0,
      loadWh: 0, chargeWh: 0, dischargeWh: 0,
    );
    expect(EnergyBucketRow.decode(row.encode())!.socs, isEmpty);
  });
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

/// A refetch must not erase what was captured while the bucket was live.
///
/// The live forecast window moves forward through the day, so a bucket fetched
/// again in the evening comes back with no forecast for the morning — and the
/// morning is exactly the part of the sun line that went missing.
void _mergeKeepsContext() {
  test('merge keeps a captured forecast when the refetch has none', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = EnergyCache(await SharedPreferences.getInstance());

    const base = EnergyBucketRow(
      epoch: 1000, pvWh: 10, importWh: 0, exportWh: 0,
      loadWh: 5, chargeWh: 0, dischargeWh: 0,
    );

    await cache.merge([base.withContext(forecastWh: 3194, spotUeur: 1200)]);
    // The same bucket, measured again, with no forecast or price this time.
    final after = await cache.merge([base]);

    expect(after[1000]!.forecastWh, 3194);
    expect(after[1000]!.spotUeur, 1200);
    // Measurements still take the newer value.
    expect(after[1000]!.pvWh, 10);
  });

  test('a newer forecast still replaces an older one', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = EnergyCache(await SharedPreferences.getInstance());
    const base = EnergyBucketRow(
      epoch: 2000, pvWh: 0, importWh: 0, exportWh: 0,
      loadWh: 0, chargeWh: 0, dischargeWh: 0,
    );
    await cache.merge([base.withContext(forecastWh: 100)]);
    final after = await cache.merge([base.withContext(forecastWh: 250)]);
    expect(after[2000]!.forecastWh, 250);
  });
}
