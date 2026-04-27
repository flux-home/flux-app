part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sensor readings section — single card, one row per reading
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingsSection extends StatelessWidget {
  const _ReadingsSection({required this.readings, required this.loading});
  final List<ClusterReading>? readings;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (readings == null || readings!.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.white.withAlpha(18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < readings!.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: Colors.white.withAlpha(25), indent: 14, endIndent: 14),
            _ReadingRow(reading: readings![i]),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual reading row — icon + label on top, full-width dot matrix below
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.reading});
  final ClusterReading reading;

  @override
  Widget build(BuildContext context) {
    // Unit text or subtitle shown to the right of the dot matrix.
    final sideText = reading.unit.isNotEmpty
        ? reading.unit
        : reading.subtitle;

    // All values go through the glyph font — uppercase for consistent rendering.
    final dotText = reading.displayValue.toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Icon + label + quality dot ────────────────────────────────
          Row(
            children: [
              Icon(reading.icon, size: 13, color: reading.iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reading.label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (reading.quality != null)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: qualityColor(reading.quality!),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Dot-matrix value + unit ───────────────────────────────────
          // Equal-width spacer on the left mirrors the unit box on the right
          // so the glyph stays centred across the full row width.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (sideText != null) const SizedBox(width: 44),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: CustomPaint(
                    painter: DotMatrixPainter(
                      text: dotText,
                      litColor: Colors.white,
                      dimColor: Colors.white.withAlpha(22),
                    ),
                  ),
                ),
              ),
              if (sideText != null)
                SizedBox(
                  width: 44,
                  child: Text(
                    sideText,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: reading.quality != null
                          ? qualityColor(reading.quality!)
                          : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
