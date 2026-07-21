import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:provider/provider.dart';

/// Off-LAN remote-access configuration (flux-interface ADR-0004/0006/0007).
///
/// Reach the hub when away from home. Flux runs no cloud: the phone connects
/// straight to the hub through an encrypted tunnel keyed by the same PSK as on
/// the LAN. The rendezvous only helps the two find each other; a relay (TURN),
/// needed on cellular/CGNAT, carries only the already-encrypted bytes. Users
/// bring their own relay account so no third party is ever in the middle.
///
/// Reached from the Flux Hub / controller settings screen.
class RemoteAccessScreen extends StatefulWidget {
  const RemoteAccessScreen({super.key});

  @override
  State<RemoteAccessScreen> createState() => _RemoteAccessScreenState();
}

class _RemoteAccessScreenState extends State<RemoteAccessScreen> {
  /// Default metered.ca TURN host, prefilled so users only paste credentials.
  /// Shown on the same dashboard page as the username/credential.
  static const _fallbackTurnHost  = 'standard.relay.metered.ca:80';
  static const _meteredSignupUrl  = 'https://dashboard.metered.ca/signup';

  // Effective built-in defaults, shown in the fields when no override is stored.
  String get _rzvDefault      => HubConnection.defaultRendezvousUrl;
  String get _stunDefault     =>
      '${HubConnection.defaultStunHost}:${HubConnection.defaultStunPort}';
  String get _turnHostDefault => HubConnection.defaultTurnHost.isNotEmpty
      ? HubConnection.defaultTurnHost
      : _fallbackTurnHost;
  String get _turnUserDefault => HubConnection.defaultTurnUser;
  String get _turnPassDefault => HubConnection.defaultTurnPass;

  final TextEditingController _rzvCtrl      = TextEditingController();
  final TextEditingController _stunCtrl     = TextEditingController();
  final TextEditingController _turnHostCtrl = TextEditingController();
  final TextEditingController _turnUserCtrl = TextEditingController();
  final TextEditingController _turnPassCtrl = TextEditingController();

  String? _id;
  bool    _enabled     = false;
  bool    _busyToggle  = false;
  bool    _connecting  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rzvCtrl.dispose();
    _stunCtrl.dispose();
    _turnHostCtrl.dispose();
    _turnUserCtrl.dispose();
    _turnPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hub = context.read<HubConnection>();
    // Everything the controls need to be usable comes from local storage only —
    // set it FIRST and never block on the network, so the screen (incl. the
    // off-LAN "Connect remotely" test) stays live even with Wi-Fi off.
    final id  = await ControllerSettings.firstControllerId();
    final url  = id == null ? null : await ControllerSettings.loadRendezvousUrl(id);
    final stun = id == null ? null : await ControllerSettings.loadStunServer(id);
    final (turn, tu, tp) = id == null
        ? (null, null, null)
        : await ControllerSettings.loadTurn(id);
    if (!mounted) return;
    setState(() {
      _id = id;
      // Show the effective value in every field: a stored override if present,
      // otherwise the built-in default (fluxbox rendezvous, metered STUN, and
      // any TURN creds baked into this build).
      _rzvCtrl.text      = url  ?? _rzvDefault;
      _stunCtrl.text     = stun ?? _stunDefault;
      _turnHostCtrl.text = turn ?? _turnHostDefault;
      _turnUserCtrl.text = tu   ?? _turnUserDefault;
      _turnPassCtrl.text = tp   ?? _turnPassDefault;
    });

