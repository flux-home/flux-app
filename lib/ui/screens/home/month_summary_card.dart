import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/providers/device_provider.dart';

// The same colours the timeline uses for the same things. A kilowatt-hour that
// came off the roof should not change colour between two cards on one screen.
const _cSolar = Color(0xFFF6D08A);
const _cSoc   = Color(0xFF8FA5E8);
const _cGrid  = Color(0xFFC4483A);

/// The month so far: one bar a day, and the three numbers that summarise it.
///
/// The day view answers "what happened today"; this one answers the question a
/// day cannot — whether today was ordinary. A single day's 98% self-supplied
/// means nothing without the twenty days beside it, and the shape of a month is
/// where a dull fortnight, a battery that stopped reaching full, or the turn of
/// the season actually shows up.
///
/// Each bar is a day's CONSUMPTION, split by where it came from: sun used
/// directly, then the battery, then what had to be bought. The height is
/// therefore the day's use and the red is the part that cost money — the two
/// things worth seeing from across the room.
class MonthSummaryCard extends StatefulWidget {
  const MonthSummaryCard({super.key});

  @override
  State<MonthSummaryCard> createState() => _MonthSummaryCardState();
}

class _MonthSummaryCardState extends State<MonthSummaryCard> {
  Timer? _refresh;

