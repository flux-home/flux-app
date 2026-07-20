import 'package:flutter/material.dart';
import 'package:matter_home/services/add_controller_flow.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/settings/app_info_screen.dart';
import 'package:matter_home/ui/screens/settings/device_info_screen.dart';
import 'package:matter_home/ui/screens/settings/matter_settings_screen.dart';
import 'package:matter_home/ui/screens/settings/remote_access_screen.dart';
import 'package:matter_home/ui/screens/settings/thread_settings_screen.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

// Connection-state accents.
const _onlineColor     = Color(0xFF9FD8A8); // green
const _remoteColor     = Color(0xFFA9C7F2); // blue
const _connectingColor = Color(0xFFBFC4CC); // grey
const _offlineColor    = Color(0xFFF2A9A0); // coral

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final hub = context.watch<HubConnection>();

    final (Color dot, String label) = switch (hub.status) {
      ControllerStatus.online => hub.connectionKind == ConnectionKind.remote
          ? (_remoteColor, 'Connected · remote')
          : (_onlineColor, 'Connected'),
      ControllerStatus.connecting => (_connectingColor, 'Connecting…'),
      ControllerStatus.offline    => (_offlineColor, 'Offline'),
      ControllerStatus.noHub      => (_offlineColor, 'No hub configured'),
    };
    final configured = hub.hasConfiguredHub;
    final host = hub.service?.endpoint.host;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          // ── Connection status (display-only when a hub is configured) ────
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: Container(width: 12, height: 12,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: (host != null && host.isNotEmpty)
                  ? Text(host, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                  : (configured ? null : const Text('Tap to add a controller')),
              trailing: configured ? null : Icon(Icons.add, color: cs.primary),
              onTap: configured ? null : () => runAddControllerFlow(context),
            ),
          ),

          const SizedBox(height: 16),

          // ── Top-level items ──────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _tile(context, Icons.info_outline, 'Device info', () => const DeviceInfoScreen()),
                _divider(cs),
                _tile(context, Icons.hub_outlined, 'Matter', () => const MatterSettingsScreen()),
                _divider(cs),
                _tile(context, Icons.lan_outlined, 'Thread', () => const ThreadSettingsScreen()),
                _divider(cs),
                _tile(context, Icons.cloud_outlined, 'Remote access', () => const RemoteAccessScreen()),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: SectionLabel('About'),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              title: const Text('App Info'),
              trailing: const Icon(Icons.chevron_right),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => const AppInfoScreen())),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, Widget Function() page) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => page())),
    );
  }

  Widget _divider(ColorScheme cs) =>
      Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant);
}
