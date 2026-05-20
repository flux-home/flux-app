import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:matter_home/models/energy_bucket.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EnergyHistoryChart — scrollable 15-min mirrored bar chart
//
// Design (Teenage Engineering / OP-1 inspired):
//   • Imported energy  →  amber bars growing UP   from the zero axis
//   • Exported energy  →  teal  bars growing DOWN from the zero axis
//   • The two flows are immediately readable without a legend scan
//   • 4 px bars / 2 px gaps, horizontally scrollable, "now" pinned right
//   • Faint 2px stub at the current slot even before the first bucket seals
//   • Day-boundary hairlines + weekday labels below
//   • No Y-axis numbers — proportional scale is enough
//
// Layout (px):
//   importH  = 80   ← amber bars grow up from zeroY
//   zeroH    =  1   ← white hairline at zeroY
//   exportH  = 36   ← teal bars grow down from zeroY
//   labelH   = 22   ← weekday labels
//   total    = 139
// ─────────────────────────────────────────────────────────────────────────────

class EnergyHistoryChart extends StatefulWidget {
  const EnergyHistoryChart({
    required this.history,
    required this.currentBucketWh,
    required this.currentExportedBucketWh,
    super.key,
  });

  final List<EnergyBucket> history;
  final int                currentBucketWh;
  final int                currentExportedBucketWh;

  @override
  State<EnergyHistoryChart> createState() => _EnergyHistoryChartState();
}

class _EnergyHistoryChartState extends State<EnergyHistoryChart> {
  late final ScrollController _scroll;

