part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// On/Off card — single toggle button with dot-matrix state label
// ─────────────────────────────────────────────────────────────────────────────

class _OnOffCard extends StatelessWidget {
  const _OnOffCard({required this.view});
  final DeviceView view;

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final isStale = view.isStale;
    final isOn    = view.isOn;
    final label   = isStale ? '--' : (isOn ? 'ON' : 'OFF');

    final bg = !isStale && isOn ? cs.primary : const Color(0xFF1A1A1A);

    final litColor = isStale ? Colors.white24
                   : isOn    ? cs.onPrimary
                   :           cs.primary;

    final dimColor = isStale ? Colors.white.withAlpha(10)
                   : isOn    ? cs.onPrimary.withAlpha(50)
                   :           cs.primary.withAlpha(40);

    return Center(
      child: GestureDetector(
        onTap: isStale ? null : () => context.read<DeviceProvider>().toggle(view.id),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 200,
          height: 88,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isStale ? Colors.white.withAlpha(20) : cs.primary,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: CustomPaint(
              painter: DotMatrixPainter(
                text: label,
                litColor: litColor,
                dimColor: dimColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
