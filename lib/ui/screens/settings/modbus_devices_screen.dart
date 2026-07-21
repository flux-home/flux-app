import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'package:matter_home/services/proto/flux.pbenum.dart' as $enum;
import 'package:matter_home/ui/widgets/dot_matrix_empty_hint.dart';
import 'package:matter_home/utils/power_format.dart';
import 'package:provider/provider.dart';

const _success = Color(0xFF34A853);

/// Manage the Modbus devices the controller polls (PV inverters, meters).
/// Discover on the LAN, add (from a scan candidate or manually), and remove.
/// The devices themselves show up like any other device once added.
class ModbusDevicesScreen extends StatefulWidget {
  const ModbusDevicesScreen({super.key});

  @override
  State<ModbusDevicesScreen> createState() => _ModbusDevicesScreenState();
}

class _ModbusDevicesScreenState extends State<ModbusDevicesScreen> {
  bool _busy = false;

  FluxCoapService? get _svc => context.read<HubConnection>().service;

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final devices = context.watch<DeviceProvider>().modbusDevices;
    final online  = context.watch<HubConnection>().isOnline;

    return Scaffold(
      appBar: AppBar(title: const Text('Modbus devices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_busy || !online) ? null : _startAdd,
        backgroundColor: online ? null : cs.surfaceContainerHighest,
        icon: const Icon(Icons.add),
        label: Text(online ? 'Add device' : 'Controller offline'),
      ),
      body: devices.isEmpty
          ? const DotMatrixEmptyHint(
              headline: 'NO MODBUS DEVICES',
              subline: 'TAP + TO ADD',
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final d in devices)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: ListTile(
                      leading: Icon(Icons.dns_outlined, color: cs.primary),
                      title: Text(d.name),
                      subtitle: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: d.isOnline ? _success : cs.outline,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(_powerLabel(d)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: online ? cs.error : cs.outline),
                        onPressed: online ? () => _confirmRemove(d) : null,
                      ),
                      onTap: () => context.push('/device/${d.id}'),
                    ),
                  ),
              ],
            ),
    );
  }

  String _powerLabel(DeviceView d) {
    final mw = d.live?.activePower;
    if (mw == null) return d.isOnline ? 'Connected' : 'Offline';
    final (v, u) = formatPowerMw(mw);
    return '$v $u';
  }

  // ── Add flow ────────────────────────────────────────────────────────────

  Future<void> _startAdd() async {
    final svc = _svc;
    if (svc == null) {
      _snack('Controller offline — reconnect to add devices.');
      return;
    }
    // Discovery-first: scan, then let the user pick a candidate or add manually.
    final pick = await showModalBottomSheet<_AddPick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ScanSheet(svc: svc),
    );
    if (pick == null || !mounted) return;

    final cfg = await showModalBottomSheet<$proto.ModbusDeviceConfig>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ConfigSheet(candidate: pick.candidate),
    );
    if (cfg == null || !mounted) return;
    await _submit(cfg);
  }

  Future<void> _submit($proto.ModbusDeviceConfig cfg) async {
    setState(() => _busy = true);
    final svc = _svc;
    final ok = svc != null && await svc.addModbusDevice(cfg);
    if (ok) await context.read<DeviceProvider>().syncWithController();
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(ok ? 'Added ${cfg.name}' : "Couldn't add device — check the address.");
  }

  // ── Remove ──────────────────────────────────────────────────────────────

  Future<void> _confirmRemove(DeviceView d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove device?'),
        content: Text('"${d.name}" will stop being polled and disappear from '
            'your devices.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Remove',
                  style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final svc = _svc;
    final done = svc != null && await svc.removeModbusDevice(d.nodeId);
    if (done) await context.read<DeviceProvider>().syncWithController();
    if (mounted) _snack(done ? 'Removed ${d.name}' : "Couldn't remove device.");
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}

/// Result of the scan sheet: a picked candidate (null ⇒ user chose manual add).
class _AddPick {
  const _AddPick(this.candidate);
  final $proto.ModbusCandidate? candidate;
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan sheet — runs discovery, lists candidates, offers manual add.
// ─────────────────────────────────────────────────────────────────────────────

class _ScanSheet extends StatefulWidget {
  const _ScanSheet({required this.svc});
  final FluxCoapService svc;

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  bool _scanning = true;
  List<$proto.ModbusCandidate> _found = const [];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final res = await widget.svc.scanModbusDevices();
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _found = res?.candidates.toList() ?? const [];
    });
  }

  bool _identified($proto.ModbusCandidate c) =>
      c.profile != $enum.ModbusProfile.MODBUS_PROFILE_UNKNOWN;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add Modbus device',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    SizedBox(
                        width: 26, height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                    SizedBox(height: 14),
                    Text('Scanning your network…',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('This can take up to ~20 seconds',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            else ...[
              if (_found.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('No devices found on your network.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in _found)
                        ListTile(
                          leading: Icon(
                            _identified(c)
                                ? Icons.check_circle_outline
                                : Icons.help_outline,
                            color: _identified(c) ? _success : cs.onSurfaceVariant,
                          ),
                          title: Text(_identified(c)
                              ? (c.model.isNotEmpty ? c.model : 'Modbus device')
                              : 'Unknown device'),
                          subtitle: Text([
                            c.host,
                            if (c.serial.isNotEmpty) c.serial,
                          ].join(' · ')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, _AddPick(c)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scan,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Rescan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, const _AddPick(null)),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Add manually'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Config sheet — name/host/port/unit/transport/profile → ModbusDeviceConfig.
// Prefilled from a scan candidate; fully editable for a manual add.
// ─────────────────────────────────────────────────────────────────────────────

class _ConfigSheet extends StatefulWidget {
  const _ConfigSheet({this.candidate});
  final $proto.ModbusCandidate? candidate;

  @override
  State<_ConfigSheet> createState() => _ConfigSheetState();
}

class _ConfigSheetState extends State<_ConfigSheet> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  final _port = TextEditingController(text: '502');
  final _unit = TextEditingController(text: '1');
  late $enum.ModbusTransport _transport;
  late $enum.ModbusProfile _profile;

  static const _profiles = [
    $enum.ModbusProfile.MODBUS_PROFILE_SUNSPEC,
    $enum.ModbusProfile.MODBUS_PROFILE_VM3P75CT,
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.candidate;
    _name = TextEditingController(text: c?.model ?? '');
    _host = TextEditingController(text: c?.host ?? '');
    _transport = c?.transport ?? $enum.ModbusTransport.MODBUS_TRANSPORT_TCP;
    _profile = (c != null && _profiles.contains(c.profile))
        ? c.profile
        : $enum.ModbusProfile.MODBUS_PROFILE_SUNSPEC;
  }

  @override
  void dispose() {
    _name.dispose(); _host.dispose(); _port.dispose(); _unit.dispose();
    super.dispose();
  }

  String _profileLabel($enum.ModbusProfile p) => switch (p) {
        $enum.ModbusProfile.MODBUS_PROFILE_VM3P75CT => 'Victron VM-3P75CT meter',
        _ => 'SunSpec PV inverter',
      };

  bool get _valid => _host.text.trim().isNotEmpty;

  void _submit() {
    final cfg = $proto.ModbusDeviceConfig(
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 0,
      unitId: int.tryParse(_unit.text.trim()) ?? 1,
      profile: _profile,
      transport: _transport,
      name: _name.text.trim().isEmpty ? 'Modbus device' : _name.text.trim(),
    );
    Navigator.pop(context, cfg);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Device details',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _host,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Host / IP address',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Port', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Unit id', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<$enum.ModbusTransport>(
                segments: const [
                  ButtonSegment(
                      value: $enum.ModbusTransport.MODBUS_TRANSPORT_TCP,
                      label: Text('TCP')),
                  ButtonSegment(
                      value: $enum.ModbusTransport.MODBUS_TRANSPORT_UDP,
                      label: Text('UDP')),
                ],
                selected: {_transport},
                onSelectionChanged: (s) => setState(() => _transport = s.first),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<$enum.ModbusProfile>(
                initialValue: _profile,
                decoration: const InputDecoration(
                    labelText: 'Profile', border: OutlineInputBorder()),
                items: [
                  for (final p in _profiles)
                    DropdownMenuItem(value: p, child: Text(_profileLabel(p))),
                ],
                onChanged: (p) => setState(() => _profile = p ?? _profile),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _valid ? _submit : null,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: const Text('Add device'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
