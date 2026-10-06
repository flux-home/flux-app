import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;

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

  bool _enabled = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<DeviceProvider>();
      final cfg = await p.fetchEnergyLimits();
      if (!mounted || cfg == null) return;
      setState(() {
        _enabled = cfg.enabled;
        _limit.text = cfg.exportLimitW == 0 ? '' : cfg.exportLimitW.toString();
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
      ..pvBaseLimitW = 0;

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
    final canWrite = hub.connectionKind == ConnectionKind.local;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grid connection',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: _loaded ? (v) => setState(() => _enabled = v) : null,
            title: const Text('Limit what I feed in'),
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
              labelText: 'Feed-in limit',
              hintText: '11600',
              suffixText: 'W',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text('Set by your grid operator.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),

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
