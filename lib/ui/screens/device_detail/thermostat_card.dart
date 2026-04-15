part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Thermostat card
// ─────────────────────────────────────────────────────────────────────────────

class _ThermostatCard extends StatelessWidget {
  // null = off

  const _ThermostatCard({
    required this.state,
    required this.pendingSetpt,
    required this.pendingMode,
    required this.onSetSetpoint,
  });
  final ThermostatState? state;
  final int? pendingSetpt;
  final int? pendingMode;
  final Future<void> Function(double?) onSetSetpoint;

  @override
  Widget build(BuildContext context) {
    final effectiveMode = pendingMode ?? state?.systemMode;
    // isOff: device mode is 0 (off) or mode is unknown
    final isOff = (effectiveMode ?? 0) == 0;
    // setpointC is only meaningful when not off
    final setpointC = isOff
        ? null
        : pendingSetpt != null
        ? pendingSetpt! / 100.0
        : state?.heatingSetptC;

    // Dark instrument-panel background so the colored arc and white text pop.
    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          children: [
            // ── Dial ──────────────────────────────────────────────────────────
            _ThermostatDial(
              measuredTempC: state?.localTempC,
              setpointC: setpointC,
              isOff: isOff,
              supportsCooling: state?.supportsCooling ?? false,
              coolingSetptC: state?.coolingSetptC,
              systemMode: effectiveMode,
              tempMin: state?.effectiveMinHeatC ?? 5.0,
              tempMax: state?.effectiveMaxHeatC ?? 35.0,
              onSetpointChanged: (v) {},
              onSetpointEnd: state != null ? onSetSetpoint : (_) async {},
            ),

            // ── Status line ───────────────────────────────────────────────────
            if (state != null) ...[
              const SizedBox(height: 8),
              _StatusLine(state: state!, effectiveSetptC: setpointC, effectiveMode: effectiveMode),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status line — dot-matrix strip below the dial
// ─────────────────────────────────────────────────────────────────────────────

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state, required this.effectiveSetptC, required this.effectiveMode});
  final ThermostatState state;
  final double? effectiveSetptC;
  final int? effectiveMode;

  (String, Color) _resolve() {
    final mode = effectiveMode ?? 0;
    final temp = state.localTempC;
    final setpt = effectiveSetptC;
    const idle = Colors.white38;

    if (mode == 0) return ('OFF', idle);

    // Mode-agnostic: show heating state based on temp delta.
    if (setpt != null && temp != null && setpt > temp + 0.5) {
      return ('HEATING', const Color(0xFFFFCC80));
    }

    return ('IDLE', idle);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve();
    return SizedBox(
      height: 14,
      child: CustomPaint(
        painter: DotMatrixPainter(text: label, litColor: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thermostat dial
// ─────────────────────────────────────────────────────────────────────────────

const _kArcStart = 135.0 * math.pi / 180.0;
const _kArcSweep = 270.0 * math.pi / 180.0;

class _ThermostatDial extends StatefulWidget {
  const _ThermostatDial({
    required this.measuredTempC,
    required this.setpointC,
    required this.isOff,
    required this.supportsCooling,
    required this.coolingSetptC,
    required this.systemMode,
    required this.tempMin,
    required this.tempMax,
    required this.onSetpointChanged,
    required this.onSetpointEnd,
  });
  final double? measuredTempC;
  final double? setpointC;
  final double? coolingSetptC;
  final bool supportsCooling;
  final bool isOff; // device is currently off
  final int? systemMode;
  final double tempMin;
  final double tempMax;
  final void Function(double) onSetpointChanged;

  /// null = set to off, non-null = set setpoint
  final Future<void> Function(double?) onSetpointEnd;

  @override
  State<_ThermostatDial> createState() => _ThermostatDialState();
}

// First 18° of the 270° arc = OFF zone.  The remaining 252° is min→max temp.
const double _kOffDeg = 18;

class _ThermostatDialState extends State<_ThermostatDial> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  double? _dragTemp;
  bool _dragIsOff = false;

  // Whether the dial is currently in the off position (drag or widget state).
  bool get _isOff => _dragIsOff || (widget.isOff && _dragTemp == null);
  double get _setpoint => _dragTemp ?? widget.setpointC ?? widget.tempMin;

  bool get _isActive {
    if (_isOff) return false;
    final t = widget.measuredTempC;
    final s = _dragTemp ?? widget.setpointC;
    return t != null && s != null && s > t + 0.5;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    if (_isActive) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_ThermostatDial old) {
    super.didUpdateWidget(old);
    if (_isActive && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!_isActive && _pulseCtrl.isAnimating) {
      _pulseCtrl
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  /// Returns null (= OFF) when rel < _kOffDeg, otherwise the temperature.
  double? _angleToValue(double angleDeg) {
    const startDeg = _kArcStart * 180 / math.pi;
    var rel = ((angleDeg - startDeg) % 360 + 360) % 360;
    if (rel > 270) rel = (rel - 270 < 360 - rel) ? 270 : 0;
    if (rel < _kOffDeg) return null; // OFF zone
    final fraction = (rel - _kOffDeg) / (270.0 - _kOffDeg);
    return (widget.tempMin + fraction * (widget.tempMax - widget.tempMin)).clamp(widget.tempMin, widget.tempMax);
  }

  void _handleDrag(Offset pos, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    var deg = math.atan2(pos.dy - c.dy, pos.dx - c.dx) * 180 / math.pi;
    if (deg < 0) deg += 360;
    final val = _angleToValue(deg);
    if (val == null) {
      setState(() {
        _dragIsOff = true;
        _dragTemp = null;
      });
    } else {
      final snapped = ((val * 2).round() / 2.0).clamp(widget.tempMin, widget.tempMax);
      setState(() {
        _dragIsOff = false;
        _dragTemp = snapped;
      });
      widget.onSetpointChanged(snapped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final side = c.maxWidth;
        return AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => _handleDrag(d.localPosition, Size(side, side)),
              onPanEnd: (_) {
                final wasOff = _dragIsOff;
                final wasTemp = _dragTemp;
                setState(() {
                  _dragIsOff = false;
                  _dragTemp = null;
                });
                if (wasOff) {
                  widget.onSetpointEnd(null); // → turn off
                } else if (wasTemp != null) {
                  widget.onSetpointEnd(wasTemp); // → set temperature
                }
              },
              child: CustomPaint(
                painter: _DialPainter(
                  measuredTempC: widget.measuredTempC,
                  setpointC: _isOff ? null : _setpoint,
                  isOff: _isOff,
                  coolingSetptC: widget.supportsCooling ? widget.coolingSetptC : null,
                  systemMode: widget.systemMode,
                  pulseValue: _pulseCtrl.value,
                  tempMin: widget.tempMin,
                  tempMax: widget.tempMax,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Dial painter ───────────────────────────────────────────────────────────────

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.measuredTempC,
    required this.setpointC,
    required this.tempMin,
    required this.tempMax,
    this.isOff = false,
    this.coolingSetptC,
    this.systemMode,
    this.pulseValue = 0,
  });
  final double? measuredTempC;
  final double? setpointC;
  final double? coolingSetptC;
  final bool isOff;
  final int? systemMode;
  final double pulseValue;
  final double tempMin;
  final double tempMax;

  /// Fraction of the temperature sub-arc [0,1] for a given temperature.
  double _frac(double t) => ((t - tempMin) / (tempMax - tempMin)).clamp(0.0, 1.0);

  /// Angle (radians from arc start) for a temperature, offset past the OFF zone.
  double _tempAngle(double t) => _kArcSweep * (_kOffDeg / 270.0 + _frac(t) * (1.0 - _kOffDeg / 270.0));

  static const _kCoolColor = Color(0xFF81D4FA); // pastel sky blue

  /// Pastel gradient: sky blue (200°) → pastel yellow (55°) → pastel red (0°).
  /// Hue descends; saturation rises slightly toward max so the hot end reads
  /// unmistakably as pastel red rather than washed-out coral.
  Color get _arcColor {
    if (setpointC == null) return Colors.white.withAlpha(60);
    final f = _frac(setpointC!);
    final hue = f < 0.5
        ? 200 -
              (f * 2) *
                  145 // 200° → 55°  (blue → yellow)
        : 55 - ((f - 0.5) * 2) * 55; // 55°  → 0°   (yellow → red)
    // Saturation and lightness grade toward a clearly pastel red at max.
    final sat = 0.75 + f * 0.13; // 0.75 → 0.88
    final lit = 0.78 - f * 0.02; // 0.78 → 0.76
    return HSLColor.fromAHSL(1, hue.clamp(0, 360), sat, lit).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final c = Offset(cx, cy);
    final r = math.min(cx, cy) - 20;
    final rc = Rect.fromCircle(center: c, radius: r);
    final arc = _arcColor;

    // ── Track ────────────────────────────────────────────────────────────────
    canvas.drawArc(
      rc,
      _kArcStart,
      _kArcSweep,
      false,
      Paint()
        ..color = Colors.white.withAlpha(28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    if (isOff) {
      // ── OFF state: dim knob at arc start, "OFF" in centre ─────────────────
      final kp = c + Offset(math.cos(_kArcStart) * r, math.sin(_kArcStart) * r);
      canvas
        ..drawCircle(kp, 10, Paint()..color = Colors.white.withAlpha(40))
        ..drawCircle(
          kp,
          10,
          Paint()
            ..color = Colors.white.withAlpha(60)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

      paintDotMatrix(
        canvas,
        c + Offset(0, -r * 0.05),
        'OFF',
        maxWidth: r * 0.75,
        maxHeight: r * 0.36,
        color: Colors.white.withAlpha(100),
      );

      // Still show room temperature below "OFF"
      if (measuredTempC != null) {
        paintDotMatrix(
          canvas,
          c + Offset(0, r * 0.32),
          '${measuredTempC!.toStringAsFixed(1)}°',
          maxWidth: r * 0.65,
          maxHeight: r * 0.22,
          color: Colors.white.withAlpha(80),
        );
        // Measured tick on arc
        final ma = _kArcStart + _tempAngle(measuredTempC!);
        final d = Offset(math.cos(ma), math.sin(ma));
        canvas.drawLine(
          c + d * (r - 9),
          c + d * (r + 9),
          Paint()
            ..color = Colors.white.withAlpha(120)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    } else {
      // ── Active state ────────────────────────────────────────────────────────

      // Filled arc up to setpoint
      if (setpointC != null) {
        final sweep = _tempAngle(setpointC!);
        if (sweep > 0) {
          canvas.drawArc(
            rc,
            _kArcStart,
            sweep,
            false,
            Paint()
              ..color = arc.withAlpha(190)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
        }

        // Knob
        final ka = _kArcStart + sweep;
        final kp = c + Offset(math.cos(ka) * r, math.sin(ka) * r);

        if (pulseValue > 0) {
          canvas.drawCircle(
            kp,
            11 + pulseValue * 9,
            Paint()
              ..color = arc.withAlpha((70 * (1 - pulseValue)).round())
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }

        canvas
          ..drawCircle(kp, 11, Paint()..color = arc)
          ..drawCircle(
            kp,
            11,
            Paint()
              ..color = Colors.white.withAlpha(90)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          )
          ..save()
          ..translate(kp.dx, kp.dy)
          ..rotate(ka + math.pi / 2);
        final grip = Paint()
          ..color = Colors.black.withAlpha(90)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(Offset(-4.5, i * 2.5), Offset(4.5, i * 2.5), grip);
        }
        canvas.restore();
      }

      // Measured temp tick
      if (measuredTempC != null) {
        final ma = _kArcStart + _tempAngle(measuredTempC!);
        final d = Offset(math.cos(ma), math.sin(ma));
        canvas.drawLine(
          c + d * (r - 9),
          c + d * (r + 9),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }

      // Cooling setpoint tick
      if (coolingSetptC != null) {
        final ca = _kArcStart + _tempAngle(coolingSetptC!);
        final d = Offset(math.cos(ca), math.sin(ca));
        canvas.drawLine(
          c + d * (r - 6),
          c + d * (r + 6),
          Paint()
            ..color = _kCoolColor.withAlpha(200)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      }

      // Current temperature — large, upper-centre
      paintDotMatrix(
        canvas,
        c + Offset(0, -r * 0.12),
        measuredTempC != null ? '${measuredTempC!.toStringAsFixed(1)}°' : '--.-',
        maxWidth: r * 0.90,
        maxHeight: r * 0.36,
        color: Colors.white,
      );

      // Setpoint — smaller, below, in arc colour
      if (setpointC != null) {
        paintDotMatrix(
          canvas,
          c + Offset(0, r * 0.32),
          '${setpointC!.toStringAsFixed(1)}°',
          maxWidth: r * 0.65,
          maxHeight: r * 0.22,
          color: arc.withAlpha(220),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DialPainter o) =>
      o.measuredTempC != measuredTempC ||
      o.setpointC != setpointC ||
      o.isOff != isOff ||
      o.coolingSetptC != coolingSetptC ||
      o.systemMode != systemMode ||
      o.pulseValue != pulseValue ||
      o.tempMin != tempMin ||
      o.tempMax != tempMax;
}
