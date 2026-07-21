import 'package:flutter/material.dart';
import 'package:matter_home/services/add_controller_flow.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/settings/app_info_screen.dart';
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

    final (Color dot, String statusLabel) = switch (hub.status) {
      ControllerStatus.online => hub.connectionKind == ConnectionKind.remote
          ? (_remoteColor, 'REMOTE')
          : (_onlineColor, 'ONLINE'),
      ControllerStatus.connecting => (_connectingColor, 'CONNECTING'),
      ControllerStatus.offline    => (_offlineColor, 'OFFLINE'),
      ControllerStatus.noHub      => (_connectingColor, 'NOT SET UP'),
    };
    final configured = hub.hasConfiguredHub;
    final host = hub.service?.endpoint.host;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 20),

          // ══ CONTROLLER ══ the Flux hardware ══════════════════════════════
          _panelHeader(cs,
              icon: Icons.memory,
              label: 'CONTROLLER',
              status: _statusReadout(cs, dot, statusLabel)),
          if (configured)
            _card(cs, [
              _navTile(context, Icons.info_outline, 'Device info',
                  subtitle: host, page: () => const DeviceInfoScreen()),
              _divider(cs),
              _navTile(context, Icons.hub_outlined, 'Matter', qualifier: 'fabric',
                  page: () => const MatterSettingsScreen(scope: MatterScope.controller)),
              _divider(cs),
              _navTile(context, Icons.lan_outlined, 'Thread', qualifier: 'network',
                  page: () => const ThreadSettingsScreen(scope: ThreadScope.controller)),
            ])
          else
            _card(cs, [
              ListTile(
                leading: Icon(Icons.add, color: cs.primary),
                title: const Text('Add a controller'),
                subtitle: const Text('Pair this phone with your Flux controller'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => runAddControllerFlow(context),
              ),
            ]),

          const SizedBox(height: 28),

          // ══ THIS PHONE ══ the device in your hand ════════════════════════
          _panelHeader(cs, icon: Icons.smartphone, label: 'THIS PHONE'),
          _card(cs, [
            _navTile(context, Icons.hub_outlined, 'Matter', qualifier: 'identity',
                page: () => const MatterSettingsScreen(scope: MatterScope.phone)),
            _divider(cs),
            _navTile(context, Icons.lan_outlined, 'Thread', qualifier: 'credentials',
                page: () => const ThreadSettingsScreen(scope: ThreadScope.phone)),
            _divider(cs),
            _navTile(context, Icons.cloud_outlined, 'Remote access',
                subtitle: 'Reach the controller when away from home',
                page: () => const RemoteAccessScreen()),
          ]),

          const SizedBox(height: 28),

          // ══ ABOUT ════════════════════════════════════════════════════════
          _panelHeader(cs, label: 'ABOUT'),
          _card(cs, [
            _navTile(context, Icons.info_outline, 'App info',
                page: () => const AppInfoScreen()),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── TE-styled panel header: glyph + wide-tracked mono label + status ──────
  Widget _panelHeader(ColorScheme cs,
      {required String label, IconData? icon, Widget? status}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (status != null) status,
        ],
      ),
    );
  }

  // ── TE-styled status readout: dot + wide-tracked mono state ───────────────
  Widget _statusReadout(ColorScheme cs, Color dot, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _card(ColorScheme cs, List<Widget> children) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  /// A nav row. [qualifier] renders the TE "Label · qualifier" form (e.g.
  /// "Matter · fabric"); [subtitle] renders a plain second line instead.
  Widget _navTile(BuildContext context, IconData icon, String label,
      {String? qualifier, String? subtitle, required Widget Function() page}) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: qualifier == null
          ? Text(label)
          : Text.rich(TextSpan(children: [
              TextSpan(text: label),
              TextSpan(
                text: '   ·   $qualifier',
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w400),
              ),
            ])),
      subtitle: (subtitle != null && subtitle.isNotEmpty)
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => page())),
    );
  }

  Widget _divider(ColorScheme cs) =>
      Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant);
}
