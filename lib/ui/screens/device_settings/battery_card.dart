import 'package:flutter/material.dart';
import 'package:matter_home/models/thermostat_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Battery card
// ─────────────────────────────────────────────────────────────────────────────

class BatteryCard extends StatelessWidget {
  const BatteryCard({required this.battery, super.key});
  final BatteryInfo battery;

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final pct = battery.percent;
    final lvl = battery.chargeLevel;
    final Color color;
    final IconData icon;
    if (pct != null) {
      color = pct > 60 ? Colors.green.shade400 : pct > 20 ? Colors.orange.shade400 : Colors.red.shade400;
      icon  = pct > 60 ? Icons.battery_full    : pct > 20 ? Icons.battery_3_bar    : Icons.battery_alert;
    } else {
      color = lvl == 0 ? Colors.green.shade400 : lvl == 1 ? Colors.orange.shade400 : Colors.red.shade400;
      icon  = lvl == 0 ? Icons.battery_full    : lvl == 1 ? Icons.battery_3_bar    : Icons.battery_alert;
    }
    final String label = pct != null
        ? '$pct %'
        : switch (lvl) { 0 => 'OK', 1 => 'Warning', 2 => 'Critical', _ => 'Unknown' };

    return Card(
      color: cs.surface,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: pct != null
            ? LinearProgressIndicator(
                value: pct / 100.0,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
      ),
    );
  }
}
