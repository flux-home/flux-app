import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/models/energy_prices.dart';
import 'package:matter_home/providers/device_provider.dart';

// Bars keep the flow card's solar amber; grid and battery stay darker so they
// separate from it on lightness, which colour-vision deficiency leaves intact.
const _cSolar    = Color(0xFFF6D08A);
const _cGrid     = Color(0xFFC4483A);
const _cExport   = Color(0xFF6FBF9B);
const _cSoc      = Color(0xFF8FA5E8);
const _cPrice    = Color(0xFFE0D48A);

/// Which series the chart can draw. The key is what gets persisted, so renaming
/// one silently resets that toggle rather than crashing — acceptable, and the
/// reason the keys are short and stable.
enum _Series {
  solar('solar', 'Solar', _cSolar),
  grid('grid', 'Grid', _cGrid),
  export('export', 'Export', _cExport),
  // Key stays 'charge' though the label reads Battery: the key is what is
  // persisted, so renaming it would silently reset the toggle for anyone who had
  // already chosen.
  charge('charge', 'Battery', _cSoc),
  price('price', 'Price', _cPrice);

  const _Series(this.key, this.label, this.color);
  final String key;
  final String label;
  final Color color;

  static const _defaults = {solar, grid, charge, price};
}

/// One timeline: the last 24 hours and the price forecast on a single time axis,
/// with NOW between them.
///
/// This replaces two cards that each drew their own time axis — and drew some of
/// the same series on both. Sharing one axis is the whole point: the question a
/// dynamic tariff creates is always about a moment ("was that expensive?", "is
/// the cheap window before or after the sun?"), and two charts side by side make
/// the reader align hours by eye.
///
/// Price keeps its own scale, labelled on the right in its own colour. That is a
/// second y axis, which this codebase otherwise avoids — the honest version of it
/// is to label both scales and let the crosshair give exact values, rather than
/// pretending one axis serves both.
class EnergyTimelineCard extends StatefulWidget {
  const EnergyTimelineCard({super.key});

  @override
  State<EnergyTimelineCard> createState() => _EnergyTimelineCardState();
}

class _EnergyTimelineCardState extends State<EnergyTimelineCard> {
  int? _selected;
  Set<_Series>? _shown;
  Timer? _refresh;

