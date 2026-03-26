// ── Battery info ────────────────────────────────────────────────────────────

/// Data returned by the Power Source subscription / cluster read.
class BatteryInfo {
  /// 0–100 % derived from BatPercentRemaining, or null if not reported.
  final int? percent;

  /// BatChargeLevel: 0 = OK, 1 = Warning, 2 = Critical. Null if not reported.
  final int? chargeLevel;

  /// BatVoltage in mV, or null if not reported.
  final int? voltageMilliV;

  const BatteryInfo({this.percent, this.chargeLevel, this.voltageMilliV});

  bool get hasData =>
      percent != null || chargeLevel != null || voltageMilliV != null;
}

// ── Thermostat state ───────────────────────────────────────────────────────

class ThermostatState {
  /// All temperatures in centidegrees (0.01 °C). Null = not available.
  final int? localTempCenti;
  final int? heatingSetptCenti;
  final int? coolingSetptCenti;

  /// 0=Off 1=Auto 3=Cool 4=Heat 5=EmergencyHeat 6=Precooling 7=FanOnly
  final int? systemMode;

  /// ControlSequenceOfOperation (0x001B):
  ///   0/1 = CoolingOnly, 2/3 = HeatingOnly, 4/5 = CoolingAndHeating
  final int? controlSequence;

  const ThermostatState({
    this.localTempCenti,
    this.heatingSetptCenti,
    this.coolingSetptCenti,
    this.systemMode,
    this.controlSequence,
  });

  double? get localTempC =>
      localTempCenti != null ? localTempCenti! / 100.0 : null;
  double? get heatingSetptC =>
      heatingSetptCenti != null ? heatingSetptCenti! / 100.0 : null;
  double? get coolingSetptC =>
      coolingSetptCenti != null ? coolingSetptCenti! / 100.0 : null;

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
