import 'package:flutter/material.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/switch_group.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/cluster_parser.dart';
import 'package:matter_home/ui/screens/device_settings/add_connection_sheet.dart';
import 'package:matter_home/ui/screens/device_settings/connection_card.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Connections screen — one card per (target device × slot)
// ─────────────────────────────────────────────────────────────────────────────

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({required this.device, super.key});
  final MatterDevice device;

  List<SwitchGroup> _groups(DeviceProvider provider) {
    final json = provider.clusterCacheFor(device.id);
    if (json == null) return [];
    return extractSwitchGroups(extractReadings(parseClusters(json), device.deviceType));
  }

  @override
  Widget build(BuildContext context) {
    final provider    = context.watch<DeviceProvider>();
    final connections = provider.connectionsFor(device.id);
    final groups      = _groups(provider);
    final cs          = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Linked devices')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          for (final conn in connections)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ConnectionCard(source: device, connection: conn, groups: groups),
            ),
          const SizedBox(height: 4),
          if (groups.isEmpty && device.deviceType.isSwitch)
            Card(
              color: cs.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Open the device screen first so button data can load.',
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ),
                ]),
              ),
            ),
          Card(
            color: cs.surface,
            child: ListTile(
              leading: Icon(Icons.add_circle_outline, color: cs.primary),
              title: const Text('Connect a device'),
              enabled: !device.deviceType.isSwitch || groups.isNotEmpty,
              onTap: groups.isNotEmpty || !device.deviceType.isSwitch
                  ? () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: cs.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      builder: (_) => AddConnectionSheet(source: device, groups: groups),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
