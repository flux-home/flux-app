import 'package:flutter/material.dart';
import 'package:matter_home/ui/screens/settings/matter_settings_screen.dart';
import 'package:matter_home/ui/screens/settings/thread_settings_screen.dart';
import 'package:matter_home/ui/widgets/section_label.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  title: const Text('Matter'),
                  subtitle: const Text('Fabric & device management'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute<void>(builder: (_) => const MatterSettingsScreen())),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).colorScheme.outlineVariant),
                ListTile(
                  title: const Text('Thread'),
                  subtitle: const Text('Thread Network Management'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute<void>(builder: (_) => const ThreadSettingsScreen())),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── About ──────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: SectionLabel('About'),
          ),
          const ListTile(
            title: Text('Flux'),
            subtitle: Text('Flutter + CHIP SDK (connectedhomeip)'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
