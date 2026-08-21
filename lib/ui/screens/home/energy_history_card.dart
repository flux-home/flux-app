import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/models/energy_prices.dart';
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
              _decks(context, data),
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
  /// Energy, charge level and price as three decks over ONE time axis.
  ///
  /// Deliberately not one plot: energy (kWh) and price (ct/kWh) have unrelated
  /// scales, and putting them on two y-axes in one frame — the shape this
  /// replaces — makes their crossings look meaningful when they are an artefact
  /// of whatever ranges each axis happened to pick. Separate decks keep every
  /// scale honest while the shared x lets the eye read down a column: expensive
  /// hour, empty battery, nothing generated.
  ///
  /// One crosshair spans all three, because the question is always about a
  /// moment rather than about a series.
  Widget _decks(BuildContext context, EnergyHistoryData data) {
    final cs = Theme.of(context).colorScheme;
    final prices = context.watch<DeviceProvider>().energyPrices;

    return LayoutBuilder(builder: (context, constraints) {
      void selectAt(Offset local) {
        final n = data.points.length;
        if (n < 2) return;
        final frac = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
        setState(() => _selected = (frac * (n - 1)).round());
      }

      Widget deck(double height, CustomPainter painter) => SizedBox(
            height: height,
            child: CustomPaint(painter: painter, size: Size.infinite),
          );

      return GestureDetector(
        onHorizontalDragStart:  (d) => selectAt(d.localPosition),
        onHorizontalDragUpdate: (d) => selectAt(d.localPosition),
        onHorizontalDragEnd:    (_) => setState(() => _selected = null),
        onHorizontalDragCancel: ()  => setState(() => _selected = null),
        onTapDown: (d) => selectAt(d.localPosition),
        onTapUp:   (_) => setState(() => _selected = null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            deck(126, _SupplyDeckPainter(
              data: data, selected: _selected,
              soc: data.hasSoc ? data.socPerBucket : const [],
              axisColor: cs.onSurfaceVariant.withValues(alpha: 0.30),
              labelColor: cs.onSurfaceVariant,
            )),
            if (prices != null && !prices.isEmpty) ...[
              const SizedBox(height: 8),
              deck(58, _PriceDeckPainter(
                data: data, prices: prices, selected: _selected,
                axisColor: cs.onSurfaceVariant.withValues(alpha: 0.22),
                labelColor: cs.onSurfaceVariant,
              )),
            ],
            const SizedBox(height: 4),
            deck(14, _TimeAxisPainter(
              data: data, labelColor: cs.onSurfaceVariant,
            )),
          ],
        ),
      );
    });
  }

  // The series carries its kind, so resolve on the whole key — a PV inverter is
  // usually Modbus, and its node id alone could collide with a Matter node's.
  String _pvName(BuildContext context, PvDeviceSeries s) =>
      context.read<DeviceProvider>().deviceNameForNode(s.nodeId, kind: s.kind) ??
      s.name;

  // ── Legend ────────────────────────────────────────────────────────────────
  /// Names exactly the three things the bars are made of, plus the band behind
  /// them. It used to list the old line chart's series — including per-inverter
  /// names that no longer appear — which is worse than no legend: it told you the
  /// chart contained things it does not.
  Widget _legend(BuildContext context, EnergyHistoryData data) {
    return Wrap(
      spacing: 16, runSpacing: 6, alignment: WrapAlignment.center,
      children: [
        _legendItem(context, _cSolar, 'Solar'),
        _legendItem(context, _cBattery, 'Battery'),
        _legendItem(context, _cGrid, 'Grid'),
        if (data.hasSoc)
          _legendItem(context, _cSoc.withValues(alpha: 0.45), 'Charge level'),
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
// ── Deck painters ───────────────────────────────────────────────────────────
//
// Chart marks use their own palette rather than the app's pastel accents. The
// pastels carry identity fine on the live card, where each has a labelled row of
// its own — but as adjacent stacked segments they fail: solar amber and grid
// coral sit 11.3 apart in OKLab, which is hard to separate even with full colour
// vision, and closer still under deuteranopia. These three are stepped to clear
// that bar on this surface.
const _cSolar   = Color(0xFFB8871E);
const _cGrid    = Color(0xFFC4483A);
const _cBattery = Color(0xFF2E9468);
/// Charge level is a state, not a flow, so it keeps the neutral it has on the
/// live card rather than joining the flow palette.
const _cSoc     = Color(0xFFDCE3DF);

/// Rounds a raw step up to 1/2/5 x a power of ten, so gridline labels read as
/// numbers a person would choose. Same treatment the price chart gives its axis,
/// which is what makes the two charts look like one system.
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

/// Gutter for the value labels, shared by every deck.
///
/// Load-bearing: the decks only mean anything read as one column, so if they
/// disagree about where the plot starts, a crosshair points at 14:00 in one deck
/// and 13:00 in the next. One constant, used by all of them.
const double _padLeft = 28.0;

/// Shared geometry so every deck puts bucket *i* at the same x.
double _xForIndex(int i, int n, double width) =>
    n <= 1 ? _padLeft + (width - _padLeft) / 2
           : _padLeft + i / (n - 1) * (width - _padLeft);

void _paintCrosshair(Canvas canvas, Size size, int? selected, int n, Color c) {
  if (selected == null || n == 0) return;
  final x = _xForIndex(selected.clamp(0, n - 1), n, size.width);
  canvas.drawLine(Offset(x, 0), Offset(x, size.height),
      Paint()..color = c..strokeWidth = 1);
}

void _paintLabel(Canvas canvas, String text, Offset at, Color color,
    {double size = 9, bool rightAlign = false, FontWeight weight = FontWeight.w700}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(
        color: color, fontSize: size, fontWeight: weight,
        fontFamily: 'monospace', letterSpacing: 0.6)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, rightAlign ? at.translate(-tp.width, 0) : at);
}

/// Deck 1 — where the energy came from, stacked per bucket.
class _SupplyDeckPainter extends CustomPainter {
  _SupplyDeckPainter({
    required this.data,
    required this.selected,
    required this.soc,
    required this.axisColor,
    required this.labelColor,
  });

  final EnergyHistoryData data;
  final int? selected;
  /// Charge level per bucket, drawn as a background band. Empty when there is
  /// no battery.
  final List<double?> soc;
  final Color axisColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = data.points;
    if (pts.isEmpty) return;
    final h = data.bucket.inSeconds / 3600.0;   // W → Wh per bucket

    double supply(EnergyHistoryPoint p) =>
        p.pvW + p.gridImportW + p.batteryDischargeW;
    final peak = pts.fold<double>(0, (m, p) => supply(p) > m ? supply(p) : m);
    if (peak <= 0) return;

    final top = 10.0;
    final plot = size.height - top;
    final plotW = size.width - _padLeft;
    final bw = pts.length == 1 ? plotW : plotW / pts.length;

    // Horizontal grid in kWh per bucket, stepped to round numbers — the same
    // treatment the price chart gives its axis, so the two read as one system.
    final hPerBucket = data.bucket.inSeconds / 3600.0;
    final peakKwh = peak * hPerBucket / 1000.0;
    final step = _niceStep(peakKwh / 2);
    final gridTop = (peakKwh / step).ceil() * step;
    final grid = Paint()..strokeWidth = 1;
    for (var v = step; v <= gridTop + 1e-9; v += step) {
      final gy = size.height - (v / gridTop) * plot;
      canvas.drawLine(Offset(_padLeft, gy), Offset(size.width, gy),
          grid..color = axisColor.withValues(alpha: 0.18));
      _paintLabel(canvas, v.toStringAsFixed(step < 1 ? 1 : 0),
          Offset(_padLeft - 5, gy - 5), labelColor,
          size: 8.5, rightAlign: true, weight: FontWeight.w400);
    }
    canvas.drawLine(Offset(_padLeft, size.height), Offset(size.width, size.height),
        Paint()..color = axisColor..strokeWidth = 1);

    // ── Charge level, as a band behind the bars ──────────────────────────
    //
    // Deliberately not a plotted series: percent and kWh have no common scale,
    // so it carries no axis and no gridline of its own, and its value is read
    // from the text label rather than measured against the bars. Filled and
    // translucent so it reads as ground the bars stand on — comparing its height
    // to a bar's would be meaningless, and the drawing should not invite it.
    _paintSocBand(canvas, size, plot);

    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      var y = size.height;
      // Solar first, then what filled the gaps — reading upward, the bar says
      // "sun, then battery, then bought". The last non-zero segment carries the
      // rounded top, so build the list first.
      final segs = [
        (p.pvW, _cSolar),
        (p.batteryDischargeW, _cBattery),
        (p.gridImportW, _cGrid),
      ].where((e) => e.$1 > 0).toList();
      // Scaled against the gridded top rather than the raw peak, so a bar's
      // height can be read off the gridlines instead of merely compared.
      final full = gridTop * 1000.0 / hPerBucket;
      for (final seg in segs) {
        if (seg.$1 <= 0) continue;
        final segH = seg.$1 / full * plot;
        // Thin bars with air between them: at full slot width the day reads as a
        // solid block, and individual hours stop being countable.
        final w = (bw * 0.52).clamp(1.5, bw);
        final x = _padLeft + i * bw + (bw - w) / 2;
        final rect = Rect.fromLTWH(x, y - segH, w, segH);
        // Round the DATA END only — the top of the topmost segment — and leave
        // the baseline flat. Rounding every corner of every segment makes a
        // stack read as a column of detached pills rather than one quantity
        // split into parts.
        final isTop = y >= size.height - 0.6 || seg == segs.last;
        final r = Radius.circular((w / 3).clamp(1.0, 3.0));
        if (isTop) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(rect, topLeft: r, topRight: r),
            Paint()..color = seg.$2,
          );
        } else {
          canvas.drawRect(rect, Paint()..color = seg.$2);
        }
        y -= segH + 0.5;   // hairline gap so segments stay countable
      }
    }

    if (soc.isNotEmpty) {
      final shown = selected != null && selected! < soc.length
          ? soc[selected!.clamp(0, soc.length - 1)]
          : soc.lastWhere((v) => v != null, orElse: () => null);
      if (shown != null) {
        // Top right, clear of the bars: at the bottom left it sat on top of the
        // morning's tallest columns, which is where the eye goes first.
        _paintLabel(canvas, 'SOC ${shown.round()}%',
            Offset(size.width, 0), labelColor, size: 8.5, rightAlign: true);
      }
    }
    _paintCrosshair(canvas, size, selected, pts.length,
        labelColor.withValues(alpha: 0.55));

    if (selected != null && selected! < pts.length) {
      final p = pts[selected!.clamp(0, pts.length - 1)];
      _paintLabel(canvas,
          '${(supply(p) * h / 1000).toStringAsFixed(2)} kWh',
          Offset(size.width, soc.isEmpty ? 0 : 12), labelColor,
          rightAlign: true);
    }
  }

  /// The charge-level band: filled to the baseline, with a slightly stronger
  /// top edge so the shape stays legible where the fill is thin. A bucket with
  /// no sample breaks the band rather than dropping it to zero — an empty
  /// battery and an unheard-from battery are different facts.
  void _paintSocBand(Canvas canvas, Size size, double plot) {
    if (soc.isEmpty) return;
    double y(double pct) => size.height - (pct / 100) * plot;
    double x(int i) => _xForIndex(i, soc.length, size.width);

    var i = 0;
    while (i < soc.length) {
      if (soc[i] == null) { i++; continue; }
      var j = i;
      while (j + 1 < soc.length && soc[j + 1] != null) { j++; }

      final edge = Path();
      for (var k = i; k <= j; k++) {
        final o = Offset(x(k), y(soc[k]!));
        k == i ? edge.moveTo(o.dx, o.dy) : edge.lineTo(o.dx, o.dy);
      }
      final fill = Path.from(edge)
        ..lineTo(x(j), size.height)
        ..lineTo(x(i), size.height)
        ..close();

      // Kept faint on purpose. At the alphas this started with, the band became
      // the picture — a grey mountain with the bars trapped inside it — which is
      // exactly the misreading a second scale invites. It should be ground, and
      // the number is on the label.
      canvas.drawPath(fill, Paint()..color = _cSoc.withValues(alpha: 0.06));
      canvas.drawPath(edge, Paint()
        ..color = _cSoc.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round);
      i = j + 1;
    }
  }

  @override
  bool shouldRepaint(_SupplyDeckPainter old) =>
      old.data != data || old.selected != selected || old.soc != soc;
}

