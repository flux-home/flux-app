import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/models/room.dart';
import 'package:matter_home/providers/device_provider.dart';

/// Room management — list and delete.
///
/// Lives under the CONTROLLER panel because that is where rooms live: the
/// controller owns the list and the membership, so this screen is a view of its
/// state, not of the phone's.
///
/// Creating a room stays where a room is actually wanted — the picker on the
/// device settings screen and the commissioning flow. This screen exists for the
/// one thing those cannot express: removing one.
class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final rooms    = provider.rooms.where((r) => !r.isNoRoom).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          if (rooms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'No rooms yet. Add one when you assign a device to a room.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          else
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < rooms.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 16, endIndent: 16,
                          color: cs.outlineVariant),
                    _RoomRow(
                      room:  rooms[i],
                      count: provider.devices
                          .where((d) => d.roomId == rooms[i].id)
                          .length,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room, required this.count});

  final Room room;
  final int  count;

  Future<void> _delete(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${room.name}?'),
        // Say what happens to the devices. Deleting a room never deletes a
        // device — the controller resets each one to No Room — and the user
        // should not have to find that out by trying it.
        content: Text(count == 0
            ? 'The room will be removed.'
            : '$count device${count == 1 ? '' : 's'} will move to No Room. '
              'Nothing is removed from your home.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await context.read<DeviceProvider>().deleteRoom(room.id);
    if (!context.mounted) return;
    if (!ok) {
      // The controller owns the list, so a delete it did not accept did not
      // happen — don't let the row disappear and reappear on the next sync.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't reach the controller — room not removed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(room.name),
      subtitle: Text(count == 0
          ? 'No devices'
          : '$count device${count == 1 ? '' : 's'}'),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        color: cs.onSurfaceVariant,
        tooltip: 'Remove room',
        onPressed: () => _delete(context),
      ),
    );
  }
}
