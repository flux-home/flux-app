part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Color Temperature card
// ─────────────────────────────────────────────────────────────────────────────

class _ColorTemperatureCard extends StatelessWidget {
  const _ColorTemperatureCard({required this.view});
  final DeviceView view;

  // Practical range: 153 mireds (6500 K cool) – 500 mireds (2000 K warm)
  static const _minMireds = 153.0;
  static const _maxMireds = 500.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStale = view.isStale;
    final mireds = view.colorTempMireds?.toDouble().clamp(_minMireds, _maxMireds) ?? (_minMireds + _maxMireds) / 2;
    final kelvin = (1_000_000 / mireds).round();

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                  size: 18,
                  color: isStale ? cs.onSurfaceVariant.withAlpha(80) : Colors.amber,
                ),
                const SizedBox(width: 8),
                Text(
                  'Color Temperature',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(isStale ? '--' : '${kelvin}K', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            // cool ←─── slider ───→ warm
            Row(
              children: [
                Icon(Icons.ac_unit, size: 14, color: Colors.lightBlue.shade300),
                Expanded(
                  child: Slider(
                    value: mireds,
                    min: _minMireds,
                    max: _maxMireds,
                    onChanged: isStale ? null : (_) {},
                    onChangeEnd: isStale
                        ? null
                        : (v) => context.read<DeviceProvider>().setColorTemperature(view.id, v.round()),
                  ),
                ),
                Icon(Icons.local_fire_department, size: 14, color: Colors.orange.shade400),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
