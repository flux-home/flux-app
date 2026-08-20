import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/models/energy_role.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/utils/power_format.dart';

const _homeColor = Color(0xFFF3B8D6); // pink — the house, as elsewhere
const _otherColor = Color(0x33FFFFFF); // the part nothing accounts for

/// What inside the house is using the power.
///
/// A companion to the flow card, not a part of it: that one answers "where is
/// energy flowing" between solar, grid, battery and the house, and this one opens
/// the house up. Keeping them apart keeps each honest — the flow card's rows have
/// to balance, while these rows only have to add up to the house.
///
/// Rows come from devices the user marked [EnergyRole.homeConsumer], longest bar
/// first, with the unexplained remainder last. It renders nothing at all when
/// nothing is labelled: an empty breakdown is worse than no breakdown.
class HouseBreakdownCard extends StatelessWidget {
  const HouseBreakdownCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final s = provider.energySummary;

    final rows = <(String, double)>[
      for (final d in provider.deviceViews)
        if (d.energyRole == EnergyRole.homeConsumer && d.isOnline)
          (d.name, ((d.activePowerMw ?? 0) / 1000.0).abs()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    if (rows.isEmpty) return const SizedBox.shrink();

    final house = s.homeExcludingAssets;
    final unaccounted = s.restOfHome;
    final scale = [
      for (final r in rows) r.$2,
      unaccounted,
    ].fold<double>(1, (m, v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Text('IN THE HOUSE', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 2.4,
                  color: cs.onSurfaceVariant)),
              const Spacer(),
              Text(powerLabelW(house), style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11,
                  color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                for (final r in rows)
                  _BreakdownRow(
                      label: r.$1, watts: r.$2, scale: scale, color: _homeColor),
                if (unaccounted > 20)
                  _BreakdownRow(
                    label: 'Everything else',
                    watts: unaccounted,
                    scale: scale,
                    color: _otherColor,
                    // Not a device and not a mystery to solve — it is simply the
                    // part of the house nobody has put a meter on.
                    muted: true,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.watts,
    required this.scale,
    required this.color,
    this.muted = false,
  });

  final String label;
  final double watts;
  final double scale;
  final Color  color;
  final bool   muted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final frac = (watts / scale).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: muted ? cs.onSurfaceVariant : cs.onSurface)),
              ),
              const SizedBox(width: 10),
              Text(powerLabelW(watts), style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: muted ? cs.onSurfaceVariant : cs.onSurface)),
            ],
          ),
          const SizedBox(height: 6),
          // Bars are relative to the biggest row, not to the house total: the
          // question here is which device dominates, and scaling to the total
          // flattens every row into a stub when one appliance dwarfs the rest.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
