part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EnergyCard — Ferraris-meter inspired visualisation
//
// Layout
//   ┌──────────────────────────────────────────────┐
//   │      · · ●̈  · ·                             │
//   │   ·             ·    ← rotating amber ring   │
//   │  ·   1 2 3 . 4   ·  ← power in disc centre  │
//   │  ·      W        ·                           │
//   │   ·             ·                            │
//   │      · · · · ·                               │
//   │                                              │
//   │  ┌─┐┌─┐┌─┐┌─┐┌─┐ · ┌─┐  kWh  IMPORTED      │
//   │  │0││0││1││2││3│   │4│  ← drum-window odom. │
//   │  └─┘└─┘└─┘└─┘└─┘   └─┘                      │
//   │  ↑ Exported  0.01 kWh                        │
//   └──────────────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

class EnergyCard extends StatelessWidget {
  const EnergyCard({required this.live, super.key});

  final DeviceLiveData live;

  // ── Formatters ────────────────────────────────────────────────────────────

  static (String, String) _formatPower(int mw) {
    final w = mw / 1000.0;
    if (w.abs() >= 1000) return ((w / 1000).toStringAsFixed(1), 'kW');
    if (w.abs() >= 100)  return (w.toStringAsFixed(0), 'W');
    if (w.abs() >= 10)   return (w.toStringAsFixed(1), 'W');
    return (w.toStringAsFixed(2), 'W');
  }

