import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/fabric_sync_service.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/matter_channel.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/services/thread_sync_service.dart';
import 'package:matter_home/ui/screens/qr_scanner_screen.dart';
import 'package:provider/provider.dart';

class ControllerSettingsScreen extends StatefulWidget {
  const ControllerSettingsScreen({super.key});

  @override
  State<ControllerSettingsScreen> createState() =>
      _ControllerSettingsScreenState();
}

class _ControllerSettingsScreenState extends State<ControllerSettingsScreen> {
  ControllerInfo?  _info;
  bool             _loading      = false;
  bool             _syncing      = false;
  Uint8List?       _storedPsk;
  bool             _pskLoaded    = false;
  ThreadDataset?   _activeDataset;

  /// Controller fabric state vs. the app (null = not yet checked / unknown —
  /// never alarm the user on null).
  FabricState?     _fabricState;
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
    if (info != null) _checkSync(svc);
  }

  /// Read-only fabric classification — drives the status banner.
  /// Never provisions; seeding only happens when the user taps the action.
  Future<void> _checkSync(FluxCoapService svc) async {
    final state = await FabricSyncService(
      localFabric: context.read<MatterChannel>(),
      controller: svc,
    ).readState();
    if (mounted) setState(() => _fabricState = state);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _rediscover() async {
    setState(() { _loading = true; _info = null; _fabricState = null; _online = false; });
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

  // ── Add Controller (PSK + immediate mDNS search) ──────────────────────────

  Future<void> _addController() async {
    final result = await showModalBottomSheet<String>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => const _AddControllerSheet(),
    );
    if (result == null || !mounted) return;

    // Parse flux://setup?id=<controllerId>&psk=<hex32>  OR  raw hex
    Uint8List? psk;
    String?    controllerId;
    if (result.startsWith('flux://setup')) {
      final uri = Uri.tryParse(result);
      psk          = _hexToBytes(uri?.queryParameters['psk'] ?? '');
      controllerId = uri?.queryParameters['id'];
    } else {
      psk = _hexToBytes(result.trim());
    }

    if (psk == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid PSK — expected 32 hex characters')));
      return;
    }

    // Fallback controller ID from already-connected endpoint
    final hub = context.read<HubConnection>();
    controllerId ??= _info?.hostname
        ?? hub.service?.endpoint.dtlsIdentity
        ?? hub.service?.endpoint.host;

    if (controllerId == null || controllerId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
              'Could not determine controller ID — scan the QR code')));
      return;
    }

    await ControllerSettings.savePsk(controllerId, psk,
        dtlsIdentity: controllerId);
    if (mounted) setState(() { _storedPsk = psk; });

    // Immediately search for the controller via mDNS
    setState(() { _loading = true; _info = null; });
    final found = await hub.reconnect();
    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(found
          ? '🔒 Controller found and connected'
          : 'PSK saved — controller not found yet. Tap ↺ to retry.'),
    ));
    if (found) _fetchInfo(hub.service!);
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
      setState(() { _storedPsk = null; _info = null; _fabricState = null; _online = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hub removed')));
    }
  }

  /// Joins this phone to the hub's fabric by enrolling (the hub signs our CSR)
  /// and importing the issued identity.  Triggered by the "Join hub" banner /
  /// Advanced action.
  Future<void> _repairHub() async {
    final hub = context.read<HubConnection>();
    final svc = hub.service;
    if (svc == null) return;

    setState(() => _syncing = true);
    try {
      final sync = await FabricSyncService(
        localFabric: context.read<MatterChannel>(),
        controller: svc,
      ).ensureInSync();
      if (!mounted) return;

      final message = switch (sync.status) {
        FabricSyncStatus.adopted            => 'Joined the hub — restarting to finish…',
        FabricSyncStatus.inSync             => 'Already connected to this hub ✓',
        FabricSyncStatus.adoptRequired      => 'Joining a hub isn\'t supported on '
            'this device yet — update the app',
        FabricSyncStatus.controllerNotReady => 'Hub is still starting up — try again in a moment',
        FabricSyncStatus.notReady           => 'Not ready yet — please try again in a moment',
        FabricSyncStatus.unreachable        => 'Hub is offline — check it\'s powered on and nearby',
        FabricSyncStatus.failed             => 'Couldn\'t join the hub — please try again',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      if (sync.ok) _fetchInfo(svc);
    } finally {
      if (mounted) setState(() => _syncing = false);
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
        ThreadSyncStatus.adopted     => 'Using the hub\'s Thread network ✓',
        ThreadSyncStatus.pushed      => 'Thread network sent to the hub ✓',
        ThreadSyncStatus.inSync      => 'Thread network already in sync ✓',
        ThreadSyncStatus.nothingToDo => 'No Thread network configured yet',
        ThreadSyncStatus.unreachable => 'Couldn\'t reach the hub — try again',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      if (result.status == ThreadSyncStatus.adopted) _loadActiveDataset();
    } finally {
      if (mounted) setState(() => _syncingThread = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Uint8List? _hexToBytes(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s'), '');
    if (clean.length != 32) return null;
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) return null;
    return Uint8List.fromList(List.generate(
        16, (i) => int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16)));
  }

  String _pskSummary(Uint8List psk) =>
      psk.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join() + '…';

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    context.watch<HubConnection>(); // rebuild when the service is swapped
    // "connected" = the hub is actually reachable right now (last /info ok),
    // not merely "a hub was discovered once" (hub.isConnected).
    final connected = _online;
    final hasPsk    = _pskLoaded && _storedPsk != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flux Hub'),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_outlined),
            tooltip: 'Search again',
            onPressed: _loading ? null : _rediscover,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SizedBox(height: 8),

          _statusHeader(connected: connected, hasPsk: hasPsk),

          if (connected && _fabricState == FabricState.needsAdopt)
            _joinBanner(),
          if (connected && _fabricState == FabricState.controllerNotReady)
            _startingUpBanner(),

          if (hasPsk) ...[
            const SizedBox(height: 8),
            _sectionLabel(context, 'Hub'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.lock_outline,
                        color: connected
                            ? Colors.green.shade400
                            : Theme.of(context).colorScheme.onSurfaceVariant),
                    title: const Text('Secure connection'),
                    subtitle: Text(connected
                        ? 'Your hub is connected and encrypted'
                        : 'Set up — will connect when in range'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error),
                    title: Text('Remove hub',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    onTap: _clearPsk,
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            _sectionLabel(context, 'Hub'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Add your hub'),
                subtitle: const Text('Scan the QR code on the hub to connect'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _loading ? null : _addController,
              ),
            ),
          ],

          if (connected && _info != null &&
              _info!.firmwareVersion.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel(context, 'About'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.memory_outlined),
                title: const Text('Software'),
                subtitle: Text('Version ${_info!.firmwareVersion}'),
              ),
            ),
          ],

          if (connected) _advancedSection(),
        ],
      ),
    );
  }

  // ── Status header ────────────────────────────────────────────────────────

  Widget _statusHeader({required bool connected, required bool hasPsk}) {
    final cs = Theme.of(context).colorScheme;
    final (String title, String? subtitle) = switch (true) {
      _ when _loading                       => ('Searching for your hub…', null),
      _ when connected                      => ('Connected', _hubName()),
      _ when hasPsk && _probing && !_online => ('Checking hub…', null),
      _ when hasPsk                         => ('Hub offline',
          'Make sure it\'s powered on and on the same Wi-Fi, then tap ↻'),
      _                                     => ('No hub yet', 'Add your hub to get started'),
    };

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? Colors.green.shade400 : cs.outline,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A friendly name for the hub — falls back to a generic label.
  String _hubName() {
    final host = _info?.hostname ?? '';
    return host.isNotEmpty ? host : 'Flux Hub';
  }

  // ── Banners ────────────────────────────────────────────────────────────────

  /// Shown when the hub has a fabric this phone hasn't joined yet.
  Widget _joinBanner() {
    final cs = Theme.of(context).colorScheme;
    return _bannerCard(
      color: cs.primaryContainer,
      fg: cs.onPrimaryContainer,
      icon: Icons.group_add_outlined,
      title: 'Join this hub',
      body: 'Connect this phone to the hub so it can see and control the same '
          'devices as your other phones.',
      action: FilledButton.icon(
        onPressed: _syncing ? null : _repairHub,
        icon: _syncing
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.check_circle_outline, size: 18),
        label: Text(_syncing ? 'Joining…' : 'Join hub'),
      ),
    );
  }

  /// Shown briefly while the hub is still generating its identity on first boot.
  Widget _startingUpBanner() {
    final cs = Theme.of(context).colorScheme;
    return _bannerCard(
      color: cs.surfaceContainerHighest,
      fg: cs.onSurface,
      icon: Icons.hourglass_top_outlined,
      title: 'Hub is starting up',
      body: 'Your hub is getting ready. This only takes a moment — pull to '
          'refresh if it doesn\'t finish.',
    );
  }

  Widget _bannerCard({
    required Color color,
    required Color fg,
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: color,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: fg)),
                  if (action != null) ...[
                    const SizedBox(height: 10),
                    action,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Advanced / Diagnostics (collapsed by default) ──────────────────────────

  Widget _advancedSection() {
    final cs = Theme.of(context).colorScheme;
    final fabricProvisioned = (_info?.fabricId.toInt() ?? 0) != 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.tune_outlined),
          title: const Text('Advanced'),
          subtitle: const Text('Diagnostics & technical details'),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            // Connection details
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
              fabricProvisioned
                  ? '0x${_info!.fabricId.toHexString()} · ${_fabricStateLabel()}'
                  : 'none',
            ),

            const Divider(height: 1, indent: 16, endIndent: 16),

            // Technical actions
            ListTile(
              leading: _syncing
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.primary))
                  : const Icon(Icons.sync_outlined),
              title: const Text('Join hub fabric'),
              subtitle: const Text(
                  'Enroll this phone on the hub\'s fabric (the hub signs our '
                  'certificate)'),
              onTap: _syncing ? null : _repairHub,
            ),
            ListTile(
              leading: _syncingThread
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.primary))
                  : const Icon(Icons.hub_outlined),
              title: const Text('Sync Thread network'),
              subtitle: Text(_activeDataset != null && !_activeDataset!.isEmpty
                  ? 'Adopt the hub\'s network, or send "${_activeDataset!.label}"'
                  : 'Adopt the hub\'s Thread network if it has one'),
              onTap: _syncingThread ? null : _syncThread,
            ),
          ],
        ),
      ),
    );
  }

  String _fabricStateLabel() => switch (_fabricState) {
        FabricState.inSync             => 'joined',
        FabricState.needsAdopt         => 'not joined',
        FabricState.controllerNotReady => 'hub starting up',
        _                              => 'unknown',
      };

  static String _formatUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Text(label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.8)),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
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
}

