import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/providers/room_provider.dart';
import 'package:matter_home/ui/widgets/bottom_sheet_scaffold.dart';
import 'package:provider/provider.dart';

class RoomPickerSheet extends StatefulWidget {
  const RoomPickerSheet({required this.deviceId, super.key});
  final String deviceId;

  @override
  State<RoomPickerSheet> createState() => _RoomPickerSheetState();
}

class _RoomPickerSheetState extends State<RoomPickerSheet> {
  Future<void> _createRoom(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New room'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Room name', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final room = await context.read<RoomProvider>().createRoom(name);
    if (!context.mounted) return;
    await context.read<RoomProvider>().assignRoom(widget.deviceId, room.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs            = Theme.of(context).colorScheme;
    final deviceProvider = context.watch<DeviceProvider>();
    final roomProvider   = context.watch<RoomProvider>();
    final device         = deviceProvider.findById(widget.deviceId);
    final rooms          = roomProvider.rooms;
    final currentRoomId  = device?.roomId ?? (rooms.isNotEmpty ? rooms.first.id : null);

    return BottomSheetScaffold(
      title: 'Room',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final room in rooms)
                  RadioListTile<String>(
                    value: room.id,
                    groupValue: currentRoomId,
                    secondary: Icon(Icons.meeting_room_outlined,
                        color: room.id == currentRoomId ? cs.primary : cs.onSurfaceVariant),
                    title: Text(room.name),
                    onChanged: (_) async {
                      await context.read<RoomProvider>().assignRoom(widget.deviceId, room.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.add_circle_outline, color: cs.primary),
                  title: Text('New room', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500)),
                  onTap: () => _createRoom(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
