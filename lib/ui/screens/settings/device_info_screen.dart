import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:provider/provider.dart';

/// Read-only identity/health for one controller, plus the destructive
/// "Remove controller" action at the bottom (moved off the old dots menu).
class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({super.key, this.controllerId});

  /// Optional hint for the PSK lookup; falls back to the live service identity.
  final String? controllerId;

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  ControllerInfo? _info;
  Uint8List?      _storedPsk;
  ThreadDataset?  _activeDataset;
  bool            _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _idFor(HubConnection hub) =>
      hub.service?.endpoint.dtlsIdentity ?? widget.controllerId ?? '';

  Future<void> _load() async {
    final hub = context.read<HubConnection>();
    final svc = hub.service;
    final info = svc == null ? null : await svc.getInfo();
    final ds   = await ThreadSettingsService.loadActive();
    final psk  = await ControllerSettings.loadPsk(_idFor(hub));
    if (!mounted) return;
    setState(() {
      _info          = info;
      _activeDataset = ds;
      _storedPsk     = psk;
      _loaded        = true;
    });
  }

  Future<void> _remove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove controller?'),
        content: const Text(
            'The pairing key will be deleted. The app will no longer connect to '
            'this controller until you add it again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final hub = context.read<HubConnection>();
    await ControllerSettings.clearPsk(_idFor(hub));
    await hub.connect();
    if (!mounted) return;
    Navigator.of(context).pop();   // back to Settings
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Controller removed')));
  }

  static String _formatUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _pskSummary(Uint8List psk) =>
      '${psk.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}…';

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120,
                child: Text(label, style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
            Expanded(child: Text(value,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final version = _info?.firmwareVersion ?? '';
    final fabricProvisioned = (_info?.fabricId.toInt() ?? 0) != 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Device info')),
      body: !_loaded
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row('Name', _info?.hostname.isNotEmpty ?? false
                            ? _info!.hostname : (widget.controllerId ?? 'Controller')),
                        if (_info?.ethernetIp.isNotEmpty ?? false)
                          _row('IP address', _info!.ethernetIp),
                        if (version.isNotEmpty) _row('Firmware', version),
                        if ((_info?.uptimeSeconds ?? 0) > 0)
                          _row('Uptime', _formatUptime(_info!.uptimeSeconds)),
                        _row('Fabric', fabricProvisioned
                            ? '0x${_info!.fabricId.toHexString()}' : 'none'),
                        _row('Thread network',
                            _activeDataset != null && !_activeDataset!.isEmpty
                                ? _activeDataset!.label : 'none'),
                        if (_storedPsk != null)
                          _row('Pairing key', '${_pskSummary(_storedPsk!)} (stored)'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: _remove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove controller'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
