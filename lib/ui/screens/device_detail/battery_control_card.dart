part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Battery control card — Device Energy Management power adjustment
//
//   ┌──────────────────────────────────────────────┐
//   │ ⚡ Battery control              ● Auto        │  ← state chip
//   │                                              │
//   │  [ Charge | Discharge ]                      │
//   │  Power ───────────●─────────────   300 W     │
//   │  For   (15 min) (30 min) (1 h) (2 h) (4 h)   │
//   │                     [ Start charging ]       │
//   └──────────────────────────────────────────────┘
//
// While a hold runs the controls collapse to what it is doing, the time left,
// and "Return to auto". A hold always ends by itself — the battery is never
// left forced if the app goes away.
//
// Shown for any device whose live attributes advertise DEM PowerAdjustment, so
// a Matter battery gets the same card as a Modbus one. No optimistic state:
// after Start the card waits for esaState to report the hold.
// ─────────────────────────────────────────────────────────────────────────────

enum _AdjustMode { charge, discharge }

/// The words for one control verb.
///
/// A battery told "−2 kW" is discharging; an inverter told the same is being
/// capped at 2 kW of output. Identical request, opposite feeling, so the card
/// carries a vocabulary rather than a second implementation.
class _Words {
  const _Words({
    required this.title,
    required this.icon,
    required this.verb,
    required this.setpointLabel,
    required this.actionLabel,
    required this.actionIcon,
    required this.releaseLabel,
    required this.noTakeError,
    required this.refusedError,
    required this.releaseError,
  });

  factory _Words.of(PowerAdjust a) => a.isGenerationOnly
      ? _Words(
          title: 'Output limit',
          icon: Icons.solar_power_outlined,
          // The limit is what the inverter may produce, so it reads as a
          // ceiling, not as something being done to it.
          verb: (mw) => 'Limited to',
          setpointLabel: 'Limit output to',
          // Not "start" anything: the inverter is already generating, and this
          // only puts a ceiling on it.
          actionLabel: 'Limit power',
          actionIcon: Icons.vertical_align_bottom,
          releaseLabel: 'Remove limit',
          noTakeError: 'The inverter did not take the limit. '
              'It may be asleep — a PV inverter stops answering after dark.',
          refusedError: 'The inverter refused the limit.',
          releaseError: 'Could not remove the limit.',
        )
      : _Words(
          title: 'Battery control',
          icon: Icons.bolt_outlined,
          verb: (mw) => mw > 0 ? 'Charging at' : 'Discharging at',
          setpointLabel: 'Power',
          actionLabel: 'Set power level',
          actionIcon: Icons.play_arrow_outlined,
          releaseLabel: 'Return to auto',
          noTakeError: 'The battery did not take the setpoint. '
              'Check its connection.',
          refusedError: 'The battery refused the request.',
          releaseError: 'Could not return the battery to auto.',
        );

  final String title;
  final IconData icon;
  final String Function(int mw) verb;
  final String setpointLabel;
  final String actionLabel;
  final IconData actionIcon;
  final String releaseLabel;
  final String noTakeError;
  final String refusedError;
  final String releaseError;

}

class BatteryControlCard extends StatefulWidget {
  const BatteryControlCard({
    required this.adjust,
    required this.onStart,
    required this.onCancel,
    this.enabled = true,
    super.key,
  });

  final PowerAdjust adjust;

  /// Sends PowerAdjustRequest; resolves true if the controller accepted it.
  final Future<bool> Function(int powerMw, Duration duration) onStart;

  /// Sends CancelPowerAdjustRequest.
  final Future<bool> Function() onCancel;

  /// False while the device is stale/unreachable.
  final bool enabled;

  @override
  State<BatteryControlCard> createState() => _BatteryControlCardState();
}

class _BatteryControlCardState extends State<BatteryControlCard> {
  static const int _stepW = 50;
  static const int _defaultW = 500;

  late _AdjustMode _mode;
  late int _watts;
  late Duration _duration;
  bool _busy = false;

  /// Set after a successful Start until the device reports the hold.
  bool _awaitingDevice = false;
  Timer? _awaitTimer;

  PowerAdjust get _a => widget.adjust;
  _Words get _w => _Words.of(_a);

  @override
  void initState() {
    super.initState();
    _mode = _a.canCharge ? _AdjustMode.charge : _AdjustMode.discharge;
    _watts = _defaultW.clamp(_stepW, _maxW(_mode));
    final choices = _a.durationChoices();
    _duration = choices.contains(const Duration(hours: 1))
        ? const Duration(hours: 1)
        : choices.first;
  }

  @override
  void didUpdateWidget(BatteryControlCard old) {
    super.didUpdateWidget(old);
    if (_awaitingDevice && widget.adjust.isActive) {
      _awaitTimer?.cancel();
      _awaitingDevice = false;
    }
    final max = _maxW(_mode);
    if (_watts > max) _watts = max;
    if (_duration > _a.maxDuration) _duration = _a.durationChoices().last;
  }

  @override
  void dispose() {
    _awaitTimer?.cancel();
    super.dispose();
  }

  int _maxW(_AdjustMode m) {
    final mw = m == _AdjustMode.charge ? _a.maxPowerMw : -_a.minPowerMw;
    final w = mw ~/ 1000;
    return w < _stepW ? _stepW : w;
  }

