import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/room.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/screens/qr_scanner_screen.dart';
import 'package:matter_home/ui/theme.dart';
import 'package:matter_home/ui/widgets/device_card.dart';
import 'package:matter_home/ui/widgets/dot_matrix_painter.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flux Home', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings'))],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (!context.mounted) return;
          // Let flutter_zxing trigger the native camera permission dialog
          // on first use — no explicit pre-check needed on iOS.
          final payload = await Navigator.of(context)
              .push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
          if (payload != null && context.mounted) {
            unawaited(context.push('/commission', extra: payload));
          }
        },
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
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
            // Pull down to re-fetch the controller's device list. No-op in
            // standalone mode (no controller connected).
            onRefresh: () => provider.syncWithController(),
            child: totalDevices == 0
                ? const CustomScrollView(
                    // AlwaysScrollable so the pull gesture works even when the
                    // (otherwise non-scrolling) empty hint is shown.
                    physics: AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyDeviceHint(),
                      ),
                    ],
                  )
                : _buildDeviceList(context, groups),
          );
        },
      ),
    );
  }

  Widget _buildDeviceList(
    BuildContext context,
    List<(Room, List<DeviceView>)> groups,
  ) {
    return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
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

// ---------------------------------------------------------------------------
// Empty-state hint
// ---------------------------------------------------------------------------

class _EmptyDeviceHint extends StatelessWidget {
  const _EmptyDeviceHint();

  @override
  Widget build(BuildContext context) {
    const dim = Color(0x1F6DC9A2); // kBrandGreen @ ~12 % opacity

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 280,
            height: 42,
            child: CustomPaint(
              painter: DotMatrixPainter(
                text: 'NO DEVICES',
                litColor: kBrandGreen,
                dimColor: dim,
              ),
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            width: 260,
            height: 32,
            child: CustomPaint(
              painter: DotMatrixPainter(
                text: 'TAP + TO ADD',
                litColor: kBrandGreen,
                dimColor: dim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
