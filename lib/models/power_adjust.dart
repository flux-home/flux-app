import 'package:flutter/foundation.dart';

/// Matter Device Energy Management (cluster 0x0098) — the PowerAdjustment
/// feature, which is how an energy manager tells a battery to charge or
/// discharge at a set power for a bounded time.
///
/// Built from the live attribute keys the controller publishes. For a Matter
/// battery they come from its subscription (`esaFeatureMap`, `esaState`,
/// `powerAdjMinPower`, …). The controller publishes the same keys for the
/// Modbus batteries it drives itself, plus `powerAdjPower` / `powerAdjRemaining`
/// describing the active hold, which Matter only conveys as events. Those two
/// are optional; a Matter battery simply won't send them.
///
/// Power is signed like `activePower`: positive = consuming (charging),
/// negative = generating (discharging). All powers are in milliwatts.
@immutable
class PowerAdjust {
  const PowerAdjust({
    required this.minPowerMw,
    required this.maxPowerMw,
    required this.maxDuration,
    required this.state,
    this.activePowerMw,
    this.remaining,
  });

  /// DEM FeatureMap bit 0 (PA).
  static const int featurePowerAdjustment = 0x1;

  // ESAStateEnum.
  static const int stateOffline = 0;
  static const int stateOnline = 1;
  static const int stateFault = 2;
  static const int statePowerAdjustActive = 3;
  static const int statePaused = 4;

  /// Used when a device advertises PA but no maximum duration.
  static const Duration fallbackMaxDuration = Duration(hours: 1);

  /// Most negative setpoint (fastest discharge) the device accepts.
  final int minPowerMw;

  /// Most positive setpoint (fastest charge) the device accepts.
  final int maxPowerMw;

  /// Longest hold the device accepts.
  final Duration maxDuration;

  /// ESAStateEnum value.
  final int state;

  /// Setpoint of the running hold, when the device reports it.
  final int? activePowerMw;

  /// Time left on the running hold, when the device reports it.
  final Duration? remaining;

  bool get isActive => state == statePowerAdjustActive;
  bool get isOffline => state == stateOffline;
  bool get canCharge => maxPowerMw > 0;
  bool get canDischarge => minPowerMw < 0;

  /// Reads the DEM view out of a device's live attributes, or null if the
  /// device doesn't offer power adjustment (no PA feature bit, or no usable
  /// power range yet).
  static PowerAdjust? fromAttrs(Map<String, dynamic> attrs) {
    final features = attrs['esaFeatureMap'];
    if (features is! int || features & featurePowerAdjustment == 0) return null;

    // PowerAdjustmentCapability is the current, adjustable range; AbsMin/Max is
    // the device's absolute envelope. Prefer the former, fall back to the latter.
    final minMw = _int(attrs['powerAdjMinPower']) ?? _int(attrs['absMinPower']);
    final maxMw = _int(attrs['powerAdjMaxPower']) ?? _int(attrs['absMaxPower']);
    if (minMw == null || maxMw == null || minMw >= maxMw) return null;

    final maxS = _int(attrs['powerAdjMaxDuration']);
    final remS = _int(attrs['powerAdjRemaining']);
    final state = _int(attrs['esaState']) ?? stateOnline;
    final active = state == statePowerAdjustActive;
    return PowerAdjust(
      minPowerMw: minMw,
      maxPowerMw: maxMw,
      maxDuration: maxS != null && maxS > 0
          ? Duration(seconds: maxS)
          : fallbackMaxDuration,
      state: state,
      activePowerMw: active ? _int(attrs['powerAdjPower']) : null,
      remaining: active && remS != null ? Duration(seconds: remS) : null,
    );
  }

  /// Clamps a requested setpoint into the advertised range.
  int clampPowerMw(int mw) => mw.clamp(minPowerMw, maxPowerMw);

  /// Hold durations to offer, limited to what the device accepts.
  List<Duration> durationChoices() {
    const presets = [
      Duration(minutes: 15),
      Duration(minutes: 30),
      Duration(hours: 1),
      Duration(hours: 2),
      Duration(hours: 4),
    ];
    final fits = presets.where((d) => d <= maxDuration).toList();
    return fits.isEmpty ? [maxDuration] : fits;
  }

  static int? _int(Object? v) => v is int ? v : null;
}
