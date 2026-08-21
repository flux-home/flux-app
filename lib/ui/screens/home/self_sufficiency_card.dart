import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/providers/device_provider.dart';

const _selfColor = Color(0xFFA9E0C0); // mint — what the house kept
const _boughtColor = Color(0xFFF2A9A0); // coral — what it had to buy

/// How much of the last 24 h the house covered itself.
///
/// Its own card because it answers a different question from the chart beside
/// it: not what happened hour by hour, but how the day came out. It was a
/// footnote under four KPI tiles, which is where a headline number goes to be
/// ignored.
///
/// Shown as one bar split in two rather than a percentage with a progress
/// meter, because the complement is the interesting half: 84% self-supplied
/// only means something next to the 16% that had to be bought.
class SelfSufficiencyCard extends StatelessWidget {
  const SelfSufficiencyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = context.watch<DeviceProvider>().energyHistory;
    final pct = data?.selfSufficiencyPercent;
    if (data == null || pct == null) return const SizedBox.shrink();

    final consumed = data.consumptionKwh;
    final bought = data.gridImportKwh.clamp(0.0, consumed);
    final own = (consumed - bought).clamp(0.0, consumed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text('SELF-SUFFICIENCY', style: TextStyle(
              fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700,
              letterSpacing: 2.4, color: cs.onSurfaceVariant)),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$pct%', style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        letterSpacing: -0.6)),
                    const SizedBox(width: 9),
                    Text('of the last 24 h came from your own roof',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                // One bar, two parts — own generation and what was bought — so
                // the split is read directly instead of inferred from 100 minus
                // a number.
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Row(
                    children: [
                      if (own > 0)
                        Expanded(
                          flex: (own * 1000).round().clamp(1, 1 << 30),
                          child: Container(height: 8, color: _selfColor),
                        ),
                      if (bought > 0)
                        Expanded(
                          flex: (bought * 1000).round().clamp(1, 1 << 30),
                          child: Container(height: 8, color: _boughtColor),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _key(context, _selfColor, 'Own', own),
                    const SizedBox(width: 18),
                    _key(context, _boughtColor, 'Bought', bought),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _key(BuildContext context, Color c, String label, double kwh) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(width: 9, height: 9,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(width: 6),
        Text('${kwh.toStringAsFixed(1)} kWh', style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
