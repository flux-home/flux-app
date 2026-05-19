import 'package:flutter/material.dart';

// ── Scan overlay painter ──────────────────────────────────────────────────────
//
// Paints the scrim-with-rounded-cutout overlay used by both [QrScannerScreen]
// and the commissioning backdrop.  Extracted here so neither screen has to
// duplicate the painter.

class ScanOverlayPainter extends CustomPainter {
  const ScanOverlayPainter({
    this.cutoutSize = _kDefaultCutoutSize,
    this.radius = _kDefaultRadius,
  });

  static const double _kDefaultCutoutSize = 240;
  static const double _kDefaultRadius = 22;

  final double cutoutSize;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 40),
      width: cutoutSize,
      height: cutoutSize,
    );
    final rRect =
        RRect.fromRectAndRadius(cutoutRect, Radius.circular(radius));
    canvas
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
          Path()..addRRect(rRect),
        ),
        Paint()..color = Colors.black.withAlpha(210),
      )
      ..drawRRect(
        rRect,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
