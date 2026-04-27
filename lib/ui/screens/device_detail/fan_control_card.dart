part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fan Control card
// ─────────────────────────────────────────────────────────────────────────────

class _FanControlCard extends StatelessWidget {
  const _FanControlCard({required this.view});
  final DeviceView view;

  static const _modes = ['Off', 'Low', 'Med', 'High', 'On', 'Auto'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStale = view.isStale;
    final mode = view.fanMode;
    final pct = view.fanPercent;

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
                  Icons.wind_power_outlined,
                  size: 18,
                  color: isStale ? cs.onSurfaceVariant.withAlpha(80) : cs.onSurface,
                ),
                const SizedBox(width: 8),
                Text('Fan', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(isStale || pct == null ? '--' : '$pct%', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            // ── Speed slider ──────────────────────────────────────────────────
            Slider(
              value: pct?.toDouble().clamp(0, 100) ?? 0,
              max: 100,
              onChanged: isStale ? null : (_) {},
              onChangeEnd: isStale ? null : (v) => context.read<DeviceProvider>().setFanPercent(view.id, v.round()),
            ),
            // ── Mode chips ────────────────────────────────────────────────────
            Wrap(
              spacing: 6,
              children: List.generate(_modes.length, (i) {
                final selected = mode == i;
                return ChoiceChip(
                  label: Text(_modes[i]),
                  selected: selected,
                  onSelected: isStale ? null : (_) => context.read<DeviceProvider>().setFanMode(view.id, i),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
