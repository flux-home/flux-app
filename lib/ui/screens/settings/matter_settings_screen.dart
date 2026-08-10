import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Matter sub-screen
// ---------------------------------------------------------------------------

/// The controller's Matter fabric — the one your devices are commissioned onto.
class MatterSettingsScreen extends StatefulWidget {
  const MatterSettingsScreen({super.key});

  @override
  State<MatterSettingsScreen> createState() => _MatterSettingsScreenState();
}

class _MatterSettingsScreenState extends State<MatterSettingsScreen> {
  String? _hubFabricId;    // the controller's fabric (via CoAP)

  @override
  void initState() {
    super.initState();
    // Hub fabric: MatterFabricPort is proxied from the controller.
    context.read<MatterFabricPort>().getFabricId().then((id) {
      if (mounted) setState(() => _hubFabricId = id ?? 'N/A');
    });
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Matter')),
      body: ListView(children: _controllerBody(cs)),
    );
  }

  // ── CONTROLLER: the home's real Matter fabric ─────────────────────────────
  List<Widget> _controllerBody(ColorScheme cs) => [
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            ListTile(
              leading: Icon(Icons.memory, color: cs.primary),
              title: const Text('Fabric ID'),
              subtitle: Text(_hubFabricId ?? '…',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              trailing: (_hubFabricId != null && _hubFabricId != 'N/A')
                  ? IconButton(icon: const Icon(Icons.copy_outlined), tooltip: 'Copy',
                      onPressed: () => _copy(_hubFabricId!, 'Fabric ID'))
                  : null,
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
            ListTile(
              dense: true,
              leading: Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
              title: Text("Your devices are commissioned onto the controller's fabric.",
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            ),
          ]),
        ),
        const SizedBox(height: 40),
      ];

}
