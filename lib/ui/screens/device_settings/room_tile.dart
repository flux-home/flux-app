import 'package:flutter/material.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/screens/device_settings/room_picker_sheet.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Room tile
// ─────────────────────────────────────────────────────────────────────────────

class RoomTile extends StatelessWidget {
  const RoomTile({required this.device, super.key});
  final MatterDevice device;

  Future<void> _showSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => RoomPickerSheet(deviceId: device.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final d        = provider.findById(device.id) ?? device;
    final rooms    = provider.rooms;
    final room     = rooms.firstWhere(
      (r) => r.id == d.roomId,
      orElse: () => rooms.first,
    );

    return Card(
      color: cs.surface,
      child: ListTile(
        leading: Icon(Icons.meeting_room_outlined, color: cs.primary),
        title: Text(room.name),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        onTap: () => _showSheet(context),
      ),
    );
  }
}
