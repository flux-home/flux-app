// ── Water Heater state ─────────────────────────────────────────────────────────

/// Live state for a Matter Water Heater device (device type 0x050F).
///
/// Combines attributes from the Thermostat cluster (0x0201) — temperature
/// measurement and setpoint control — and the Water Heater Management cluster
/// (0x0094) — heat demand, tank fill level, and boost state.
///
/// All temperatures are in centidegrees (0.01 °C).
class WaterHeaterState {

  const WaterHeaterState({
    this.localTempCenti,
    this.heatingSetptCenti,
    this.minHeatSetptCenti,
    this.maxHeatSetptCenti,
    this.tankPercentHeat,
    this.heatDemand,
    this.boostState,
  });

  /// Current water temperature in centidegrees.  Null if not yet available.
  final int? localTempCenti;

  /// Target heating setpoint in centidegrees (OccupiedHeatingSetpoint).
  final int? heatingSetptCenti;

  /// Configurable min/max setpoint limits in centidegrees.
  /// When null the safe defaults (40 °C / 80 °C) are used.
  final int? minHeatSetptCenti;
  final int? maxHeatSetptCenti;

  /// Tank heat level: 0–100 %.  Null when the device does not report it.
  final int? tankPercentHeat;

  /// WaterHeaterManagement HeatDemand bitmap8.
  /// Non-zero means the heater element is actively firing.
  final int? heatDemand;

  /// WaterHeaterManagement BoostStateEnum: 0 = Inactive, 1 = Active.
  final int? boostState;

  // ── Derived helpers ─────────────────────────────────────────────────────────

  double? get localTempC =>
      localTempCenti != null ? localTempCenti! / 100.0 : null;

  double? get setpointC =>
      heatingSetptCenti != null ? heatingSetptCenti! / 100.0 : null;

  /// Effective setpoint range for the dial — tighter of device limits or
  /// safe hardware defaults (40 °C / 80 °C).
  double get effectiveMinC => (minHeatSetptCenti ?? 4000) / 100.0;
  double get effectiveMaxC => (maxHeatSetptCenti ?? 8000) / 100.0;

  /// True when at least one heater element is active.
  bool get isHeating => (heatDemand ?? 0) != 0;

  /// True when a Boost command is currently active.
  bool get isBoostActive => boostState == 1;
}
