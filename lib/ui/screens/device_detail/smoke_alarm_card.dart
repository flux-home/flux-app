part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smoke / CO Alarm card  (read-only)
// ─────────────────────────────────────────────────────────────────────────────

class _SmokeAlarmCard extends StatelessWidget {
  const _SmokeAlarmCard({required this.view});
  final DeviceView view;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStale = view.isStale;
    final smoke = isStale ? null : view.smokeState;
    final co = isStale ? null : view.coState;
    final anyAlarm = (smoke ?? 0) > 0 || (co ?? 0) > 0;

    Color stateColor() {
      final worst = [(smoke ?? 0), (co ?? 0)].reduce((a, b) => a > b ? a : b);
      return switch (worst) {
        2 => Colors.red.shade500,
        1 => Colors.orange.shade500,
        _ => Colors.green.shade500,
      };
    }

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
                  anyAlarm ? Icons.warning_rounded : Icons.check_circle_outline,
                  size: 18,
                  color: isStale ? cs.onSurfaceVariant.withAlpha(80) : stateColor(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Smoke / CO Alarm',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AlarmIndicator(label: 'Smoke', state: smoke),
                _AlarmIndicator(label: 'CO', state: co),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmIndicator extends StatelessWidget {
  // 0=Normal 1=Warning 2=Critical null=unknown

  const _AlarmIndicator({required this.label, this.state});
  final String label;
  final int? state;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    if (state == null) {
      color = Colors.grey;
      text = '--';
    } else if (state == 2) {
      color = Colors.red.shade500;
      text = 'Critical';
    } else if (state == 1) {
      color = Colors.orange.shade500;
      text = 'Warning';
    } else {
      color = Colors.green.shade500;
      text = 'OK';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
