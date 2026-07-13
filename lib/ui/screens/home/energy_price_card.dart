import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/models/energy_prices.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:provider/provider.dart';

// Price-level bands (pastel, shared with the rest of the energy palette).
const _cheapColor     = Color(0xFFA9E0C0); // mint
const _normalColor    = Color(0xFFF6D08A); // amber
const _expensiveColor = Color(0xFFF2A9A0); // coral
const _consumeColor   = Color(0xFFF3B8D6); // pink — consumption overlay

Color _levelColor(PriceLevel l) => switch (l) {
      PriceLevel.cheap => _cheapColor,
      PriceLevel.normal => _normalColor,
      PriceLevel.expensive => _expensiveColor,
    };

String _levelLabel(PriceLevel l) => switch (l) {
      PriceLevel.cheap => 'Cheap',
      PriceLevel.normal => 'Normal',
      PriceLevel.expensive => 'Expensive',
    };

/// A "Prices & consumption" card: the day-ahead spot price curve as colour-banded
/// bars (cheap / normal / expensive) over time, with home consumption overlaid,
/// so you can see whether you draw power when it's cheap or expensive.
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
    // Re-fetch + rebuild so the "now" marker and current-price readout advance.
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
              _readout(context, prices),
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

  Widget _readout(BuildContext context, EnergyPrices prices) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final cur = prices.currentAt(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (cur != null) ...[
          Text(cur.ctPerKwh.toStringAsFixed(1),
              style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: cs.onSurface)),
          Text(' ct/kWh',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: _levelBadge(cur.level),
          ),
        ] else
          Text('— ct/kWh',
              style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Ø ${prices.avgCt.toStringAsFixed(1)} · '
            '${prices.minCt.toStringAsFixed(1)}–${prices.maxCt.toStringAsFixed(1)}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _levelBadge(PriceLevel level) {
    final c = _levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c, width: 1.2),
      ),
      child: Text(_levelLabel(level),
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
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
            axisColor: cs.onSurfaceVariant.withValues(alpha: 0.30),
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
        _swatch(context, _cheapColor, 'Cheap'),
        _swatch(context, _normalColor, 'Normal'),
        _swatch(context, _expensiveColor, 'Expensive'),
        _lineSwatch(context, _consumeColor, 'Consumption'),
      ],
    );
  }

  Widget _swatch(BuildContext context, Color c, String label) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration:
          BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    ]);
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
  static const _padTop = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = prices.points;
    if (pts.isEmpty) return;

    final plotH = size.height - _padBottom - _padTop;
    final plotW = size.width;

    final resMs = prices.resolution.inMilliseconds;
    final coverStart = pts.first.time.millisecondsSinceEpoch;
    final coverEnd = pts.last.time.millisecondsSinceEpoch + resMs;

    // Window to roughly now ±12h so past consumption and upcoming prices share
    // the view (the full curve runs a day+ ahead, which would squish the
    // consumption trace into the left edge). Clamp to the covered range.
    const half = 12 * 3600 * 1000;
    final nowMs = now.millisecondsSinceEpoch;
    var startMs = nowMs - half < coverStart ? coverStart : nowMs - half;
    var endMs = nowMs + half > coverEnd ? coverEnd : nowMs + half;
    if (endMs <= startMs) { startMs = coverStart; endMs = coverEnd; }
    final span = (endMs - startMs).toDouble();
    double x(int ms) => plotW * (ms - startMs) / span;

    // Price Y scale: include 0 so negative prices sit below the zero line.
    final lo = prices.minCt < 0 ? prices.minCt : 0.0;
    final hi = prices.maxCt > 0 ? prices.maxCt : 1.0;
    final range = (hi - lo) <= 0 ? 1.0 : (hi - lo);
    double yPrice(double ct) => _padTop + plotH * (1 - (ct - lo) / range);
    final zeroY = yPrice(0);

    // Price bars, coloured by level.
    for (final p in pts) {
      final x0 = x(p.time.millisecondsSinceEpoch);
      final x1 = x(p.time.millisecondsSinceEpoch + resMs);
      final yv = yPrice(p.ctPerKwh);
      final top = p.ctPerKwh >= 0 ? yv : zeroY;
      final bot = p.ctPerKwh >= 0 ? zeroY : yv;
      final rect = Rect.fromLTRB(x0 + 0.5, top, x1 - 0.5, bot);
      canvas.drawRect(rect,
          Paint()..color = _levelColor(p.level).withValues(alpha: 0.55));
    }

    // Zero line (only meaningful when there are negative prices).
    if (lo < 0) {
      canvas.drawLine(Offset(0, zeroY), Offset(plotW, zeroY),
          Paint()..color = axisColor..strokeWidth = 1);
    }

    // Consumption overlay (scaled to its own max), only over covered time.
    final h = history;
    if (h != null && h.points.isNotEmpty) {
      var consMax = 0.0;
      for (final hp in h.points) {
        if (hp.consumptionW > consMax) consMax = hp.consumptionW;
      }
      if (consMax > 0) {
        final baseY = _padTop + plotH;
        final line = Path();
        final fill = Path();
        var started = false;
        double firstX = 0, lastX = 0;
        for (final hp in h.points) {
          final ms = hp.time.millisecondsSinceEpoch;
          if (ms < startMs || ms > endMs) continue;
          final px = x(ms);
          // Use the bottom ~85% of the plot for the consumption trace.
          final py = _padTop + plotH * (1 - 0.85 * (hp.consumptionW / consMax));
          if (!started) {
            line.moveTo(px, py);
            fill.moveTo(px, baseY);
            fill.lineTo(px, py);
            firstX = px;
            started = true;
          } else {
            line.lineTo(px, py);
            fill.lineTo(px, py);
          }
          lastX = px;
        }
        if (started) {
          fill.lineTo(lastX, baseY);
          fill.lineTo(firstX, baseY);
          fill.close();
          canvas.drawPath(fill, Paint()..color = _consumeColor.withValues(alpha: 0.18));
          canvas.drawPath(
              line,
              Paint()
                ..color = _consumeColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..strokeJoin = StrokeJoin.round
                ..isAntiAlias = true);
        }
      }
    }

    // "Now" marker.
    if (nowMs >= startMs && nowMs <= endMs) {
      final nx = x(nowMs);
      canvas.drawLine(Offset(nx, _padTop), Offset(nx, _padTop + plotH),
          Paint()..color = labelColor.withValues(alpha: 0.7)..strokeWidth = 1);
    }

    // Hour labels at each midnight + noon.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final p in pts) {
      final t = p.time;
      if (t.minute == 0 && (t.hour == 0 || t.hour == 12)) {
        final lx = x(t.millisecondsSinceEpoch);
        canvas.drawLine(Offset(lx, _padTop), Offset(lx, _padTop + plotH),
            Paint()..color = axisColor.withValues(alpha: 0.5)..strokeWidth = 1);
        tp
          ..text = TextSpan(
              text: t.hour == 0 ? '00:00' : '12:00',
              style: TextStyle(color: labelColor, fontSize: 9))
          ..layout();
        tp.paint(canvas, Offset(lx + 2, size.height - tp.height));
      }
    }
  }

  @override
  bool shouldRepaint(_PriceChartPainter old) =>
      old.prices != prices || old.history != history || old.now != now;
}
