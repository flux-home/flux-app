import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/settings/modbus_devices_screen.dart';
import 'package:matter_home/ui/screens/settings/grid_settings_screen.dart';
import 'package:matter_home/ui/screens/settings/solar_settings_screen.dart';
import 'package:matter_home/ui/screens/settings/tariff_settings_screen.dart';

/// Energy configuration: the tariff, and the meters that feed everything else.
///
/// Reached from the Energy view's own settings button rather than the app's
/// settings screen, because it configures what that view shows. It was a card at
/// the bottom of the Energy view — setup competing for space with the data it
/// produces, and read once a year.
///
/// Both write to the controller, so both are disabled while it is unreachable.
class EnergySettingsScreen extends StatelessWidget {
  const EnergySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<HubConnection>().isOnline;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Energy setup')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _row(context,
                    title: 'Electricity tariff',
                    subtitle: 'Fees, levies & VAT on top of spot',
                    enabled: online,
                    builder: () => const TariffSettingsScreen()),
                Divider(height: 1, indent: 16, endIndent: 16,
                    color: cs.outlineVariant),
                _row(context,
                    title: 'Modbus meters',
                    subtitle: 'Meters & inverters over Modbus',
                    enabled: online,
                    builder: () => const ModbusDevicesScreen()),
                Divider(height: 1, indent: 16, endIndent: 16,
                    color: cs.outlineVariant),
                _row(context,
                    title: 'Solar forecast',
                    subtitle: 'Location, roof angle & array size',
                    enabled: online,
                    builder: () => const SolarSettingsScreen()),
                Divider(height: 1, indent: 16, endIndent: 16,
                    color: cs.outlineVariant),
                // Solar is what the roof can make, tariff is what energy costs,
                // and this is what the connection allows. The three together are
                // the model the energy engine runs on.
                _row(context,
                    title: 'Energy Management',
                    subtitle: 'Feed-in limit and how it is held',
                    enabled: online,
                    builder: () => const GridSettingsScreen()),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Stored on the phone, not the controller, and separated from the rows
          // above for exactly that reason: nothing on the wire carries a battery
          // capacity yet, so this one setting cannot follow the others onto the
          // device record.
          const _BatteryCapacityCard(),
          if (!online)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Those three write to the controller — reconnect to change them.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, {
    required String title,
    required String subtitle,
    required bool enabled,
    required Widget Function() builder,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(title, style: TextStyle(
          color: enabled ? cs.onSurface : cs.onSurfaceVariant)),
      subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right,
          color: enabled ? cs.onSurfaceVariant : cs.outlineVariant),
      enabled: enabled,
      onTap: enabled
          ? () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => builder()))
          : null,
    );
  }
}


/// Usable battery capacity, so a charge level can be read as an amount of energy.
///
/// "78%" cannot be compared with an hour that used 1.3 kWh; "12.4 kWh stored"
/// can, and that comparison — how long the battery will carry the house — is the
/// thing a percentage never answers.
class _BatteryCapacityCard extends StatefulWidget {
  const _BatteryCapacityCard();

  @override
  State<_BatteryCapacityCard> createState() => _BatteryCapacityCardState();
}

class _BatteryCapacityCardState extends State<_BatteryCapacityCard> {
  late final TextEditingController _c = TextEditingController(
    text: context.read<DeviceProvider>().batteryCapacityKwh?.toString() ?? '',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    context.read<DeviceProvider>().setBatteryCapacityKwh(v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Battery capacity',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
            const SizedBox(height: 4),
            Text('Usable kWh. Leave empty to show charge as a percentage.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                suffixText: 'kWh',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: _save,
              onTapOutside: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                _save(_c.text);
              },
            ),
          ],
        ),
      ),
    );
  }
}
