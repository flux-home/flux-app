part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Thermostat card
// ─────────────────────────────────────────────────────────────────────────────

class _ThermostatCard extends StatelessWidget {
  final ThermostatState?               state;
  final int?                           pendingSetpt;
  final int?                           pendingMode;
  final int?                           humidityCenti;
  final BatteryInfo?                   battery;
  final String?                        serialNumber;
  final String?                        softwareVersion;
  final Future<void> Function(double)  onSetSetpoint;
  final Future<void> Function(int)     onSetMode;

  const _ThermostatCard({
    required this.state,           required this.pendingSetpt,
    required this.pendingMode,     required this.humidityCenti,
    required this.battery,         required this.serialNumber,
    required this.softwareVersion, required this.onSetSetpoint,
    required this.onSetMode,
  });

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final setpointC = pendingSetpt != null
        ? pendingSetpt! / 100.0
        : state?.heatingSetptC;

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _ThermostatDial(
            measuredTempC:     state?.localTempC,
            setpointC:         setpointC,
            supportsCooling:   state?.supportsCooling ?? false,
            coolingSetptC:     state?.coolingSetptC,
            onSetpointChanged: (v) {},
            onSetpointEnd:     state != null ? onSetSetpoint : (_) {},
          ),
          const SizedBox(height: 16),
          if (state != null)
            _ModeSelector(
              modes:    state!.availableModes,
              current:  pendingMode ?? state!.systemMode,
              onSelect: onSetMode,
            ),
          if (humidityCenti != null || battery != null) ...[
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (humidityCenti != null)
                _SensorPill(
                  icon: Icons.water_drop_outlined,
                  iconColor: Colors.lightBlue[300]!,
                  value: '${(humidityCenti! / 100.0).toStringAsFixed(0)} %',
                  label: 'humidity',
                ),
              if (humidityCenti != null && battery != null)
                const SizedBox(width: 24),
              if (battery != null) _BatteryPill(battery: battery!),
            ]),
          ],
          if (serialNumber != null || softwareVersion != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (serialNumber    != null) InfoRow(label: 'Serial',     value: serialNumber!,     labelWidth: 90, mono: true),
            if (softwareVersion != null) InfoRow(label: 'SW version', value: softwareVersion!,  labelWidth: 90, mono: true),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thermostat dial
// ─────────────────────────────────────────────────────────────────────────────

const _kArcStart = 135.0 * math.pi / 180.0;
const _kArcSweep = 270.0 * math.pi / 180.0;
const _kTempMin  = 5.0;
const _kTempMax  = 35.0;

class _ThermostatDial extends StatefulWidget {
  final double? measuredTempC, setpointC, coolingSetptC;
  final bool    supportsCooling;
  final void Function(double) onSetpointChanged, onSetpointEnd;

  const _ThermostatDial({
    required this.measuredTempC, required this.setpointC,
    required this.supportsCooling, required this.coolingSetptC,
    required this.onSetpointChanged, required this.onSetpointEnd,
  });

  @override
  State<_ThermostatDial> createState() => _ThermostatDialState();
}

class _ThermostatDialState extends State<_ThermostatDial> {
  double? _dragTemp;
  double get _setpoint => _dragTemp ?? widget.setpointC ?? 20.0;
  bool   get _hasData  => widget.setpointC != null;

  double _angleToTemp(double angleDeg) {
    final startDeg = _kArcStart * 180 / math.pi;
    var rel = ((angleDeg - startDeg) % 360 + 360) % 360;
    if (rel > 270) rel = (rel - 270 < 360 - rel) ? 270 : 0;
    return (_kTempMin + (rel / 270) * (_kTempMax - _kTempMin))
        .clamp(_kTempMin, _kTempMax);
  }

  void _handleDrag(Offset pos, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    var deg = math.atan2(pos.dy - c.dy, pos.dx - c.dx) * 180 / math.pi;
    if (deg < 0) deg += 360;
    final snapped = ((_angleToTemp(deg) * 2).round() / 2.0)
        .clamp(_kTempMin, _kTempMax);
    setState(() => _dragTemp = snapped);
    widget.onSetpointChanged(snapped);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final side = c.maxWidth;
      return SizedBox(width: side, height: side,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) { if (_hasData) _handleDrag(d.localPosition, Size(side, side)); },
          onPanEnd: (_) {
            if (_dragTemp != null) {
              widget.onSetpointEnd(_dragTemp!);
              setState(() => _dragTemp = null);
            }
          },
          child: CustomPaint(painter: _DialPainter(
            measuredTempC: widget.measuredTempC,
            setpointC:     _hasData ? _setpoint : null,
            coolingSetptC: widget.supportsCooling ? widget.coolingSetptC : null,
          )),
        ),
      );
    });
  }
}

class _DialPainter extends CustomPainter {
  final double? measuredTempC, setpointC, coolingSetptC;
  const _DialPainter({required this.measuredTempC, required this.setpointC,
                      this.coolingSetptC});

