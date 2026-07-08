/// Formats a power value for display, choosing W / kW automatically.
///
/// Shared by the per-device [EnergyCard] and the home energy-flow overview so
/// both read identically.
library;

/// Formats [watts] as a `(value, unit)` pair, e.g. `('1.9', 'kW')` or
/// `('340', 'W')`.  The magnitude drives precision; the sign is preserved so
/// callers can show direction if they want.
(String, String) formatPowerW(double watts) {
  final a = watts.abs();
  if (a >= 1000) return ((watts / 1000).toStringAsFixed(1), 'kW');
  if (a >= 100)  return (watts.toStringAsFixed(0), 'W');
  if (a >= 10)   return (watts.toStringAsFixed(1), 'W');
  return (watts.toStringAsFixed(2), 'W');
}

/// Convenience: format milliwatts (Matter EPM unit) as a `(value, unit)` pair.
(String, String) formatPowerMw(int milliwatts) =>
    formatPowerW(milliwatts / 1000.0);

/// A single combined string, e.g. `'1.9 kW'`.
String powerLabelW(double watts) {
  final (v, u) = formatPowerW(watts);
  return '$v $u';
}
