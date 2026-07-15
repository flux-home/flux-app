import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/add_controller_flow.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/services/thread_sync_service.dart';
import 'package:matter_home/ui/screens/settings/remote_access_screen.dart';
import 'package:matter_home/ui/widgets/dot_matrix_empty_hint.dart';
import 'package:provider/provider.dart';

// Connection-state accents, shared with ControllerStatusChip.
const _localColor   = Color(0xFF9FD8A8); // green
const _remoteColor  = Color(0xFFA9C7F2); // blue
const _connectingC  = Color(0xFFBFC4CC); // grey
const _offlineColor = Color(0xFFF2A9A0); // coral

enum _HubAction { refresh, syncThread, remove }

class ControllerSettingsScreen extends StatefulWidget {
  const ControllerSettingsScreen({super.key});

  @override
  State<ControllerSettingsScreen> createState() =>
      _ControllerSettingsScreenState();
}

class _ControllerSettingsScreenState extends State<ControllerSettingsScreen> {
  ControllerInfo?  _info;
  bool             _loading       = false;
  Uint8List?       _storedPsk;
  bool             _pskLoaded     = false;
  ThreadDataset?   _activeDataset;
  bool             _syncingThread = false;
  bool             _probing       = false;
  Timer?           _poll;

  @override
  void initState() {
    super.initState();
    _loadPskStatus();
    _loadActiveDataset();
    final svc = context.read<HubConnection>().service;
    if (svc != null) _fetchInfo(svc);
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      final s = context.read<HubConnection>().service;
      if (s != null && !_probing && !_loading) _fetchInfo(s);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadActiveDataset() async {
    final ds = await ThreadSettingsService.loadActive();
    if (mounted) setState(() => _activeDataset = ds);
  }

  Future<void> _loadPskStatus() async {
    final hub = context.read<HubConnection>();
    final id  = hub.service?.endpoint.dtlsIdentity
        ?? _info?.hostname
        ?? hub.service?.endpoint.host ?? '';
    if (id.isEmpty) { if (mounted) setState(() => _pskLoaded = true); return; }
    final psk = await ControllerSettings.loadPsk(id);
    if (mounted) setState(() { _storedPsk = psk; _pskLoaded = true; });
  }

  Future<void> _fetchInfo(FluxCoapService svc) async {
    if (mounted) setState(() => _probing = true);
    final info = await svc.getInfo();
    if (!mounted) return;
    setState(() {
      _info    = info;
      _probing = false;
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _rediscover() async {
    setState(() { _loading = true; _info = null; });
    final hub   = context.read<HubConnection>();
    final found = await hub.reconnect();
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(found
          ? 'Connected to ${hub.service!.endpoint.host}'
          : 'Controller not found — make sure it is on the same network'),
    ));
    if (found) {
      _fetchInfo(hub.service!);
      _loadPskStatus();
    }
  }

  Future<void> _addController() async {
    final found = await runAddControllerFlow(context);
    if (!mounted) return;
    await _loadPskStatus();
    if (found) {
      final svc = context.read<HubConnection>().service;
      if (svc != null) _fetchInfo(svc);
    }
  }

  Future<void> _clearPsk() async {
    final hub = context.read<HubConnection>();
    final id  = hub.service?.endpoint.dtlsIdentity
        ?? _info?.hostname
        ?? hub.service?.endpoint.host ?? '';
    if (id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove controller?'),
        content: const Text(
            'The PSK will be deleted. The app will no longer connect to '
            'this controller until you add it again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await ControllerSettings.clearPsk(id);
    await hub.reconnect();
    if (mounted) {
      setState(() { _storedPsk = null; _info = null; });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hub removed')));
    }
  }

  /// Reconciles the Thread network with the hub as source of truth.
  Future<void> _syncThread() async {
    final svc = context.read<HubConnection>().service;
    if (svc == null) return;
    setState(() => _syncingThread = true);
    try {
      final result = await ThreadSyncService(svc).ensureInSync();
      if (!mounted) return;
      final message = switch (result.status) {
        ThreadSyncStatus.adopted     => "Using the hub's Thread network ✓",
        ThreadSyncStatus.pushed      => 'Thread network sent to the hub ✓',
        ThreadSyncStatus.inSync      => 'Thread network already in sync ✓',
        ThreadSyncStatus.nothingToDo => 'No Thread network configured yet',
        ThreadSyncStatus.unreachable => "Couldn't reach the hub — try again",
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      if (result.status == ThreadSyncStatus.adopted) _loadActiveDataset();
    } finally {
      if (mounted) setState(() => _syncingThread = false);
    }
  }

  void _onHubAction(_HubAction action) {
    switch (action) {
      case _HubAction.refresh:    _rediscover();
      case _HubAction.syncThread: _syncThread();
      case _HubAction.remove:     _clearPsk();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _hubName() {
    final host = _info?.hostname ?? '';
    return host.isNotEmpty ? host : 'Flux Hub';
  }

  /// (accent colour, short label) for the current connection state.
  (Color, String) _connState(HubConnection hub) {
    if (_loading) return (_connectingC, 'Searching…');
    switch (hub.status) {
      case ControllerStatus.online:
        return hub.connectionKind == ConnectionKind.remote
            ? (_remoteColor, 'Remote')
            : (_localColor, 'Local');
      case ControllerStatus.connecting:
        return (_connectingC, 'Connecting…');
      case ControllerStatus.offline:
        return (_offlineColor, 'Offline');
      case ControllerStatus.noHub:
        return (_offlineColor, 'Offline');
    }
  }

  String _pskSummary(Uint8List psk) =>
      '${psk.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}…';

  static String _formatUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 108,
            child: Text(label, style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(
            fontSize: 13, fontFamily: 'monospace'))),
      ],
    ),
  );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubConnection>();
    final configured = hub.hasConfiguredHub || (_pskLoaded && _storedPsk != null);
    final cs         = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Flux Hub')),
      floatingActionButton: configured
          ? null
          : FloatingActionButton(
              onPressed: _loading ? null : _addController,
              elevation: 2,
              shape: const CircleBorder(),
              tooltip: 'Add hub',
              child: const Icon(Icons.add, size: 28),
            ),
      body: !_pskLoaded && !configured
          ? const SizedBox.shrink()
          : !configured
              ? const DotMatrixEmptyHint(headline: 'NO HUB YET', subline: 'TAP + TO ADD')
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _heroCard(hub, cs),
                    const SizedBox(height: 12),
                    // Remote access — off-LAN reachability. Intentionally NOT
                    // gated on `online`: this is the path you use to reach the
                    // hub *when you're away*, so it must stay reachable offline.
                    _navCard(
                      icon: Icons.cloud_outlined,
                      title: 'Remote access',
                      subtitle: 'Reach the hub when you are away',
                      onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                          builder: (_) => const RemoteAccessScreen())),
                    ),
                  ],
                ),
    );
  }

  /// Slick hub hero: name + colored connection state + firmware, with details
  /// tucked into an expandable so the top stays clean.
  Widget _heroCard(HubConnection hub, ColorScheme cs) {
    final (color, stateLabel) = _connState(hub);
    final version = _info?.firmwareVersion ?? '';
    final fabricProvisioned = (_info?.fabricId.toInt() ?? 0) != 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
            child: Row(
              children: [
                Container(width: 11, height: 11,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_hubName(),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Text(stateLabel,
                            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                        if (version.isNotEmpty) ...[
                          Text('  ·  ', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                          Flexible(
                            child: Text(version,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, fontFamily: 'monospace',
                                    color: cs.onSurfaceVariant)),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                PopupMenuButton<_HubAction>(
                  onSelected: _onHubAction,
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: _HubAction.refresh,
                      enabled: !_loading,
                      child: const Text('Refresh'),
                    ),
                    PopupMenuItem(
                      value: _HubAction.syncThread,
                      enabled: hub.isOnline && !_syncingThread,
                      child: const Text('Sync Thread network'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: _HubAction.remove,
                      child: Text('Remove hub', style: TextStyle(color: cs.error)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Text('Details',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_info?.ethernetIp.isNotEmpty ?? false)
                      _detailRow('IP address', _info!.ethernetIp),
                    if (version.isNotEmpty) _detailRow('Firmware', version),
                    if ((_info?.uptimeSeconds ?? 0) > 0)
                      _detailRow('Uptime', _formatUptime(_info!.uptimeSeconds)),
                    _detailRow('Fabric',
                        fabricProvisioned ? '0x${_info!.fabricId.toHexString()}' : 'none'),
                    _detailRow('Thread network',
                        _activeDataset != null && !_activeDataset!.isEmpty
                            ? _activeDataset!.label : 'none'),
                    if (_storedPsk != null)
                      _detailRow('Pairing key', '${_pskSummary(_storedPsk!)} (stored)'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        onTap: onTap,
      ),
    );
  }
}
