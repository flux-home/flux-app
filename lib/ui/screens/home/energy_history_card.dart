import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:provider/provider.dart';

// Series accents — shared with the house energy scene so the whole Energy view
// reads with one palette.
const _pvColor     = Color(0xFFF6D08A); // amber   — solar (aggregate)
const _loadColor   = Color(0xFFF3B8D6); // pink    — home consumption
const _importColor = Color(0xFFF2A9A0); // coral   — grid import
const _exportColor = Color(0xFFA9E0C0); // mint    — grid export

// Warm palette for per-inverter PV lines.
const _pvPalette = <Color>[
  Color(0xFFF6D08A), Color(0xFFEFA765), Color(0xFFE8D66B),
  Color(0xFFCBB25E), Color(0xFFF2BFA0), Color(0xFFDCC77A),
];

/// A "Last 24 hours" energy history card: overlaid **energy** lines (one per
/// source / sink, kWh per 1-hour bucket) over the time axis, a scrubbable
/// per-bucket readout, and window kWh totals.
///
/// Fetches lazily via [DeviceProvider.fetchEnergyHistory] (1-hour buckets, with
/// the per-device PV breakdown).
class EnergyHistoryCard extends StatefulWidget {
  const EnergyHistoryCard({super.key});

  @override
  State<EnergyHistoryCard> createState() => _EnergyHistoryCardState();
}

class _EnergyHistoryCardState extends State<EnergyHistoryCard> {
  int? _selected; // scrubbed bucket index, or null → show window totals
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