/// Deck 2 — what a kWh cost, on the same time axis. Its own deck precisely
/// because ct/kWh has nothing to do with the kWh scale above it.
class _PriceDeckPainter extends CustomPainter {
  _PriceDeckPainter({
    required this.data,
    required this.prices,
    required this.selected,
    required this.axisColor,
    required this.labelColor,
  });

  final EnergyHistoryData data;
  final EnergyPrices prices;
  final int? selected;
  final Color axisColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = data.points;
    if (pts.isEmpty) return;

    // Price aligned to the SAME buckets as the energy above, so a column means
    // one moment in both decks.
    final series = [for (final p in pts) prices.currentAt(p.time)?.ctPerKwh];
    final known = series.whereType<double>();
    if (known.isEmpty) return;
    var lo = known.reduce((a, b) => a < b ? a : b);
    var hi = known.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1) { hi = lo + 1; }

    const pad = 14.0;
    final plot = size.height - pad - 4;
    double y(double ct) => pad + (1 - (ct - lo) / (hi - lo)) * plot;

    // One gridline at each end of the range, labelled in the shared gutter, so
    // the price deck is read the same way as the deck above it.
    for (final v in [lo, hi]) {
      canvas.drawLine(Offset(_padLeft, y(v)), Offset(size.width, y(v)),
          Paint()..color = axisColor.withValues(alpha: 0.18)..strokeWidth = 1);
      _paintLabel(canvas, v.toStringAsFixed(0),
          Offset(_padLeft - 5, y(v) - 5), labelColor,
          size: 8.5, rightAlign: true, weight: FontWeight.w400);
    }

    final path = Path();
    var started = false;
    var loI = -1, hiI = -1;
    for (var i = 0; i < series.length; i++) {
      final v = series[i];
      if (v == null) { started = false; continue; }
      if (loI < 0 || v < series[loI]!) loI = i;
      if (hiI < 0 || v > series[hiI]!) hiI = i;
      final o = Offset(_xForIndex(i, series.length, size.width), y(v));
      if (!started) { path.moveTo(o.dx, o.dy); started = true; } else { path.lineTo(o.dx, o.dy); }
    }
    canvas.drawPath(path, Paint()
      ..color = labelColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round);

    // Direct labels on the two hours anyone actually asks about.
    void mark(int i, Color c, String suffix) {
      if (i < 0) return;
      final v = series[i]!;
      final o = Offset(_xForIndex(i, series.length, size.width), y(v));
      canvas.drawCircle(o, 3, Paint()..color = c);
      final right = o.dx > size.width * 0.6;
      _paintLabel(canvas, '${v.toStringAsFixed(0)} $suffix',
          Offset(o.dx + (right ? -6 : 6), o.dy - 12), c, size: 8.5,
          rightAlign: right);
    }
    mark(loI, _cBattery, 'cheapest');
    mark(hiI, _cGrid, 'dearest');

    _paintLabel(canvas, 'ct/kWh', Offset(0, 0), labelColor, size: 8.5);
    _paintCrosshair(canvas, size, selected, series.length,
        labelColor.withValues(alpha: 0.55));

    if (selected != null && selected! < series.length) {
      final v = series[selected!.clamp(0, series.length - 1)];
      if (v != null) {
        _paintLabel(canvas, '${v.toStringAsFixed(1)} ct',
            Offset(size.width, 0), labelColor, rightAlign: true);
      }
    }
  }

  @override
  bool shouldRepaint(_PriceDeckPainter old) =>
      old.data != data || old.selected != selected || old.prices != prices;
}

/// One time axis for all the decks above it — the thing that makes them readable
/// as a column instead of three unrelated pictures.
class _TimeAxisPainter extends CustomPainter {
  _TimeAxisPainter({required this.data, required this.labelColor});

  final EnergyHistoryData data;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = data.points;
    if (pts.length < 2) return;
    for (final frac in [0.0, 0.25, 0.5, 0.75]) {
      final i = (frac * (pts.length - 1)).round();
      final t = pts[i].time;
      final label = '${t.hour.toString().padLeft(2, '0')}:00';
      final x = _xForIndex(i, pts.length, size.width);
      _paintLabel(canvas, label, Offset(x + (frac == 0 ? 0 : -14), 0),
          labelColor, size: 8.5, weight: FontWeight.w400);
    }
  }

  @override
  bool shouldRepaint(_TimeAxisPainter old) => old.data != data;
}
