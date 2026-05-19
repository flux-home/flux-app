import 'package:flutter/material.dart';
import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/switch_group.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/screens/device_settings/connection_detail_sheet.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Connection card: target device + gesture summary + edit tap
// ─────────────────────────────────────────────────────────────────────────────

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    required this.source,
    required this.connection,
    required this.groups,
    super.key,
  });
  final MatterDevice      source;
  final DeviceConnection  connection;
  final List<SwitchGroup> groups;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final view = context.read<DeviceProvider>().viewFor(connection.targetDeviceId);
    if (view == null) return const SizedBox.shrink();

    final pills = <Widget>[for (final rule in connection.rules) _GesturePill(rule: rule)];

    return Card(
      color: cs.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: cs.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          builder: (_) => ConnectionDetailSheet(
            source: source, connection: connection, targetView: view, groups: groups),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
                child: Icon(view.deviceType.icon, size: 20, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(view.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    if (connection.switchGroup != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(6)),
                        child: Text('Slot ${connection.switchGroup}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
                      ),
                  ]),
                  if (pills.isNotEmpty) ...[const SizedBox(height: 6), Wrap(spacing: 6, runSpacing: 4, children: pills)],
                ]),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gesture pill ──────────────────────────────────────────────────────────────

class _GesturePill extends StatelessWidget {
  const _GesturePill({required this.rule});
  final AutomationRule rule;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_triggerIcon(rule.trigger), size: 11, color: cs.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(rule.action.label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

IconData _triggerIcon(TriggerType t) => switch (t) {
  TriggerType.switchPress  => Icons.radio_button_checked_outlined,
  TriggerType.switchCw     => Icons.keyboard_arrow_up,
  TriggerType.switchCcw    => Icons.keyboard_arrow_down,
  TriggerType.contactOpen  => Icons.meeting_room_outlined,
  TriggerType.contactClose => Icons.sensor_door_outlined,
};
