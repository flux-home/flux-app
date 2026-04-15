// ── Battery info ────────────────────────────────────────────────────────────

/// Data returned by the Power Source subscription / cluster read.
class BatteryInfo {

  const BatteryInfo({this.percent, this.chargeLevel, this.voltageMilliV});
  /// 0–100 % derived from BatPercentRemaining, or null if not reported.
  final int? percent;

  /// BatChargeLevel: 0 = OK, 1 = Warning, 2 = Critical. Null if not reported.
  final int? chargeLevel;

  /// BatVoltage in mV, or null if not reported.
  final int? voltageMilliV;

  bool get hasData =>
      percent != null || chargeLevel != null || voltageMilliV != null;
}

// ── Thermostat state ───────────────────────────────────────────────────────

class ThermostatState {

  const ThermostatState({
    this.localTempCenti,
    this.heatingSetptCenti,
    this.coolingSetptCenti,
    this.minHeatSetptCenti,
    this.maxHeatSetptCenti,
    this.minCoolSetptCenti,
    this.maxCoolSetptCenti,
    this.absMinHeatSetptCenti,
    this.absMaxHeatSetptCenti,
    this.absMinCoolSetptCenti,
    this.absMaxCoolSetptCenti,
    this.systemMode,
    this.controlSequence,
  });
  /// All temperatures in centidegrees (0.01 °C). Null = not available.
  final int? localTempCenti;
  final int? heatingSetptCenti;
  final int? coolingSetptCenti;

  /// Setpoint limits in centidegrees — configurable limits (user-adjustable).
  final int? minHeatSetptCenti;
  final int? maxHeatSetptCenti;
  final int? minCoolSetptCenti;
  final int? maxCoolSetptCenti;

  /// Absolute limits (hardware floor/ceiling, spec §4.3.x).
  final int? absMinHeatSetptCenti;
  final int? absMaxHeatSetptCenti;
  final int? absMinCoolSetptCenti;
  final int? absMaxCoolSetptCenti;

  /// 0=Off 1=Auto 3=Cool 4=Heat 5=EmergencyHeat 6=Precooling 7=FanOnly
  final int? systemMode;

  /// ControlSequenceOfOperation (0x001B):
  ///   0/1 = CoolingOnly, 2/3 = HeatingOnly, 4/5 = CoolingAndHeating
  final int? controlSequence;

  double? get localTempC =>
      localTempCenti != null ? localTempCenti! / 100.0 : null;
  double? get heatingSetptC =>
      heatingSetptCenti != null ? heatingSetptCenti! / 100.0 : null;
  double? get coolingSetptC =>
      coolingSetptCenti != null ? coolingSetptCenti! / 100.0 : null;

  /// Effective heating setpoint range in °C.
  /// Takes the tighter intersection of the configurable and absolute limits,
  /// falling back to safe defaults when neither is reported.
  /// Tighter of two optional centidegree values, converted to °C.
  static double _tighterMin(int? cfg, int? abs, int fallbackCenti) {
    final a = cfg;
    final b = abs;
    if (a != null && b != null) return (a > b ? a : b) / 100.0;
    return (a ?? b ?? fallbackCenti) / 100.0;
  }

  static double _tighterMax(int? cfg, int? abs, int fallbackCenti) {
    final a = cfg;
    final b = abs;
    if (a != null && b != null) return (a < b ? a : b) / 100.0;
    return (a ?? b ?? fallbackCenti) / 100.0;
  }

  double get effectiveMinHeatC =>
      _tighterMin(minHeatSetptCenti, absMinHeatSetptCenti, 500);
  double get effectiveMaxHeatC =>
      _tighterMax(maxHeatSetptCenti, absMaxHeatSetptCenti, 3500);
  double get effectiveMinCoolC =>
      _tighterMin(minCoolSetptCenti, absMinCoolSetptCenti, 1600);
  double get effectiveMaxCoolC =>
      _tighterMax(maxCoolSetptCenti, absMaxCoolSetptCenti, 3200);

  /// True when the device supports heating (CSO 2, 3, 4, 5; or unknown).
  bool get supportsHeating {
    if (controlSequence == null) return true;
    return const {2, 3, 4, 5}.contains(controlSequence);
  }

  /// True only when the device explicitly advertises cooling (CSO 0, 1, 4, 5).
  bool get supportsCooling {
    if (controlSequence == null) return false;
    return const {0, 1, 4, 5}.contains(controlSequence);
  }

  static const _modeNames = <int, String>{
    0: 'Off', 1: 'Auto', 3: 'Cool', 4: 'Heat',
    5: 'Emergency Heat', 6: 'Precooling', 7: 'Fan Only', 8: 'Dry', 9: 'Sleep',
  };

  String get systemModeName =>
      systemMode != null ? (_modeNames[systemMode!] ?? 'Mode $systemMode') : '—';

  List<({int mode, String label})> get availableModes {
    const off  = (mode: 0, label: 'Off');
    const auto = (mode: 1, label: 'Auto');
    const cool = (mode: 3, label: 'Cool');
    const heat = (mode: 4, label: 'Heat');
    return switch (controlSequence) {
      0 || 1 => [off, cool],
      2 || 3 => [off, heat],
      4 || 5 => [off, heat, cool, auto],
      _      => [off, heat, cool, auto],
    };
  }
}
