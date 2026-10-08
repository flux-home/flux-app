import 'package:flutter/foundation.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/energy_role.dart';

/// Live, whole-home energy picture aggregated by [EnergyRole].
///
/// Computed from the current [DeviceView]s by [EnergySummary.fromDevices].
/// All power fields are **watts** (Matter reports milliwatts; we convert).
///
/// Sign convention — positive = power flowing *into* the house node:
///   • grid:    `activePower > 0` = importing (buying);  `< 0` = exporting.
///   • battery: `activePower > 0` = charging (load);     `< 0` = discharging.
///   • pv / car / heatpump: magnitude only (PV always produces, the two
///     consumers always consume).
///
/// Multiple devices may carry the same role; their power is summed.
@immutable
/// One home battery's own level and flow, so a house with two stores can show
/// them as two facts rather than one mean of the two.
@immutable
class BatteryState {
  const BatteryState({
    required this.nodeId,
    required this.name,
    required this.netW,
    this.socPercent,
  });

  final int nodeId;
  final String name;

  /// Positive = charging, negative = discharging. Same sign convention as the
  /// combined [EnergySummary.batteryCharge] / [EnergySummary.batteryDischarge]
  /// pair, so a per-battery note cannot contradict the aggregate bar.
  final double netW;

  final int? socPercent;
}

class EnergySummary {
  const EnergySummary({
    this.gridImport = 0,
    this.gridExport = 0,
    this.pvProduction = 0,
    this.batteryCharge = 0,
    this.batteryDischarge = 0,
    this.batterySocPercent,
    this.batteries = const [],
    this.carSocPercent,
    this.carCharging = 0,
    this.heatPump = 0,
    this.homeConsumers = 0,
    this.gridCount = 0,
    this.pvCount = 0,
    this.batteryCount = 0,
    this.carCount = 0,
    this.heatPumpCount = 0,
    this.homeConsumerCount = 0,
  });

  final double gridImport;       // W drawn from the grid
  final double gridExport;       // W pushed to the grid
  final double pvProduction;     // W produced by PV
  final double batteryCharge;    // W flowing into the battery
  final double batteryDischarge; // W flowing out of the battery
  /// Charge level of the home battery, averaged across battery devices.
  ///
  /// An UNWEIGHTED mean, and therefore only meaningful with one battery: two
  /// packs at 73% and 44% read 59% here, which is neither of them and is not
  /// the house's actual stored fraction either (that needs capacities nothing
  /// records). Kept for the single-battery case; [batteries] is what a house
  /// with more than one should show.
  final int?   batterySocPercent;

  /// Every home battery separately, in device order.
  final List<BatteryState> batteries;

  /// Charge level of the car, when a wallbox reports it. Same mechanism as the
  /// home battery (a `batPercentRaw` attribute on the car-charger device), so a
  /// wallbox that publishes the vehicle's level needs no further plumbing —
  /// and one that does not simply leaves this null and the gauge hidden.
  final int?   carSocPercent;
  final double carCharging;      // W consumed by car chargers
  final double heatPump;         // W consumed by heat pumps

  /// Sum of devices marked as a measured part of the house load. Attribution,
  /// not a flow: already inside [houseLoad], so it is subtracted from
  /// [restOfHome] rather than added anywhere.
  final double homeConsumers;

  // How many devices are tagged with each role (drives which nodes render).
  final int gridCount;
  final int pvCount;
  final int batteryCount;
  final int carCount;
  final int heatPumpCount;
  final int homeConsumerCount;

  bool get hasGrid    => gridCount    > 0;
  bool get hasPv      => pvCount      > 0;
  bool get hasBattery => batteryCount > 0;
  bool get hasCar     => carCount     > 0;
  bool get hasHeatPump => heatPumpCount > 0;
  bool get hasHomeConsumers => homeConsumerCount > 0;

  /// True when at least one device carries an energy role — gates the overview.
  bool get hasAnyRole =>
      hasGrid || hasPv || hasBattery || hasCar || hasHeatPump || hasHomeConsumers;

  /// Total power the house is consuming right now (energy balance):
  /// production + imports + battery discharge − exports − battery charge.
  double get houseLoad =>
      pvProduction + gridImport + batteryDischarge - gridExport - batteryCharge;

