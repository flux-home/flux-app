import 'dart:math' as math;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 5 × 7 dot-matrix glyph table
// ─────────────────────────────────────────────────────────────────────────────
// Each entry is 7 rows of bit-masks.  Bit (cols-1) = leftmost column.
// Digits & period use 5 columns; '.' uses 3 columns (half-width).

const dotMatrixGlyphs = <String, List<int>>{
  // ── Digits ─────────────────────────────────────────────────────────────────
  '0': [0x0E,0x11,0x13,0x15,0x19,0x11,0x0E],
  '1': [0x04,0x0C,0x04,0x04,0x04,0x04,0x0E],
  '2': [0x0E,0x11,0x01,0x06,0x08,0x10,0x1F],
  '3': [0x0E,0x11,0x01,0x06,0x01,0x11,0x0E],
  '4': [0x02,0x06,0x0A,0x12,0x1F,0x02,0x02],
  '5': [0x1F,0x10,0x1E,0x01,0x01,0x11,0x0E],
  '6': [0x0E,0x10,0x1E,0x11,0x11,0x11,0x0E],
  '7': [0x1F,0x01,0x02,0x04,0x08,0x08,0x08],
  '8': [0x0E,0x11,0x11,0x0E,0x11,0x11,0x0E],
  '9': [0x0E,0x11,0x11,0x0F,0x01,0x01,0x0E],
  // ── Punctuation ────────────────────────────────────────────────────────────
  '.': [0x00,0x00,0x00,0x00,0x00,0x02,0x02],   // 3-col half-width
  '-': [0x00,0x00,0x00,0x1F,0x00,0x00,0x00],
  // ── Uppercase (for "ON" / "OFF" status readings) ───────────────────────────
  'O': [0x0E,0x11,0x11,0x11,0x11,0x11,0x0E],
  'N': [0x11,0x19,0x15,0x13,0x11,0x11,0x11],
  'F': [0x1F,0x10,0x10,0x1E,0x10,0x10,0x10],
  // ── Punctuation (extended) ──────────────────────────────────────────────────
  '%': [0x0C,0x0C,0x02,0x04,0x08,0x03,0x03],
  // ── Lowercase (for "offline" label) ────────────────────────────────────────
  'o': [0x00,0x00,0x0E,0x11,0x11,0x11,0x0E],
  'f': [0x06,0x04,0x0E,0x04,0x04,0x04,0x04],
  'l': [0x04,0x04,0x04,0x04,0x04,0x04,0x06],
  'i': [0x04,0x00,0x04,0x04,0x04,0x04,0x04],
  'n': [0x00,0x00,0x0E,0x11,0x11,0x11,0x11],
  'e': [0x00,0x00,0x0E,0x11,0x1F,0x10,0x0E],
};

int dotMatrixCharCols(String ch) => ch == '.' ? 3 : 5;

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

/// Renders [text] as a 5 × 7 dot-matrix in the given canvas, centred and
/// scaled to fill the available size.
///
/// [litColor]  – colour of lit (foreground) dots.
/// [dimColor]  – optional colour of unlit (background) dots; omitted if null.
class DotMatrixPainter extends CustomPainter {
  final String text;
  final Color  litColor;
  final Color? dimColor;

  const DotMatrixPainter({
    required this.text,
    required this.litColor,
    this.dimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chars = text.characters.toList();
    final n     = chars.length;
    if (n == 0) return;

    final totalCols =
        chars.fold(0, (s, c) => s + dotMatrixCharCols(c)) + (n - 1);

    const gap  = 2.0;
    final stepW = (size.width  + gap) / totalCols;
    final stepH = (size.height + gap) / 7;
    final step  = math.min(stepW, stepH);
    final r     = (step - gap) / 2;

    final matW = step * totalCols - gap;
    final matH = step * 7         - gap;
    final ox   = (size.width  - matW) / 2;
    final oy   = (size.height - matH) / 2;

    final litPaint = Paint()..color = litColor ..style = PaintingStyle.fill;
    final dimPaint = dimColor != null
        ? (Paint()..color = dimColor!..style = PaintingStyle.fill)
        : null;

    double cx = ox;
    for (final ch in chars) {
      final glyph = dotMatrixGlyphs[ch] ?? dotMatrixGlyphs['-']!;
      final cols  = dotMatrixCharCols(ch);
      for (int row = 0; row < 7; row++) {
        final bits = glyph[row];
        for (int col = 0; col < cols; col++) {
          final lit = ((bits >> ((cols - 1) - col)) & 1) == 1;
          if (lit) {
            canvas.drawCircle(
              Offset(cx + col * step + step / 2, oy + row * step + step / 2),
              r, litPaint,
            );
          } else if (dimPaint != null) {
            canvas.drawCircle(
              Offset(cx + col * step + step / 2, oy + row * step + step / 2),
              r * 0.55, dimPaint,
            );
          }
        }
      }
      cx += cols * step + step;
    }
  }

  @override
  bool shouldRepaint(DotMatrixPainter old) =>
      old.text != text || old.litColor != litColor || old.dimColor != dimColor;
}