  /// A day bucket changes at most once a day; the only reason to re-ask at all is
  /// that today's bucket is still filling.
  static const _refreshInterval = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
    _refresh = Timer.periodic(_refreshInterval, (_) => _fetch());
  }

  void _fetch() {
    if (!mounted) return;
    context.read<DeviceProvider>().fetchMonthHistory();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final data = provider.monthHistory;

    const months = ['January','February','March','April','May','June','July',
                    'August','September','October','November','December'];
    final title = months[DateTime.now().month - 1].toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Text(title, style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 2.4,
                  color: cs.onSurfaceVariant)),
              const Spacer(),
              if (data != null && !data.isEmpty)
                Text('${data.points.length} days', style: TextStyle(
                    fontFamily: 'monospace', fontSize: 10,
                    color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: data == null || data.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                        provider.monthHistoryLoading
                            ? 'Adding up the month…'
                            : 'No history for this month yet.',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13)),
                  )
                : _body(context, data),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, EnergyHistoryData d) {
    final cs = Theme.of(context).colorScheme;
    final hours = context.watch<DeviceProvider>().monthHoursPerDay;
    final partial = [
      for (var i = 0; i < hours.length; i++)
        if (hours[i] < 24) i,
    ];
    final days = d.points.length;
    final ss = d.selfSufficiencyPercent;
    final perDay = days == 0 ? 0.0 : d.consumptionKwh / days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(d.consumptionKwh.toStringAsFixed(0), style: const TextStyle(
                fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
            const SizedBox(width: 4),
            Text('kWh', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
            const SizedBox(width: 9),
            Text('used · ${perDay.toStringAsFixed(1)} a day',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        if (ss != null) ...[
          const SizedBox(height: 4),
          Text(
            '$ss% self-supplied · ${d.pvKwh.toStringAsFixed(0)} kWh generated · '
            '${d.gridImportKwh.toStringAsFixed(0)} bought · '
            '${d.gridExportKwh.toStringAsFixed(0)} exported',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 128,
          child: CustomPaint(
            size: Size.infinite,
            painter: _MonthPainter(
              data: d,
              partialDays: partial.toSet(),
              axisColor: cs.onSurfaceVariant.withValues(alpha: 0.30),
              labelColor: cs.onSurfaceVariant,
            ),
          ),
        ),
        if (partial.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
              '${partial.length} day${partial.length == 1 ? '' : 's'} only '
              'partly recorded — shown as a gap',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 14, runSpacing: 6,
          children: [
            _key(context, _cSolar, 'Sun used'),
            _key(context, _cSoc, 'Battery'),
            _key(context, _cGrid, 'Bought'),
          ],
        ),
      ],
    );
  }

  Widget _key(BuildContext context, Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(
              shape: BoxShape.circle, color: c)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

/// One bar a day, stacked by where the day's energy came from.
class _MonthPainter extends CustomPainter {
  _MonthPainter({
    required this.data,
    required this.partialDays,
    required this.axisColor,
    required this.labelColor,
  });

  final EnergyHistoryData data;

  /// Days the phone did not see all of. Drawn hollow rather than short: a day
  /// with four hours of data is not a quiet day, and a summary that cannot tell
  /// the two apart is worse than one that admits the gap.
  final Set<int> partialDays;
  final Color axisColor;
  final Color labelColor;

  static const _padLeft = 26.0;
  static const _padRight = 6.0;
  static const _padBottom = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = data.points;
    if (pts.isEmpty) return;

    final plotL = _padLeft, plotR = size.width - _padRight;
    final plotW = plotR - plotL;
    const top = 10.0;
    final base = size.height - _padBottom;

    // Each day's bar is that day's consumption, split by source. Charging
    // subtracts from the sun it came from and discharging adds it back where it
    // was used, so a stored kilowatt-hour is counted once, on the day it ran
    // something — which is the only split that adds up to the day's use.
    double sun(EnergyHistoryPoint p) {
      final v = p.pvW - p.gridExportW - p.batteryChargeW;
      return v > 0 ? v : 0;
    }

    var peak = 0.0;
    for (final p in pts) {
      final total = sun(p) + p.batteryDischargeW + p.gridImportW;
      if (total > peak) peak = total;
    }
    final peakKwh = data.kwhFromW(peak);
    final step = _niceStep((peakKwh <= 0 ? 1 : peakKwh) / 2);
    final gridTop = (peakKwh / step).ceil().clamp(1, 1000) * step;

    double y(double kwh) => base - (kwh / gridTop) * (base - top);

    for (var v = step; v <= gridTop + 1e-9; v += step) {
      canvas.drawLine(Offset(plotL, y(v)), Offset(plotR, y(v)),
          Paint()..color = axisColor.withValues(alpha: 0.16)..strokeWidth = 1);
      _tiny(canvas, v.toStringAsFixed(step < 1 ? 1 : 0),
          Offset(plotL - 4, y(v) - 5), labelColor, rightAlign: true);
    }
    canvas.drawLine(Offset(plotL, base), Offset(plotR, base),
        Paint()..color = axisColor..strokeWidth = 1);

    // A month is 28 to 31 bars however wide the phone is, so the slot is what it
    // is; the bar takes most of it and the gap does the separating.
    final slot = plotW / pts.length;
    final bw = (slot * 0.62).clamp(1.0, 18.0);
    final today = DateTime.now();

    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final cx = plotL + slot * i + slot / 2;
      if (partialDays.contains(i)) {
        // A hollow stub on the baseline: something was recorded, not enough to
        // total.
        canvas.drawRect(
            Rect.fromLTWH(cx - bw / 2, base - 3, bw, 3),
            Paint()..color = axisColor.withValues(alpha: 0.45));
        continue;
      }
      var yy = base;
      for (final (w, c) in [
        (sun(p), _cSolar),
        (p.batteryDischargeW, _cSoc),
        (p.gridImportW, _cGrid),
      ]) {
        if (w <= 0) continue;
        final h = data.kwhFromW(w) / gridTop * (base - top);
        canvas.drawRect(
            Rect.fromLTWH(cx - bw / 2, yy - h, bw, h), Paint()..color = c);
        yy -= h + 1;
      }
      // Today's bar is still filling, and a short last bar otherwise reads as a
      // quiet day rather than an unfinished one.
      if (p.time.year == today.year && p.time.month == today.month &&
          p.time.day == today.day) {
        _tiny(canvas, 'today', Offset(cx, top - 2), labelColor,
            center: true);
      }
    }

    // Dates at the ends and the middle: enough to place a bar, few enough to
    // stay legible at this width.
    for (final i in {0, pts.length ~/ 2, pts.length - 1}) {
      final t = pts[i].time;
      _tiny(canvas, '${t.day}', Offset(plotL + slot * i + slot / 2, base + 3),
          labelColor, center: true, weight: FontWeight.w400);
    }
  }

  void _tiny(Canvas canvas, String text, Offset at, Color color,
      {bool rightAlign = false,
      bool center = false,
      FontWeight weight = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
          color: color, fontSize: 8.5, fontWeight: weight,
          fontFamily: 'monospace', letterSpacing: 0.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        center ? at.translate(-tp.width / 2, 0)
               : rightAlign ? at.translate(-tp.width, 0) : at);
  }

  @override
  bool shouldRepaint(_MonthPainter old) =>
      old.data != data || old.partialDays != partialDays;
}

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
