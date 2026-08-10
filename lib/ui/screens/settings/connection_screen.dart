import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

          // ── Last connection metrics ──────────────────────────────────────
          const SizedBox(height: 20),
          _label(cs, 'LAST CONNECTION'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              _valueRow(cs, 'Attempt',
                  hub.lastConnectAt == null
                      ? 'none yet'
                      : '${hub.lastConnectOk == true ? "ok" : "failed"}'
                          ' · ${_ago(hub.lastConnectAt!)} ago'),
              _divider(cs),
              _valueRow(cs, 'Setup time', _ms(hub.lastConnectDuration)),
              _divider(cs),
              _valueRow(cs, 'Via',
                  hub.lastConnectKind == null || hub.lastConnectOk != true
                      ? '—'
                      : hub.lastConnectKind == ConnectionKind.remote
                          ? 'remote tunnel'
                          : 'local network'),
              _divider(cs),
              _valueRow(cs, 'Heartbeat',
                  hub.lastProbeAt == null
                      ? '—'
                      : hub.lastProbeRtt != null
                          ? '${_ms(hub.lastProbeRtt)} · ${_ago(hub.lastProbeAt!)} ago'
                          : 'failed · ${_ago(hub.lastProbeAt!)} ago'),
              _divider(cs),
              _valueRow(cs, 'Attempts',
                  '${hub.connectAttempts} total · ${hub.connectFailures} failed'),
              if (hub.probeFailStreak > 0) ...[
                _divider(cs),
                _valueRow(cs, 'Missed beats', '${hub.probeFailStreak}'),
              ],
              if (hub.lastConnectError != null) ...[
                _divider(cs),
                _valueRow(cs, 'Last error', hub.lastConnectError!),
              ],
            ]),
          ),

          // ── Where the last attempt got to ────────────────────────────────
          if (hub.lastAttemptSteps.isNotEmpty) ...[
            const SizedBox(height: 20),
            _label(cs, 'LAST ATTEMPT'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final step in hub.lastAttemptSteps) _stepRow(cs, step),
                  _divider(cs),
                  _CopyDiagnosticsTile(hub: hub),
                ],
              ),
            ),
          ],

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

  /// One stage of the last attempt: what it was, whether it passed, and — the
  /// part that was missing before — why it didn't.
  Widget _stepRow(ColorScheme cs, ConnectStep step) {
    final (IconData icon, Color tint) = switch (step.outcome) {
      ConnectStepOutcome.ok      => (Icons.check, _onlineColor),
      ConnectStepOutcome.failed  => (Icons.close, _offlineColor),
      ConnectStepOutcome.skipped => (Icons.remove, cs.onSurfaceVariant),
    };
    final ms = step.duration;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(step.stage.label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: step.isFailure
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: step.isFailure ? tint : cs.onSurface)),
                  ),
                  if (ms != null)
                    Text(_ms(ms),
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant)),
                ]),
                if (step.detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(step.detail!,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _ms(Duration? d) => d == null
      ? '—'
      : d.inMilliseconds < 1000
          ? '${d.inMilliseconds} ms'
          : '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

  static String _ago(DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 60) return '${s}s';
    if (s < 3600) return '${s ~/ 60}m';
    return '${s ~/ 3600}h';
  }
}

/// Copies the full trace of the last attempt to the clipboard.
///
/// The point is being able to report a failure from the phone that is failing —
/// which is usually the one that is off the LAN, nowhere near a machine with
/// adb attached.
class _CopyDiagnosticsTile extends StatelessWidget {
  const _CopyDiagnosticsTile({required this.hub});

  final HubConnection hub;

  String _report() {
    final b = StringBuffer()
      ..writeln('flux connection diagnostics')
      ..writeln('status: ${hub.status.name}  via: ${hub.connectionKind.name}')
      ..writeln('attempts: ${hub.connectAttempts}  failures: ${hub.connectFailures}');
    if (hub.lastConnectAt != null) {
      b.writeln('last attempt: ${hub.lastConnectAt!.toIso8601String()} '
          '(${hub.lastConnectOk == true ? "ok" : "failed"})');
    }
    if (hub.lastConnectError != null) b.writeln('error: ${hub.lastConnectError}');
    b.writeln('--- stages ---');
    for (final s in hub.lastAttemptSteps) {
      b.writeln('${s.outcome.name.padRight(7)} ${s.stage.label}'
          '${s.duration != null ? " (${s.duration!.inMilliseconds} ms)" : ""}'
          '${s.detail != null ? " — ${s.detail}" : ""}');
    }
    final trace = hub.lastRemoteDiagnostics;
    if (trace.isNotEmpty) b..writeln('--- trace ---')..writeln(trace);
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.copy_all_outlined, size: 20),
      title: const Text('Copy diagnostics'),
      subtitle: const Text('Full trace of the last attempt'),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: _report()));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Diagnostics copied')));
      },
    );
  }
}