  /// Consumption not attributed to a monitored consumer role (the "rest of
  /// home" node).  Clamped at 0 — a negative value just means the monitored
  /// consumers exceed the computed balance (measurement skew).
  /// The house's draw excluding the two named *assets* (car, heat pump) but
  /// still including whatever the user has labelled as house consumers.
  ///
  /// This is what a balance view wants: assets get their own rows, and everything
  /// else is one "home" figure. [restOfHome] is the wrong number there — it also
  /// removes labelled consumers, so a balance built on it develops a hole as soon
  /// as a device is named.
  double get homeExcludingAssets {
    final v = houseLoad - carCharging - heatPump;
    return v > 0 ? v : 0;
  }

  double get restOfHome {
    final rest = houseLoad - carCharging - heatPump - homeConsumers;
    return rest > 0 ? rest : 0;
  }

  /// Folds the current device views into a summary. Devices without a role
  /// (or without live power) contribute nothing to the sums but a tagged
  /// device still counts toward node presence.
  factory EnergySummary.fromDevices(Iterable<DeviceView> devices) {
    double gridNet = 0, pv = 0, batNet = 0, car = 0, heat = 0, consumers = 0;
    var gridN = 0, pvN = 0, batN = 0, carN = 0, heatN = 0, consumerN = 0;
    var socSum = 0, socCount = 0;
    final batteries = <BatteryState>[];
    var carSocSum = 0, carSocCount = 0;

    for (final d in devices) {
      // Skip devices whose reading isn't current — it must not be presented as
      // a live value in the overview.
      //
      // Reachability alone is not enough. A Modbus inverter whose server has
      // stopped answering still counts as reachable: the controller polls it
      // rather than subscribing, so nothing fails in a way `isOnline` sees. Its
      // last reading then sat in the overview as live solar — a steady 6.5 kW
      // the roof was not making.
      if (!d.isOnline || d.isStale) continue;
      final w = (d.activePowerMw ?? 0) / 1000.0;
      switch (d.energyRole) {
        // A plain consumer with no more specific role. It contributes no
        // dedicated node: its draw is already inside the energy balance, so it
        // lands in `restOfHome`. Adding it anywhere here would double-count.
        // (Stacked case labels share a body in Dart — this used to sit on top
        // of `grid`, which silently counted a consumer as grid import.)
        case EnergyRole.load:
          break;
        case EnergyRole.grid:
          gridNet += w;
          gridN++;
        case EnergyRole.pv:
          pv += w.abs();
          pvN++;
        case EnergyRole.homeBattery:
          batNet += w;
          batN++;
          final soc = d.batteryPercent;
          if (soc != null) { socSum += soc; socCount++; }
          batteries.add(BatteryState(
            nodeId: d.nodeId, name: d.name, netW: w, socPercent: soc));
        case EnergyRole.homeConsumer:
          // Attribution only — see [homeConsumers]. Summed so it can be taken
          // OUT of the unattributed remainder, never added to the balance.
          consumers += w.abs();
          consumerN++;
        case EnergyRole.carCharger:
          car += w.abs();
          carN++;
          final carSoc = d.batteryPercent;
          if (carSoc != null) { carSocSum += carSoc; carSocCount++; }
        case EnergyRole.heatPump:
          heat += w.abs();
          heatN++;
        case EnergyRole.none:
          break;
      }
    }

    return EnergySummary(
      gridImport:       gridNet > 0 ? gridNet : 0,
      gridExport:       gridNet < 0 ? -gridNet : 0,
      pvProduction:     pv,
      batteryCharge:    batNet > 0 ? batNet : 0,
      batteryDischarge: batNet < 0 ? -batNet : 0,
      batterySocPercent: socCount > 0 ? (socSum / socCount).round() : null,
      batteries:        batteries,
      carSocPercent: carSocCount > 0 ? (carSocSum / carSocCount).round() : null,
      carCharging:      car,
      heatPump:         heat,
      homeConsumers:    consumers,
      gridCount:        gridN,
      pvCount:          pvN,
      batteryCount:     batN,
      carCount:         carN,
      heatPumpCount:    heatN,
      homeConsumerCount: consumerN,
    );
  }
}
