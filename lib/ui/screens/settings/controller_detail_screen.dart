import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/settings/device_info_screen.dart';
import 'package:matter_home/ui/screens/settings/matter_settings_screen.dart';
import 'package:matter_home/ui/screens/settings/remote_access_screen.dart';
import 'package:matter_home/ui/screens/settings/thread_settings_screen.dart';
import 'package:provider/provider.dart';

// Connection-state accents, shared with ControllerStatusChip.
const _localColor   = Color(0xFF9FD8A8); // green
const _remoteColor  = Color(0xFFA9C7F2); // blue
const _connectingC  = Color(0xFFBFC4CC); // grey
const _offlineColor = Color(0xFFF2A9A0); // coral

/// Per-controller detail: a connection header plus the submenu
/// (Device info · Matter · Thread · Remote access). The live connection is
/// single-active for now, but the UI is multi-controller-ready — [controllerId]
/// says which controller these pages belong to. Refresh is pull-to-refresh;
/// Remove lives at the bottom of Device info; Sync Thread lives on the Thread
/// page — no overflow menu.
class ControllerDetailScreen extends StatefulWidget {
  const ControllerDetailScreen({super.key, required this.controllerId});

  final String controllerId;

  @override
  State<ControllerDetailScreen> createState() => _ControllerDetailScreenState();
}

class _ControllerDetailScreenState extends State<ControllerDetailScreen> {
  ControllerInfo? _info;
  bool            _loading = false;
  Timer?          _poll;

  @override
  void initState() {
    super.initState();
    final svc = context.read<HubConnection>().service;
    if (svc != null) _fetchInfo(svc);
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      final s = context.read<HubConnection>().service;
      if (s != null && !_loading) _fetchInfo(s);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _fetchInfo(FluxCoapService svc) async {
    final info = await svc.getInfo();
    if (mounted) setState(() => _info = info);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final hub   = context.read<HubConnection>();
    final found = await hub.connect();
    if (!mounted) return;
    setState(() => _loading = false);
    if (found && hub.service != null) await _fetchInfo(hub.service!);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(found
          ? 'Connected to ${hub.service?.endpoint.host ?? _name()}'
          : 'Controller not found — make sure it is on the same network'),
    ));
  }

  String _name() {
    final h = _info?.hostname ?? '';
    return h.isNotEmpty ? h : widget.controllerId;
  }

  (Color, String) _connState(HubConnection hub) {
    if (_loading) return (_connectingC, 'Searching…');
    switch (hub.status) {
      case ControllerStatus.online:
        return hub.connectionKind == ConnectionKind.remote
            ? (_remoteColor, 'Remote')
            : (_localColor, 'Local');
      case ControllerStatus.connecting: return (_connectingC, 'Connecting…');
      case ControllerStatus.offline:    return (_offlineColor, 'Offline');
      case ControllerStatus.noHub:      return (_offlineColor, 'Offline');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubConnection>();
    final cs  = Theme.of(context).colorScheme;
    final (color, stateLabel) = _connState(hub);
    final version = _info?.firmwareVersion ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(_name())),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ── Connection header ────────────────────────────────────────
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(children: [
                  Container(width: 11, height: 11,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name(),
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
                                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: cs.onSurfaceVariant)),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // ── Submenu ──────────────────────────────────────────────────
            _navCard(cs, Icons.info_outline, 'Device info',
                'IP, firmware, fabric, pairing key',
                () => DeviceInfoScreen(controllerId: widget.controllerId)),
            _navCard(cs, Icons.hub_outlined, 'Matter',
                'Fabric & device management',
                () => const MatterSettingsScreen()),
            _navCard(cs, Icons.lan_outlined, 'Thread',
                'Thread network management',
                () => const ThreadSettingsScreen()),
            _navCard(cs, Icons.cloud_outlined, 'Remote access',
                'Reach the hub when you are away',
                () => const RemoteAccessScreen()),
          ],
        ),
      ),
    );
  }

  Widget _navCard(ColorScheme cs, IconData icon, String title, String subtitle,
          Widget Function() page) =>
      Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ListTile(
          leading: Icon(icon, color: cs.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          onTap: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => page())),
        ),
      );
}
