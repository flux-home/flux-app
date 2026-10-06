part of '../device_detail_screen.dart';

/// What is limiting this inverter, and to what. Read-only on purpose.
///
/// The limit is not a per-device setting any more: it follows from the grid
/// connection's feed-in limit, which the controller enforces continuously. A
/// slider here would be overwritten within a cycle — the engine re-asserts the
/// setpoint every couple of seconds — so offering one would be offering a
/// control that does not work.
///
/// What is worth showing is the consequence, because it is otherwise invisible:
/// an inverter held at 10.8 kW and an inverter under a cloud produce the same
/// reading, and only the controller knows which this is.
class PvLimitCard extends StatelessWidget {
  const PvLimitCard({required this.adjust, super.key});

  final PowerAdjust adjust;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = context.watch<DeviceProvider>();
    final ctrl = p.energyControl;
    final managed = ctrl != null && ctrl.enabled;

    // The device's own hold is the authority on the number: it is what the
    // inverter was actually told, whoever told it.
    final heldMw = adjust.isActive ? adjust.activePowerMw : null;
    final limitW = heldMw != null ? (heldMw.abs() / 1000).round() : null;

    final String mode;
    final String detail;
    Color tone = cs.onSurfaceVariant;

    if (limitW == null) {
      mode = 'Unlimited';
      detail = managed
          ? 'Nothing is being held back right now.'
          : 'No feed-in limit is set.';
    } else if (managed) {
      mode = 'Holding the feed-in limit';
      tone = const Color(0xFFE8C14A);
      detail = ctrl.curtailing
          ? 'Limited to ${powerLabelW(limitW.toDouble())} — this is costing '
            'production right now.'
          : 'Limited to ${powerLabelW(limitW.toDouble())}. The roof is not '
            'making that much, so nothing is being lost.';
    } else {
      mode = 'Manual limit';
      tone = const Color(0xFFE0894A);
      detail = 'Limited to ${powerLabelW(limitW.toDouble())} by hand, with no '
          'feed-in limit configured.';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.solar_power_outlined,
                    size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Output control',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tone.withValues(alpha: 0.5)),
                    color: tone.withValues(alpha: 0.12),
                  ),
                  child: Text(mode,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tone)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(detail,
                style: TextStyle(
                    fontSize: 13.5, height: 1.35, color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Text('Set in Settings → Energy setup → Grid connection.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
