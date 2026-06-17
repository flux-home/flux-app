import 'package:flutter/material.dart';
import 'package:matter_home/ui/theme.dart';
import 'package:matter_home/ui/widgets/dot_matrix_painter.dart';

/// Two-line LED-matrix-style empty-state hint, e.g. "NO DEVICES" / "TAP + TO ADD".
/// Shared by screens whose body is empty until the user taps a FAB.
class DotMatrixEmptyHint extends StatelessWidget {
  const DotMatrixEmptyHint({required this.headline, required this.subline, super.key});

  final String headline;
  final String subline;

  @override
  Widget build(BuildContext context) {
    const dim = Color(0x1F6DC9A2); // kBrandGreen @ ~12 % opacity

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 280,
            height: 42,
            child: CustomPaint(
              painter: DotMatrixPainter(text: headline, litColor: kBrandGreen, dimColor: dim),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 260,
            height: 32,
            child: CustomPaint(
              painter: DotMatrixPainter(text: subline, litColor: kBrandGreen, dimColor: dim),
            ),
          ),
        ],
      ),
    );
  }
}
