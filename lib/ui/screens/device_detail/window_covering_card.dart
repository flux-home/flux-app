part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Window Covering card
// ─────────────────────────────────────────────────────────────────────────────

class _WindowCoveringCard extends StatelessWidget {
  const _WindowCoveringCard({required this.view});
  final DeviceView view;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStale = view.isStale;
    final lift = view.liftPercent100ths; // 0 = open, 10000 = closed
    final pct = lift != null ? (lift / 100).round() : null; // 0–100 %closed
    final openPct = pct != null ? (100 - pct) : null; // 0–100 %open

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.blinds_outlined,
                  size: 18,
                  color: isStale ? cs.onSurfaceVariant.withAlpha(80) : cs.onSurface,
                ),
                const SizedBox(width: 8),
                Text('Covering', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  isStale || openPct == null ? '--' : '$openPct% open',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Position slider ───────────────────────────────────────────────
            Slider(
              value: openPct?.toDouble().clamp(0, 100) ?? 0,
              max: 100,
              onChanged: isStale ? null : (_) {},
              onChangeEnd: isStale
                  ? null
                  : (v) {
                      final p100 = ((100 - v) * 100).round().clamp(0, 10000);
                      context.read<DeviceProvider>().coveringGoToLift(view.id, p100);
                    },
            ),
            // ── Up / Stop / Down buttons ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CoveringBtn(
                  icon: Icons.keyboard_arrow_up_rounded,
                  label: 'Open',
                  onTap: isStale ? null : () => context.read<DeviceProvider>().coveringUp(view.id),
                ),
                _CoveringBtn(
                  icon: Icons.stop_rounded,
                  label: 'Stop',
                  onTap: isStale ? null : () => context.read<DeviceProvider>().coveringStop(view.id),
                ),
                _CoveringBtn(
                  icon: Icons.keyboard_arrow_down_rounded,
                  label: 'Close',
                  onTap: isStale ? null : () => context.read<DeviceProvider>().coveringDown(view.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoveringBtn extends StatelessWidget {
  const _CoveringBtn({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: onTap == null ? cs.onSurfaceVariant.withAlpha(80) : cs.onSurface),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: onTap == null ? cs.onSurfaceVariant.withAlpha(80) : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