  @override
  Widget build(BuildContext context) {
    final mw         = live.activePower;
    final mv         = live.voltage;
    final ma         = live.activeCurrent;
    final wh         = live.cumulativeEnergyWh;
    final exportedWh = live.cumulativeEnergyExportedWh;

    final hasVoltage = mv != null && mv > 0;
    final hasCurrent  = ma != null && ma != 0;

    final (powerLabel, powerUnit) =
        mw != null ? _formatPower(mw) : ('--', 'W');
    final watts = mw != null ? mw / 1000.0 : 0.0;

    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Ferraris disc ─────────────────────────────────────────────
            _FerrarisDisc(
              watts:      watts,
              powerLabel: powerLabel,
              powerUnit:  powerUnit,
            ),

            // ── Voltage + Current (optional) ─────────────────────────────
            if (hasVoltage || hasCurrent) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (hasVoltage)
                    Expanded(
                      child: _MetricTile(
                        icon:  Icons.electrical_services_outlined,
                        color: Colors.blue.shade400,
                        label: 'Voltage',
                        value: (mv / 1000.0).toStringAsFixed(1),
                        unit:  'V',
                      ),
                    ),
                  if (hasVoltage && hasCurrent) const SizedBox(width: 10),
                  if (hasCurrent)
                    Expanded(
                      child: _MetricTile(
                        icon:  Icons.electric_bolt_outlined,
                        color: Colors.orange.shade400,
                        label: 'Current',
                        value: (ma.abs() / 1000.0).toStringAsFixed(2),
                        unit:  'A',
                      ),
                    ),
                ],
              ),
            ],

            // ── Odometer (imported kWh) ───────────────────────────────────
            if (wh != null) ...[
              const SizedBox(height: 18),
              Divider(height: 1, color: Colors.white.withAlpha(15)),
              const SizedBox(height: 14),
              Center(child: _OdometerDisplay(wh: wh, label: 'IMPORTED')),
            ],

            // ── Odometer (exported kWh) ─────────────────────────────────────────
            if (exportedWh != null) ...[
              const SizedBox(height: 14),
              if (wh == null) ...[
                Divider(height: 1, color: Colors.white.withAlpha(15)),
                const SizedBox(height: 14),
              ],
              Center(
                child: _OdometerDisplay(
                  wh:    exportedWh,
                  label: 'EXPORTED',
                  color: Colors.green.shade400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ferraris disc — the spinning amber ring with power value at its centre
// ─────────────────────────────────────────────────────────────────────────────

class _FerrarisDisc extends StatefulWidget {
  const _FerrarisDisc({
    required this.watts,
    required this.powerLabel,
    required this.powerUnit,
  });

  final double watts;
  final String powerLabel;
  final String powerUnit;

  @override
  State<_FerrarisDisc> createState() => _FerrarisDiscState();
}

class _FerrarisDiscState extends State<_FerrarisDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Period scales with power: 600 kW·ms so at 1 kW the mark crosses the
  // strip once per 0.6 s; at 100 W once per 6 s; capped at 150 ms (fast)
  // and 30 s (practically still).
  Duration get _period {
    if (widget.watts <= 0) return const Duration(seconds: 30);
    final ms = (3_000_000 / widget.watts).clamp(500.0, 60_000.0);
    return Duration(milliseconds: ms.round());
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _period);
    if (widget.watts > 0) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_FerrarisDisc old) {
    super.didUpdateWidget(old);
    if (old.watts != widget.watts) {
      _ctrl.duration = _period;
      if (widget.watts > 0) {
        if (!_ctrl.isAnimating) _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Power value (dot-matrix centred) ──────────────────────────────
        Row(
          children: [
            const SizedBox(width: 44),
            Expanded(
              child: SizedBox(
                height: 52,
                child: CustomPaint(
                  painter: DotMatrixPainter(
                    text:     widget.powerLabel,
                    litColor: Colors.white,
                    dimColor: Colors.white.withAlpha(20),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                widget.powerUnit,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color:         Colors.white,
                  fontSize:      16,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),

        // ── Horizontal spinning strip ──────────────────────────────────────
        const SizedBox(height: 14),
        SizedBox(
          height: 12,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _DiscStripPainter(
                t:       _ctrl.value,
                spinning: widget.watts > 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disc strip painter — horizontal, dot spacing fixed at 8 px.
// A single red mark (with white cosine-bell fade on both sides) sweeps
// left→right continuously.  Speed is set by the AnimationController period.
// ─────────────────────────────────────────────────────────────────────────────

class _DiscStripPainter extends CustomPainter {
  const _DiscStripPainter({required this.t, required this.spinning});

  final double t;
  final bool   spinning;

  static const _step   = 8.0;  // px between dot centres
  static const _dotR   = 2.5;  // dot radius
  // Bell half-width for the moving red mark (tight — red pops out of the ring).
  static const _hWidth = 4.5;
  // The visible strip is 1/_ratio of the full disc circumference.
  // The mark is hidden for the remaining (_ratio−1)/_ratio of each turn.
  static const _ratio  = 4.0;

  /// Smooth cosine bell: 1.0 at d=0, 0.0 at d≥_hWidth.
  static double _bell(double d) =>
      d >= _hWidth ? 0.0 : 0.5 * (1 + math.cos(math.pi * d / _hWidth));

  @override
  void paint(Canvas canvas, Size size) {
    final cy     = size.height / 2;
    final n      = (size.width / _step).floor();
    final ox     = (size.width - n * _step) / 2;
    final center = (n - 1) / 2.0;

    // Full revolution = n * _ratio dot-units.  The mark is only visible
    // while markPos ∈ [0, n-1]; the rest of the time it’s on the back.
    final markPos = t * n * _ratio;

    for (var i = 0; i < n; i++) {
      final x = ox + i * _step + _step / 2;

      // ── Background ring ─ always drawn, never dimmed ─────────────────────────
      final normDist = (i - center).abs() / center;   // 0 = centre, 1 = edge
      final bgBright = math.pow(math.cos(normDist * math.pi / 2), 2).toDouble();
      canvas.drawCircle(
        Offset(x, cy),
        _dotR * (0.3 + bgBright * 0.5),
        Paint()..color = Colors.white.withAlpha((10 + bgBright * 50).round()),
      );

      if (!spinning) {
        // Stationary: park the dim red mark at the far left.
        if (i == 0) {
          canvas.drawCircle(Offset(x, cy), _dotR * 0.65,
              Paint()..color = Colors.red.shade400.withAlpha(80));
        }
        continue;
      }

      // ── Red mark ─ drawn on top, linear distance (no wrap-around) ──────────
      // When markPos is outside [0, n-1] the bell is 0 and nothing extra
      // is drawn — the background ring stays visible on its own.
      final dist = (i - markPos).abs();
      final b    = _bell(dist) * bgBright;  // modulate by ring envelope
      if (b < 0.02) continue;

      final whiteness = (dist / 1.5).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, cy),
        _dotR * (0.3 + b * 0.7),
        Paint()..color =
            Color.lerp(Colors.red.shade400, Colors.white, whiteness)!
                .withAlpha((b * 255).round().clamp(0, 255)),
      );
    }
  }

  @override
  bool shouldRepaint(_DiscStripPainter old) =>
      old.t != t || old.spinning != spinning;
}

// ─────────────────────────────────────────────────────────────────────────────
// Odometer — drum-window kWh counter
// ─────────────────────────────────────────────────────────────────────────────

class _OdometerDisplay extends StatelessWidget {
  const _OdometerDisplay({
    required this.wh,
    required this.label,
    this.color = Colors.amber,
  });

  final int    wh;
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final kwh   = wh / 1000.0;
    // Always 5 integer digits + 1 decimal — true odometer style
    final intPart = kwh.floor().toString().padLeft(5, '0');
    final decPart = ((kwh * 10).floor() % 10).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Label ──────────────────────────────────────────────────────────────────────────────
        Text(
          label,
          style: TextStyle(
            color:         color.withAlpha(160),
            fontSize:      10,
            fontWeight:    FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 8),

        // ── Digit drums + decimal dot ────────────────────────────────────────────────────────────────────────
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final d in intPart.characters)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: _DigitDrum(digit: d, dim: false, color: color),
              ),
            // Decimal point
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 4, height: 4,
                decoration: BoxDecoration(
                  color:     color,
                  shape:     BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 6)],
                ),
              ),
            ),
            _DigitDrum(digit: decPart, dim: true, color: color),
            const SizedBox(width: 10),
            Text(
              'kWh',
              style: TextStyle(
                color:      color.withAlpha(200),
                fontSize:   13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
class _DigitDrum extends StatelessWidget {
  const _DigitDrum({
    required this.digit,
    required this.dim,
    this.color = Colors.amber,
  });

  final String digit;
  final bool   dim;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final litColor = dim
        ? color.withAlpha(160)
        : color.withAlpha(230);

    return Container(
      width: 24, height: 38,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(60),
        border: Border.all(color: Colors.white.withAlpha(22), width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: CustomPaint(
          painter: DotMatrixPainter(
            text:     digit,
            litColor: litColor,
            dimColor: color.withAlpha(18),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric tile — voltage / current chip (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color    color;
  final String   label;
  final String   value;
  final String   unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:        Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 5),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              TextSpan(text: ' $unit', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Energy footer row (unchanged)
// ─────────────────────────────────────────────────────────────────────────────








