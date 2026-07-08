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
import 'package:matter_home/ui/widgets/dot_matrix_empty_hint.dart';
import 'package:provider/provider.dart';

enum _HubAction { refresh, syncThread, remove }

class ControllerSettingsScreen extends StatefulWidget {
  const ControllerSettingsScreen({super.key});

  @override
  State<ControllerSettingsScreen> createState() =>
      _ControllerSettingsScreenState();
}

class _ControllerSettingsScreenState extends State<ControllerSettingsScreen> {
  ControllerInfo?  _info;
  bool             _loading      = false;
  Uint8List?       _storedPsk;
  bool             _pskLoaded    = false;
  ThreadDataset?   _activeDataset;
  bool             _syncingThread = false;

  /// Live reachability: true once a `/info` read succeeds, false when it fails.
  /// This is the real "connected" signal — [HubConnection.isConnected] only
  /// means "a hub was discovered at some point", which stays true even offline.
  bool             _online   = false;
  bool             _probing  = false;
  Timer?           _poll;

  @override
  void initState() {
    super.initState();
    _loadPskStatus();
    _loadActiveDataset();
    final svc = context.read<HubConnection>().service;
    if (svc != null) _fetchInfo(svc);
    // Re-probe periodically so the status reflects the hub going on/offline
    // while this screen is open.
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
      _online  = info != null; // real reachability
      _probing = false;
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _rediscover() async {
    setState(() { _loading = true; _info = null; _online = false; });
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
      setState(() { _storedPsk = null; _info = null; _online = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hub removed')));
    }
  }

  /// Reconciles the Thread network with the hub as source of truth: adopts the
  /// hub's network if it has one, otherwise pushes the app's active dataset.
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

  // ── Details ───────────────────────────────────────────────────────────────

  /// Hub details shown inline beneath the hub card. Rows that need live data
  /// (host, firmware, uptime) only appear once a `/info` read has succeeded;
  /// the stored pairing key, fabric and Thread network are always shown.
  Widget _detailsCard(ColorScheme cs) {
    final fabricProvisioned = (_info?.fabricId.toInt() ?? 0) != 0;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DETAILS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            if (_info != null) ...[
              _detailRow('Host', _info!.hostname),
              if (_info!.ethernetIp.isNotEmpty)
                _detailRow('IP address', _info!.ethernetIp),
              if (_info!.firmwareVersion.isNotEmpty)
                _detailRow('Firmware', _info!.firmwareVersion),
              if (_info!.uptimeSeconds > 0)
                _detailRow('Uptime', _formatUptime(_info!.uptimeSeconds)),
            ],
            if (_storedPsk != null)
              _detailRow('Pairing key', '${_pskSummary(_storedPsk!)} (stored)'),
            _detailRow(
              'Fabric',
              fabricProvisioned ? '0x${_info!.fabricId.toHexString()}' : 'none',
            ),
            _detailRow(
              'Thread network',
              _activeDataset != null && !_activeDataset!.isEmpty
                  ? _activeDataset!.label
                  : 'none',
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// A friendly name for the hub — falls back to a generic label.
  String _hubName() {
    final host = _info?.hostname ?? '';
    return host.isNotEmpty ? host : 'Flux Hub';
  }

  String _hubSubtitle() => switch (true) {
        _ when _loading                                       => 'Searching…',
        _ when _online && (_info?.fabricId.toInt() ?? 0) == 0 => 'Starting up…',
        _ when _online && _info!.firmwareVersion.isNotEmpty   => 'Connected · v${_info!.firmwareVersion}',
        _ when _online                                        => 'Connected',
        _ when _probing                                       => 'Checking…',
        _                                                      => 'Offline',
      };

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
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 92,
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
    final hub = context.watch<HubConnection>(); // rebuild when the service is swapped
    // A hub is "configured" the moment a PSK is stored, even if the controller
    // can't be reached right now — so we must never fall back to "NO HUB YET"
    // in that case. HubConnection.hasConfiguredHub is the source of truth;
    // _storedPsk only loads once the controller ID can be resolved (i.e. the
    // box was discovered), which never happens for an offline PSK-added hub.
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
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListTile(
                        leading: Icon(Icons.router_outlined, color: cs.primary),
                        title: Text(_hubName()),
                        subtitle: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _online ? Colors.green.shade400 : cs.outline,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(_hubSubtitle()),
                          ],
                        ),
                        trailing: PopupMenuButton<_HubAction>(
                          onSelected: _onHubAction,
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: _HubAction.refresh,
                              enabled: !_loading,
                              child: const Text('Refresh'),
                            ),
                            PopupMenuItem(
                              value: _HubAction.syncThread,
                              enabled: !_syncingThread,
                              child: const Text('Sync Thread network'),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: _HubAction.remove,
                              child: Text('Remove hub', style: TextStyle(color: cs.error)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _detailsCard(cs),
                  ],
                ),
    );
  }
}
