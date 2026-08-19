import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/energy_flow.dart';
import 'package:matter_home/models/energy_summary.dart';

/// The attribution is the story the Energy screen tells, so it is pinned here
/// rather than left to whatever the widget happens to render.
void main() {
  _netFlowTests();
  group('attributeEnergy', () {
    test('solar covers the house first, then appliances, then the battery', () {
      // 6.2 kW of sun: 0.9 house + 1.4 heat pump + 3.6 car + 0.3 into battery.
      const s = EnergySummary(
        pvProduction: 6200, heatPump: 1400, carCharging: 3600,
        batteryCharge: 300, pvCount: 1, heatPumpCount: 1, carCount: 1,
        batteryCount: 1,
      );
      final t = attributeEnergy(s);

      expect(t.map((e) => '${e.from.name}->${e.to.name}'), [
        'solar->restOfHome', 'solar->heatPump', 'solar->car', 'solar->battery',
      ]);
      expect(t.last.watts, closeTo(300, 0.01));
    });

    test('a load split across two sources produces one row each', () {
      // Evening: battery 1.2 kW + grid 2.1 kW carrying 1.1 house + 2.2 heat pump.
      // The battery is spent before the grid, so it covers the house and part
      // of the heat pump — which is exactly the two-row answer we want.
      const s = EnergySummary(
        gridImport: 2100, batteryDischarge: 1200, heatPump: 2200,
        gridCount: 1, batteryCount: 1, heatPumpCount: 1,
      );
      final t = attributeEnergy(s);

      expect(t.length, 3);
      expect(t[0].from, EnergyEndpoint.battery);
      expect(t[0].to, EnergyEndpoint.restOfHome);
      expect(t[1].from, EnergyEndpoint.battery);
      expect(t[1].to, EnergyEndpoint.heatPump);
      expect(t[2].from, EnergyEndpoint.grid);
      expect(t[2].to, EnergyEndpoint.heatPump);
      // Nothing invented, nothing lost.
      expect(t.fold<double>(0, (a, e) => a + e.watts), closeTo(3300, 0.01));
    });

    test('export is served last, so the house is covered before the grid', () {
      const s = EnergySummary(
        pvProduction: 3000, gridExport: 2000, pvCount: 1, gridCount: 1,
      );
      final t = attributeEnergy(s);
      expect(t.map((e) => e.to), [EnergyEndpoint.restOfHome, EnergyEndpoint.grid]);
      expect(t.last.watts, closeTo(2000, 0.01));
    });

    test('a trickle is not worth a row of its own', () {
      const s = EnergySummary(pvProduction: 5, pvCount: 1);
      expect(attributeEnergy(s), isEmpty);
    });

    test('no roles assigned means nothing to attribute', () {
      expect(attributeEnergy(const EnergySummary()), isEmpty);
    });
  });
}

/// The behaviour that makes a zero-feed-in house readable: the grid sits at
/// zero instead of flipping sign every few seconds.
void _netFlowTests() {
  group('netFlow', () {
    test('a house regulating to zero reads balanced, whichever way it leans', () {
      for (final w in [5.0, 20.0, 39.0]) {
        expect(netFlow(consuming: w, supplying: 0), 0, reason: '+${w}W');
        expect(netFlow(consuming: 0, supplying: w), 0, reason: '-${w}W');
      }
    });

    test('a real flow keeps its sign and its magnitude', () {
      expect(netFlow(consuming: 0, supplying: 900), -900);
      expect(netFlow(consuming: 1200, supplying: 0), 1200);
    });

    test('the band applies to the NET, not to either side alone', () {
      // Importing and exporting at once is measurement skew, not two flows.
      expect(netFlow(consuming: 1010, supplying: 1000), 0);
    });
  });
}