  static const _refreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // This card is what ASKS for both data sets. The two cards it replaced each
    // fetched their own on mount and on a timer; merging the views without
    // merging the fetches is why it first rendered "no energy history yet" —
    // nothing had requested any.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
    _refresh = Timer.periodic(_refreshInterval, (_) => _fetch());
  }

  void _fetch() {
    if (!mounted) return;
    final p = context.read<DeviceProvider>();
    p.fetchEnergyHistory();
    p.fetchEnergyPrices();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Set<_Series> _seriesFor(DeviceProvider p) {
    if (_shown != null) return _shown!;
    final saved = p.chartSeries;
    if (saved == null) return _Series._defaults;
    return {
      for (final s in _Series.values)
        if (saved.contains(s.key)) s,
    };
  }

  void _toggle(DeviceProvider p, _Series s) {
    final next = {..._seriesFor(p)};
    next.contains(s) ? next.remove(s) : next.add(s);
    setState(() => _shown = next);
    p.setChartSeries([for (final e in next) e.key]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final data = provider.energyHistory;
    final prices = provider.energyPrices;
    final shown = _seriesFor(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Text('ENERGY & PRICE', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 2.4,
                  color: cs.onSurfaceVariant)),
              const Spacer(),
              if (prices != null && !prices.isEmpty)
                Text(_priceNow(prices), style: TextStyle(
                    fontFamily: 'monospace', fontSize: 10,
                    color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data == null || data.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                        provider.energyHistoryLoading
                            ? 'Loading the last 24 hours…'
                            : 'No energy history yet.',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13)),
                  )
                else ...[
                  _hero(context, data),
                  const SizedBox(height: 12),
                  _plot(context, data, prices, shown),
                  const SizedBox(height: 12),
                  // Below the chart: the chips are a control for what is above
                  // them, and reading order should reach the picture first.
                  _chips(context, provider, shown),
                  if (!data.timeSynced)
                    _note(context,
                        'Times approximate — controller clock not yet synced'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _priceNow(EnergyPrices prices) {
    final now = DateTime.now();
    final cur = prices.currentAt(now);
    final avg = prices.avgCtIn(now.subtract(const Duration(hours: 24)), now) ??
        prices.avgCt;
    final nowPart = cur == null ? '—' : '${cur.ctPerKwh.toStringAsFixed(1)} ct';
    return '$nowPart now · Ø ${avg.toStringAsFixed(1)}';
  }

  Widget _hero(BuildContext context, EnergyHistoryData data) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(data.consumptionKwh.toStringAsFixed(1), style: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
        const SizedBox(width: 4),
        Text('kWh', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant)),
        const SizedBox(width: 9),
        Text('used · 24 h', style: TextStyle(
            fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }

  /// The chips ARE the legend: one row of words instead of two saying the same
  /// thing, and tapping the word that names a series is where anyone would look
  /// to turn it off.
  Widget _chips(BuildContext context, DeviceProvider p, Set<_Series> shown) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: [
        for (final s in _Series.values)
          GestureDetector(
            onTap: () => _toggle(p, s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: shown.contains(s)
                        ? s.color
                        : cs.outlineVariant,
                    width: 1.2),
                color: shown.contains(s)
                    ? s.color.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: shown.contains(s)
                          ? s.color
                          : cs.onSurfaceVariant.withValues(alpha: 0.35))),
                  const SizedBox(width: 6),
                  Text(s.label, style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: shown.contains(s)
                          ? cs.onSurface
                          : cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _plot(BuildContext context, EnergyHistoryData data,
      EnergyPrices? prices, Set<_Series> shown) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      void selectAt(Offset local) {
        final n = data.points.length;
        if (n < 2) return;
        final frac = (local.dx / c.maxWidth).clamp(0.0, 1.0);
        setState(() => _selected = (frac * (n - 1)).round());
      }

      return GestureDetector(
        onHorizontalDragStart:  (d) => selectAt(d.localPosition),
        onHorizontalDragUpdate: (d) => selectAt(d.localPosition),
        onHorizontalDragEnd:    (_) => setState(() => _selected = null),
        onHorizontalDragCancel: ()  => setState(() => _selected = null),
        onTapDown: (d) => selectAt(d.localPosition),
        onTapUp:   (_) => setState(() => _selected = null),
        child: SizedBox(
          height: 168,
          child: CustomPaint(
            size: Size.infinite,
            painter: _TimelinePainter(
              data: data,
              prices: shown.contains(_Series.price) ? prices : null,
              shown: shown,
              selected: _selected,
              axisColor: cs.onSurfaceVariant.withValues(alpha: 0.30),
              labelColor: cs.onSurfaceVariant,
              nowColor: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    });
  }

  Widget _note(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(text, style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

/// Draws the whole timeline: past on the left, forecast on the right, NOW
/// between them.
///
/// The x mapping is by TIME, not by index, because the two data sets have
/// different cadences — energy comes in 15-minute buckets, price in hours, and
/// the forecast runs past the end of both. Mapping by index would slide them
/// against each other and make the crosshair lie.
class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.data,
    required this.prices,
    required this.shown,
    required this.selected,
    required this.axisColor,
    required this.labelColor,
    required this.nowColor,
  });

  final EnergyHistoryData data;
  final EnergyPrices? prices;
  final Set<_Series> shown;
  final int? selected;
  final Color axisColor;
  final Color labelColor;
  final Color nowColor;

  static const _padLeft = 26.0;   // kWh labels
  static const _padRight = 30.0;  // ct/kWh labels
  static const _padBottom = 14.0; // time axis

  @override
  void paint(Canvas canvas, Size size) {
    if (data.points.isEmpty) return;

    // Bars are aggregated to the hour. At 15-minute buckets across a window that
    // now includes the forecast, each bar came out about two pixels wide — and
    // the price curve this shares an axis with is hourly anyway, so the finer
    // grain bought nothing but noise.
    final pts = _hourly(data);
    if (pts.isEmpty) return;
    const bucket = Duration(hours: 1);

    // ── time domain ────────────────────────────────────────────────────
    //
    // NOW is the end of MEASURED data, not the phone's clock. Energy is stamped
    // by the controller and price by the phone, so when the controller's clock
    // is behind — which it says it is, in the note under this chart — using the
    // phone's now leaves a gap between the last bar and the marker, and slides
    // the price curve away from the hours it belongs to. Everything is mapped on
    // the controller's timeline instead, and the price series is shifted by the
    // observed difference so the two agree about what "13:00" means.
    final tStart = pts.first.time;
    final histEnd = pts.last.time.add(bucket);
    final skew = DateTime.now().difference(histEnd);
    DateTime priceT(DateTime t) => t.subtract(skew);

    var tEnd = histEnd;
    if (prices != null && prices!.points.isNotEmpty) {
      final last = priceT(prices!.points.last.time);
      if (last.isAfter(tEnd)) tEnd = last;
    }
    final span = tEnd.difference(tStart).inSeconds;
    if (span <= 0) return;

    final plotL = _padLeft;
    final plotR = size.width - _padRight;
    final plotW = plotR - plotL;
    final base = size.height - _padBottom;
    final top = 12.0;
    final plotH = base - top;
    double x(DateTime t) =>
        plotL + t.difference(tStart).inSeconds / span * plotW;

    // ── the forecast half, tinted so "past" and "ahead" are visible ────
    final nowX = x(histEnd);
    if (nowX < plotR) {
      canvas.drawRect(Rect.fromLTRB(nowX, top, plotR, base),
          Paint()..color = labelColor.withValues(alpha: 0.04));
    }

    // ── kWh scale, shared by bars and (if shown) export below zero ─────
    const hPerBucket = 1.0;   // hourly bars
    double up(EnergyHistoryPoint p) =>
        (shown.contains(_Series.solar) ? p.pvW : 0) +
        (shown.contains(_Series.grid) ? p.gridImportW : 0);
    final peakUp = pts.fold<double>(0, (m, p) => up(p) > m ? up(p) : m);
    final showExport = shown.contains(_Series.export);
    final peakDown = showExport
        ? pts.fold<double>(0, (m, p) => p.gridExportW > m ? p.gridExportW : m)
        : 0.0;

    final peakUpKwh = peakUp * hPerBucket / 1000.0;
    final step = _niceStep((peakUpKwh <= 0 ? 1 : peakUpKwh) / 2);
    final gridTop = (peakUpKwh / step).ceil().clamp(1, 1000) * step;
    final downKwh = peakDown * hPerBucket / 1000.0;
    // Zero sits proportionally, so up and down share one scale.
    final zeroFrac = downKwh <= 0 ? 1.0 : gridTop / (gridTop + downKwh);
    final zeroY = top + plotH * zeroFrac;
    double yKwh(double kwh) => zeroY - (kwh / gridTop) * (zeroY - top);

    final grid = Paint()..strokeWidth = 1;
    for (var v = step; v <= gridTop + 1e-9; v += step) {
      final gy = yKwh(v);
      canvas.drawLine(Offset(plotL, gy), Offset(plotR, gy),
          grid..color = axisColor.withValues(alpha: 0.16));
      _tinyLabel(canvas, v.toStringAsFixed(step < 1 ? 1 : 0),
          Offset(plotL - 4, gy - 5), labelColor, rightAlign: true);
    }
    canvas.drawLine(Offset(plotL, zeroY), Offset(plotR, zeroY),
        Paint()..color = axisColor..strokeWidth = 1);

    // ── charge band, behind everything ─────────────────────────────────
    if (shown.contains(_Series.charge) && data.hasSoc) {
      final soc = _hourSoc;
      var i = 0;
      while (i < soc.length) {
        if (soc[i] == null) { i++; continue; }
        var j = i;
        while (j + 1 < soc.length && soc[j + 1] != null) { j++; }
        double socY(double pct) => zeroY - (pct / 100) * (zeroY - top);
        final edge = Path();
        for (var k = i; k <= j; k++) {
          final o = Offset(x(pts[k].time), socY(soc[k]!));
          k == i ? edge.moveTo(o.dx, o.dy) : edge.lineTo(o.dx, o.dy);
        }
        final fill = Path.from(edge)
          ..lineTo(x(pts[j].time), zeroY)
          ..lineTo(x(pts[i].time), zeroY)
          ..close();
        canvas.drawPath(fill, Paint()..color = _cSoc.withValues(alpha: 0.06));
        canvas.drawPath(edge, Paint()
          ..color = _cSoc.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
        i = j + 1;
      }
    }

    // ── bars ───────────────────────────────────────────────────────────
    final slot = plotW * (bucket.inSeconds / span);
    final bw = (slot * 0.52).clamp(1.0, slot);
    for (final p in pts) {
      final cx = x(p.time) + slot / 2;
      var y = zeroY;
      final segs = <(double, Color)>[
        if (shown.contains(_Series.solar)) (p.pvW, _cSolar),
        if (shown.contains(_Series.grid)) (p.gridImportW, _cGrid),
      ].where((e) => e.$1 > 0).toList();
      for (var k = 0; k < segs.length; k++) {
        final h = segs[k].$1 * hPerBucket / 1000.0 / gridTop * (zeroY - top);
        final r = Radius.circular((bw / 3).clamp(1.0, 3.0));
        final rect = Rect.fromLTWH(cx - bw / 2, y - h, bw, h);
        if (k == segs.length - 1) {
          canvas.drawRRect(
              RRect.fromRectAndCorners(rect, topLeft: r, topRight: r),
              Paint()..color = segs[k].$2);
        } else {
          canvas.drawRect(rect, Paint()..color = segs[k].$2);
        }
        y -= h + 0.5;
      }
      if (showExport && p.gridExportW > 0) {
        final h = p.gridExportW * hPerBucket / 1000.0 /
            (downKwh <= 0 ? 1 : downKwh) * (base - zeroY);
        final r = Radius.circular((bw / 3).clamp(1.0, 3.0));
        canvas.drawRRect(
            RRect.fromRectAndCorners(
                Rect.fromLTWH(cx - bw / 2, zeroY, bw, h),
                bottomLeft: r, bottomRight: r),
            Paint()..color = _cExport);
      }
    }

    // ── price, its own scale, labelled on the right in its own colour ──
    if (prices != null && prices!.points.isNotEmpty) {
      final inView = [
        for (final p in prices!.points)
          if (!priceT(p.time).isBefore(tStart) && !priceT(p.time).isAfter(tEnd))
            p,
      ];
      if (inView.length > 1) {
        var lo = inView.first.ctPerKwh, hi = lo;
        for (final p in inView) {
          if (p.ctPerKwh < lo) lo = p.ctPerKwh;
          if (p.ctPerKwh > hi) hi = p.ctPerKwh;
        }
        if (hi - lo < 1) hi = lo + 1;
        double yCt(double ct) => base - (ct - lo) / (hi - lo) * plotH * 0.92;

        // A step, not a slope. A spot tariff is constant within its interval and
        // jumps at the boundary; drawing a diagonal between two hours invents
        // prices that were never offered, and makes the moment a price changed —
        // the thing you would act on — impossible to locate.
        final path = Path();
        for (var k = 0; k < inView.length; k++) {
          final t0 = priceT(inView[k].time);
          final t1 = k + 1 < inView.length
              ? priceT(inView[k + 1].time)
              : t0.add(const Duration(hours: 1));
          final y = yCt(inView[k].ctPerKwh);
          k == 0 ? path.moveTo(x(t0), y) : path.lineTo(x(t0), y);
          path.lineTo(x(t1), y);
        }
        canvas.drawPath(path, Paint()
          ..color = _cPrice
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round);
        for (final v in [lo, hi]) {
          _tinyLabel(canvas, v.toStringAsFixed(0),
              Offset(plotR + 4, yCt(v) - 5), _cPrice);
        }
      }
    }

    // ── NOW, and the crosshair ─────────────────────────────────────────
    if (nowX > plotL && nowX < plotR) {
      canvas.drawLine(Offset(nowX, top), Offset(nowX, base),
          Paint()..color = nowColor..strokeWidth = 1);
      _tinyLabel(canvas, 'NOW', Offset(nowX + 3, top - 2), nowColor);
    }
    if (selected != null && selected! < pts.length) {
      final p = pts[selected!.clamp(0, pts.length - 1)];
      final sx = x(p.time) + slot / 2;
      canvas.drawLine(Offset(sx, top), Offset(sx, base),
          Paint()..color = labelColor.withValues(alpha: 0.55)..strokeWidth = 1);
      final t = p.time;
      _tinyLabel(canvas,
          '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}  '
          '${(up(p) * hPerBucket / 1000).toStringAsFixed(2)} kWh',
          Offset(plotR, top - 2), labelColor, rightAlign: true);
    }

    // ── time axis ──────────────────────────────────────────────────────
    for (var f = 0.0; f < 1.0; f += 0.25) {
      final t = tStart.add(Duration(seconds: (span * f).round()));
      final lx = plotL + f * plotW;
      _tinyLabel(canvas, '${t.hour.toString().padLeft(2, '0')}:00',
          Offset(lx + (f == 0 ? 0 : -12), base + 3), labelColor,
          weight: FontWeight.w400);
    }
  }

  /// Sums the 15-minute buckets into hours, carrying the charge level from the
  /// last sample in each hour — a level is not summed.
  List<EnergyHistoryPoint> _hourly(EnergyHistoryData d) {
    // Cleared per call: paint runs on every frame that touches this widget, and
    // an accumulating list would both grow without bound and slide the charge
    // samples out of step with the bars after the first repaint.
    _hourSoc.clear();
    final out = <EnergyHistoryPoint>[];
    final soc = d.socPerBucket;
    final perHour = 3600 / d.bucket.inSeconds;
    var i = 0;
    while (i < d.points.length) {
      final hour = DateTime(d.points[i].time.year, d.points[i].time.month,
          d.points[i].time.day, d.points[i].time.hour);
      var pv = 0.0, dis = 0.0, imp = 0.0, exp = 0.0, chg = 0.0, load = 0.0;
      var n = 0;
      double? lastSoc;
      while (i < d.points.length) {
        final p = d.points[i];
        final h = DateTime(p.time.year, p.time.month, p.time.day, p.time.hour);
        if (h != hour) break;
        pv += p.pvW; dis += p.batteryDischargeW; imp += p.gridImportW;
        exp += p.gridExportW; chg += p.batteryChargeW; load += p.loadW;
        if (i < soc.length && soc[i] != null) lastSoc = soc[i];
        n++; i++;
      }
      if (n == 0) break;
      // Mean power over the hour: the painter turns W back into Wh with a
      // one-hour factor, so averaging here keeps the totals honest.
      out.add(EnergyHistoryPoint(
        time: hour,
        pvW: pv / n, gridImportW: imp / n, gridExportW: exp / n,
        loadW: load / n, batteryChargeW: chg / n, batteryDischargeW: dis / n,
      ));
      _hourSoc.add(lastSoc);
      if (n < perHour && i >= d.points.length) break;   // partial trailing hour
    }
    return out;
  }

  /// Charge level per aggregated hour, filled by [_hourly] alongside its result.
  final List<double?> _hourSoc = [];

  void _tinyLabel(Canvas canvas, String text, Offset at, Color color,
      {bool rightAlign = false, FontWeight weight = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
          color: color, fontSize: 8.5, fontWeight: weight,
          fontFamily: 'monospace', letterSpacing: 0.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rightAlign ? at.translate(-tp.width, 0) : at);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.data != data || old.prices != prices ||
      old.selected != selected || old.shown != shown;
}

/// Rounds a raw step up to 1/2/5 × a power of ten so gridline labels read as
/// numbers a person would choose.
double _niceStep(double raw) {
  if (raw <= 0) return 1;
  var mag = 1.0;
  while (mag * 10 <= raw) { mag *= 10; }
  while (mag > raw) { mag /= 10; }
  for (final m in [1.0, 2.0, 5.0]) {
    if (mag * m >= raw) return mag * m;
  }
  return mag * 10;
}
