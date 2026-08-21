import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/home_category.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/screens/home/energy_timeline_card.dart';
import 'package:matter_home/ui/screens/home/energy_flow_card.dart';
import 'package:matter_home/ui/screens/home/house_breakdown_card.dart';
import 'package:matter_home/ui/screens/home/day_balance_card.dart';
import 'package:matter_home/ui/screens/settings/energy_settings_screen.dart';
import 'package:matter_home/ui/widgets/device_card.dart';
import 'package:matter_home/ui/widgets/dot_matrix_empty_hint.dart';
import 'package:provider/provider.dart';

/// A single top-level category surface (Energy / Lighting / Climate).
///
/// Energy leads with the [EnergyFlowCard] ledger; every category then
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

    // The Energy view always leads with the flow ledger (which says so itself
    // when no roles are assigned), so it is never "empty".
    final showScene = category == HomeCategory.energy;
    final isEmpty = devices.isEmpty && !showScene;

    return Scaffold(
      appBar: AppBar(
        title: Text(category.label),
        foregroundColor: color,
        actions: [
          if (showScene)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Energy setup',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute<void>(
                      builder: (_) => const EnergySettingsScreen())),
            ),
        ],
      ),
      body: isEmpty
          ? DotMatrixEmptyHint(
              headline: 'NO ${category.label.toUpperCase()}',
              subline: 'NOTHING HERE YET',
            )
          : CustomScrollView(
              slivers: [
                if (showScene) _EnergyCards(provider: provider),
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

/// The Energy view's cards, in whatever order the user dragged them into.
///
/// Long-press to pick a card up: a plain drag would fight the chart's own
/// horizontal scrub gesture, and a handle would put furniture on every card for
/// something done once.
///
/// The order is stored by key rather than by index, so adding a card in a later
/// version appends it instead of shuffling everything after it — and a key that
/// disappears is simply skipped rather than leaving a hole.
class _EnergyCards extends StatelessWidget {
  const _EnergyCards({required this.provider});

  final DeviceProvider provider;

  static const _cards = <String, Widget>{
    'flow': EnergyFlowCard(),
    'house': HouseBreakdownCard(),
    'timeline': EnergyTimelineCard(),
    'balance': DayBalanceCard(),
  };

  List<String> get _order {
    final saved = provider.energyCardOrder;
    if (saved == null) return _cards.keys.toList();
    return [
      ...saved.where(_cards.containsKey),
      ..._cards.keys.where((k) => !saved.contains(k)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return SliverReorderableList(
      itemCount: order.length,
      onReorder: (from, to) {
        final next = [...order];
        final moved = next.removeAt(from);
        next.insert(from < to ? to - 1 : to, moved);
        provider.setEnergyCardOrder(next);
      },
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 8,
        child: child,
      ),
      itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(order[i]),
        index: i,
        child: _cards[order[i]]!,
      ),
    );
  }
}
