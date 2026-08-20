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
            deck(112, _SupplyDeckPainter(
              data: data, selected: _selected,
              axisColor: cs.onSurfaceVariant.withValues(alpha: 0.30),
              labelColor: cs.onSurfaceVariant,
            )),
            if (data.hasSoc) ...[
              const SizedBox(height: 8),
              deck(46, _SocDeckPainter(
                soc: data.socPerBucket, selected: _selected,
                axisColor: cs.onSurfaceVariant.withValues(alpha: 0.22),
                labelColor: cs.onSurfaceVariant,
              )),
            ],
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

/// Shared geometry so every deck puts bucket *i* at the same x.
double _xForIndex(int i, int n, double width) =>
    n <= 1 ? width / 2 : i / (n - 1) * width;

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
    required this.axisColor,
    required this.labelColor,
  });

  final EnergyHistoryData data;
  final int? selected;
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

    final top = 12.0;
    final plot = size.height - top;
    final bw = pts.length == 1 ? size.width : size.width / pts.length;

    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height),
        Paint()..color = axisColor..strokeWidth = 1);

    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      var y = size.height;
      // Solar first, then what filled the gaps — reading upward, the bar says
      // "sun, then battery, then bought".
      for (final seg in [
        (p.pvW, _cSolar),
        (p.batteryDischargeW, _cBattery),
        (p.gridImportW, _cGrid),
      ]) {
        if (seg.$1 <= 0) continue;
        final segH = seg.$1 / peak * plot;
        final x = i * bw;
        canvas.drawRect(
          Rect.fromLTWH(x + 0.5, y - segH, (bw - 1).clamp(0.5, bw), segH),
          Paint()..color = seg.$2,
        );
        y -= segH + 0.5;   // hairline gap so segments stay countable
      }
    }

    _paintLabel(canvas, '${(peak * h / 1000).toStringAsFixed(1)} kWh',
        Offset(0, 0), labelColor);
    _paintCrosshair(canvas, size, selected, pts.length,
        labelColor.withValues(alpha: 0.55));

    if (selected != null && selected! < pts.length) {
      final p = pts[selected!.clamp(0, pts.length - 1)];
      _paintLabel(canvas,
          '${(supply(p) * h / 1000).toStringAsFixed(2)} kWh',
          Offset(size.width, 0), labelColor, rightAlign: true);
    }
  }

  @override
  bool shouldRepaint(_SupplyDeckPainter old) =>
      old.data != data || old.selected != selected;
}

/// Deck 2 — charge level. A level, so it is a line between 0 and 100 with the
/// bounds drawn: without them a flat line at 40% and one at 90% look identical.
class _SocDeckPainter extends CustomPainter {
  _SocDeckPainter({
    required this.soc,
    required this.selected,
    required this.axisColor,
    required this.labelColor,
  });

  final List<double?> soc;
  final int? selected;
  final Color axisColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (soc.isEmpty) return;
    const pad = 6.0;
    final plot = size.height - pad * 2;
    double y(double pct) => pad + (1 - pct / 100) * plot;

    final guide = Paint()..color = axisColor..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(100)), Offset(size.width, y(100)), guide);
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), guide);

    final path = Path();
    var started = false;
    for (var i = 0; i < soc.length; i++) {
      final v = soc[i];
      if (v == null) { started = false; continue; }  // a gap stays a gap
      final o = Offset(_xForIndex(i, soc.length, size.width), y(v));
      if (!started) { path.moveTo(o.dx, o.dy); started = true; } else { path.lineTo(o.dx, o.dy); }
    }
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFDCE3DF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round);

    _paintLabel(canvas, 'SOC', Offset(0, 0), labelColor, size: 8.5);
    _paintCrosshair(canvas, size, selected, soc.length,
        labelColor.withValues(alpha: 0.55));

    final shown = selected != null && selected! < soc.length
        ? soc[selected!.clamp(0, soc.length - 1)]
        : soc.lastWhere((v) => v != null, orElse: () => null);
    if (shown != null) {
      _paintLabel(canvas, '${shown.round()}%', Offset(size.width, 0),
          labelColor, rightAlign: true);
    }
  }

  @override
  bool shouldRepaint(_SocDeckPainter old) =>
      old.soc != soc || old.selected != selected;
}

/// Deck 3 — what a kWh cost, on the same time axis. Its own deck precisely
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
