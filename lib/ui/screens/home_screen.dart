import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/room.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/add_controller_flow.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/qr_scanner_screen.dart';
import 'package:matter_home/ui/widgets/category_bar.dart';
import 'package:matter_home/ui/widgets/device_card.dart';
import 'package:matter_home/ui/widgets/dot_matrix_empty_hint.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Commissioning requires a hub (see CommissioningController), so the FAB
    // surfaces whichever action is actually possible: pair a hub first, then
    // add devices once one is connected.
    final hub = context.watch<HubConnection>();
    final hubConnected  = hub.isConnected;
    final hubConfigured = hub.hasConfiguredHub;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flux Home', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings'))],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => hubConnected ? _addDevice(context) : _addHub(context),
        elevation: 2,
        shape: const CircleBorder(),
        tooltip: hubConnected ? 'Add device' : 'Add hub',
        child: Icon(hubConnected ? Icons.add : Icons.router_outlined, size: 28),
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          if (provider.state == DeviceProviderState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = provider.deviceViewsByRoom;

          // If every room is empty the device list is empty overall.
          final totalDevices = groups.fold<int>(0, (sum, g) => sum + g.$2.length);

          return RefreshIndicator(
            // Pull down to re-fetch the controller's device list. When a hub is
            // configured but currently offline, also retry the connection.
            onRefresh: () async {
              final hub = context.read<HubConnection>();
              if (!hub.isConnected && hub.hasConfiguredHub) {
                await hub.reconnect();
              }
              await provider.syncWithController();
            },
            child: totalDevices == 0
                ? CustomScrollView(
                    // AlwaysScrollable so the pull gesture works even when the
                    // (otherwise non-scrolling) empty hint is shown.
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: DotMatrixEmptyHint(
                          headline: hubConnected
                              ? 'NO DEVICES'
                              : hubConfigured ? 'HUB OFFLINE' : 'NO HUB YET',
                          subline: hubConnected
                              ? 'TAP + TO ADD'
                              : hubConfigured ? 'PULL TO RECONNECT' : 'TAP + TO PAIR',
                        ),
                      ),
                    ],
                  )
                : _buildDeviceList(context, groups),
          );
        },
      ),
    );
  }

  Future<void> _addDevice(BuildContext context) async {
    // Let flutter_zxing trigger the native camera permission dialog
    // on first use — no explicit pre-check needed on iOS.
    final payload = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    if (payload != null && context.mounted) {
      unawaited(context.push('/commission', extra: payload));
    }
  }

  Future<void> _addHub(BuildContext context) => runAddControllerFlow(context);

  Widget _buildDeviceList(
    BuildContext context,
    List<(Room, List<DeviceView>)> groups,
  ) {
    return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Category buttons (Energy / Lighting / Climate) ───────────
              const SliverToBoxAdapter(child: CategoryBar()),
              for (final (room, views) in groups)
                if (room.isNoRoom && views.isEmpty) ...[] else ...[
                // ── Room header ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: SectionLabel(room.name),
                  ),
                ),

                // ── Device grid for this room ────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: views.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'No devices',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => DeviceCard(
                              deviceId: views[i].id,
                              onTap: () => context.push('/device/${views[i].id}'),
                            ),
                            childCount: views.length,
                          ),
                        ),
                ),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
            ],
          );
  }
}
