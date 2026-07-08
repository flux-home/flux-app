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
  climate;

  String get label => switch (this) {
        HomeCategory.energy   => 'Energy',
        HomeCategory.lighting => 'Lighting',
        HomeCategory.climate  => 'Climate',
      };

  IconData get icon => switch (this) {
        HomeCategory.energy   => Icons.bolt_outlined,
        HomeCategory.lighting => Icons.lightbulb_outline,
        HomeCategory.climate  => Icons.thermostat_outlined,
      };

  /// Pastel accent for the button outline + text and the category screen title.
  Color get color => switch (this) {
        HomeCategory.energy   => const Color(0xFFE8D66B), // pastel yellow
        HomeCategory.lighting => const Color(0xFFF2B877), // pastel orange
        HomeCategory.climate  => const Color(0xFF8FCDEF), // pastel blue
      };

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
      };
}
