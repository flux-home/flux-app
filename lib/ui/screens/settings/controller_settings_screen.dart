import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/matter_channel.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/thread_settings_service.dart';
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
  bool             _pushingThread = false;
  Uint8List?       _storedPsk;
  bool             _pskLoaded    = false;
  ThreadDataset?   _activeDataset;

  @override
  void initState() {
    super.initState();
    _loadPskStatus();
    _loadActiveDataset();
    final svc = context.read<HubConnection>().service;
    if (svc != null) _fetchInfo(svc);
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
    final info = await svc.getInfo();
    if (mounted) setState(() => _info = info);
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
      setState(() { _storedPsk = null; _info = null; });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Controller removed')));
    }
  }

  Future<void> _syncFabric() async {
    final hub = context.read<HubConnection>();
    final svc = hub.service;
    if (svc == null) return;

    setState(() => _syncing = true);
    try {
      final localChannel = context.read<MatterChannel>();
      final creds = await localChannel.exportFabricForController();
      if (!mounted) return;
      if (creds == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to export fabric — CHIP SDK not ready')));
        return;
      }

      final result = await svc.provisionFabric(
        fabricId:  creds.fabricId,
        nodeId:    0x0002,
        rootCaTlv: creds.rootCaTlv,
        nocTlv:    creds.nocTlv,
        opPrivKey: creds.opPrivKey,
        ipk:       creds.ipk,
        vendorId:  0xFFF1,
      );
      if (!mounted) return;

      if (result != null && result.success) {
        final hostname = hub.service?.endpoint.dtlsIdentity
            ?? _info?.hostname
            ?? hub.service?.endpoint.host ?? '';
        if (hostname.isNotEmpty) {
          await ControllerSettings.saveProvisionedFlag(hostname);
        }
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fabric synced to controller')));
        _fetchInfo(svc);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sync failed: ${result?.error ?? 'no response'}')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _pushThreadDataset() async {
    final svc = context.read<HubConnection>().service;
    if (svc == null || _activeDataset == null) return;

    final hex = _activeDataset!.hex.replaceAll(RegExp(r'\s'), '');
    if (hex.isEmpty) return;

    setState(() => _pushingThread = true);
    try {
      final bytes = Uint8List.fromList(List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ));
      final ok = await svc.postThreadDataset(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Thread dataset pushed to controller ✓'
            : 'Push failed — check controller logs'),
      ));
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _pushingThread = false);
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
    final cs  = Theme.of(context).colorScheme;
    final hub = context.watch<HubConnection>();
    final connected = hub.isConnected;
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
            tooltip: 'Search for controller',
            onPressed: _loading ? null : _rediscover,
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ── Connection status ─────────────────────────────────────────────
          _sectionLabel(context, 'Connection'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected
                          ? Colors.green.shade400
                          : cs.outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: connected && _info != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Connected',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              _row('Host',     _info!.hostname),
                              _row('IP',       _info!.ethernetIp),
                              _row('Firmware', _info!.firmwareVersion),
                            ],
                          )
                        : Text(
                            _loading
                                ? 'Searching…'
                                : connected
                                    ? 'Connected — loading info…'
                                    : hasPsk
                                        ? 'Controller not found.\nTap ↺ to search again.'
                                        : 'No controller added yet.\nTap "Add Controller" below.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Controller ────────────────────────────────────────────────────
          _sectionLabel(context, 'Controller'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (hasPsk) ...[
                  ListTile(
                    leading: Icon(Icons.lock_outlined,
                        color: connected
                            ? Colors.green.shade400
                            : cs.onSurfaceVariant),
                    title: Text(
                      connected ? 'Secured (DTLS)' : 'Controller added',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    subtitle: Text(
                      'PSK: ${_pskSummary(_storedPsk!)}',
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: cs.onSurfaceVariant),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: cs.error),
                    title: Text('Remove controller',
                        style: TextStyle(color: cs.error)),
                    onTap: _clearPsk,
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Add Controller'),
                    subtitle: const Text('Scan the QR code on the controller'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _loading ? null : _addController,
                  ),
                ],
              ],
            ),
          ),

          if (connected && _activeDataset != null) ...[
            const SizedBox(height: 24),
            _sectionLabel(context, 'Thread'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                leading: _pushingThread
                    ? SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cs.primary))
                    : Icon(Icons.upload_outlined, color: cs.primary),
                title: const Text('Push Thread dataset'),
                subtitle: Text(
                  _activeDataset!.label,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                onTap: _pushingThread ? null : _pushThreadDataset,
              ),
            ),
          ],

          if (connected) ...[
            const SizedBox(height: 24),
            _sectionLabel(context, 'Fabric'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (_info != null)
                    ListTile(
                      leading: Icon(
                        _info!.fabricId.toInt() != 0
                            ? Icons.verified_outlined
                            : Icons.sync_problem_outlined,
                        color: _info!.fabricId.toInt() != 0
                            ? Colors.green.shade400
                            : cs.error,
                      ),
                      title: Text(
                        _info!.fabricId.toInt() != 0
                            ? 'Provisioned'
                            : 'Not provisioned',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle: _info!.fabricId.toInt() != 0
                          ? Text(
                              'Fabric ID: 0x${_info!.fabricId.toHexString()}',
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant),
                            )
                          : Text(
                              'Controller has no fabric identity',
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                            ),
                    ),
                  if (_info != null)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: _syncing
                        ? SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: cs.primary))
                        : const Icon(Icons.sync_outlined),
                    title: Text(
                      _info?.fabricId.toInt() != 0
                          ? 'Re-sync fabric'
                          : 'Sync fabric to controller',
                    ),
                    subtitle: const Text(
                        'Sends the app\'s Root CA and controller NOC via CoAP'),
                    onTap: _syncing ? null : _syncFabric,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Text(label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.8)),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      SizedBox(width: 72,
          child: Text('$label:', style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500))),
      Expanded(child: Text(value, style: const TextStyle(
          fontSize: 12, fontFamily: 'monospace'))),
    ]),
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