  static String _fmtKwh(double kwh) {
    if (kwh >= 10) return kwh.toStringAsFixed(1);
    if (kwh >= 1)  return kwh.toStringAsFixed(2);
    return kwh.toStringAsFixed(kwh > 0 && kwh < 0.1 ? 3 : 2);
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
              const SizedBox(height: 12),
              _legend(context, data),
              const SizedBox(height: 14),
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
        Text('LAST 24 HOURS',
            style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant, letterSpacing: 1.4)),
        const Spacer(),
        if (data != null)
          Text('kWh / 1 h',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  // ── Value readout (totals, or the scrubbed bucket) ──────────────────────────
  Widget _readout(BuildContext context, EnergyHistoryData data) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sel = _selected != null &&
            _selected! >= 0 &&
            _selected! < data.points.length
        ? data.points[_selected!]
        : null;

    if (sel == null) {
      // Default: whole-window consumption total.
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

    final idx = _selected!;
    final h = sel.time.hour.toString().padLeft(2, '0');
    final m = sel.time.minute.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$h:$m', style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 4),
        Wrap(spacing: 12, runSpacing: 2, children: [
          if (data.hasPvBreakdown)
            for (var k = 0; k < data.pvSeries.length; k++)
              _readoutChip(
                  _pvPalette[k % _pvPalette.length],
                  _pvName(context, data.pvSeries[k]),
                  data.kwhFromW(idx < data.pvSeries[k].wattsPerBucket.length
                      ? data.pvSeries[k].wattsPerBucket[idx]
                      : 0))
          else
            _readoutChip(_pvColor, 'Solar', data.kwhFromW(sel.pvW)),
          _readoutChip(_loadColor, 'Home', data.kwhFromW(sel.loadW)),
          _readoutChip(_importColor, 'Import', data.kwhFromW(sel.gridImportW)),
          _readoutChip(_exportColor, 'Export', data.kwhFromW(sel.gridExportW)),
        ]),
      ],
    );
  }

  Widget _readoutChip(Color c, String label, double kwh) {
    return Builder(builder: (context) {
      final tt = Theme.of(context).textTheme;
      final cs = Theme.of(context).colorScheme;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text('$label ', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        Text('${_fmtKwh(kwh)} kWh',
            style: tt.bodySmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600)),
      ]);
    });
  }

  // ── Chart ───────────────────────────────────────────────────────────────────
  Widget _chart(EnergyHistoryData data) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: LayoutBuilder(builder: (context, constraints) {
        final cs = Theme.of(context).colorScheme;
        void selectAt(Offset local) {
          final n = data.points.length;
          if (n < 2) return;
          final frac = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
          setState(() => _selected = (frac * (n - 1)).round());
        }

        return GestureDetector(
          onHorizontalDragStart: (d) => selectAt(d.localPosition),
          onHorizontalDragUpdate: (d) => selectAt(d.localPosition),
          onHorizontalDragEnd: (_) => setState(() => _selected = null),
          onHorizontalDragCancel: () => setState(() => _selected = null),
          onTapDown: (d) => selectAt(d.localPosition),
          onTapUp: (_) => setState(() => _selected = null),
          child: CustomPaint(
            painter: _LineChartPainter(
              data: data,
              selected: _selected,
              axisColor: cs.onSurfaceVariant.withValues(alpha: 0.30),
              labelColor: cs.onSurfaceVariant,
            ),
          ),
        );
      }),
    );
  }

  String _pvName(BuildContext context, PvDeviceSeries s) =>
      context.read<DeviceProvider>().deviceNameForNode(s.nodeId) ?? s.name;

  // ── Legend ────────────────────────────────────────────────────────────────
  Widget _legend(BuildContext context, EnergyHistoryData data) {
    return Wrap(
      spacing: 16, runSpacing: 6, alignment: WrapAlignment.center,
      children: [
        if (data.hasPvBreakdown)
          for (var k = 0; k < data.pvSeries.length; k++)
            _legendItem(context, _pvPalette[k % _pvPalette.length],
                _pvName(context, data.pvSeries[k]))
        else
          _legendItem(context, _pvColor, 'Solar'),
        _legendItem(context, _loadColor, 'Home'),
        _legendItem(context, _importColor, 'Grid import'),
        _legendItem(context, _exportColor, 'Grid export'),
      ],
    );
  }

  Widget _legendItem(BuildContext context, Color c, String label) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 14, height: 3, color: c),
      const SizedBox(width: 6),
      Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    ]);
  }

  // ── KPI totals ──────────────────────────────────────────────────────────────
  Widget _kpis(BuildContext context, EnergyHistoryData data) {
    final ss = data.selfSufficiencyPercent;
    return Column(children: [
      Row(children: [
        _kpi(context, 'Generated', data.pvKwh, _pvColor),
        _kpi(context, 'Consumed', data.consumptionKwh, _loadColor),
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
// Plots each series scaled to the window's peak. Line *shapes* are identical
// whether values are read as average-W or kWh-per-bucket (they differ only by a
// constant factor), so the painter works in W and the readout labels the kWh.
class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.data,
    required this.selected,
    required this.axisColor,
    required this.labelColor,
  });

  final EnergyHistoryData data;
  final int? selected;
  final Color axisColor;
  final Color labelColor;

  static const _padBottom = 18.0;
  static const _padTop = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final points = data.points;
    if (points.length < 2) return;

    final plotH = size.height - _padBottom - _padTop;
    final plotW = size.width;
    final n = points.length;
    final peak = data.peakW <= 0 ? 1.0 : data.peakW;
    final ceil = _niceCeil(peak);

    double x(int i) => plotW * i / (n - 1);
    double y(double w) => _padTop + plotH * (1 - (w / ceil));

    final grid = Paint()..color = axisColor..strokeWidth = 1;
    for (var g = 0; g <= 2; g++) {
      final gy = _padTop + plotH * g / 2;
      canvas.drawLine(Offset(0, gy), Offset(plotW, gy), grid);
    }

    // kWh ceiling label (top-left), so the Y scale is legible.
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
          text: '${_fmtCeil(data.kwhFromW(ceil))} kWh',
          style: TextStyle(color: labelColor, fontSize: 9))
      ..layout();
    tp.paint(canvas, Offset(2, _padTop));

    // Hour ticks every 3h using bucket time.
    for (var i = 0; i < n; i++) {
      final t = points[i].time;
      if (t.minute == 0 && t.hour % 3 == 0) {
        final lx = x(i);
        canvas.drawLine(Offset(lx, _padTop), Offset(lx, _padTop + plotH),
            grid..color = axisColor.withValues(alpha: 0.5));
        tp
          ..text = TextSpan(
              text: '${t.hour.toString().padLeft(2, '0')}:00',
              style: TextStyle(color: labelColor, fontSize: 9))
          ..layout();
        tp.paint(canvas, Offset(lx - tp.width / 2, size.height - tp.height));
      }
    }

    void line(double Function(EnergyHistoryPoint) sel, Color c) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final px = x(i), py = y(sel(points[i]));
        i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      canvas.drawPath(path, Paint()
        ..color = c..style = PaintingStyle.stroke
        ..strokeWidth = 2..strokeJoin = StrokeJoin.round..isAntiAlias = true);
    }

    void listLine(List<double> vals, Color c) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final px = x(i), py = y(i < vals.length ? vals[i] : 0);
        i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      canvas.drawPath(path, Paint()
        ..color = c..style = PaintingStyle.stroke
        ..strokeWidth = 2..strokeJoin = StrokeJoin.round..isAntiAlias = true);
    }

    line((p) => p.gridExportW, _exportColor);
    line((p) => p.gridImportW, _importColor);
    line((p) => p.loadW, _loadColor);
    if (data.hasPvBreakdown) {
      for (var k = 0; k < data.pvSeries.length; k++) {
        listLine(data.pvSeries[k].wattsPerBucket, _pvPalette[k % _pvPalette.length]);
      }
    } else {
      line((p) => p.pvW, _pvColor);
    }

    final s = selected;
    if (s != null && s >= 0 && s < n) {
      final cx = x(s);
      canvas.drawLine(Offset(cx, _padTop), Offset(cx, _padTop + plotH),
          Paint()..color = labelColor.withValues(alpha: 0.6)..strokeWidth = 1);
      void dot(double w, Color c) =>
          canvas.drawCircle(Offset(cx, y(w)), 3.0, Paint()..color = c);
      dot(points[s].gridExportW, _exportColor);
      dot(points[s].gridImportW, _importColor);
      dot(points[s].loadW, _loadColor);
      if (data.hasPvBreakdown) {
        for (var k = 0; k < data.pvSeries.length; k++) {
          final vals = data.pvSeries[k].wattsPerBucket;
          dot(s < vals.length ? vals[s] : 0, _pvPalette[k % _pvPalette.length]);
        }
      } else {
        dot(points[s].pvW, _pvColor);
      }
    }
  }

  String _fmtCeil(double v) =>
      v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(v >= 1 ? 1 : 2);

  double _niceCeil(double v) {
    if (v <= 0) return 1;
    var mag = 1.0;
    while (mag * 10 <= v) { mag *= 10; }
    while (mag > v) { mag /= 10; }
    for (final m in [1.0, 2.0, 5.0, 10.0]) {
      if (mag * m >= v) return mag * m;
    }
    return mag * 10;
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.data != data || old.selected != selected;
}
