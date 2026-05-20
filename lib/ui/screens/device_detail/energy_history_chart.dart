import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:matter_home/models/energy_bucket.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EnergyHistoryChart — scrollable 15-min mirrored bar chart with axes
//
// Layout (px):
//   [Y-axis 32px] | [scrollable bars]
//
//   importH  = 80   amber bars grow UP   from zeroY
//   zeroH    =  1   hairline
//   exportH  = 36   teal bars grow DOWN  from zeroY
//   labelH   = 30   hour ticks (row 1) + day names (row 2)
//   total    = 147
//
// Y-axis (left, fixed): max / mid / 0 / mid-export / max-export labels in Wh
// X-axis: day names centred per day; hour ticks at 06 / 12 / 18
// ─────────────────────────────────────────────────────────────────────────────

const _importColor = Color(0xFFE8A838);
const _exportColor = Color(0xFF3EC9A7);

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

  static const _slotPx  = 6.0;
  static const _barPx   = 4.0;
  static const _importH = 80.0;
  static const _exportH = 36.0;
  static const _labelH  = 30.0;
  static const _totalH  = _importH + 1 + _exportH + _labelH;

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
        // ── Legend ────────────────────────────────────────────────────────
        Row(
          children: [
            _LegendDot(color: _importColor, label: 'IMPORT'),
            const SizedBox(width: 14),
            _LegendDot(color: _exportColor, label: 'EXPORT', dim: !hasExport),
          ],
        ),
        const SizedBox(height: 8),

        // ── Y-axis + scrollable bars ───────────────────────────────────────
        SizedBox(
          height: _totalH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed Y-axis panel
              _YAxisPanel(
                importH:   _importH,
                exportH:   _exportH,
                labelH:    _labelH,
                maxImport: maxImport,
                maxExport: hasExport ? maxExport : null,
              ),
              const SizedBox(width: 4),
              // Scrollable bar chart
              Expanded(
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
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Y-axis panel — fixed left strip showing Wh scale
// ─────────────────────────────────────────────────────────────────────────────

class _YAxisPanel extends StatelessWidget {
  const _YAxisPanel({
    required this.importH,
    required this.exportH,
    required this.labelH,
    required this.maxImport,
    this.maxExport,
  });

  final double importH;
  final double exportH;
  final double labelH;
  final int    maxImport;
  final int?   maxExport;

  @override
  Widget build(BuildContext context) => SizedBox(
    width:  32,
    height: importH + 1 + exportH + labelH,
    child:  CustomPaint(
      painter: _YAxisPainter(
        importH:   importH,
        exportH:   exportH,
        maxImport: maxImport,
        maxExport: maxExport,
      ),
    ),
  );
}

class _YAxisPainter extends CustomPainter {
  const _YAxisPainter({
    required this.importH,
    required this.exportH,
    required this.maxImport,
    this.maxExport,
  });

  final double importH;
  final double exportH;
  final int    maxImport;
  final int?   maxExport;

  static String _fmt(int wh) {
    if (wh >= 10000) return '${(wh / 1000).toStringAsFixed(0)}k';
    if (wh >= 1000)  return '${(wh / 1000).toStringAsFixed(1)}k';
    return '$wh';
  }

  static const _style = TextStyle(
    color:      Color(0x77FFFFFF),
    fontSize:   8,
    fontWeight: FontWeight.w500,
  );
  static const _unitStyle = TextStyle(
    color:      Color(0x44FFFFFF),
    fontSize:   7,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final zeroY = importH;

    // unit label "Wh" pinned top-right
    _draw(canvas, 'Wh', size.width, 0, style: _unitStyle);

    // Import scale — top (max), middle, zero line
    _draw(canvas, _fmt(maxImport),     size.width, 10);
    _draw(canvas, _fmt(maxImport ~/ 2), size.width, importH / 2 - 4);
    _draw(canvas, '0',                 size.width, zeroY - 9);

    // Hairline along zero
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()..color = Colors.white.withAlpha(18)..strokeWidth = 0.5,
    );

    // Export scale (only when device exports)
    final exp = maxExport;
    if (exp != null && exp > 1) {
      _draw(canvas, _fmt(exp ~/ 2), size.width, zeroY + 1 + exportH / 2 - 4);
      _draw(canvas, _fmt(exp),      size.width, zeroY + 1 + exportH - 10);
    }
  }

  void _draw(Canvas canvas, String text, double rightEdge, double cy,
      {TextStyle? style}) {
    final tp = TextPainter(
      text:          TextSpan(text: text, style: style ?? _style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(rightEdge - tp.width, cy));
  }

  @override
  bool shouldRepaint(_YAxisPainter old) =>
      old.maxImport != maxImport || old.maxExport != maxExport;
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend dot
// ─────────────────────────────────────────────────────────────────────────────

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
          color: dim ? color.withAlpha(60) : color,
          shape: BoxShape.circle,
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
// Bar painter — mirrored import/export + hour ticks + day labels
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

  static const _dayStyle = TextStyle(
    color:      Color(0x66FFFFFF),
    fontSize:   9,
    fontWeight: FontWeight.w500,
  );
  static const _hourStyle = TextStyle(
    color:      Color(0x44FFFFFF),
    fontSize:   8,
    fontWeight: FontWeight.w400,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final zeroY      = importH;
    final labelTop   = importH + 1 + exportH; // y=0 of label zone
    final totalSlots = size.width ~/ slotPx;
    final currentSlot = now.difference(epoch).inMinutes ~/ 15;

    // ── Zero-axis hairline ─────────────────────────────────────────────────
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()..color = Colors.white.withAlpha(20)..strokeWidth = 0.5,
    );

    // ── Lookup tables ──────────────────────────────────────────────────────
    final importLookup = <int, int>{};
    final exportLookup = <int, int>{};
    for (final b in history) {
      final idx = b.time.difference(epoch).inMinutes ~/ 15;
      if (idx >= 0) {
        if (b.wh > 0)         importLookup[idx] = b.wh;
        if (b.exportedWh > 0) exportLookup[idx] = b.exportedWh;
      }
    }

    final importPaint     = Paint()..color = _importColor.withAlpha(200);
    final exportPaint     = Paint()..color = _exportColor.withAlpha(200);
    final importLivePaint = Paint()..color = _importColor.withAlpha(90);
    final exportLivePaint = Paint()..color = _exportColor.withAlpha(90);

    // ── Sealed bars ────────────────────────────────────────────────────────
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

    // ── In-progress (current unsealed slot) ───────────────────────────────
    {
      final ix   = currentSlot * slotPx;
      final impH = math.max(currentBucketWh / maxImport * importH, 2.0).clamp(2.0, importH);
      canvas.drawRect(Rect.fromLTWH(ix, zeroY - impH, barPx, impH), importLivePaint);
      if (currentExportedBucketWh > 0) {
        final expH = (currentExportedBucketWh / maxExport * exportH).clamp(1.0, exportH);
        canvas.drawRect(Rect.fromLTWH(ix, zeroY + 1, barPx, expH), exportLivePaint);
      }
    }

    // ── Day boundaries + hour ticks + labels ──────────────────────────────
    final guidePaint = Paint()
      ..color      = Colors.white.withAlpha(12)
      ..strokeWidth = 0.5;
    final hourTickPaint = Paint()
      ..color      = Colors.white.withAlpha(18)
      ..strokeWidth = 0.5;

    var cursor = epoch;
    while (cursor.isBefore(now)) {
      final next         = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final dayStartSlot = cursor.difference(epoch).inMinutes ~/ 15;
      final midnightSlot = next.difference(epoch).inMinutes ~/ 15;
      final midnightX    = midnightSlot * slotPx;

      // Midnight boundary line
      if (midnightX > 0 && midnightX < size.width) {
        canvas.drawLine(Offset(midnightX, 0), Offset(midnightX, labelTop), guidePaint);
      }

      // Hour ticks + labels at 06, 12, 18
      for (final h in [6, 12, 18]) {
        final hourDt   = DateTime(cursor.year, cursor.month, cursor.day, h);
        if (hourDt.isAfter(epoch) && hourDt.isBefore(now)) {
          final slot = hourDt.difference(epoch).inMinutes ~/ 15;
          final x    = slot * slotPx;
          // Tick
          canvas.drawLine(
            Offset(x, labelTop),
            Offset(x, labelTop + 4),
            hourTickPaint,
          );
          // Label: "06" / "12" / "18"
          _drawText(canvas, h.toString().padLeft(2, '0'), x, labelTop + 5,
              style: _hourStyle, center: true);
        }
      }

      // Day name centred in the day
      final labelCx = (dayStartSlot + (midnightSlot - dayStartSlot) / 2.0) * slotPx;
      _drawText(canvas, _dayLabel(cursor), labelCx, labelTop + 16,
          style: _dayStyle, center: true);

      cursor = next;
    }

    // Current (partial) day
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final todaySlot     = todayMidnight.difference(epoch).inMinutes ~/ 15;
    _drawText(canvas, _dayLabel(todayMidnight),
        (todaySlot + (totalSlots - todaySlot) / 2.0) * slotPx,
        labelTop + 16,
        style: _dayStyle, center: true);
  }

  static String _dayLabel(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  void _drawText(Canvas canvas, String text, double cx, double cy,
      {required TextStyle style, bool center = false}) {
    final tp = TextPainter(
      text:          TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center ? cx - tp.width / 2 : cx, cy));
  }

  @override
  bool shouldRepaint(_MirroredPainter old) =>
      old.history                 != history                 ||
      old.currentBucketWh         != currentBucketWh         ||
      old.currentExportedBucketWh != currentExportedBucketWh ||
      old.maxImport               != maxImport               ||
      old.maxExport               != maxExport;
}
