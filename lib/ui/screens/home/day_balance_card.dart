import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/providers/device_provider.dart';

const _avoidedColor  = Color(0xFFF6D08A); // solar amber — import you did not make
const _exportedColor = Color(0xFFA9E0C0); // mint — what went to the grid
const _paidColor     = Color(0xFFF2A9A0); // coral — what you had to buy

/// How the day came out, in money.
///
/// One net figure, then the three amounts it is made of, each on its own labelled
/// row and all to the same scale.
///
/// It began as a single out-against-in bar, which turned out to be unreadable:
/// the split between the two sides was a two-pixel hairline, and "OUT" and "IN"
/// asked the reader to work out which blocks belonged to which. Three rows need no
/// divider to be found and no legend to be matched — each row states its own name
/// and its own amount — and the arithmetic is written out underneath so the net
/// figure is checkable rather than asserted.
///
/// Avoided import stays its own row rather than joining exported in a green
/// total: it is money that never left, not money that arrived.
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
    final scale = [avoided, exported, paid].reduce((a, b) => a > b ? a : b);

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
                const SizedBox(height: 16),
                // Shared scale across the three, so the row lengths are worth
                // comparing to each other.
                _AmountRow(label: 'Avoided import', value: avoided,
                    scale: scale, color: _avoidedColor),
                _AmountRow(label: 'Exported', value: exported,
                    scale: scale, color: _exportedColor),
                _AmountRow(label: 'Paid', value: paid,
                    scale: scale, color: _paidColor),
                const SizedBox(height: 6),
                // The sum spelled out: with three amounts and one total, the
                // reader should not have to guess which ones were added and
                // which subtracted.
                Text('${eur(avoided)} + ${eur(exported)} − ${eur(paid)} '
                    '= ${net >= 0 ? '+' : '−'}${eur(net.abs())}',
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 10.5,
                        color: cs.onSurfaceVariant)),
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
}

/// One amount: its name, its figure, and a bar sized against the largest of the
/// three so the rows can be compared at a glance.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    required this.scale,
    required this.color,
  });

  final String label;
  final double value;
  final double scale;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Text('€${value.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: scale <= 0 ? 0 : (value / scale).clamp(0.0, 1.0),
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
