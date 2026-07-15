import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:provider/provider.dart';

// Series accents — shared with the house energy scene so the whole Energy view
// reads with one palette.
const _pvColor      = Color(0xFFF6D08A); // amber — solar
const _consumeColor = Color(0xFFF3B8D6); // pink  — home consumption
const _importColor  = Color(0xFFF2A9A0); // coral — grid import
const _exportColor  = Color(0xFFA9E0C0); // mint  — grid export

/// A "Last 24 hours" energy card: whole-home **consumption in kWh per 15-minute
/// bucket** as a bar chart, a scrubbable per-bucket readout, and window totals.
///
/// Consumption is the energy-balance figure (generation + import − export),
/// so it's robust even when individual loads aren't metered. Fetches lazily via
/// [DeviceProvider.fetchEnergyHistory] (aggregate only — no per-device series).
class EnergyHistoryCard extends StatefulWidget {
  const EnergyHistoryCard({super.key});

  @override
  State<EnergyHistoryCard> createState() => _EnergyHistoryCardState();
}

class _EnergyHistoryCardState extends State<EnergyHistoryCard> {
  int? _selected; // scrubbed bucket index, or null → show 24h total
  Timer? _refresh;

  static const _refreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DeviceProvider>().fetchEnergyHistory();
    });
    _refresh = Timer.periodic(_refreshInterval, (_) {
      if (mounted) context.read<DeviceProvider>().fetchEnergyHistory();
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
    final data     = provider.energyHistory;
    final loading  = provider.energyHistoryLoading;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, data),
            const SizedBox(height: 12),
            if (data == null)
              _placeholder(context, loading)
            else if (data.isEmpty)
              _placeholder(context, loading, empty: true)
            else ...[
              _readout(context, data),
              const SizedBox(height: 8),
              _chart(data),
              const SizedBox(height: 16),
              _kpis(context, data),
              if (!data.timeSynced) _footnote(context,
                  'Times approximate — controller clock not yet synced'),
              if (data.truncated) _footnote(context,
                  'Range truncated — showing the most recent buckets'),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context, EnergyHistoryData? data) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Text('CONSUMPTION · LAST 24 HOURS',
            style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant, letterSpacing: 1.4)),
        const Spacer(),
        if (data != null)
          Text('kWh / 15 min',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  // ── Value readout (24h total, or the scrubbed bucket) ───────────────────────
  Widget _readout(BuildContext context, EnergyHistoryData data) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sel = (_selected != null &&
            _selected! >= 0 &&
            _selected! < data.points.length)
        ? _selected
        : null;

    if (sel == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(_fmtKwh(data.consumptionKwh), style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700, color: cs.onSurface)),
          Text(' kWh', style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          Text('consumed · 24 h',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      );
    }

    final t = data.points[sel].time;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final endMin = (t.minute + (data.bucket.inMinutes)) % 60;
    final endHr  = (t.hour + ((t.minute + data.bucket.inMinutes) ~/ 60)) % 24;
    final end = '${endHr.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(_fmtKwh(data.bucketConsumptionKwh(sel)),
            style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700, color: cs.onSurface)),
        Text(' kWh', style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(width: 8),
        Text('$hh:$mm–$end',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  static String _fmtKwh(double kwh) =>
      kwh >= 10 ? kwh.toStringAsFixed(1) : kwh.toStringAsFixed(2);

  // ── Chart ───────────────────────────────────────────────────────────────────
  Widget _chart(EnergyHistoryData data) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: LayoutBuilder(builder: (context, constraints) {
        final cs = Theme.of(context).colorScheme;
        void selectAt(Offset local) {
          final n = data.points.length;
          if (n < 1) return;
          final frac = (local.dx / constraints.maxWidth).clamp(0.0, 0.9999);
          setState(() => _selected = (frac * n).floor().clamp(0, n - 1));
        }

        return GestureDetector(
          onHorizontalDragStart: (d) => selectAt(d.localPosition),
          onHorizontalDragUpdate: (d) => selectAt(d.localPosition),
          onHorizontalDragEnd: (_) => setState(() => _selected = null),
          onHorizontalDragCancel: () => setState(() => _selected = null),
          onTapDown: (d) => selectAt(d.localPosition),
          onTapUp: (_) => setState(() => _selected = null),
          child: CustomPaint(
            painter: _BarChartPainter(
              data: data,
              selected: _selected,
              barColor: _consumeColor,
              axisColor: cs.onSurfaceVariant.withValues(alpha: 0.30),
              labelColor: cs.onSurfaceVariant,
            ),
          ),
        );
      }),
    );
  }

  // ── KPI totals ──────────────────────────────────────────────────────────────
  Widget _kpis(BuildContext context, EnergyHistoryData data) {
    final ss = data.selfSufficiencyPercent;
    return Column(children: [
      Row(children: [
        _kpi(context, 'Consumed', data.consumptionKwh, _consumeColor),
        _kpi(context, 'Generated', data.pvKwh, _pvColor),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _kpi(context, 'Imported', data.gridImportKwh, _importColor),
        _kpi(context, 'Exported', data.gridExportKwh, _exportColor),
      ]),
      if (ss != null) ...[
        const SizedBox(height: 12),
        _selfSufficiency(context, ss),
      ],
    ]);
  }

  Widget _kpi(BuildContext context, String label, double kwh, Color c) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Row(children: [
        Container(width: 3, height: 30, decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant, letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text('${_fmtKwh(kwh)} kWh',
              style: tt.titleMedium?.copyWith(
                  color: cs.onSurface, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _selfSufficiency(BuildContext context, int pct) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('SELF-SUFFICIENCY', style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant, letterSpacing: 0.8)),
        const Spacer(),
        Text('$pct%', style: tt.labelMedium?.copyWith(
            color: cs.onSurface, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: pct / 100,
          minHeight: 6,
          backgroundColor: cs.surfaceContainerHighest,
          valueColor: const AlwaysStoppedAnimation(_exportColor),
        ),
      ),
    ]);
  }

  // ── Placeholder / footnote ──────────────────────────────────────────────────
  Widget _placeholder(BuildContext context, bool loading, {bool empty = false}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      height: 120,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(empty ? 'NO ENERGY DATA YET' : 'HISTORY UNAVAILABLE',
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
      child: Text(text,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────
class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.selected,
    required this.barColor,
    required this.axisColor,
    required this.labelColor,
  });

  final EnergyHistoryData data;
  final int? selected;
  final Color barColor;
  final Color axisColor;
  final Color labelColor;

  static const _padBottom = 18.0; // room for hour labels
  static const _padTop = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = data.points.length;
    if (n < 1) return;

    final plotH = size.height - _padBottom - _padTop;
    final plotW = size.width;
    final ceil = _niceCeil(data.peakConsumptionKwh <= 0 ? 1.0 : data.peakConsumptionKwh);

    double xLeft(int i) => plotW * i / n;
    double barW() => (plotW / n) * 0.78;
    double y(double kwh) => _padTop + plotH * (1 - (kwh / ceil));

    // Horizontal gridlines (0 / half / max) + the max-value label.
    final grid = Paint()..color = axisColor..strokeWidth = 1;
    for (var g = 0; g <= 2; g++) {
      final gy = _padTop + plotH * g / 2;
      canvas.drawLine(Offset(0, gy), Offset(plotW, gy), grid);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
          text: '${_fmtCeil(ceil)} kWh',
          style: TextStyle(color: labelColor, fontSize: 9))
      ..layout();
    tp.paint(canvas, Offset(2, _padTop));

    // Bars.
    for (var i = 0; i < n; i++) {
      final v = data.bucketConsumptionKwh(i);
      final left = xLeft(i) + ((plotW / n) - barW()) / 2;
      final top = v <= 0 ? _padTop + plotH : y(v);
      final isSel = selected == i;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(left, top, left + barW(), _padTop + plotH),
        topLeft: const Radius.circular(1.5),
        topRight: const Radius.circular(1.5),
      );
      canvas.drawRRect(
          rect,
          Paint()
            ..color = barColor.withValues(
                alpha: selected == null || isSel ? 1.0 : 0.35)
            ..isAntiAlias = true);
    }

    // Hour ticks every 6h (00/06/12/18) using bucket time.
    for (var i = 0; i < n; i++) {
      final t = data.points[i].time;
      if (t.minute == 0 && t.hour % 6 == 0) {
        final lx = xLeft(i) + (plotW / n) / 2;
        tp
          ..text = TextSpan(
              text: '${t.hour.toString().padLeft(2, '0')}:00',
              style: TextStyle(color: labelColor, fontSize: 9))
          ..layout();
        tp.paint(canvas, Offset(lx - tp.width / 2, size.height - tp.height));
      }
    }
  }

  String _fmtCeil(double v) =>
      v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(v >= 1 ? 1 : 2);

  /// Round [v] up to 1/2/5 × 10^k for a tidy Y ceiling.
  double _niceCeil(double v) {
    if (v <= 0) return 1;
    var mag = 1.0;
    while (mag * 10 <= v) {
      mag *= 10;
    }
    while (mag > v) {
      mag /= 10;
    }
    for (final m in [1.0, 2.0, 5.0, 10.0]) {
      if (mag * m >= v) return mag * m;
    }
    return mag * 10;
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data || old.selected != selected;
}
