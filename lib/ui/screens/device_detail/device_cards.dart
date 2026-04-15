part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// On/Off card
// ─────────────────────────────────────────────────────────────────────────────

class _OnOffCard extends StatelessWidget {
  const _OnOffCard({required this.view});
  final DeviceView view;

  @override
  Widget build(BuildContext context) {
    final isStale = view.isStale;
    final isOn = view.isOn;
    final label = isStale ? '--' : (isOn ? 'ON' : 'OFF');

    final litColor = isStale
        ? Colors.white24
        : isOn
        ? Colors.white
        : Colors.white38;

    void toggle() {
      if (!isStale) context.read<DeviceProvider>().toggle(view.id);
    }

    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Function keys ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _FnKey(
                    label: 'ON',
                    selected: !isStale && isOn,
                    enabled: !isStale,
                    onTap: (!isStale && !isOn) ? toggle : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FnKey(
                    label: 'OFF',
                    selected: !isStale && !isOn,
                    enabled: !isStale,
                    onTap: (!isStale && isOn) ? toggle : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Dot-matrix state ───────────────────────────────────────
            SizedBox(
              height: 40,
              child: CustomPaint(
                painter: DotMatrixPainter(text: label, litColor: litColor, dimColor: Colors.white.withAlpha(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Function key ──────────────────────────────────────────────────────────────

class _FnKey extends StatelessWidget {
  const _FnKey({required this.label, required this.selected, required this.enabled, this.onTap});
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? Colors.white
                : enabled
                ? Colors.white24
                : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.black87
                  : enabled
                  ? Colors.white54
                  : Colors.white24,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

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

// ─────────────────────────────────────────────────────────────────────────────
// Sensor readings section
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingsSection extends StatelessWidget {
  const _ReadingsSection({required this.readings, required this.loading});
  final List<ClusterReading>? readings;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (readings == null || readings!.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: readings!.length,
      itemBuilder: (_, i) => _ReadingCard(reading: readings![i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual reading tile  — home-screen card style + dot-matrix value
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.reading});
  final ClusterReading reading;

  /// True when the displayValue is a plain number (usable as dot-matrix input).
  bool get _isNumeric => double.tryParse(reading.displayValue) != null;

  @override
  Widget build(BuildContext context) {
    final isNum = _isNumeric;
    final hasUnit = reading.unit.isNotEmpty;

    return Card(
      color: Colors.white.withAlpha(18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: Colors.white, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top-left: icon + label + quality dot ──────────────────────
            Row(
              children: [
                Icon(reading.icon, size: 14, color: reading.iconColor),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    reading.label,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (reading.quality != null)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: qualityColor(reading.quality!), shape: BoxShape.circle),
                  ),
              ],
            ),

            // ── Centre: value ──────────────────────────────────────────────
            Expanded(
              child: Center(
                child: SizedBox(
                  height: 38,
                  width: double.infinity,
                  child: isNum
                      ? CustomPaint(
                          painter: DotMatrixPainter(
                            text: reading.displayValue,
                            litColor: Colors.white,
                            dimColor: Colors.white.withAlpha(28),
                          ),
                        )
                      : Center(
                          child: Text(
                            reading.displayValue,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
              ),
            ),

            // ── Bottom-right: unit ─────────────────────────────────────────
            if (hasUnit || reading.subtitle != null)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  reading.subtitle != null && !hasUnit ? reading.subtitle! : reading.unit,
                  style: TextStyle(
                    color: reading.quality != null ? qualityColor(reading.quality!) : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Window Covering card
// ─────────────────────────────────────────────────────────────────────────────

class _WindowCoveringCard extends StatelessWidget {
  const _WindowCoveringCard({required this.view});
  final DeviceView view;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStale = view.isStale;
    final lift = view.liftPercent100ths; // 0 = open, 10000 = closed
    final pct = lift != null ? (lift / 100).round() : null; // 0–100 %closed
    final openPct = pct != null ? (100 - pct) : null; // 0–100 %open

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.blinds_outlined,
                  size: 18,
                  color: isStale ? cs.onSurfaceVariant.withAlpha(80) : cs.onSurface,
                ),
                const SizedBox(width: 8),
                Text('Covering', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  isStale || openPct == null ? '--' : '$openPct% open',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Position slider ───────────────────────────────────────────────
            Slider(
              value: openPct?.toDouble().clamp(0, 100) ?? 0,
              max: 100,
              onChanged: isStale ? null : (_) {},
              onChangeEnd: isStale
                  ? null
                  : (v) {
                      final p100 = ((100 - v) * 100).round().clamp(0, 10000);
                      context.read<DeviceProvider>().coveringGoToLift(view.id, p100);
                    },
            ),
            // ── Up / Stop / Down buttons ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CoveringBtn(
                  icon: Icons.keyboard_arrow_up_rounded,
                  label: 'Open',
                  onTap: isStale ? null : () => context.read<DeviceProvider>().coveringUp(view.id),
                ),
                _CoveringBtn(
                  icon: Icons.stop_rounded,
                  label: 'Stop',
                  onTap: isStale ? null : () => context.read<DeviceProvider>().coveringStop(view.id),
                ),
                _CoveringBtn(
                  icon: Icons.keyboard_arrow_down_rounded,
                  label: 'Close',
                  onTap: isStale ? null : () => context.read<DeviceProvider>().coveringDown(view.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoveringBtn extends StatelessWidget {
  const _CoveringBtn({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: onTap == null ? cs.onSurfaceVariant.withAlpha(80) : cs.onSurface),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: onTap == null ? cs.onSurfaceVariant.withAlpha(80) : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fan Control card
// ─────────────────────────────────────────────────────────────────────────────

class _FanControlCard extends StatelessWidget {
  const _FanControlCard({required this.view});
  final DeviceView view;

  static const _modes = ['Off', 'Low', 'Med', 'High', 'On', 'Auto'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStale = view.isStale;
    final mode = view.fanMode;
    final pct = view.fanPercent;

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.wind_power_outlined,
                  size: 18,
                  color: isStale ? cs.onSurfaceVariant.withAlpha(80) : cs.onSurface,
                ),
                const SizedBox(width: 8),
                Text('Fan', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(isStale || pct == null ? '--' : '$pct%', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            // ── Speed slider ──────────────────────────────────────────────────
            Slider(
              value: pct?.toDouble().clamp(0, 100) ?? 0,
              max: 100,
              onChanged: isStale ? null : (_) {},
              onChangeEnd: isStale ? null : (v) => context.read<DeviceProvider>().setFanPercent(view.id, v.round()),
            ),
            // ── Mode chips ────────────────────────────────────────────────────
            Wrap(
              spacing: 6,
              children: List.generate(_modes.length, (i) {
                final selected = mode == i;
                return ChoiceChip(
                  label: Text(_modes[i]),
                  selected: selected,
                  onSelected: isStale ? null : (_) => context.read<DeviceProvider>().setFanMode(view.id, i),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Color Temperature card
// ─────────────────────────────────────────────────────────────────────────────

class _ColorTemperatureCard extends StatelessWidget {
  const _ColorTemperatureCard({required this.view});
  final DeviceView view;

  // Practical range: 153 mireds (6500 K cool) – 500 mireds (2000 K warm)
  static const _minMireds = 153.0;
  static const _maxMireds = 500.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStale = view.isStale;
    final mireds = view.colorTempMireds?.toDouble().clamp(_minMireds, _maxMireds) ?? (_minMireds + _maxMireds) / 2;
    final kelvin = (1_000_000 / mireds).round();

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                  size: 18,
                  color: isStale ? cs.onSurfaceVariant.withAlpha(80) : Colors.amber,
                ),
                const SizedBox(width: 8),
                Text(
                  'Color Temperature',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(isStale ? '--' : '${kelvin}K', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            // cool ←─── slider ───→ warm
            Row(
              children: [
                Icon(Icons.ac_unit, size: 14, color: Colors.lightBlue.shade300),
                Expanded(
                  child: Slider(
                    value: mireds,
                    min: _minMireds,
                    max: _maxMireds,
                    onChanged: isStale ? null : (_) {},
                    onChangeEnd: isStale
                        ? null
                        : (v) => context.read<DeviceProvider>().setColorTemperature(view.id, v.round()),
                  ),
                ),
                Icon(Icons.local_fire_department, size: 14, color: Colors.orange.shade400),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smoke / CO Alarm card  (read-only)
// ─────────────────────────────────────────────────────────────────────────────

class _SmokeAlarmCard extends StatelessWidget {
  const _SmokeAlarmCard({required this.view});
  final DeviceView view;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStale = view.isStale;
    final smoke = isStale ? null : view.smokeState;
    final co = isStale ? null : view.coState;
    final anyAlarm = (smoke ?? 0) > 0 || (co ?? 0) > 0;

    Color stateColor() {
      final worst = [(smoke ?? 0), (co ?? 0)].reduce((a, b) => a > b ? a : b);
      return switch (worst) {
        2 => Colors.red.shade500,
        1 => Colors.orange.shade500,
        _ => Colors.green.shade500,
      };
    }

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  anyAlarm ? Icons.warning_rounded : Icons.check_circle_outline,
                  size: 18,
                  color: isStale ? cs.onSurfaceVariant.withAlpha(80) : stateColor(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Smoke / CO Alarm',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AlarmIndicator(label: 'Smoke', state: smoke),
                _AlarmIndicator(label: 'CO', state: co),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmIndicator extends StatelessWidget {
  // 0=Normal 1=Warning 2=Critical null=unknown

  const _AlarmIndicator({required this.label, this.state});
  final String label;
  final int? state;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    if (state == null) {
      color = Colors.grey;
      text = '--';
    } else if (state == 2) {
      color = Colors.red.shade500;
      text = 'Critical';
    } else if (state == 1) {
      color = Colors.orange.shade500;
      text = 'Warning';
    } else {
      color = Colors.green.shade500;
      text = 'OK';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
