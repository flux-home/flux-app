import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/room.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:provider/provider.dart';

/// Shown immediately after a successful commissioning.
///
/// The user picks an existing room, creates a new one, or skips.
/// On confirm / skip the screen navigates to the device detail page.
class RoomPickerScreen extends StatefulWidget {
  const RoomPickerScreen({required this.deviceId, super.key});
  final String deviceId;

  @override
  State<RoomPickerScreen> createState() => _RoomPickerScreenState();
}

class _RoomPickerScreenState extends State<RoomPickerScreen> {
  /// Currently highlighted room — defaults to "No Room".
  String _selectedRoomId = Room.noRoomId;
  bool _confirming = false;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    await context.read<DeviceProvider>().assignRoom(widget.deviceId, _selectedRoomId);
    if (mounted) context.go('/');
  }

  void _skip() => context.go('/');

  Future<void> _createRoom() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New room'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Room name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final room = await context.read<DeviceProvider>().createRoom(name);
    setState(() => _selectedRoomId = room.id);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final rooms  = context.watch<DeviceProvider>().rooms;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Assign to room',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _confirming ? null : _skip,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Room list ───────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount: rooms.length + 1, // +1 for "New room" row
              itemBuilder: (ctx, i) {
                if (i < rooms.length) {
                  final room     = rooms[i];
                  final selected = room.id == _selectedRoomId;
                  return RadioListTile<String>(
                    value:       room.id,
                    groupValue:  _selectedRoomId,
                    title:       Text(room.name),
                    secondary:   Icon(
                      Icons.meeting_room_outlined,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    onChanged: (_) => setState(() => _selectedRoomId = room.id),
                  );
                }
                // "New room" row
                return ListTile(
                  leading: Icon(Icons.add_circle_outline, color: cs.primary),
                  title: Text(
                    'New room',
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500),
                  ),
                  onTap: _createRoom,
                );
              },
            ),
          ),

          // ── Confirm button ───────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirming ? null : _confirm,
                  child: _confirming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
