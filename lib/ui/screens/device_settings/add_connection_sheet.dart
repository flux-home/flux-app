import 'package:flutter/material.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/switch_group.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/widgets/bottom_sheet_scaffold.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Add connection sheet — pick a target device, smart preset applied
// ─────────────────────────────────────────────────────────────────────────────

class AddConnectionSheet extends StatelessWidget {
  const AddConnectionSheet({required this.source, required this.groups, super.key});
  final MatterDevice      source;
  final List<SwitchGroup> groups;

  @override
  Widget build(BuildContext context) {
    final cs         = Theme.of(context).colorScheme;
    final provider   = context.watch<DeviceProvider>();
    final candidates = provider.linkableTargets(excludingDeviceId: source.id);

    return BottomSheetScaffold(
      title: 'Connect a device',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Text('No compatible devices found.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (_, i) {
                  final v = candidates[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(v.deviceType.icon, size: 18, color: cs.onPrimaryContainer),
                    ),
                    title:    Text(v.name),
                    subtitle: Text(v.deviceType.displayName,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    onTap: () {
                      provider.connectDevice(
                        sourceDeviceId: source.id,
                        sourceType:     source.deviceType,
                        targetDeviceId: v.id,
                        switchGroups:   groups,
                      );
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
