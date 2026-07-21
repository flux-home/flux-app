import 'package:flutter/material.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/settings/remote_access_screen.dart';
import 'package:provider/provider.dart';

// Connection-state accents (shared with the Settings panels).
const _onlineColor     = Color(0xFF9FD8A8); // green
const _remoteColor     = Color(0xFFA9C7F2); // blue
const _connectingColor = Color(0xFFBFC4CC); // grey
const _offlineColor    = Color(0xFFF2A9A0); // coral

/// Connection detail — how this phone is reaching the controller right now,
/// broken out into its two independent paths: the local network and the
/// remote (off-LAN) tunnel. Reached from the connection widget in Settings.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  bool?   _remoteEnabled;   // null → couldn't read the controller's config
  String? _rendezvous;
  String? _relay;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final svc = context.read<HubConnection>().service;
    final cfg = svc == null ? null : await svc.getRemoteConfig();
    if (!mounted) return;
    setState(() {
      _remoteEnabled = cfg?.enabled;
      _rendezvous = (cfg?.rendezvousUrl.isNotEmpty ?? false)
          ? cfg!.rendezvousUrl
          : HubConnection.defaultRendezvousUrl;
      _relay = (cfg?.turn.isNotEmpty ?? false)
          ? '${cfg!.turn.first.host}:${cfg.turn.first.port}'
          : (HubConnection.defaultTurnHost.isNotEmpty
              ? HubConnection.defaultTurnHost
              : null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final hub  = context.watch<HubConnection>();
    final kind = hub.connectionKind;
    final ep   = hub.service?.endpoint;

    final (Color dot, String headline, String detail) = switch (hub.status) {
      ControllerStatus.online => kind == ConnectionKind.remote
          ? (_remoteColor, 'Connected', 'Remote · encrypted tunnel')
          : (_onlineColor, 'Connected', 'Local network'),
      ControllerStatus.connecting => (_connectingColor, 'Connecting…', ''),
      ControllerStatus.offline    => (_offlineColor, 'Offline', 'Controller unreachable'),
      ControllerStatus.noHub      => (_connectingColor, 'Not set up', ''),
    };

    // Per-path state.
    final localState = switch (hub.status) {
      ControllerStatus.online when kind == ConnectionKind.local => ('Active', _onlineColor),
      ControllerStatus.online     => ('Standby', _connectingColor),
      ControllerStatus.connecting => ('Connecting…', _connectingColor),
      _                           => ('Not connected', _offlineColor),
    };
    final (String remoteText, Color remoteDot) = _remoteEnabled == false
        ? ('Off', _connectingColor)
        : kind == ConnectionKind.remote
            ? ('Active tunnel', _remoteColor)
            : _remoteEnabled == true
                ? ('Standby', _connectingColor)
                : ('Unknown', _connectingColor);

    return Scaffold(
      appBar: AppBar(title: const Text('Connection')),
      body: ListView(
        children: [
          const SizedBox(height: 24),

          // ── Big current-state block ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(width: 14, height: 14,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    if (detail.isNotEmpty)
                      Text(detail, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Local network ────────────────────────────────────────────────
          _label(cs, 'LOCAL NETWORK'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _stateRow(cs, 'State', localState.$1, localState.$2),
              _divider(cs),
              _valueRow(cs, 'Address',
                  kind == ConnectionKind.local && ep != null ? '${ep.host}:${ep.port}' : '—'),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Remote access ────────────────────────────────────────────────
          _label(cs, 'REMOTE ACCESS'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              _stateRow(cs, 'State', remoteText, remoteDot),
              _divider(cs),
              _valueRow(cs, 'Rendezvous', _rendezvous ?? '…'),
              _divider(cs),
              _valueRow(cs, 'Relay', _relay ?? 'none'),
              _divider(cs),
              ListTile(
                title: const Text('Configure remote access'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => const RemoteAccessScreen())),
              ),
            ]),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _label(ColorScheme cs, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(text, style: TextStyle(
            fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700,
            letterSpacing: 2.4, color: cs.onSurfaceVariant)),
      );

  Widget _stateRow(ColorScheme cs, String label, String value, Color dot) => ListTile(
        title: Text(label, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _valueRow(ColorScheme cs, String label, String value) => ListTile(
        title: Text(label, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(value, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
        ),
      );

  Widget _divider(ColorScheme cs) =>
      Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant);
}
