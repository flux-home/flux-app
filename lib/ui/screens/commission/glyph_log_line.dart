import 'package:flutter/material.dart';
import 'package:matter_home/providers/commissioning_controller.dart';
import 'package:matter_home/ui/widgets/dot_matrix_painter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Glyph log line — one word-per-slot animated dot-matrix row used in the
// commissioning progress track.
// ─────────────────────────────────────────────────────────────────────────────

class GlyphLogLine extends StatelessWidget {
  // distFromActive drives animation offset in the parent list; the linter
  // cannot see it is read by the enclosing AnimatedList builder.
  // ignore: unused_element_parameter
  const GlyphLogLine({
    required this.text,
    required this.distFromActive,
    this.level,
    this.overrideColor,
    super.key,
  });
  final String     text;
  final LogLevel?  level;
  final Color?     overrideColor;
  final int        distFromActive;

  static const double _activeWordH = 44;
  static const double _otherWordH  = 32;
  static const double _activeTextH = 32;
  static const double _otherTextH  = 22;

  bool   get _isActive => distFromActive == 0;
  double get _wordH    => _isActive ? _activeWordH : _otherWordH;
  double get _textH    => _isActive ? _activeTextH : _otherTextH;

  List<String> get _words {
    final ws = text.trim().split(' ').where((w) => w.isNotEmpty).toList();
    return ws.isEmpty ? [''] : ws;
  }

  double get _opacity {
    final d = distFromActive.abs();
    return switch (d) {
      0 => 1.00,
      1 => 0.45,
      2 => 0.18,
      3 => 0.07,
      _ => 0.03,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final baseColor = overrideColor ??
        (level == null
            ? cs.onSurface
            : switch (level!) {
                LogLevel.success => const Color(0xFF34A853),
                LogLevel.error   => cs.error,
                LogLevel.step    => cs.onSurface,
                LogLevel.info    => cs.onSurfaceVariant,
              });

    final litColor = baseColor.withValues(alpha: _opacity);
    final dimColor = litColor.withAlpha(12);
    final words    = _words;

    return SizedBox(
      height: words.length * _wordH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final word in words)
              SizedBox(
                height: _wordH,
                child: Center(
                  child: SizedBox(
                    height: _textH,
                    width: double.infinity,
                    child: word.isEmpty
                        ? null
                        : CustomPaint(
                            painter: DotMatrixPainter(
                              text: word,
                              litColor: litColor,
                              dimColor: dimColor,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
