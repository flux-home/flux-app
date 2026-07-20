import 'package:flutter/material.dart';
import 'package:matter_home/services/add_controller_flow.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/settings/app_info_screen.dart';
import 'package:matter_home/ui/screens/settings/controller_detail_screen.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String> _controllers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await ControllerSettings.allControllerIds();
    if (mounted) setState(() => _controllers = ids);
  }

  Future<void> _addController() async {
    await runAddControllerFlow(context);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final hub = context.watch<HubConnection>();

    // Single-active backend: connection state is meaningful for the currently
    // connected controller. (Per-controller state lands with real multi-ctrl.)
    String stateFor(String id) {
      if (!hub.isOnline) return 'Offline';
      return hub.connectionKind == ConnectionKind.remote
          ? 'Connected · remote'
          : 'Connected · local';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: SectionLabel('Controllers'),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final id in _controllers) ...[
                  ListTile(
                    leading: Icon(Icons.router_outlined, color: cs.primary),
                    title: Text(id, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(stateFor(id)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                        builder: (_) => ControllerDetailScreen(controllerId: id))),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                ],
                ListTile(
                  leading: Icon(Icons.add, color: cs.primary),
                  title: const Text('Add controller'),
                  onTap: _addController,
                ),
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
}