  static const _slotPx   = 6.0;
  static const _barPx    = 4.0;
  static const _importH  = 80.0;
  static const _exportH  = 36.0;
  static const _labelH   = 22.0;
  static const _totalH   = _importH + 1 + _exportH + _labelH;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Canvas origin: midnight of the oldest sealed bucket's day, or today.
  static DateTime _epoch(List<EnergyBucket> history) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (history.isEmpty) return today;
    final oldest    = history.first.time;
    final oldestDay = DateTime(oldest.year, oldest.month, oldest.day);
    final cutoff    = today.subtract(const Duration(days: 7));
    return oldestDay.isBefore(cutoff) ? cutoff : oldestDay;
  }

  static int _slotsNeeded(List<EnergyBucket> history) {
    final now  = DateTime.now();
    final span = now.difference(_epoch(history)).inMinutes ~/ 15 + 2;
    return math.min(span, 7 * 24 * 4);
  }

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final epoch = _epoch(widget.history);
    final slots = _slotsNeeded(widget.history);

    final allImport = [...widget.history.map((b) => b.wh),         widget.currentBucketWh];
    final allExport = [...widget.history.map((b) => b.exportedWh), widget.currentExportedBucketWh];
    final maxImport = allImport.reduce(math.max).clamp(1, 999999999);
    final maxExport = allExport.reduce(math.max).clamp(1, 999999999);

    final hasExport = widget.history.any((b) => b.exportedWh > 0) ||
                      widget.currentExportedBucketWh > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Legend ──────────────────────────────────────────────────────────
        Row(
          children: [
            _LegendDot(color: _importColor, label: 'IMPORT'),
            const SizedBox(width: 14),
            _LegendDot(color: _exportColor, label: 'EXPORT',
                dim: !hasExport),
          ],
        ),
        const SizedBox(height: 8),

        // ── Chart ───────────────────────────────────────────────────────────
        SizedBox(
          height: _totalH,
          child: SingleChildScrollView(
            controller:      _scroll,
            scrollDirection: Axis.horizontal,
            child: CustomPaint(
              size: Size(_slotPx * slots, _totalH),
              painter: _MirroredPainter(
                history:                 widget.history,
                currentBucketWh:         widget.currentBucketWh,
                currentExportedBucketWh: widget.currentExportedBucketWh,
                epoch:                   epoch,
                now:                     now,
                maxImport:               maxImport,
                maxExport:               maxExport,
                slotPx:                  _slotPx,
                barPx:                   _barPx,
                importH:                 _importH,
                exportH:                 _exportH,
                labelH:                  _labelH,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Colours ──────────────────────────────────────────────────────────────────
const _importColor = Color(0xFFE8A838); // warm amber  — consumption
const _exportColor = Color(0xFF3EC9A7); // cool teal   — generation

// ── Legend dot ────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, this.dim = false});
  final Color  color;
  final String label;
  final bool   dim;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          color:  dim ? color.withAlpha(60) : color,
          shape:  BoxShape.circle,
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          color:         dim ? Colors.white.withAlpha(40) : Colors.white.withAlpha(100),
          fontSize:      9,
          fontWeight:    FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _MirroredPainter extends CustomPainter {
  const _MirroredPainter({
    required this.history,
    required this.currentBucketWh,
    required this.currentExportedBucketWh,
    required this.epoch,
    required this.now,
    required this.maxImport,
    required this.maxExport,
    required this.slotPx,
    required this.barPx,
    required this.importH,
    required this.exportH,
    required this.labelH,
  });

  final List<EnergyBucket> history;
  final int      currentBucketWh;
  final int      currentExportedBucketWh;
  final DateTime epoch;
  final DateTime now;
  final int      maxImport;
  final int      maxExport;
  final double   slotPx;
  final double   barPx;
  final double   importH;
  final double   exportH;
  final double   labelH;

  static const _labelStyle = TextStyle(
    color:      Color(0x66FFFFFF),
    fontSize:   9,
    fontWeight: FontWeight.w500,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final zeroY = importH; // y-coordinate of the zero axis

    // ── Zero-axis hairline ────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()..color = Colors.white.withAlpha(20)..strokeWidth = 0.5,
    );

    // ── Build lookup tables ───────────────────────────────────────────────────
    final importLookup = <int, int>{};
    final exportLookup = <int, int>{};
    for (final b in history) {
      final idx = b.time.difference(epoch).inMinutes ~/ 15;
      if (idx >= 0) {
        if (b.wh > 0)         importLookup[idx] = b.wh;
        if (b.exportedWh > 0) exportLookup[idx] = b.exportedWh;
      }
    }

    final totalSlots  = size.width ~/ slotPx;
    final currentSlot = now.difference(epoch).inMinutes ~/ 15;

    final importPaint      = Paint()..color = _importColor.withAlpha(200);
    final exportPaint      = Paint()..color = _exportColor.withAlpha(200);
    final importLivePaint  = Paint()..color = _importColor.withAlpha(90);
    final exportLivePaint  = Paint()..color = _exportColor.withAlpha(90);

    // ── Sealed bars ───────────────────────────────────────────────────────────
    for (var s = 0; s < totalSlots; s++) {
      final impWh = importLookup[s];
      if (impWh != null && impWh > 0) {
        final h = (impWh / maxImport * importH).clamp(1.0, importH);
        canvas.drawRect(Rect.fromLTWH(s * slotPx, zeroY - h, barPx, h), importPaint);
      }
      final expWh = exportLookup[s];
      if (expWh != null && expWh > 0) {
        final h = (expWh / maxExport * exportH).clamp(1.0, exportH);
        canvas.drawRect(Rect.fromLTWH(s * slotPx, zeroY + 1, barPx, h), exportPaint);
      }
    }

    // ── In-progress bars (current unsealed slot) ──────────────────────────────
    {
      final ix = currentSlot * slotPx;
      final impH = math.max(currentBucketWh / maxImport * importH, 2.0).clamp(2.0, importH);
      canvas.drawRect(Rect.fromLTWH(ix, zeroY - impH, barPx, impH), importLivePaint);

      if (currentExportedBucketWh > 0) {
        final expH = (currentExportedBucketWh / maxExport * exportH).clamp(1.0, exportH);
        canvas.drawRect(Rect.fromLTWH(ix, zeroY + 1, barPx, expH), exportLivePaint);
      }
    }

    // ── Day-boundary hairlines + labels ───────────────────────────────────────
    final guidePaint = Paint()
      ..color      = Colors.white.withAlpha(12)
      ..strokeWidth = 0.5;

    var cursor = epoch;
    while (cursor.isBefore(now)) {
      final next         = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final midnightSlot = next.difference(epoch).inMinutes ~/ 15;
      final x            = midnightSlot * slotPx;

      if (x > 0 && x < size.width) {
        canvas.drawLine(Offset(x, 0), Offset(x, importH + exportH + 1), guidePaint);
        final dayStart = cursor.difference(epoch).inMinutes ~/ 15;
        _drawLabel(canvas, _dayLabel(cursor),
            (dayStart + (midnightSlot - dayStart) / 2) * slotPx,
            importH + 1 + exportH + 4);
      }
      cursor = next;
    }
    // Label for the current (partial) day
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final todaySlot     = todayMidnight.difference(epoch).inMinutes ~/ 15;
    _drawLabel(canvas, _dayLabel(todayMidnight),
        (todaySlot + (totalSlots - todaySlot) / 2.0) * slotPx,
        importH + 1 + exportH + 4);
  }

  static String _dayLabel(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  void _drawLabel(Canvas canvas, String text, double cx, double cy) {
    final tp = TextPainter(
      text:          TextSpan(text: text, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textAlign:     TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(_MirroredPainter old) =>
      old.history                 != history                 ||
      old.currentBucketWh         != currentBucketWh         ||
      old.currentExportedBucketWh != currentExportedBucketWh ||
      old.maxImport               != maxImport               ||
      old.maxExport               != maxExport;
}
