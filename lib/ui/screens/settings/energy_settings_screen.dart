import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/settings/modbus_devices_screen.dart';
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
              ],
            ),
          ),
          if (!online)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Both write to the controller — reconnect to change them.',
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
