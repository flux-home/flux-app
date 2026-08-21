import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/home_category.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/home/energy_timeline_card.dart';
import 'package:matter_home/ui/screens/home/energy_flow_card.dart';
import 'package:matter_home/ui/screens/home/house_breakdown_card.dart';
import 'package:matter_home/ui/screens/home/day_balance_card.dart';
import 'package:matter_home/ui/screens/settings/modbus_devices_screen.dart';
import 'package:matter_home/ui/screens/settings/tariff_settings_screen.dart';
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
      ),
      body: isEmpty
          ? DotMatrixEmptyHint(
              headline: 'NO ${category.label.toUpperCase()}',
              subline: 'NOTHING HERE YET',
            )
          : CustomScrollView(
              slivers: [
                if (showScene) ...[
                  const SliverToBoxAdapter(child: EnergyFlowCard()),
                  const SliverToBoxAdapter(child: HouseBreakdownCard()),
                  const SliverToBoxAdapter(child: EnergyTimelineCard()),
                  const SliverToBoxAdapter(child: DayBalanceCard()),
                  const SliverToBoxAdapter(child: _EnergySetupCard()),
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

/// Energy configuration surfaced in the Energy view: the electricity tariff and
/// the Modbus meters/inverters that feed it. Both write to the controller, so
/// they're disabled (with a hint) whenever the hub isn't reachable.
class _EnergySetupCard extends StatelessWidget {
  const _EnergySetupCard();

  @override
  Widget build(BuildContext context) {
    final online = context.watch<HubConnection>().isOnline;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          _row(context,
              icon: Icons.euro_outlined,
              title: 'Electricity tariff',
              subtitle: 'Fees, levies & VAT on top of spot',
              enabled: online,
              builder: () => const TariffSettingsScreen()),
          Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
          _row(context,
              icon: Icons.dns_outlined,
              title: 'Modbus meters',
              subtitle: 'Meters & inverters over Modbus',
              enabled: online,
              builder: () => const ModbusDevicesScreen()),
          if (!online)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Connect to your controller to change these.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required Widget Function() builder,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? cs.primary : cs.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: enabled
          ? () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => builder()))
          : null,
    );
  }
}
