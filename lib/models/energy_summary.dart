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
class EnergySummary {
  const EnergySummary({
    this.gridImport = 0,
    this.gridExport = 0,
    this.pvProduction = 0,
    this.batteryCharge = 0,
    this.batteryDischarge = 0,
    this.batterySocPercent,
    this.carCharging = 0,
    this.heatPump = 0,
    this.gridCount = 0,
    this.pvCount = 0,
    this.batteryCount = 0,
    this.carCount = 0,
    this.heatPumpCount = 0,
  });

  final double gridImport;       // W drawn from the grid
  final double gridExport;       // W pushed to the grid
  final double pvProduction;     // W produced by PV
  final double batteryCharge;    // W flowing into the battery
  final double batteryDischarge; // W flowing out of the battery
  final int?   batterySocPercent;
  final double carCharging;      // W consumed by car chargers
  final double heatPump;         // W consumed by heat pumps

  // How many devices are tagged with each role (drives which nodes render).
  final int gridCount;
  final int pvCount;
  final int batteryCount;
  final int carCount;
  final int heatPumpCount;

  bool get hasGrid    => gridCount    > 0;
  bool get hasPv      => pvCount      > 0;
  bool get hasBattery => batteryCount > 0;
  bool get hasCar     => carCount     > 0;
  bool get hasHeatPump => heatPumpCount > 0;

  /// True when at least one device carries an energy role — gates the overview.
  bool get hasAnyRole =>
      hasGrid || hasPv || hasBattery || hasCar || hasHeatPump;

  /// Total power the house is consuming right now (energy balance):
  /// production + imports + battery discharge − exports − battery charge.
  double get houseLoad =>
      pvProduction + gridImport + batteryDischarge - gridExport - batteryCharge;

  /// Consumption not attributed to a monitored consumer role (the "rest of
  /// home" node).  Clamped at 0 — a negative value just means the monitored
  /// consumers exceed the computed balance (measurement skew).
  double get restOfHome {
    final rest = houseLoad - carCharging - heatPump;
    return rest > 0 ? rest : 0;
  }

  /// Folds the current device views into a summary. Devices without a role
  /// (or without live power) contribute nothing to the sums but a tagged
  /// device still counts toward node presence.
  factory EnergySummary.fromDevices(Iterable<DeviceView> devices) {
    double gridNet = 0, pv = 0, batNet = 0, car = 0, heat = 0;
    var gridN = 0, pvN = 0, batN = 0, carN = 0, heatN = 0;
    var socSum = 0, socCount = 0;

    for (final d in devices) {
      // Skip unreachable devices — their last-known reading isn't current, so
      // it must not be presented as a live value in the overview.
      if (!d.isOnline) continue;
      final w = (d.activePowerMw ?? 0) / 1000.0;
      switch (d.energyRole) {
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
        case EnergyRole.carCharger:
          car += w.abs();
          carN++;
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
      carCharging:      car,
      heatPump:         heat,
      gridCount:        gridN,
      pvCount:          pvN,
      batteryCount:     batN,
      carCount:         carN,
      heatPumpCount:    heatN,
    );
  }
}
