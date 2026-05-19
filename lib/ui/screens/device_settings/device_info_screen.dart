import 'package:flutter/material.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/screens/cluster_inspector_screen.dart';
import 'package:matter_home/ui/screens/thread_diag_screen.dart';
import 'package:matter_home/ui/widgets/info_row.dart';
import 'package:matter_home/utils/date_utils.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Device info sub-screen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceInfoScreen extends StatelessWidget {
  const DeviceInfoScreen({required this.device, super.key});
  final MatterDevice device;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final view = context.watch<DeviceProvider>().viewFor(device.id);

    final rows = <Widget>[];
    void add(String label, String? value, {bool mono = false, bool link = false}) {
      if (value == null || value.isEmpty) return;
      rows.add(InfoRow(label: label, value: value, mono: mono, link: link));
    }

    add('Product',        view?.displayProductName);
    add('Vendor',         view?.vendorName);
    add('Product ID',     view?.productId,   mono: true);
    add('Part no.',       view?.partNumber);
    add('Hardware',       view?.hwVersion);
    add('Firmware',       view?.softwareVersion);
    add('Mfg. date',      view?.manufacturingDate);
    add('Type',           device.deviceType.displayName);
    add('Network',        device.networkType == NetworkType.unknown ? null : device.networkType.label);
    add('Node ID', '0x${device.nodeId.toRadixString(16).padLeft(16, '0').toUpperCase()}', mono: true);
    add('Commissioned',   formatDateTime(device.commissionedAt));
    add('Serial no.',     view?.serialNumber, mono: true);
    add('Unique ID',      view?.uniqueId,     mono: true);
    add('Product URL',    view?.productUrl,   link: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Device info', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: cs.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: rows.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Loading…', style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : Column(children: rows),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: cs.surface,
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.hub_outlined, color: cs.primary),
                title: const Text('Thread diagnostics'),
                subtitle: const Text('Channel, role, neighbours, routing table'),
                trailing: const Icon(Icons.chevron_right),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => ThreadDiagScreen(device: device)),
                ),
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
              ListTile(
                leading: Icon(Icons.manage_search, color: cs.primary),
                title: const Text('Inspect clusters'),
                subtitle: const Text('View all Matter clusters and attributes'),
                trailing: const Icon(Icons.chevron_right),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => ClusterInspectorScreen(device: device)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
