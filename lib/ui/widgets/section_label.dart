import 'package:flutter/material.dart';

/// A reusable section-header label.
///
/// [style] controls the visual variant:
/// - [SectionLabelStyle.prominent] — `labelLarge`, primary colour, bold,
///   used in form-style screens (e.g. commission screen).
/// - [SectionLabelStyle.subtle] — `labelSmall` uppercased, muted colour,
///   used in list/detail screens (default).
enum SectionLabelStyle { prominent, subtle }

class SectionLabel extends StatelessWidget {
  final String text;
  final SectionLabelStyle style;

  const SectionLabel(
    this.text, {
    super.key,
    this.style = SectionLabelStyle.subtle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    switch (style) {
      case SectionLabelStyle.prominent:
        return Text(
          text,
          style: tt.labelLarge?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        );
      case SectionLabelStyle.subtle:
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            text.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
        );
    }
  }
}
