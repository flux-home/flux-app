import 'package:flutter/material.dart';

/// The role an energy-measuring device plays in the home's energy flow.
///
/// Assigned by the user on the device settings screen (only for devices whose
/// [DeviceType.hasEnergyMeasurement] is true) and stored on [MatterDevice] as
/// [MatterDevice.energyRole] — the same shape as room assignment.  The home
/// screen aggregates live power by role to draw the energy-flow overview.
///
/// [none] means "not part of the energy overview".  Multiple devices may share
/// the same role (e.g. two PV inverters); their power is summed.
enum EnergyRole {
  none,
  grid,
  pv,
  carCharger,
  heatPump,
  homeBattery;

  /// Human-readable label for pickers and the overview.
  String get label => switch (this) {
        EnergyRole.none        => 'Unassigned',
        EnergyRole.grid        => 'Grid',
        EnergyRole.pv          => 'Solar PV',
        EnergyRole.carCharger  => 'Car Charger',
        EnergyRole.heatPump    => 'Heat Pump',
        EnergyRole.homeBattery => 'Home Battery',
      };

  IconData get icon => switch (this) {
        EnergyRole.none        => Icons.help_outline,
        EnergyRole.grid        => Icons.bolt_outlined,
        EnergyRole.pv          => Icons.solar_power_outlined,
        EnergyRole.carCharger  => Icons.ev_station_outlined,
        EnergyRole.heatPump    => Icons.heat_pump_outlined,
        EnergyRole.homeBattery => Icons.battery_charging_full_outlined,
      };

  /// The controller's energy-log class code for this role (mirrors
  /// flux_EnergyClass: 1=grid, 2=pv, 3=load, 4=battery). Consumers and the two
  /// tracked consumer roles both map to `load` (the log only distinguishes
  /// grid/pv/load/battery). `none` → null (no override; clears it controller-side).
  int? get controllerClass => switch (this) {
        EnergyRole.grid        => 1,
        EnergyRole.pv          => 2,
        EnergyRole.carCharger  => 3,
        EnergyRole.heatPump    => 3,
        EnergyRole.homeBattery => 4,
        EnergyRole.none        => null,
      };

  /// Parses a persisted [name]; unknown or missing values fall back to [none].
  static EnergyRole fromName(String? name) => EnergyRole.values.firstWhere(
        (e) => e.name == name,
        orElse: () => EnergyRole.none,
      );

  /// The roles a user can assign, in display order ([none] last as "clear").
  static const assignable = [grid, pv, carCharger, heatPump, homeBattery, none];
}
