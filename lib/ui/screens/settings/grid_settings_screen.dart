import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'package:matter_home/utils/power_format.dart';

/// What the grid connection allows, and what the controller is doing about it.
///
/// The limit is the one number in the energy system that nothing on the network
/// reports: it comes from the grid operator. It lives on the controller because
/// the controller is what enforces it — a limit held only on a phone stops
/// existing when the phone does, which is exactly when it still has to hold.
///
/// The screen carries the reasoning as well as the number. A regulatory limit
/// outlives the memory of why it was set, and a year from now the difference
/// between a rule that still applies and one that expired is the note someone
/// wrote at the time.
///
/// Writes are LAN-only on the controller (flux-proto ADR-0012), so the save
/// button is disabled over a remote tunnel rather than failing after the fact.
class GridSettingsScreen extends StatefulWidget {
  const GridSettingsScreen({super.key});

  @override
  State<GridSettingsScreen> createState() => _GridSettingsScreenState();
}

class _GridSettingsScreenState extends State<GridSettingsScreen> {
  final _limit = TextEditingController();
  final _margin = TextEditingController();
  final _pvBase = TextEditingController();
  final _basis = TextEditingController();

  bool _enabled = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<DeviceProvider>();
      final cfg = await p.fetchEnergyLimits();
      await p.fetchEnergyControl();
      if (!mounted || cfg == null) return;
      setState(() {
        _enabled = cfg.enabled;
        _limit.text = cfg.exportLimitW == 0 ? '' : cfg.exportLimitW.toString();
        _margin.text = cfg.exportMarginW == 0 ? '' : cfg.exportMarginW.toString();
        _pvBase.text = cfg.pvBaseLimitW == 0 ? '' : cfg.pvBaseLimitW.toString();
        _basis.text = cfg.basis;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_limit, _margin, _pvBase, _basis]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _save() async {
    final limit = _int(_limit);
    if (_enabled && (limit == null || limit <= 0)) {
      _snack('Enter the limit your grid operator allows');
      return;
    }
    final margin = _int(_margin) ?? 0;
    final base = _int(_pvBase) ?? 0;
    if (_enabled && margin >= (limit ?? 0)) {
      _snack('The margin has to be smaller than the limit');
      return;
    }
    if (_enabled && base > (limit ?? 0)) {
      _snack('What the inverter may make alone cannot exceed the limit');
      return;
    }

    final p = context.read<DeviceProvider>();
    final cfg = p.energyLimits?.deepCopy() ?? $proto.EnergyLimits();
    cfg
      ..enabled = _enabled
      ..exportLimitW = limit ?? 0
      ..exportMarginW = margin
      ..pvBaseLimitW = base
      ..basis = _basis.text.trim();

    setState(() => _saving = true);
    final ok = await p.updateEnergyLimits(cfg);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(ok ? 'Grid limits saved' : "Couldn't save — on the local network?");
    if (ok) Navigator.of(context).pop();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hub = context.watch<HubConnection>();
    final p = context.watch<DeviceProvider>();
    final canWrite = hub.connectionKind == ConnectionKind.local;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grid connection',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'How much your installation may feed into the grid. Your grid '
            'operator sets this — nothing on the network reports it, so it is '
            'the one number you have to supply.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          if (p.energyControl != null) _NowPanel(state: p.energyControl!),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: _loaded ? (v) => setState(() => _enabled = v) : null,
            title: const Text('Hold the house inside the limit'),
            subtitle: Text(
                'Off means the controller enforces nothing at all.',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          const Divider(height: 24),

          _label(context, 'THE LIMIT'),
          _field(_limit, 'Feed-in limit', '11600', 'W',
              helper: 'Measured where the meter sees everything that feeds in, '
                  'including a balcony plant on the same connection.'),
          const SizedBox(height: 14),
          _field(_basis, 'Where it comes from',
              '60% of 18 kWp + 800 W balcony', '',
              text: true,
              helper: 'For your own benefit later. A limit outlives the memory '
                  'of why it was set.'),
          const SizedBox(height: 24),

          _label(context, 'HOW IT IS HELD'),
          _field(_pvBase, 'Solar alone may make', '10800', 'W',
              helper: 'The limit minus anything else that feeds in beside the '
                  'inverter. Safe to leave in place, so it is what the '
                  'controller falls back to whenever it is not in control.'),
          const SizedBox(height: 14),
          _field(_margin, 'Stay below by', '200', 'W',
              helper: 'Absorbs what changes between two readings. Blank = 200.'),
          const SizedBox(height: 10),
          Text(
            'Surplus above the limit goes into a battery first, and the '
            'inverter is only throttled when there is nowhere to put it.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          if (!canWrite)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                hub.isOnline
                    ? 'Connected remotely — these can only be changed on your '
                      'home network.'
                    : 'Controller unreachable.',
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ),
          FilledButton(
            onPressed: (_saving || !canWrite || !_loaded) ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: TextStyle(
            fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _field(TextEditingController c, String label, String hint, String unit,
      {String? helper, bool text = false}) {
    return TextField(
      controller: c,
      keyboardType: text ? TextInputType.text : TextInputType.number,
      inputFormatters: text
          ? null
          : [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        suffixText: unit.isEmpty ? null : unit,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// What the engine is doing, above the settings that cause it.
///
/// A held limit and a passing cloud look identical in the power readings, so
/// this is the only place the difference is visible. It also names why a
/// battery is not absorbing: full is a limitation, not following is a fault,
/// and they want different reactions from the reader.
class _NowPanel extends StatelessWidget {
  const _NowPanel({required this.state});
  final $proto.EnergyControl state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final String line;
    Color tone = cs.primary;
    if (!state.enabled) {
      line = 'Not enforcing anything.';
      tone = cs.onSurfaceVariant;
    } else if (!state.armed) {
      line = 'Enabled, but not measuring the grid yet.';
      tone = const Color(0xFFE0894A);
    } else if (state.curtailing) {
      line = 'Holding solar at ${powerLabelW(state.pvLimitW.toDouble())} — '
          'exporting ${powerLabelW(state.exportW.toDouble())}.';
      tone = const Color(0xFFE8C14A);
    } else {
      line = 'Exporting ${powerLabelW(state.exportW.toDouble())}, '
          'inside the limit.';
    }

    String? battery;
    if (!state.enabled || state.batteryNodeId.toInt() == 0) {
      battery = null;
    } else if (state.batteryFull) {
      battery = 'Battery full — surplus is curtailed, not stored.';
    } else if (state.batteryStalled) {
      battery = 'Battery is taking setpoints but not following them.';
    } else if (state.batteryW > 50) {
      battery = 'Battery absorbing ${powerLabelW(state.batteryW.toDouble())}.';
    } else {
      battery = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line, style: const TextStyle(fontSize: 14, height: 1.35)),
                if (battery != null) ...[
                  const SizedBox(height: 3),
                  Text(battery,
                      style: TextStyle(
                          fontSize: 12.5, color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
