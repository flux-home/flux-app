import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/models/energy_prices.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:provider/provider.dart';

const _priceColor  = Color(0xFFE8D66B); // yellow — price bars
const _importColor = Color(0xFFF2A9A0); // coral — grid import overlay
const _exportColor = Color(0xFFA9E0C0); // mint  — grid export overlay + feed-in

/// A "Prices & consumption" card: the day-ahead spot price curve as bars with a
/// readable ct/kWh axis, home consumption overlaid, and the aggregated cost of
/// consumed energy shown top-left.
class EnergyPriceCard extends StatefulWidget {
  const EnergyPriceCard({super.key});

  @override
  State<EnergyPriceCard> createState() => _EnergyPriceCardState();
}

class _EnergyPriceCardState extends State<EnergyPriceCard> {
  Timer? _refresh;
  static const _refreshInterval = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DeviceProvider>().fetchEnergyPrices();
    });
    _refresh = Timer.periodic(_refreshInterval, (_) {
      if (mounted) context.read<DeviceProvider>().fetchEnergyPrices();
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final prices   = provider.energyPrices;
    final history  = provider.energyHistory;
    final loading  = provider.energyPricesLoading;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            const SizedBox(height: 12),
            if (prices == null || prices.isEmpty)
              _placeholder(context, loading)
            else ...[
              _readout(context, prices, history,
                  (provider.pricingConfig?.feedInUeurPerKwh ?? 0) / 10000.0),
              const SizedBox(height: 10),
              _chart(prices, history),
              const SizedBox(height: 12),
              _legend(context),
              if (prices.stale) _footnote(context,
                  'Price data stale — controller hasn\'t refreshed the curve'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Text('PRICES & CONSUMPTION',
            style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant, letterSpacing: 1.4)),
        const Spacer(),
        Text('day-ahead',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _readout(BuildContext context, EnergyPrices prices,
      EnergyHistoryData? history, double feedInCt) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final cur = prices.currentAt(now);
    final importCents = prices.importCostCents(history);
    final exportCents = feedInCt > 0 ? prices.exportRevenueCents(history, feedInCt) : null;

    String eur(double cents) => '€${(cents / 100).toStringAsFixed(2)}';

    Widget stat(String value, String label, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: color)),
            Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stat(importCents == null ? '—' : eur(importCents), 'import cost',
            cs.onSurface),
        if (exportCents != null && exportCents > 0) ...[
          const SizedBox(width: 22),
          stat(eur(exportCents), 'feed-in · 24h', _exportColor),
        ],
        const Spacer(),
        // Current gross price.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              cur != null ? '${cur.ctPerKwh.toStringAsFixed(1)} ct/kWh' : '— ct/kWh',
              style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
            Text('now · Ø ${prices.avgCt.toStringAsFixed(1)}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  Widget _chart(EnergyPrices prices, EnergyHistoryData? history) {
    return AspectRatio(
      aspectRatio: 1.9,
      child: LayoutBuilder(builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        return CustomPaint(
          painter: _PriceChartPainter(
            prices: prices,
            history: history,
            now: DateTime.now(),
            axisColor: cs.onSurfaceVariant.withValues(alpha: 0.28),
            labelColor: cs.onSurfaceVariant,
          ),
        );
      }),
    );
  }

  Widget _legend(BuildContext context) {
    return Wrap(
      spacing: 16, runSpacing: 6, alignment: WrapAlignment.center,
      children: [
        _lineSwatch(context, _priceColor, 'Price (ct/kWh)'),
        _lineSwatch(context, _importColor, 'Import'),
        _lineSwatch(context, _exportColor, 'Export'),
      ],
    );
  }

  Widget _lineSwatch(BuildContext context, Color c, String label) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 14, height: 3, color: c),
      const SizedBox(width: 6),
      Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _placeholder(BuildContext context, bool loading) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      height: 120,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : Text('PRICE DATA UNAVAILABLE',
                style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant, letterSpacing: 1.2)),
      ),
    );
  }

  Widget _footnote(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(text, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────
class _PriceChartPainter extends CustomPainter {
  _PriceChartPainter({
    required this.prices,
    required this.history,
    required this.now,
    required this.axisColor,
    required this.labelColor,
  });

  final EnergyPrices prices;
  final EnergyHistoryData? history;
  final DateTime now;
  final Color axisColor;
  final Color labelColor;

  static const _padBottom = 18.0;
  static const _padTop = 8.0;
  static const _padLeft = 28.0; // room for the ct/kWh axis labels

  @override
  void paint(Canvas canvas, Size size) {
    final pts = prices.points;
    if (pts.isEmpty) return;

    final plotH = size.height - _padBottom - _padTop;
    final plotW = size.width - _padLeft;

    final resMs = prices.resolution.inMilliseconds;
    final coverStart = pts.first.time.millisecondsSinceEpoch;
    final coverEnd = pts.last.time.millisecondsSinceEpoch + resMs;

    // Window to ~now ±12h so past consumption and upcoming prices share the view.
    const half = 12 * 3600 * 1000;
    final nowMs = now.millisecondsSinceEpoch;
    var startMs = nowMs - half < coverStart ? coverStart : nowMs - half;
    var endMs = nowMs + half > coverEnd ? coverEnd : nowMs + half;
    if (endMs <= startMs) { startMs = coverStart; endMs = coverEnd; }
    final span = (endMs - startMs).toDouble();
    double x(int ms) => _padLeft + plotW * (ms - startMs) / span;

    // Price Y scale — include 0, round the top (and bottom, if negative) to a
    // nice value so the gridline labels are tidy.
    final rawHi = prices.maxCt > 0 ? prices.maxCt : 1.0;
    final rawLo = prices.minCt < 0 ? prices.minCt : 0.0;
    final step = _niceStep((rawHi - rawLo) / 4);
    final hi = (rawHi / step).ceil() * step;
    final lo = (rawLo / step).floor() * step;
    final range = (hi - lo) <= 0 ? 1.0 : (hi - lo);
    double yPrice(double ct) => _padTop + plotH * (1 - (ct - lo) / range);

    // Horizontal gridlines + ct/kWh labels.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final gridPaint = Paint()..color = axisColor..strokeWidth = 1;
    for (var v = lo; v <= hi + 0.001; v += step) {
      final gy = yPrice(v);
      canvas.drawLine(Offset(_padLeft, gy), Offset(size.width, gy),
          gridPaint..color = axisColor.withValues(alpha: v == 0 ? 0.5 : 0.22));
      tp
        ..text = TextSpan(
            text: step >= 1 ? v.toStringAsFixed(0) : v.toStringAsFixed(1),
            style: TextStyle(color: labelColor, fontSize: 9))
        ..layout();
      tp.paint(canvas, Offset(_padLeft - tp.width - 4, gy - tp.height / 2));
    }

    // Price as a stepped line — each interval held flat at its price, with
    // risers at the interval boundaries (no fill).
    final priceLine = Path();
    var startedPrice = false;
    for (final p in pts) {
      final x0 = x(p.time.millisecondsSinceEpoch);
      final x1 = x(p.time.millisecondsSinceEpoch + resMs);
      final yv = yPrice(p.ctPerKwh);
      if (!startedPrice) {
        priceLine.moveTo(x0, yv);
        startedPrice = true;
      } else {
        priceLine.lineTo(x0, yv); // riser to this interval's level
      }
      priceLine.lineTo(x1, yv);    // hold flat across the interval
    }
    canvas.drawPath(
        priceLine,
        Paint()
          ..color = _priceColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true);

    // Grid import + export overlays (shared scale), only over covered time.
    final h = history;
    if (h != null && h.points.isNotEmpty) {
      var flowMax = 0.0;
      for (final hp in h.points) {
        if (hp.gridImportW > flowMax) flowMax = hp.gridImportW;
        if (hp.gridExportW > flowMax) flowMax = hp.gridExportW;
      }
      if (flowMax > 0) {
        void trace(double Function(EnergyHistoryPoint) sel, Color c) {
          final line = Path();
          var started = false;
          for (final hp in h.points) {
            final ms = hp.time.millisecondsSinceEpoch;
            if (ms < startMs || ms > endMs) continue;
            final px = x(ms);
            final py = _padTop + plotH * (1 - 0.85 * (sel(hp) / flowMax));
            if (!started) { line.moveTo(px, py); started = true; }
            else { line.lineTo(px, py); }
          }
          canvas.drawPath(
              line,
              Paint()
                ..color = c
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..strokeJoin = StrokeJoin.round
                ..isAntiAlias = true);
        }
        trace((hp) => hp.gridExportW, _exportColor);
        trace((hp) => hp.gridImportW, _importColor);
      }
    }

    // "Now" marker + current price label.
    if (nowMs >= startMs && nowMs <= endMs) {
      final nx = x(nowMs);
      canvas.drawLine(Offset(nx, _padTop), Offset(nx, _padTop + plotH),
          Paint()..color = labelColor.withValues(alpha: 0.7)..strokeWidth = 1);
    }

    // Vertical time gridlines + labels every 3 hours across the window, so the
    // time scale is readable (midnight is emphasised).
    for (final p in pts) {
      final t = p.time;
      final ms = t.millisecondsSinceEpoch;
      if (ms < startMs || ms > endMs) continue;
      if (t.minute != 0 || t.hour % 3 != 0) continue;
      final lx = x(ms);
      final midnight = t.hour == 0;
      canvas.drawLine(Offset(lx, _padTop), Offset(lx, _padTop + plotH),
          Paint()
            ..color = axisColor.withValues(alpha: midnight ? 0.45 : 0.20)
            ..strokeWidth = 1);
      tp
        ..text = TextSpan(
            text: '${t.hour.toString().padLeft(2, '0')}:00',
            style: TextStyle(
                color: labelColor,
                fontSize: 8.5,
                fontWeight: midnight ? FontWeight.w700 : FontWeight.w400))
        ..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, size.height - tp.height));
    }
  }

  /// Round [v] up to a tidy 1/2/5 × 10^k step for the price axis.
  double _niceStep(double v) {
    if (v <= 0) return 1;
    var mag = 1.0;
    while (mag * 10 <= v) {
      mag *= 10;
    }
    for (final m in [1.0, 2.0, 5.0, 10.0]) {
      if (mag * m >= v) return mag * m;
    }
    return mag * 10;
  }

  @override
  bool shouldRepaint(_PriceChartPainter old) =>
      old.prices != prices || old.history != history || old.now != now;
}
