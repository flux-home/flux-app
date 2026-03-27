import 'package:flutter/material.dart';

import '../widgets/section_label.dart';
import 'network_check_screen.dart';
import 'settings/matter_settings_screen.dart';
import 'settings/thread_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ── Submenus ───────────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.hub_outlined, color: cs.primary),
                  title: const Text('Matter'),
                  subtitle: const Text('Fabric & device management'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MatterSettingsScreen())),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                ListTile(
                  leading: Icon(Icons.router_outlined, color: cs.primary),
                  title: const Text('Thread'),
                  subtitle: const Text('Operational dataset'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ThreadSettingsScreen())),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                ListTile(
                  leading: Icon(Icons.network_check_outlined, color: cs.primary),
                  title: const Text('Network Check'),
                  subtitle: const Text('Diagnose IPv6 & Thread commissioning'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NetworkCheckScreen())),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── About ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: SectionLabel('About'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Flux'),
            subtitle: Text('Flutter + CHIP SDK (connectedhomeip)'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
