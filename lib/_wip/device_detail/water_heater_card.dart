import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:matter_home/models/water_heater_models.dart';
import 'package:matter_home/ui/widgets/dot_matrix_painter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Water Heater card
// ─────────────────────────────────────────────────────────────────────────────

class WaterHeaterCard extends StatelessWidget {

  const WaterHeaterCard({
    required this.state,
    required this.pendingSetpt,
    required this.onSetSetpoint,
    required this.onSetBoost,
    super.key,
  });

  final WaterHeaterState? state;
  /// Pending setpoint centidegrees from a recent drag gesture.
  final int? pendingSetpt;
  final Future<void> Function(double) onSetSetpoint;
  final Future<void> Function(bool) onSetBoost;

  @override
  Widget build(BuildContext context) {
    final setpointC = pendingSetpt != null
        ? pendingSetpt! / 100.0
        : state?.setpointC;

    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          children: [
            // ── Dial ────────────────────────────────────────────────────────
            _WaterHeaterDial(
              currentTempC:    state?.localTempC,
              setpointC:       setpointC,
              isHeating:       state?.isHeating ?? false,
              tempMin:         state?.effectiveMinC ?? 40.0,
              tempMax:         state?.effectiveMaxC ?? 80.0,
              onSetpointEnd:   state != null ? onSetSetpoint : (_) async {},
            ),

            // ── Status strip ─────────────────────────────────────────────────
            if (state != null) ...[
              const SizedBox(height: 8),
              _StatusStrip(state: state!, effectiveSetptC: setpointC),
            ],

            // ── Tank heat level ──────────────────────────────────────────────
            if (state?.tankPercentHeat != null) ...[
              const SizedBox(height: 14),
              _TankBar(percent: state!.tankPercentHeat!),
            ],

            // ── Boost button ─────────────────────────────────────────────────
            const SizedBox(height: 16),
            _BoostButton(
              isActive: state?.isBoostActive ?? false,
              onToggle: state != null ? onSetBoost : (_) async {},
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status strip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.state, required this.effectiveSetptC});
  final WaterHeaterState state;
  final double? effectiveSetptC;

  (String, Color) _resolve() {
    if (state.isBoostActive) return ('BOOST', const Color(0xFFFF8A65));
    if (state.isHeating)     return ('HEATING', const Color(0xFFFFCC80));
    return ('IDLE', Colors.white38);
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
// Tank heat-level bar
// ─────────────────────────────────────────────────────────────────────────────

class _TankBar extends StatelessWidget {
  const _TankBar({required this.percent});
  final int percent;

  Color get _fillColor {
    // Cold (blue) → warm (orange) → hot (red)
    final f = (percent / 100.0).clamp(0.0, 1.0);
    final hue = (220.0 - f * 200.0).clamp(0.0, 360.0);
    return HSLColor.fromAHSL(1, hue, 0.80, 0.60).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tank',
              style: TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 0.5),
            ),
            Text(
              '$percent%',
              style: TextStyle(fontSize: 11, color: _fillColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value:           percent / 100.0,
            backgroundColor: Colors.white12,
            valueColor:      AlwaysStoppedAnimation<Color>(_fillColor),
            minHeight:       6,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Boost button
// ─────────────────────────────────────────────────────────────────────────────

class _BoostButton extends StatelessWidget {
  const _BoostButton({required this.isActive, required this.onToggle});
  final bool isActive;
  final Future<void> Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? const Color(0xFFFF8A65)  // warm orange when active
        : Colors.white54;
    final label = isActive ? 'CANCEL BOOST' : 'BOOST';

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side:            BorderSide(color: color, width: 1.5),
          foregroundColor: color,
          padding:         const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon:    Icon(isActive ? Icons.cancel_outlined : Icons.local_fire_department_outlined, size: 18),
        label:   Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        onPressed: () => onToggle(!isActive),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dial
// ─────────────────────────────────────────────────────────────────────────────

const _kArcStart = 135.0 * math.pi / 180.0;
const _kArcSweep = 270.0 * math.pi / 180.0;

class _WaterHeaterDial extends StatefulWidget {
  const _WaterHeaterDial({
    required this.currentTempC,
    required this.setpointC,
    required this.isHeating,
    required this.tempMin,
    required this.tempMax,
    required this.onSetpointEnd,
  });

  final double? currentTempC;
  final double? setpointC;
  final bool    isHeating;
  final double  tempMin;
  final double  tempMax;
  final Future<void> Function(double) onSetpointEnd;

  @override
  State<_WaterHeaterDial> createState() => _WaterHeaterDialState();
}

class _WaterHeaterDialState extends State<_WaterHeaterDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  double? _dragTemp;

  double get _setpoint =>
      _dragTemp ?? widget.setpointC ?? ((widget.tempMin + widget.tempMax) / 2);

  bool get _isActive {
    if (!widget.isHeating && _dragTemp == null) return false;
    final t = widget.currentTempC;
    final s = _dragTemp ?? widget.setpointC;
    return t != null && s != null && s > t + 0.5;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (_isActive) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_WaterHeaterDial old) {
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

  double _angleToValue(double angleDeg) {
    const startDeg = _kArcStart * 180 / math.pi;
    var rel = ((angleDeg - startDeg) % 360 + 360) % 360;
    if (rel > 270) rel = (rel - 270 < 360 - rel) ? 270 : 0;
    final fraction = rel / 270.0;
    return (widget.tempMin + fraction * (widget.tempMax - widget.tempMin))
        .clamp(widget.tempMin, widget.tempMax);
  }

  void _handleDrag(Offset pos, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    var deg = math.atan2(pos.dy - c.dy, pos.dx - c.dx) * 180 / math.pi;
    if (deg < 0) deg += 360;
    final val = _angleToValue(deg);
    // Snap to 0.5°C increments.
    final snapped = ((val * 2).round() / 2.0).clamp(widget.tempMin, widget.tempMax);
    setState(() => _dragTemp = snapped);
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
                final wasTemp = _dragTemp;
                setState(() => _dragTemp = null);
                if (wasTemp != null) widget.onSetpointEnd(wasTemp);
              },
              child: CustomPaint(
                painter: _WaterDialPainter(
                  currentTempC: widget.currentTempC,
                  setpointC:    _setpoint,
                  isHeating:    _isActive,
                  pulseValue:   _pulseCtrl.value,
                  tempMin:      widget.tempMin,
                  tempMax:      widget.tempMax,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dial painter
// ─────────────────────────────────────────────────────────────────────────────

class _WaterDialPainter extends CustomPainter {
  const _WaterDialPainter({
    required this.currentTempC,
    required this.setpointC,
    required this.tempMin,
    required this.tempMax,
    required this.isHeating,
    required this.pulseValue,
  });

  final double? currentTempC;
  final double  setpointC;
  final double  tempMin;
  final double  tempMax;
  final bool    isHeating;
  final double  pulseValue;

  double _frac(double t) =>
      ((t - tempMin) / (tempMax - tempMin)).clamp(0.0, 1.0);

  double _tempAngle(double t) => _kArcSweep * _frac(t);

  /// Arc colour: cool blue (low) → warm amber → hot orange-red (high)
  Color _arcColor(double t) {
    final f   = _frac(t);
    final hue = (220.0 - f * 200.0).clamp(0.0, 360.0);
    final sat = 0.75 + f * 0.15;
    final lit = 0.70 - f * 0.08;
    return HSLColor.fromAHSL(1, hue, sat, lit).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final c  = Offset(cx, cy);
    final r  = math.min(cx, cy) - 20;
    final rc = Rect.fromCircle(center: c, radius: r);

    // ── Background track ─────────────────────────────────────────────────────
    canvas.drawArc(
      rc, _kArcStart, _kArcSweep, false,
      Paint()
        ..color      = Colors.white.withAlpha(28)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap  = StrokeCap.round,
    );

    // ── Filled arc up to setpoint ─────────────────────────────────────────────
    final setptArc = _tempAngle(setpointC);
    if (setptArc > 0) {
      final arcColor = _arcColor(setpointC);
      canvas.drawArc(
        rc, _kArcStart, setptArc, false,
        Paint()
          ..color      = arcColor.withAlpha(190)
          ..style      = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap  = StrokeCap.round,
      );

      // ── Setpoint handle ──────────────────────────────────────────────────
      final ka = _kArcStart + setptArc;
      final kp = c + Offset(math.cos(ka) * r, math.sin(ka) * r);

      if (isHeating && pulseValue > 0) {
        canvas.drawCircle(
          kp,
          11 + pulseValue * 9,
          Paint()
            ..color      = arcColor.withAlpha((70 * (1 - pulseValue)).round())
            ..style      = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      canvas
        ..drawCircle(kp, 11, Paint()..color = arcColor)
        ..drawCircle(
          kp, 11,
          Paint()
            ..color      = Colors.white.withAlpha(90)
            ..style      = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        )
        ..save()
        ..translate(kp.dx, kp.dy)
        ..rotate(ka + math.pi / 2);
      final grip = Paint()
        ..color      = Colors.black.withAlpha(90)
        ..strokeWidth = 1.2
        ..strokeCap  = StrokeCap.round;
      for (var i = -1; i <= 1; i++) {
        canvas.drawLine(Offset(-4.5, i * 2.5), Offset(4.5, i * 2.5), grip);
      }
      canvas.restore();
    }

    // ── Current temperature tick ──────────────────────────────────────────────
    if (currentTempC != null) {
      final ma = _kArcStart + _tempAngle(currentTempC!);
      final d  = Offset(math.cos(ma), math.sin(ma));
      canvas.drawLine(
        c + d * (r - 9),
        c + d * (r + 9),
        Paint()
          ..color      = Colors.white
          ..strokeWidth = 2.5
          ..strokeCap  = StrokeCap.round,
      );
    }

    // ── Centre: current temperature reading ──────────────────────────────────
    final arcCol = _arcColor(setpointC);
    paintDotMatrix(
      canvas,
      c + Offset(0, -r * 0.12),
      currentTempC != null ? '${currentTempC!.toStringAsFixed(1)}°' : '--.-',
      maxWidth:  r * 0.90,
      maxHeight: r * 0.36,
      color:     Colors.white,
    );

    // ── Setpoint below current temp ───────────────────────────────────────────
    paintDotMatrix(
      canvas,
      c + Offset(0, r * 0.32),
      '${setpointC.toStringAsFixed(1)}°',
      maxWidth:  r * 0.65,
      maxHeight: r * 0.22,
      color:     arcCol.withAlpha(220),
    );
  }

  @override
  bool shouldRepaint(_WaterDialPainter o) =>
      o.currentTempC != currentTempC ||
      o.setpointC    != setpointC    ||
      o.isHeating    != isHeating    ||
      o.pulseValue   != pulseValue   ||
      o.tempMin      != tempMin      ||
      o.tempMax      != tempMax;
}
