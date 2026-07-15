import 'package:flutter/material.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:provider/provider.dart';

/// Off-LAN remote-access configuration (flux-interface ADR-0004/0006/0007):
/// the rendezvous URL + optional STUN/TURN overrides the app uses to reach the
/// hub when it isn't on the same network. Reached from the Flux Hub screen.
///
/// The rendezvous URL is normally learned from the hub automatically while on
/// the LAN, so these fields are an override; STUN/TURN default to metered.ca.
class RemoteAccessScreen extends StatefulWidget {
  const RemoteAccessScreen({super.key});

  @override
  State<RemoteAccessScreen> createState() => _RemoteAccessScreenState();
}

class _RemoteAccessScreenState extends State<RemoteAccessScreen> {
  final TextEditingController _rzvCtrl      = TextEditingController();
  final TextEditingController _stunCtrl     = TextEditingController();
  final TextEditingController _turnCtrl     = TextEditingController();
  final TextEditingController _turnUserCtrl = TextEditingController();
  final TextEditingController _turnPassCtrl = TextEditingController();
  String? _id;
  bool    _connecting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rzvCtrl.dispose();
    _stunCtrl.dispose();
    _turnCtrl.dispose();
    _turnUserCtrl.dispose();
    _turnPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = await ControllerSettings.firstControllerId();
    final url  = id == null ? null : await ControllerSettings.loadRendezvousUrl(id);
    final stun = id == null ? null : await ControllerSettings.loadStunServer(id);
    final (turn, tu, tp) = id == null
        ? (null, null, null)
        : await ControllerSettings.loadTurn(id);
    if (!mounted) return;
    setState(() {
      _id = id;
      _rzvCtrl.text      = url ?? '';
      _stunCtrl.text     = stun ?? '';
      _turnCtrl.text     = turn ?? '';
      _turnUserCtrl.text = tu ?? '';
      _turnPassCtrl.text = tp ?? '';
    });
  }

  Future<void> _save() async {
    final id = _id ?? await ControllerSettings.firstControllerId();
    if (id == null) return;
    await ControllerSettings.saveRendezvousUrl(id, _rzvCtrl.text.trim());
    await ControllerSettings.saveStunServer(id, _stunCtrl.text.trim());
    await ControllerSettings.saveTurn(id,
        server: _turnCtrl.text.trim(),
        user:   _turnUserCtrl.text.trim(),
        pass:   _turnPassCtrl.text.trim());
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Remote access settings saved')),
    );
  }

  /// Force the off-LAN path (skip LAN discovery) and show the full trace, so the
  /// tunnel can be debugged from the phone screen (Wi-Fi off, no adb).
  Future<void> _connect() async {
    final hub = context.read<HubConnection>();
    await _save();
    if (!mounted) return;
    setState(() => _connecting = true);
    final ok = await hub.tryRemote();
    if (!mounted) return;
    setState(() => _connecting = false);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ok ? 'Remote tunnel ✓' : 'Remote tunnel failed'),
        content: SingleChildScrollView(
          child: SelectableText(
            hub.lastRemoteDiagnostics.isEmpty
                ? 'No diagnostics captured.'
                : hub.lastRemoteDiagnostics,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = _id != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Remote access')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Reach the hub when you are away from home. The rendezvous URL is '
            'learned from the hub automatically on your home network — edit only '
            'to override. STUN/TURN default to metered.ca.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _field(_rzvCtrl, enabled,
              label: 'Rendezvous URL', hint: 'https://…workers.dev'),
          const SizedBox(height: 16),
          _field(_stunCtrl, enabled,
              label: 'STUN server',
              hint: 'stun.relay.metered.ca:80 (default)',
              helper: 'Leave blank to use the default (metered.ca).'),
          const SizedBox(height: 16),
          _field(_turnCtrl, enabled,
              label: 'TURN relay (host:port)',
              hint: 'turn:relay.example.com:3478',
              helper: 'Optional — needed across mobile/CGNAT. Blank = metered.ca default.'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_turnUserCtrl, enabled, label: 'TURN user')),
            const SizedBox(width: 12),
            Expanded(child: _field(_turnPassCtrl, enabled, label: 'TURN pass', obscure: true)),
          ]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: enabled ? _save : null, child: const Text('Save')),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: (!enabled || _connecting) ? null : _connect,
                icon: _connecting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering, size: 18),
                label: const Text('Connect remotely'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, bool enabled,
          {required String label, String? hint, String? helper, bool obscure = false}) =>
      TextField(
        controller: c,
        enabled: enabled,
        obscureText: obscure,
        autocorrect: false,
        keyboardType: TextInputType.url,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => _save(),
      );
}
