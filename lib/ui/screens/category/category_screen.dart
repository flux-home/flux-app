import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/home_category.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/screens/home/energy_flow_view.dart';
import 'package:matter_home/ui/widgets/device_card.dart';
import 'package:matter_home/ui/widgets/dot_matrix_empty_hint.dart';
import 'package:provider/provider.dart';

/// A single top-level category surface (Energy / Lighting / Climate).
///
/// Energy leads with the live [HomeEnergyOverview]; every category then lists
/// its matching devices in a grid. Reached from the home-screen [CategoryBar].
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({required this.category, super.key});

  final HomeCategory category;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final devices  = provider.deviceViews.where(category.matches).toList();
    final color    = category.color;

    final showEnergyFlow =
        category == HomeCategory.energy && provider.energySummary.hasAnyRole;
    final isEmpty = devices.isEmpty && !showEnergyFlow;

    return Scaffold(
      appBar: AppBar(
        title: Text(category.label),
        foregroundColor: color,
      ),
      body: isEmpty
          ? DotMatrixEmptyHint(
              headline: 'NO ${category.label.toUpperCase()}',
              subline: category == HomeCategory.energy
                  ? 'ASSIGN ROLES IN DEVICE SETTINGS'
                  : 'NOTHING HERE YET',
            )
          : CustomScrollView(
              slivers: [
                if (showEnergyFlow)
                  SliverToBoxAdapter(
                    child: HomeEnergyOverview(summary: provider.energySummary),
                  ),
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
