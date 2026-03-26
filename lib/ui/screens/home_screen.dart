import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/device_provider.dart';
import '../widgets/device_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nothing else Matters',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_outlined),
            tooltip: 'Add device',
            onPressed: () => context.push('/commission'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          if (provider.state == DeviceProviderState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.devices.isEmpty) {
            return const SizedBox.shrink();
          }

          return RefreshIndicator(
            onRefresh: provider.refreshAll,
            child: CustomScrollView(
              slivers: [
                ..._buildRoomSections(context, provider),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildRoomSections(BuildContext context, DeviceProvider provider) {
    final rooms = provider.rooms;
    if (rooms.isEmpty) return [];

    return rooms.expand((room) {
      final roomDevices =
          provider.devices.where((d) => d.room == room).toList();
      return [
        if (room != 'Unassigned')
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
            sliver: SliverToBoxAdapter(
              child: Text(
                room,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final device = roomDevices[i];
                return DeviceCard(
                  device: device,
                  onTap: () => context.push('/device/${device.id}'),
                );
              },
              childCount: roomDevices.length,
            ),
          ),
        ),
      ];
    }).toList();
  }
}
