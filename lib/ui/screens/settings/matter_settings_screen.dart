import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/device_provider.dart';
import '../../../services/matter_channel.dart';
import '../../widgets/section_label.dart';

// ---------------------------------------------------------------------------
// Matter sub-screen
// ---------------------------------------------------------------------------

class MatterSettingsScreen extends StatefulWidget {
  const MatterSettingsScreen({super.key});

  @override
  State<MatterSettingsScreen> createState() => _MatterSettingsScreenState();
}

class _MatterSettingsScreenState extends State<MatterSettingsScreen> {
  String? _fabricId;
  int?    _vendorId;

  @override
  void initState() {
    super.initState();
    final ch = context.read<MatterChannel>();
    ch.getFabricId().then((id) {
      if (mounted) setState(() => _fabricId = id ?? 'N/A');
    });
    ch.getVendorId().then((vid) {
      if (mounted) setState(() => _vendorId = vid);
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all devices?'),
        content: const Text(
          'All devices will be removed from local storage. '
          'The physical devices are NOT factory-reset and must be '
          'unpaired manually before they can be re-commissioned.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<DeviceProvider>().clearAllDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All devices cleared')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Matter')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: SectionLabel('Fabric')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.vpn_key_outlined, color: cs.primary),
                  title: const Text('Fabric ID'),
                  subtitle: Text(
                    _fabricId ?? '…',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                  trailing: _fabricId != null && _fabricId != 'N/A'
                      ? IconButton(
                          icon: const Icon(Icons.copy_outlined),
                          tooltip: 'Copy',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _fabricId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fabric ID copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        )
                      : null,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                ListTile(
                  leading: Icon(Icons.badge_outlined, color: cs.primary),
                  title: const Text('Vendor ID'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _vendorId != null
                            ? '0x${_vendorId!.toRadixString(16).toUpperCase().padLeft(4, '0')}'
                            : '…',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Test VID — not for production use. '
                        'Range 0xFFF1–0xFFF4 is reserved by the Matter spec for testing only.',
                        style: TextStyle(fontSize: 11, color: cs.error),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: SectionLabel('Device management')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: Icon(Icons.delete_sweep_outlined, color: cs.error),
              title: Text('Clear all devices',
                  style: TextStyle(color: cs.error)),
              subtitle: const Text('Remove from local storage only'),
              onTap: _clearAll,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread sub-screen — auto-scans, shows PAN names only
// ---------------------------------------------------------------------------

/// Merged view of a Thread network: mDNS-discovered border routers + optional
