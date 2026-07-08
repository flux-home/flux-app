import 'package:flutter/material.dart';
import 'package:matter_home/models/energy_role.dart';

/// Aspect ratio of the wireframe house scene.
const double kSceneAspect = 4 / 3;

/// Energy assets shown on the illustrated home photo. Each configured asset
/// gets a pastel value badge positioned over its spot in the picture; [home]
/// is the whole-house total. Positions are normalized [0..1] over the image
/// and hand-tuned to the artwork.
enum SceneAsset {
  grid,
  pv,
  battery,
  heatPump,
  carCharger,
  home;

  EnergyRole? get role => switch (this) {
        SceneAsset.grid       => EnergyRole.grid,
        SceneAsset.pv         => EnergyRole.pv,
        SceneAsset.battery    => EnergyRole.homeBattery,
        SceneAsset.carCharger => EnergyRole.carCharger,
        SceneAsset.heatPump   => EnergyRole.heatPump,
        SceneAsset.home       => null,
      };

  /// Short label for the overlay pill.
  String get shortLabel => switch (this) {
        SceneAsset.grid       => 'Grid',
        SceneAsset.pv         => 'Solar',
        SceneAsset.battery    => 'Battery',
        SceneAsset.heatPump   => 'Heat pump',
        SceneAsset.carCharger => 'Car',
        SceneAsset.home       => 'Home',
      };

  /// Overlay position over the wireframe scene.
  Offset get anchor => switch (this) {
        SceneAsset.grid       => const Offset(0.14, 0.44),
        SceneAsset.pv         => const Offset(0.44, 0.24),
        SceneAsset.battery    => const Offset(0.15, 0.72),
        SceneAsset.heatPump   => const Offset(0.85, 0.50),
        SceneAsset.carCharger => const Offset(0.83, 0.72),
        SceneAsset.home       => const Offset(0.50, 0.62),
      };

  static const all = [grid, pv, battery, heatPump, carCharger, home];
}