    // The master-switch state lives on the hub and needs a LAN read. Do it
    // AFTER the fields are live so a slow/failed read can never grey out the
    // screen. null (off-LAN / unreachable) simply leaves the toggle as-is.
    final svc = hub.service;
    if (svc == null) return;
    final cfg = await svc.getRemoteConfig();
    if (mounted && cfg != null) setState(() => _enabled = cfg.enabled);
  }

  /// Persist the app-side relay/rendezvous/STUN config locally. A field is
  /// stored only when it DIFFERS from the built-in default — leaving it as shown
  /// keeps tracking the default (and future builds), while an edit becomes a
  /// real override. A relay counts as configured only when BOTH username and
  /// credential are present; otherwise it's cleared and we fall back to the
  /// build-time default relay (STUN-only in public builds).
  Future<void> _save({bool silent = false}) async {
    final id = _id ?? await ControllerSettings.firstControllerId();
    if (id == null) return;

    final rzv  = _rzvCtrl.text.trim();
    final stun = _stunCtrl.text.trim();
    await ControllerSettings.saveRendezvousUrl(id, rzv  == _rzvDefault  ? '' : rzv);
    await ControllerSettings.saveStunServer  (id, stun == _stunDefault ? '' : stun);

    final u = _turnUserCtrl.text.trim();
    final p = _turnPassCtrl.text.trim();
    final h = _turnHostCtrl.text.trim();
    final isDefault = u == _turnUserDefault && p == _turnPassDefault && h == _turnHostDefault;
    final hasCreds  = u.isNotEmpty && p.isNotEmpty;
    if (isDefault || !hasCreds) {
      await ControllerSettings.saveTurn(id, server: '', user: '', pass: '');
    } else {
      await ControllerSettings.saveTurn(id,
          server: h.isEmpty ? _turnHostDefault : h, user: u, pass: p);
    }

    if (silent || !mounted) return;
    FocusScope.of(context).unfocus();
    _snack('Remote access settings saved');
  }

  /// Master switch. Enabling writes RemoteConfig.enabled (+ the effective
  /// rendezvous URL) to the hub — a LAN-only write (ADR-0012), so it fails when
  /// off-LAN and we revert the switch.
  Future<void> _toggle(bool v) async {
    final svc = context.read<HubConnection>().service;
    if (svc == null) {
      _snack('Connect on your home Wi-Fi to change this.');
      return;
    }
    setState(() { _enabled = v; _busyToggle = true; });
    await _save(silent: true);
    final effUrl = _rzvCtrl.text.trim().isEmpty
        ? HubConnection.defaultRendezvousUrl
        : _rzvCtrl.text.trim();
    final ok = await svc.setRemoteEnabled(v, rendezvousUrl: effUrl);
    if (!mounted) return;
    setState(() { _busyToggle = false; if (!ok) _enabled = !v; });
    _snack(ok
        ? (v ? 'Remote access enabled' : 'Remote access disabled')
        : "Couldn't update the controller — connect on your home network and try again.");
  }

  Future<void> _copySignupLink() async {
    await Clipboard.setData(const ClipboardData(text: _meteredSignupUrl));
    if (!mounted) return;
    _snack('Signup link copied — open it in your browser');
  }

  /// Force the off-LAN path (skip LAN discovery) and show the full trace, so the
  /// tunnel can be debugged from the phone screen (Wi-Fi off, no adb).
  Future<void> _connect() async {
    final hub = context.read<HubConnection>();
    await _save(silent: true);
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

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final hub     = context.watch<HubConnection>();
    final enabled = _id != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Remote access (beta)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── What this is / why (privacy & security) ──────────────────────
          Card(
            color: cs.surfaceContainerHighest,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lock_outline, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Private by design',
                        style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Reach your controller when you are away from home. Flux runs no '
                    'cloud and keeps no account of yours — your phone connects '
                    'straight to your controller through an encrypted tunnel secured by '
                    'the same key as on your home Wi-Fi.\n\n'
                    'A lightweight “rendezvous” only helps the two find each '
                    'other; it can’t read or change your data. On mobile '
                    'networks a relay may be needed to carry the '
                    '(still-encrypted) connection — use your own free account '
                    'so no third party is ever in the middle.',
                    style: TextStyle(fontSize: 13, height: 1.35, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Master switch + status ───────────────────────────────────────
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remote access'),
            subtitle: Text(_statusText(hub),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            secondary: _busyToggle
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.wifi_tethering, color: _enabled ? cs.primary : cs.onSurfaceVariant),
            value: _enabled,
            onChanged: (!enabled || _busyToggle) ? null : _toggle,
          ),
          if (hub.service == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Turning it on/off requires being on your home network.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ),
          const Divider(height: 28),

          // ── Relay (guided metered flow) ──────────────────────────────────
          Text('Relay for away-from-home',
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 4),
          Text(
            'Only used on cellular / CGNAT networks where a direct connection '
            'fails. It carries the already-encrypted tunnel, never your keys. '
            'Your relay credentials are shown below. No relay yet? Create your '
            'own free account so it stays under your control:',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: enabled ? _copySignupLink : null,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Create a free metered.ca account'),
          ),
          const SizedBox(height: 8),
          Text(
            '1.  Sign up (free tier, ~50 GB/month)\n'
            '2.  Open “TURN Server credentials”\n'
            '3.  Paste the Username and Credential below',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _field(_turnUserCtrl, enabled, label: 'Username', hint: 'from your metered dashboard'),
          const SizedBox(height: 12),
          _field(_turnPassCtrl, enabled, label: 'Credential', obscure: true),
          const SizedBox(height: 4),

          // Escape hatch for non-metered TURN providers.
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text('Use a different TURN provider',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              children: [
                _field(_turnHostCtrl, enabled,
                    label: 'Relay host (host:port)',
                    helper: 'Default shown. Works with any TURN server (coturn, Twilio, …).'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Advanced ─────────────────────────────────────────────────────
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Advanced'),
              children: [
                _field(_rzvCtrl, enabled,
                    label: 'Rendezvous server',
                    helper: 'Where your phone and controller find each other. '
                            'Default shown — edit only to override.'),
                const SizedBox(height: 14),
                _field(_stunCtrl, enabled,
                    label: 'STUN server',
                    helper: 'Helps discover your public address. '
                            'Default shown — edit only to override.'),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: (!enabled || _connecting) ? null : _connect,
                    icon: _connecting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bug_report_outlined, size: 18),
                    label: const Text('Connect remotely (test)'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(onPressed: enabled ? () => _save() : null, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }

  String _statusText(HubConnection hub) {
    switch (hub.status) {
      case ControllerStatus.noHub:      return 'No controller paired yet.';
      case ControllerStatus.connecting: return 'Connecting…';
      case ControllerStatus.offline:    return 'Controller offline.';
      case ControllerStatus.online:
        return hub.connectionKind == ConnectionKind.remote
            ? 'Connected remotely (via the tunnel).'
            : 'Connected on your home network.';
    }
  }

  Widget _field(TextEditingController c, bool enabled,
          {required String label, String? hint, String? helper, bool obscure = false}) =>
      TextField(
        controller: c,
        enabled: enabled,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.url,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => _save(),
      );
}