  double _frac(double t) =>
      ((t - _kTempMin) / (_kTempMax - _kTempMin)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final c  = Offset(cx, cy);
    final r  = math.min(cx, cy) - 20;
    final rc = Rect.fromCircle(center: c, radius: r);

    canvas.drawArc(rc, _kArcStart, _kArcSweep, false,
        Paint()..color=Colors.white.withAlpha(45)..style=PaintingStyle.stroke
               ..strokeWidth=2.5..strokeCap=StrokeCap.round);

    if (setpointC != null) {
      final f = _frac(setpointC!);
      if (f > 0) canvas.drawArc(rc, _kArcStart, _kArcSweep * f, false,
          Paint()..color=Colors.white..style=PaintingStyle.stroke
                 ..strokeWidth=2.5..strokeCap=StrokeCap.round);
      final ka = _kArcStart + _kArcSweep * f;
      final kp = c + Offset(math.cos(ka)*r, math.sin(ka)*r);
      canvas.drawCircle(kp, 9, Paint()..color=Colors.white);
      canvas.drawCircle(kp, 9, Paint()..color=Colors.white.withAlpha(80)
          ..style=PaintingStyle.stroke..strokeWidth=3);
    }
    if (measuredTempC != null) {
      final ma = _kArcStart + _kArcSweep * _frac(measuredTempC!);
      final d  = Offset(math.cos(ma), math.sin(ma));
      canvas.drawLine(c+d*(r-9), c+d*(r+9),
          Paint()..color=Colors.white..strokeWidth=2..strokeCap=StrokeCap.round);
    }
    if (coolingSetptC != null) {
      final ca = _kArcStart + _kArcSweep * _frac(coolingSetptC!);
      final d  = Offset(math.cos(ca), math.sin(ca));
      canvas.drawLine(c+d*(r-6), c+d*(r+6),
          Paint()..color=Colors.lightBlue.withAlpha(200)..strokeWidth=1.5
                 ..strokeCap=StrokeCap.round);
    }
    paintDotMatrix(canvas, c + Offset(0, -r * 0.18),
        setpointC != null ? setpointC!.toStringAsFixed(1) : '--.-',
        maxWidth: r * 1.0, maxHeight: r * 0.30, color: Colors.white);
    paintDotMatrix(canvas, c + Offset(0, r * 0.22),
        measuredTempC != null ? measuredTempC!.toStringAsFixed(1) : '--.-',
        maxWidth: r * 0.70, maxHeight: r * 0.20, color: Colors.white.withAlpha(160));
  }

  @override
  bool shouldRepaint(_DialPainter o) =>
      o.measuredTempC!=measuredTempC||o.setpointC!=setpointC||o.coolingSetptC!=coolingSetptC;
}


// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SensorPill extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String value, label;
  const _SensorPill({required this.icon, required this.iconColor,
                     required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: iconColor), const SizedBox(width: 6),
      Text(value, style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: cs.onSurfaceVariant)),
    ]);
  }
}

class _BatteryPill extends StatelessWidget {
  final BatteryInfo battery;
  const _BatteryPill({required this.battery});
  @override
  Widget build(BuildContext context) {
    if (battery.percent != null) {
      final pct = battery.percent!;
      final icon  = pct>75?Icons.battery_full:pct>50?Icons.battery_5_bar
                   :pct>25?Icons.battery_3_bar:pct>10?Icons.battery_1_bar:Icons.battery_alert;
      final color = pct>25?Colors.green.shade400:pct>10?Colors.orange.shade400:Colors.red.shade400;
      return _SensorPill(icon:icon, iconColor:color, value:'$pct %', label:'battery');
    }
    if (battery.chargeLevel != null) {
      final (icon, color, text) = switch (battery.chargeLevel!) {
        1 => (Icons.battery_3_bar, Colors.orange.shade400, 'Warning'),
        2 => (Icons.battery_alert,  Colors.red.shade400,   'Critical'),
        _ => (Icons.battery_full,   Colors.green.shade400, 'OK'),
      };
      return _SensorPill(icon:icon, iconColor:color, value:text, label:'battery');
    }
    if (battery.voltageMilliV != null) {
      return _SensorPill(icon:Icons.battery_std, iconColor:Colors.green.shade400,
          value:'${(battery.voltageMilliV!/1000.0).toStringAsFixed(2)} V', label:'battery');
    }
    return const SizedBox.shrink();
  }
}

class _ModeSelector extends StatelessWidget {
  final List<({int mode, String label})> modes;
  final int? current;
  final ValueChanged<int> onSelect;
  const _ModeSelector({required this.modes, required this.current, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
      children: modes.map((m) {
        final sel = current == m.mode;
        return ChoiceChip(
          label: Text(m.label), selected: sel,
          onSelected: (_) => onSelect(m.mode),
          selectedColor: Colors.black87, backgroundColor: Colors.transparent,
          labelStyle: TextStyle(fontWeight: sel?FontWeight.bold:FontWeight.normal,
                                color: sel?Colors.white:Colors.black87),
          side: BorderSide(color: sel?Colors.black87:Colors.black26),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
