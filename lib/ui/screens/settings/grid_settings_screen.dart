import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/energy_role.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;

/// What the grid connection allows: the EEG §9 feed-in limit, and whether the
/// controller holds the house inside it.
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
  /// 0 = let the controller choose.
  $fixnum.Int64 _meter = $fixnum.Int64.ZERO;

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
        _meter = cfg.meterNodeId;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _save() async {
    final limit = _int(_limit);
    if (_enabled && (limit == null || limit <= 0)) {
      _snack('Enter the limit your grid operator allows');
      return;
    }
    final p = context.read<DeviceProvider>();
    final cfg = p.energyLimits?.deepCopy() ?? $proto.EnergyLimits();
    // Margin and the inverter's unaided limit are left at zero on purpose: the
    // controller fills in its own default for the first and measures the second
    // from whatever else feeds in. Neither is a number a person should maintain.
    cfg
      ..enabled = _enabled
      ..exportLimitW = limit ?? 0
      ..exportMarginW = 0
      ..pvBaseLimitW = 0
      ..meterNodeId = _meter;

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
        title: const Text('Energy Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: _loaded ? (v) => setState(() => _enabled = v) : null,
            title: const Text('Feed-in limit'),
            subtitle: Text(
                'Off means the controller enforces nothing.',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limit,
            enabled: _enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
            decoration: const InputDecoration(
              labelText: 'Limit',
              hintText: '11600',
              suffixText: 'W',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text('EEG §9 limit.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 22),

          DropdownButtonFormField<$fixnum.Int64>(
            initialValue: _meter,
            decoration: const InputDecoration(
              labelText: 'Measured at',
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                  value: $fixnum.Int64.ZERO,
                  child: const Text('Choose automatically')),
              for (final d in _meterChoices(p))
                DropdownMenuItem(
                    value: $fixnum.Int64(d.nodeId), child: Text(d.name)),
            ],
            onChanged: _enabled
                ? (v) => setState(() => _meter = v ?? $fixnum.Int64.ZERO)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            'The limit applies at the grid connection, so this has to be a '
            'meter that sees everything feeding in — including anything on its '
            'own supply.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 18),

          if (p.energyControl != null) _Cadence(state: p.energyControl!),
          const SizedBox(height: 18),

          if (!canWrite)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                hub.isOnline
                    ? 'Connected remotely — this can only be changed on your '
                      'home network.'
                    : 'Controller unreachable.',
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ),
          FilledButton(
            onPressed: (_saving || !canWrite || !_loaded) ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}

/// Candidate meters: anything the controller could regulate against. A device
/// publishing a system-level grid reading qualifies whatever its own role, which
/// is how a battery inverter's system service ends up in this list.
List<DeviceView> _meterChoices(DeviceProvider p) => [
      for (final d in p.deviceViews)
        if (d.energyRole == EnergyRole.grid ||
            (d.live?.attrs.containsKey('gridActivePower') ?? false))
          d,
    ];

/// How often the loop runs, and against which meter — read-only, because both
/// are the engine's own doing rather than anything to choose.
class _Cadence extends StatelessWidget {
  const _Cadence({required this.state});
  final $proto.EnergyControl state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ms = state.intervalMs;
    final every = ms >= 1000
        ? '${(ms / 1000).toStringAsFixed(ms % 1000 == 0 ? 0 : 1)} s'
        : '$ms ms';
    return Row(
      children: [
        Icon(Icons.update, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.armed
                ? 'Checked every $every.'
                : 'Checked every $every — not reading a meter yet.',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