// ── Add Controller bottom sheet ───────────────────────────────────────────────

class _AddControllerSheet extends StatefulWidget {
  const _AddControllerSheet();

  @override
  State<_AddControllerSheet> createState() => _AddControllerSheetState();
}

class _AddControllerSheetState extends State<_AddControllerSheet> {
  final _hexCtrl   = TextEditingController();
  bool  _showManual = false;

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  void _confirmHex() {
    final hex = _hexCtrl.text.replaceAll(RegExp(r'\s'), '');
    if (hex.isNotEmpty) Navigator.of(context).pop(hex);
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final hexLen = _hexCtrl.text.replaceAll(RegExp(r'\s'), '').length;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: cs.onSurface.withAlpha(40),
                borderRadius: BorderRadius.circular(2)),
          )),

          Text('Add Controller',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Scan the QR code on the controller label to connect securely.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _scanQr,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            label: const Text('Scan QR code'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
          ),

          const SizedBox(height: 12),

          if (!_showManual)
            TextButton(
              onPressed: () => setState(() => _showManual = true),
              child: const Text('Enter PSK manually'),
            )
          else ...[
            TextField(
              controller: _hexCtrl,
              autofocus: true,
              keyboardType: TextInputType.text,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'e.g. a1b2c3d4e5f60718…',
                labelText: 'PSK (32 hex characters)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                counterText: '$hexLen / 32',
              ),
              maxLength: 36,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirmHex(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: hexLen == 32 ? _confirmHex : null,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('Confirm'),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
