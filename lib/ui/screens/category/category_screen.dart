import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/home_category.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/screens/home/energy_history_card.dart';
import 'package:matter_home/ui/screens/home/energy_price_card.dart';
import 'package:matter_home/ui/screens/home/house_energy_scene.dart';
import 'package:matter_home/ui/widgets/device_card.dart';
import 'package:matter_home/ui/widgets/dot_matrix_empty_hint.dart';
import 'package:provider/provider.dart';

/// A single top-level category surface (Energy / Lighting / Climate).
///
/// Energy leads with the illustrated [HouseEnergyScene]; every category then
/// lists its matching devices in a grid. Reached from the home-screen
/// [CategoryBar].
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({required this.category, super.key});

  final HomeCategory category;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final devices  = provider.deviceViews.where(category.matches).toList();
    final color    = category.color;

    // The Energy view always leads with the house scene (all slots shown, the
    // unconfigured ones dimmed), so it's never "empty".
    final showScene = category == HomeCategory.energy;
    final isEmpty = devices.isEmpty && !showScene;

    return Scaffold(
      appBar: AppBar(
        title: Text(category.label),
        foregroundColor: color,
      ),
      body: isEmpty
          ? DotMatrixEmptyHint(
              headline: 'NO ${category.label.toUpperCase()}',
              subline: 'NOTHING HERE YET',
            )
          : CustomScrollView(
              slivers: [
                if (showScene) ...[
                  const SliverToBoxAdapter(child: HouseEnergyScene()),
                  const SliverToBoxAdapter(child: EnergyHistoryCard()),
                  const SliverToBoxAdapter(child: EnergyPriceCard()),
                ],
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => DeviceCard(
                        deviceId: devices[i].id,
                        onTap: () => context.push('/device/${devices[i].id}'),
                      ),
                      childCount: devices.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
