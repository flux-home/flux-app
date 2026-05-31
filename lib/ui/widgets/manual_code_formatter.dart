import 'package:flutter/services.dart';

/// TextInputFormatter for Matter manual pairing codes.
///
/// Supports both formats:
/// - 11-digit: `XXXX-XXX-XXXX`           (4-3-4)
/// - 21-digit: `XXXX-XXX-XXXX-XXXX-XXX-XX-X` (4-3-4-4-3-2-1)
///
/// Digits 1–11 always use 4-3-4 grouping; digits 12–21 append groups of
/// 4-3-2-1, so the formatted output grows naturally without reformatting
/// existing groups.
class ManualCodeFormatter extends TextInputFormatter {
  // Group sizes: 4-3-4 (standard) then 4-3-2-1 (extended).
  static const _groups = [4, 3, 4, 4, 3, 2, 1];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(RegExp('[^0-9]'), '');
    final digits = raw.substring(0, raw.length.clamp(0, 21));
    if (digits.isEmpty) return TextEditingValue.empty;

    final buf = StringBuffer();
    var offset = 0;
    for (final size in _groups) {
      if (offset >= digits.length) break;
      final end = (offset + size).clamp(0, digits.length);
      if (buf.isNotEmpty) buf.write('-');
      buf.write(digits.substring(offset, end));
      offset = end;
    }

    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
