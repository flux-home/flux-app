import 'package:flutter/material.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/screens/device_settings/connections_screen.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Automations summary tile → pushes to connections screen
// ─────────────────────────────────────────────────────────────────────────────

class AutomationsSummaryTile extends StatelessWidget {
  const AutomationsSummaryTile({required this.device, super.key});
  final MatterDevice device;

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final provider    = context.watch<DeviceProvider>();
    final connections = provider.connectionsFor(device.id);
    final targetIds   = connections.map((c) => c.targetDeviceId).toSet().toList();

    return Card(
      color: cs.surface,
      child: ListTile(
        title: targetIds.isEmpty
            ? Text('No linked devices', style: TextStyle(color: cs.onSurfaceVariant))
            : Wrap(
                spacing: 6, runSpacing: 4,
                children: [
                  for (final id in targetIds)
                    if (provider.viewFor(id) case final view?)
                      Chip(
                        label: Text(view.name, style: const TextStyle(fontSize: 11)),
                        avatar: Icon(view.deviceType.icon, size: 13),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                ],
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => ConnectionsScreen(device: device)),
        ),
      ),
    );
  }
}
