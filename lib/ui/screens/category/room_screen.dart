import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/device_group.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/home_category.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/widgets/device_card.dart';
import 'package:matter_home/ui/widgets/dot_matrix_empty_hint.dart';
import 'package:matter_home/ui/widgets/room_group_card.dart';
import 'package:provider/provider.dart';

/// One room inside a category: its shared controls, then its devices.
///
/// Reached by tapping a room in the category list, which shows rooms rather
/// than every device at once — a house with thirty lights is a wall of cards,
/// and the room is the thing people actually reach for.
class RoomScreen extends StatelessWidget {
  const RoomScreen({required this.category, required this.roomId, super.key});

  final HomeCategory category;
  final int roomId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final entry = provider.deviceViewsByRoom
        .where((e) => e.$1.id == roomId)
        .firstOrNull;
    final group = DeviceGroup(
      room: entry?.$1 ?? provider.rooms.first,
      devices: [
        for (final v in entry?.$2 ?? const <DeviceView>[])
          if (category.matches(v)) v,
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(group.room.name),
        foregroundColor: category.color,
      ),
      // The room can empty out while it is open — the last light in it moves
      // rooms, or the controller drops it — so this is a real state, not a
      // screen you can only reach by mistake.
      body: group.isEmpty
          ? DotMatrixEmptyHint(
              headline: 'EMPTY ROOM',
              subline: 'NO ${category.label.toUpperCase()} HERE',
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    // No name on the card: the app bar already carries it.
                    child: RoomGroupCard(
                        group: group, accent: category.color, showName: false),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => DeviceCard(
                        deviceId: group.devices[i].id,
                        onTap: () =>
                            context.push('/device/${group.devices[i].id}'),
                      ),
                      childCount: group.devices.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
