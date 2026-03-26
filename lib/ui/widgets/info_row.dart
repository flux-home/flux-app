import 'package:flutter/material.dart';

/// A reusable key-value row widget used in detail/info screens.
///
/// Renders [label] left-aligned in a fixed-width column and [value] in the
/// remaining space.  Set [mono] for monospace value text (IDs, hex strings
/// etc.) and [link] to style the value as a tappable hyperlink colour.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;
  final bool   mono;
  final bool   link;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 130,
    this.mono       = false,
    this.link       = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize:   13,
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w500,
                color:      link ? cs.primary : null,
                decoration: link ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
