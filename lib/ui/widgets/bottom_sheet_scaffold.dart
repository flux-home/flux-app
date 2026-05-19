import 'package:flutter/material.dart';

/// Standard bottom-sheet chrome: handle bar, optional title, keyboard-inset
/// padding, and safe-area wrapping.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   builder: (_) => BottomSheetScaffold(
///     title: 'Pick a room',
///     child: RoomList(),
///   ),
/// );
/// ```
class BottomSheetScaffold extends StatelessWidget {
  const BottomSheetScaffold({
    required this.child,
    this.title,
    this.titleWidget,
    this.useSafeArea = true,
    this.addKeyboardPadding = true,
    super.key,
  }) : assert(title == null || titleWidget == null,
           'Provide at most one of title or titleWidget');

  final Widget child;
  /// Simple string title rendered in titleMedium bold.
  final String? title;
  /// Custom title widget — use when the heading requires icons or rich layout.
  final Widget? titleWidget;
  final bool useSafeArea;
  final bool addKeyboardPadding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        // ── Handle bar ─────────────────────────────────────────────────────
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (title != null) ...[  
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              title!,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ] else if (titleWidget != null) ...[  
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: titleWidget!,
          ),
        ],
        child,
        const SizedBox(height: 8),
      ],
    );

    if (addKeyboardPadding) {
      content = Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: content,
      );
    }

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}
