part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brightness card
// ─────────────────────────────────────────────────────────────────────────────

class _BrightnessCard extends StatefulWidget {
  const _BrightnessCard({required this.brightness, required this.onChanged});
  final double brightness;
  final ValueChanged<double> onChanged;

  @override
  State<_BrightnessCard> createState() => _BrightnessCardState();
}

class _BrightnessCardState extends State<_BrightnessCard> {
  double? _drag;

  double get _display => (_drag ?? widget.brightness).clamp(0.01, 1.0);

  static Color _trackColor(double f) {
    if (f < 0.01) return Colors.white.withAlpha(40);
    final hue = 200.0 - f * 165.0;
    final sat = 0.75 + f * 0.13;
    final lit = 0.78 - f * 0.02;
    return HSLColor.fromAHSL(1, hue.clamp(0, 360), sat, lit).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final f = _display;
    final color = _trackColor(f);
    final label = '${(f * 100).round()}%';

    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.brightness_6_outlined, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  'Brightness',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: CustomPaint(
                painter: DotMatrixPainter(text: label, litColor: color, dimColor: Colors.white.withAlpha(20)),
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (_, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    final v = (d.localPosition.dx / constraints.maxWidth).clamp(0.01, 1.0);
                    setState(() => _drag = v);
                  },
                  onHorizontalDragEnd: (_) {
                    final committed = _drag;
                    setState(() => _drag = null);
                    if (committed != null) widget.onChanged(committed);
                  },
                  onTapUp: (d) {
                    final v = (d.localPosition.dx / constraints.maxWidth).clamp(0.01, 1.0);
                    setState(() => _drag = null);
                    widget.onChanged(v);
                  },
                  child: SizedBox(
                    height: 44,
                    child: CustomPaint(
                      painter: _BrightnessTrackPainter(fraction: f, color: color),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BrightnessTrackPainter extends CustomPainter {
  const _BrightnessTrackPainter({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  static const double _knobR = 11;
  static const double _trackH = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const x0 = _knobR;
    final x1 = size.width - _knobR;
    final kx = x0 + fraction * (x1 - x0);

    final bgRect = Rect.fromLTRB(x0, cy - _trackH / 2, x1, cy + _trackH / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(2)),
      Paint()..color = Colors.white.withAlpha(28),
    );
    if (fraction > 0.01) {
      final fillRect = Rect.fromLTRB(x0, cy - _trackH / 2, kx, cy + _trackH / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, const Radius.circular(2)),
        Paint()..color = color.withAlpha(190),
      );
    }
    final kp = Offset(kx, cy);
    canvas
      ..drawCircle(kp, _knobR, Paint()..color = color)
      ..drawCircle(
        kp,
        _knobR,
        Paint()
          ..color = Colors.white.withAlpha(90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..save()
      ..translate(kx, cy);
    final grip = Paint()
      ..color = Colors.black.withAlpha(90)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(Offset(-4.5, i * 2.5), Offset(4.5, i * 2.5), grip);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrightnessTrackPainter o) => o.fraction != fraction || o.color != color;
}