  Future<void> _start() async {
    if (_busy) return;
    unawaited(HapticFeedback.mediumImpact());
    final sign = _mode == _AdjustMode.charge ? 1 : -1;
    final mw = _a.clampPowerMw(sign * _watts * 1000);
    setState(() => _busy = true);
    try {
      final ok = await widget.onStart(mw, _duration);
      if (!mounted) return;
      if (ok) {
        setState(() => _awaitingDevice = true);
        _awaitTimer?.cancel();
        _awaitTimer = Timer(const Duration(seconds: 20), () {
          if (!mounted || !_awaitingDevice) return;
          setState(() => _awaitingDevice = false);
          _showError(_w.noTakeError);
        });
      } else {
        _showError(_w.refusedError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _busy = true);
    try {
      final ok = await widget.onCancel();
      if (!ok && mounted) _showError(_w.releaseError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = _a.isActive;
    final controllable = widget.enabled && !_a.isOffline && !_busy;

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_w.icon, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(_w.title,
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                _StateChip(adjust: _a, awaiting: _awaitingDevice),
              ],
            ),
            const SizedBox(height: 14),
            if (active) ..._activeBody(context, controllable)
            else ..._idleBody(context, controllable),
          ],
        ),
      ),
    );
  }

  List<Widget> _activeBody(BuildContext context, bool controllable) {
    final cs = Theme.of(context).colorScheme;
    final mw = _a.activePowerMw;
    final String headline;
    if (mw == null) {
      headline = 'Following an energy manager';
    } else if (mw == 0) {
      headline = 'Holding at 0 W';
    } else {
      headline = '${_w.verb(mw)} ${powerLabelW(mw.abs() / 1000.0)}';
    }
    final rem = _a.remaining;
    return [
      Text(headline, style: Theme.of(context).textTheme.titleMedium),
      if (rem != null) ...[
        const SizedBox(height: 2),
        Text('${_formatDuration(rem)} left, then back to auto',
            style: TextStyle(color: cs.onSurfaceVariant)),
      ],
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.tonalIcon(
          onPressed: controllable ? _cancel : null,
          icon: const Icon(Icons.autorenew),
          label: Text(_w.releaseLabel),
        ),
      ),
    ];
  }

  List<Widget> _idleBody(BuildContext context, bool controllable) {
    final cs = Theme.of(context).colorScheme;
    final maxW = _maxW(_mode);
    final steps = maxW ~/ _stepW;
    return [
      if (_a.canCharge && _a.canDischarge)
        SegmentedButton<_AdjustMode>(
          segments: const [
            ButtonSegment(value: _AdjustMode.charge,
                icon: Icon(Icons.battery_charging_full_outlined),
                label: Text('Charge')),
            ButtonSegment(value: _AdjustMode.discharge,
                icon: Icon(Icons.home_outlined),
                label: Text('Discharge')),
          ],
          selected: {_mode},
          onSelectionChanged: controllable
              ? (s) => setState(() {
                    _mode = s.first;
                    _watts = _watts.clamp(_stepW, _maxW(_mode));
                  })
              : null,
        ),
      const SizedBox(height: 10),
      Row(
        children: [
          Text(_w.setpointLabel, style: TextStyle(color: cs.onSurfaceVariant)),
          Expanded(
            child: Slider(
              value: _watts.toDouble().clamp(_stepW.toDouble(), maxW.toDouble()),
              min: _stepW.toDouble(),
              max: maxW.toDouble(),
              divisions: steps > 1 ? steps - 1 : null,
              label: powerLabelW(_watts.toDouble()),
              onChanged: controllable
                  ? (v) => setState(() => _watts = (v / _stepW).round() * _stepW)
                  : null,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(powerLabelW(_watts.toDouble()),
                textAlign: TextAlign.right,
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('For', style: TextStyle(color: cs.onSurfaceVariant)),
          for (final d in _a.durationChoices())
            ChoiceChip(
              label: Text(_formatDuration(d)),
              selected: d == _duration,
              onSelected: controllable ? (_) => setState(() => _duration = d) : null,
            ),
        ],
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: controllable && !_awaitingDevice ? _start : null,
          icon: Icon(_a.isGenerationOnly
              ? _w.actionIcon
              : (_mode == _AdjustMode.charge
                  ? Icons.battery_charging_full_outlined
                  : Icons.home_outlined)),
          label: Text(_w.actionLabel),
        ),
      ),
    ];
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.adjust, required this.awaiting});
  final PowerAdjust adjust;
  final bool awaiting;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (adjust.state) {
      _ when awaiting && !adjust.isActive => ('Sending…', cs.onSurfaceVariant),
      PowerAdjust.statePowerAdjustActive => ('Manual', Colors.amber.shade400),
      PowerAdjust.stateOffline => ('Offline', cs.onSurfaceVariant),
      PowerAdjust.stateFault => ('Fault', Colors.red.shade400),
      PowerAdjust.statePaused => ('Paused', cs.onSurfaceVariant),
      _ => ('Auto', Colors.green.shade400),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

String _formatDuration(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds} s';
  if (d.inHours < 1) return '${d.inMinutes} min';
  final m = d.inMinutes % 60;
  return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
}
