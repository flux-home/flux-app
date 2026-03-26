import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/matter_device.dart';
import '../../providers/device_provider.dart';
import '../../services/matter_channel.dart';
import '../widgets/info_row.dart';
import '../widgets/section_label.dart';
import 'cluster_inspector_screen.dart';
import 'thread_diag_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main settings screen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceSettingsScreen extends StatefulWidget {
  final MatterDevice device;
  const DeviceSettingsScreen({super.key, required this.device});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  bool _identifying = false;

  Future<void> _identify(MatterDevice d) async {
    if (_identifying) return;
    setState(() => _identifying = true);
    await context.read<MatterChannel>().identify(d.nodeId);
    await Future.delayed(const Duration(seconds: 15));
    if (mounted) setState(() => _identifying = false);
  }

  Future<void> _remove(BuildContext context, MatterDevice d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove device?'),
        content: Text(
          '"${d.name}" will be removed from this fabric. '
          'The device will need to be factory-reset before it can be re-commissioned.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<DeviceProvider>().removeDevice(d.id);
      if (context.mounted) context.go('/');
    }
  }

  Future<void> _rename(BuildContext context) async {
    final ctrl = TextEditingController(text: widget.device.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Device name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && context.mounted) {
      await context.read<DeviceProvider>().renameDevice(widget.device.id, newName);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        final d = provider.findById(widget.device.id) ?? widget.device;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Device settings',
                style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.drive_file_rename_outline_outlined),
                tooltip: 'Rename',
                onPressed: () => _rename(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Identify ────────────────────────────────────────────────
              const SectionLabel('Identify'),
              Card(
                color: cs.surface,
                child: ListTile(
                  leading: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _identifying
                        ? SizedBox(
                            key: const ValueKey('spinner'),
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: cs.primary),
                          )
                        : Icon(Icons.lightbulb_outline,
                            key: const ValueKey('icon'), color: cs.primary),
                  ),
                  title: Text(
                    _identifying ? 'Identifying…' : 'Identify device',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(_identifying
                      ? 'Device is blinking for 15 s'
                      : 'Makes the device blink / beep'),
                  trailing: _identifying ? null : const Icon(Icons.chevron_right),
                  onTap: _identifying ? null : () => _identify(d),
                ),
              ),

              const SizedBox(height: 20),

              // ── Tools ────────────────────────────────────────────────────
              const SectionLabel('Tools'),
              Card(
                color: cs.surface,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.info_outline, color: cs.primary),
                      title: const Text('Device info'),
                      subtitle: const Text('Type, node ID, commissioned date'),
                      trailing: const Icon(Icons.chevron_right),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceInfoScreen(device: d),
                        ),
                      ),
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16,
                        color: cs.outlineVariant),
                    ListTile(
                      leading: Icon(Icons.hub_outlined, color: cs.primary),
                      title: const Text('Thread diagnostics'),
                      subtitle: const Text(
                          'Channel, role, neighbours, routing table'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ThreadDiagScreen(device: d),
                        ),
                      ),
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16,
                        color: cs.outlineVariant),
                    ListTile(
                      leading: Icon(Icons.manage_search, color: cs.primary),
                      title: const Text('Inspect clusters'),
                      subtitle:
                          const Text('View all Matter clusters and attributes'),
                      trailing: const Icon(Icons.chevron_right),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClusterInspectorScreen(device: d),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Remove device ─────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: () => _remove(context, d),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove device'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withAlpha(120)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device info sub-screen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceInfoScreen extends StatelessWidget {
  final MatterDevice device;
  const DeviceInfoScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final live = context.watch<DeviceProvider>().liveDataFor(device.id);

    // Helper: only show a row if the value is non-null and non-empty.
    List<Widget> rows = [];
    void add(String label, String? value, {bool mono = false, bool link = false}) {
      if (value == null || value.isEmpty) return;
      rows.add(InfoRow(label: label, value: value, mono: mono, link: link));
    }

    // ── Identity ───────────────────────────────────────────────────────
    add('Product',    device.productName ?? live?.productName);
    add('Vendor',     live?.vendorName);
    add('Vendor ID',  live?.vendorId,  mono: true);
    add('Product ID', live?.productId, mono: true);
    add('Part no.',   live?.partNumber);

    // ── Versions ───────────────────────────────────────────────────────
    add('Hardware',   live?.hwVersion);
    add('Firmware',   live?.softwareVersion);

    // ── Manufacturing ──────────────────────────────────────────────────
    add('Mfg. date',  live?.manufacturingDate);

    // ── Device type / node ─────────────────────────────────────────────
    add('Type',       device.deviceType.displayName);
    add('Node ID',
        '0x${device.nodeId.toRadixString(16).padLeft(16, '0').toUpperCase()}',
        mono: true);
    add('Commissioned', _formatDate(device.commissionedAt));

    // ── Identifiers ────────────────────────────────────────────────────
    add('Serial no.', live?.serialNumber, mono: true);
    add('Unique ID',  live?.uniqueId,     mono: true);

    // ── Links ──────────────────────────────────────────────────────────
    add('Product URL', live?.productUrl, link: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device info',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
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
                        child: Text('Loading…',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : Column(children: rows),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}


