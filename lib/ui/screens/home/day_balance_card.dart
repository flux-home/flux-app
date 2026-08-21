import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/providers/device_provider.dart';

const _avoidedColor  = Color(0xFFF6D08A); // solar amber — import you did not make
const _exportedColor = Color(0xFFA9E0C0); // mint — what went to the grid
const _paidColor     = Color(0xFFF2A9A0); // coral — what you had to buy

/// How the day came out, in money.
///
/// One net figure — avoided import + exported − paid — over a bar that puts what
/// went out against what came in, with self-supply underneath as the reason for
/// the shape. The three figures were equal columns on the prices card, where they
/// read as trivia beside a chart; the number they add up to is the point.
///
/// Honest about what the figure is: avoided import is money that never left, not
/// money that arrived, so it stays a separate block with its own name rather than
/// being blended into one green total with what was exported.
class DayBalanceCard extends StatelessWidget {
  const DayBalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final prices = provider.energyPrices;
    final history = provider.energyHistory;
    if (prices == null || prices.isEmpty || history == null || history.isEmpty) {
      return const SizedBox.shrink();
    }

    final feedInCt = (provider.pricingConfig?.feedInUeurPerKwh ?? 0) / 10000.0;
    final paid = (prices.importCostCents(history) ?? 0) / 100.0;
    final avoided = (prices.selfConsumptionSavingCents(history) ?? 0) / 100.0;
    final exported = feedInCt > 0
        ? (prices.exportRevenueCents(history, feedInCt) ?? 0) / 100.0
        : 0.0;
    final net = avoided + exported - paid;

    final ss = history.selfSufficiencyPercent;
    final consumed = history.consumptionKwh;
    final bought = history.gridImportKwh.clamp(0.0, consumed);
    final own = (consumed - bought).clamp(0.0, consumed);

    String eur(double v) => '€${v.toStringAsFixed(2)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text('THE DAY CAME OUT AT', style: TextStyle(
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
                    Text('${net >= 0 ? '+' : '−'}${eur(net.abs())}',
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w700,
                            letterSpacing: -0.8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('over the last 24 hours',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _OutInBar(paid: paid, avoided: avoided, exported: exported),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16, runSpacing: 6,
                  children: [
                    _key(context, _paidColor, 'paid', eur(paid)),
                    _key(context, _exportedColor, 'exported', eur(exported)),
                    _key(context, _avoidedColor, 'avoided import', eur(avoided)),
                  ],
                ),
                if (ss != null) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: cs.outlineVariant),
                  const SizedBox(height: 12),
                  Text('$ss% self-supplied · '
                      '${own.toStringAsFixed(1)} of '
                      '${consumed.toStringAsFixed(1)} kWh',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _key(BuildContext context, Color c, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(width: 9, height: 9,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(width: 5),
        Text(value, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Out on the left of a centre line, in on the right, both to the same scale.
///
/// The centre sits where the two magnitudes balance rather than at the middle of
/// the card, so the bar itself shows which way the day went — a fixed centre
/// would make a €1 loss and a €9 gain look like the same event.
class _OutInBar extends StatelessWidget {
  const _OutInBar({
    required this.paid,
    required this.avoided,
    required this.exported,
  });

  final double paid;
  final double avoided;
  final double exported;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inTotal = avoided + exported;
    final total = paid + inTotal;
    if (total <= 0) return const SizedBox.shrink();

    int flex(double v) => (v / total * 1000).round().clamp(0, 1 << 30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('OUT', style: _tag(cs)),
            const Spacer(),
            Text('IN', style: _tag(cs)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              if (paid > 0)
                Expanded(flex: flex(paid),
                    child: Container(height: 10, color: _paidColor)),
              // A hairline of surface, so out and in never touch and read as one
              // continuous quantity.
              if (paid > 0 && inTotal > 0)
                Container(width: 2, height: 10, color: cs.surface),
              if (exported > 0)
                Expanded(flex: flex(exported),
                    child: Container(height: 10, color: _exportedColor)),
              if (avoided > 0)
                Expanded(flex: flex(avoided),
                    child: Container(height: 10, color: _avoidedColor)),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _tag(ColorScheme cs) => TextStyle(
      fontFamily: 'monospace', fontSize: 8.5, fontWeight: FontWeight.w700,
      letterSpacing: 1.4, color: cs.onSurfaceVariant);
}
