import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/models/energy_summary.dart';

/// The battery belongs on both sides of the energy balance. These pin the two
/// figures a house with storage is judged by, because both were wrong before the
/// per-bucket battery data was used.
void main() {
  _homeConsumerTests();

  EnergyHistoryPoint p({
    double pv = 0, double imp = 0, double exp = 0,
    double chg = 0, double dis = 0,
  }) =>
      EnergyHistoryPoint(
        time: DateTime.utc(2026, 8, 20, 12),
        pvW: pv, gridImportW: imp, gridExportW: exp, loadW: 0,
        batteryChargeW: chg, batteryDischargeW: dis,
      );

  group('consumptionW', () {
    test('midday: charging the battery is not consumption by the house', () {
      // 6 kW of sun: 1 kW used, 2 kW into the battery, 3 kW exported.
      final x = p(pv: 6000, chg: 2000, exp: 3000);
      expect(x.consumptionW, closeTo(1000, 0.01));
    });

    test('evening: discharging the battery IS supply to the house', () {
      // No sun. 1.6 kW of load carried by 0.9 kW battery + 0.7 kW grid.
      final x = p(imp: 700, dis: 900);
      expect(x.consumptionW, closeTo(1600, 0.01));
    });

    test('ignoring the battery goes wrong in BOTH directions', () {
      // The old formula was pv + import - export. Midday it over-read by the
      // charge; evening it under-read by the discharge.
      final midday = p(pv: 6000, chg: 2000, exp: 3000);
      final evening = p(imp: 700, dis: 900);
      final oldMidday = midday.pvW + midday.gridImportW - midday.gridExportW;
      final oldEvening = evening.pvW + evening.gridImportW - evening.gridExportW;
      expect(oldMidday, greaterThan(midday.consumptionW)); // 3000 vs 1000
      expect(oldEvening, lessThan(evening.consumptionW));  //  700 vs 1600
    });

    test('never negative', () {
      expect(p(exp: 500).consumptionW, 0);
    });
  });

  group('selfSuppliedW', () {
    test('a stored kWh is credited when used, not when generated', () {
      // Charging: the 2 kW going into the battery is not self-supply yet.
      final charging = p(pv: 6000, chg: 2000, exp: 3000);
      expect(charging.selfSuppliedW, closeTo(1000, 0.01));

      // Discharging that same energy later: now it counts, and it is the whole
      // of what the house did not buy.
      final discharging = p(dis: 2000);
      expect(discharging.selfSuppliedW, closeTo(2000, 0.01));
    });

    test('equals consumption minus what was bought', () {
      final x = p(pv: 4000, imp: 300, exp: 1000, dis: 200, chg: 500);
      expect(x.selfSuppliedW, closeTo(x.consumptionW - x.gridImportW, 0.01));
    });

    test('exporting everything self-supplies nothing', () {
      expect(p(pv: 3000, exp: 3000).selfSuppliedW, 0);
    });
  });
}

/// A Home Consumer explains part of the house total; it must never add to it.
void _homeConsumerTests() {
  group('EnergySummary home consumers', () {
    test('a labelled consumer moves power out of the remainder, not into the total', () {
      // House drawing 1000 W from the grid, of which 400 W is a labelled device.
      const withoutLabel = EnergySummary(gridImport: 1000, gridCount: 1);
      const withLabel = EnergySummary(
        gridImport: 1000, gridCount: 1,
        homeConsumers: 400, homeConsumerCount: 1,
      );
      // The house load is unchanged — labelling explains, it does not consume.
      expect(withLabel.houseLoad, withoutLabel.houseLoad);
      // And the unattributed remainder shrinks by exactly the labelled amount.
      expect(withLabel.restOfHome, closeTo(withoutLabel.restOfHome - 400, 0.01));
    });

    test('labelling everything leaves no remainder, and never a negative one', () {
      const s = EnergySummary(
        gridImport: 500, gridCount: 1,
        homeConsumers: 900, homeConsumerCount: 2,   // over-attributed (meter skew)
      );
      expect(s.restOfHome, 0);
    });

    test('a home consumer alone still counts as having a role', () {
      const s = EnergySummary(homeConsumers: 120, homeConsumerCount: 1);
      expect(s.hasAnyRole, isTrue);
      expect(s.hasHomeConsumers, isTrue);
    });
  });
}
