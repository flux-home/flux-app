import 'package:flutter/material.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/energy_role.dart';

/// A top-level grouping surfaced as a button row on the home screen (à la Apple
/// Home). Each opens its own [CategoryScreen] — Energy hosts the live
/// energy-flow overview, the others a filtered device grid.
enum HomeCategory {
  energy,
  lighting,
  climate,
  /// Everything the others do not claim — a plug that only switches, a lock, a
  /// button, a sensor with no home elsewhere.
  ///
  /// It exists so the home screen does not have to be a list of leftovers. This
  /// app is about energy; a device that has nothing to do with energy, light or
  /// comfort still has to live somewhere, and somewhere is not the first thing
  /// you see.
  other;

  String get label => switch (this) {
        HomeCategory.energy   => 'Energy',
        HomeCategory.lighting => 'Lighting',
        HomeCategory.climate  => 'Climate',
        HomeCategory.other    => 'Other',
      };

  IconData get icon => switch (this) {
        HomeCategory.energy   => Icons.bolt_outlined,
        HomeCategory.lighting => Icons.lightbulb_outline,
        HomeCategory.climate  => Icons.thermostat_outlined,
        HomeCategory.other    => Icons.widgets_outlined,
      };

  /// Pastel accent for the button outline + text and the category screen title.
  Color get color => switch (this) {
        HomeCategory.energy   => const Color(0xFFE8D66B), // pastel yellow
        HomeCategory.lighting => const Color(0xFFF2B877), // pastel orange
        HomeCategory.climate  => const Color(0xFF8FCDEF), // pastel blue
        HomeCategory.other    => const Color(0xFFB9B6C9), // pastel grey-violet
      };

  /// Whether this category's devices are listed room by room, with the room's
  /// shared controls above each set.
  ///
  /// Lighting, because "everything in here" is a thing people act on and the
  /// controls mean the same across a room. Other, because it is a miscellany
  /// and the only order anyone has for a miscellany is where things are.
  ///
  /// Energy is a dashboard, not a set of controls; Climate wants a room
  /// setpoint rather than a room slider, and gets this once it has one.
  bool get groupsByRoom =>
      this == HomeCategory.lighting || this == HomeCategory.other;

  /// Whether [v] belongs in this category's device grid.
  bool matches(DeviceView v) => switch (this) {
        HomeCategory.energy => v.energyRole != EnergyRole.none ||
            v.deviceType.hasEnergyMeasurement ||
            v.hasLivePower,
        HomeCategory.lighting => v.deviceType.isLight,
        HomeCategory.climate => switch (v.deviceType) {
            DeviceType.thermostat ||
            DeviceType.fan ||
            DeviceType.airPurifier ||
            DeviceType.temperatureSensor ||
            DeviceType.humiditySensor ||
            DeviceType.airQualitySensor => true,
            _ => false,
          },
        // Defined by exclusion, so a device is never in two places at once and
        // a new category automatically empties this one of whatever it claims.
        HomeCategory.other => !_claimed(v),
      };

  static bool _claimed(DeviceView v) =>
      HomeCategory.energy.matches(v) ||
      HomeCategory.lighting.matches(v) ||
      HomeCategory.climate.matches(v);
}
