import 'package:flutter/material.dart';
import 'package:matter_home/services/add_controller_flow.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/settings/app_info_screen.dart';
import 'package:matter_home/ui/screens/settings/connection_screen.dart';
import 'package:matter_home/ui/screens/settings/device_info_screen.dart';
import 'package:matter_home/ui/screens/settings/matter_settings_screen.dart';
import 'package:matter_home/ui/screens/settings/remote_access_screen.dart';
import 'package:matter_home/ui/screens/settings/thread_settings_screen.dart';
import 'package:provider/provider.dart';

// Connection-state accents.
const _onlineColor     = Color(0xFF9FD8A8); // green
const _remoteColor     = Color(0xFFA9C7F2); // blue
const _connectingColor = Color(0xFFBFC4CC); // grey
const _offlineColor    = Color(0xFFF2A9A0); // coral

/// Settings, arranged as two device panels so it's always clear which box a
/// setting belongs to: the **controller** (the Flux hardware) and **this
/// phone**. Terminology is unified on "controller" throughout the app.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final hub = context.watch<HubConnection>();
    final configured = hub.hasConfiguredHub;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 20),

          // ══ CONTROLLER ══ the Flux hardware ══════════════════════════════
          _label(cs, 'CONTROLLER'),
          if (configured)
            _card(cs, [
              _ConnectionWidget(hub: hub),
              _divider(cs),
              _navTile(context, 'Device info', () => const DeviceInfoScreen()),
              _divider(cs),
              _navTile(context, 'Matter',
                  () => const MatterSettingsScreen(scope: MatterScope.controller)),
              _divider(cs),
              _navTile(context, 'Thread',
                  () => const ThreadSettingsScreen(scope: ThreadScope.controller)),
            ])
          else
            _card(cs, [
              ListTile(
                title: const Text('Add a controller'),
                subtitle: const Text('Pair this phone with your Flux controller'),
                trailing: Icon(Icons.chevron_right, color: cs.primary),
                onTap: () => runAddControllerFlow(context),
              ),
            ]),

          const SizedBox(height: 28),

          // ══ THIS PHONE ══ the device in your hand ════════════════════════
          _label(cs, 'THIS PHONE'),
          _card(cs, [
            _navTile(context, 'Matter',
                () => const MatterSettingsScreen(scope: MatterScope.phone)),
            _divider(cs),
            _navTile(context, 'Thread',
                () => const ThreadSettingsScreen(scope: ThreadScope.phone)),
            _divider(cs),
            _navTile(context, 'Remote access', () => const RemoteAccessScreen()),
          ]),

          const SizedBox(height: 28),

          // ══ ABOUT ════════════════════════════════════════════════════════
          _label(cs, 'ABOUT'),
          _card(cs, [
            _navTile(context, 'App info', () => const AppInfoScreen()),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── TE-styled panel label: wide-tracked monospace, no glyph ───────────────
  Widget _label(ColorScheme cs, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(text, style: TextStyle(
            fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700,
            letterSpacing: 2.4, color: cs.onSurfaceVariant)),
      );

  Widget _card(ColorScheme cs, List<Widget> children) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _navTile(BuildContext context, String label, Widget Function() page) =>
      ListTile(
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => page())),
      );

  Widget _divider(ColorScheme cs) =>
      Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant);
}

/// Dedicated connection-state widget at the top of the CONTROLLER panel: a
/// coloured dot + plain-language state, tapping through to the full local /
/// remote breakdown in [ConnectionScreen].
class _ConnectionWidget extends StatelessWidget {
  const _ConnectionWidget({required this.hub});
  final HubConnection hub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color dot, String title, String subtitle) = switch (hub.status) {
      ControllerStatus.online => hub.connectionKind == ConnectionKind.remote
          ? (_remoteColor, 'Connected', 'Remote · encrypted tunnel')
          : (_onlineColor, 'Connected', 'Local network'),
      ControllerStatus.connecting => (_connectingColor, 'Connecting…', ''),
      ControllerStatus.offline    => (_offlineColor, 'Offline', 'Controller unreachable'),
      ControllerStatus.noHub      => (_connectingColor, 'Not set up', ''),
    };

    return ListTile(
      leading: Container(width: 12, height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const ConnectionScreen())),
    );
  }
}
