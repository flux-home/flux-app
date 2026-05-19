import 'package:flutter/material.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/ui/screens/settings/thread/border_router_detail_screen.dart';
import 'package:matter_home/ui/screens/settings/thread/thread_dataset_detail_screen.dart';
import 'package:matter_home/ui/widgets/section_label.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Active network detail screen
// ─────────────────────────────────────────────────────────────────────────────

// Data model for discovered Thread network
class ThreadNetworkInfo {
  const ThreadNetworkInfo({
    required this.networkName,
    required this.extPanId,
    required this.borderRouters,
    required this.isConfigured,
    this.configuredHex,
  });
  final String networkName;
  final String extPanId;
  final List<ThreadBorderRouter> borderRouters;
  final bool isConfigured;
  final String? configuredHex;
}

class ActiveNetworkDetailScreen extends StatelessWidget {
  const ActiveNetworkDetailScreen({
    required this.active,
    required this.scanning,
    this.network,
    super.key,
  });
  final ThreadDataset       active;
  final ThreadNetworkInfo?  network;
  final bool                scanning;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(active.label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Dataset — nav tile ─────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Icon(Icons.key_outlined, color: cs.onSurfaceVariant),
              title: const Text('Dataset'),
              subtitle: Text(active.label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ThreadDatasetDetailScreen(
                    initialHex: active.hex, initialLabel: active.label, isActive: true),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Border Routers ─────────────────────────────────────────────
          Card(
            child: network == null || network!.borderRouters.isEmpty
                ? ListTile(
                    leading: Icon(scanning ? Icons.sync : Icons.wifi_find_outlined,
                        color: cs.onSurfaceVariant),
                    title: Text(scanning ? 'Scanning…' : 'Not detected on local network',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  )
                : Column(
                    children: network!.borderRouters.asMap().entries.map((e) {
                      final r    = e.value;
                      final last = e.key == network!.borderRouters.length - 1;
                      final name = r.vendorName.isNotEmpty && r.modelName.isNotEmpty
                          ? '${r.vendorName} ${r.modelName}' : r.serviceName;
                      return Column(children: [
                        ListTile(
                          leading: Icon(Icons.device_hub, color: cs.primary),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: r.txt['tv'] != null
                              ? Text('Thread ${r.txt['tv']}',
                                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
                              : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute<void>(builder: (_) => ThreadBorderRouterDetailScreen(router: r))),
                        ),
                        if (!last) Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                      ]);
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thread network detail (for non-configured / other networks)
// ─────────────────────────────────────────────────────────────────────────────

class ThreadNetworkDetailScreen extends StatelessWidget {
  const ThreadNetworkDetailScreen({required this.network, super.key});
  final ThreadNetworkInfo network;

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final fields = network.isConfigured && network.configuredHex != null
        ? ThreadTlvDecoder.decode(network.configuredHex!.replaceAll(RegExp(r'\s'), ''))
        : <({String label, String value})>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(network.networkName, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 10),
            child: SectionLabel('Border routers'),
          ),
          if (network.borderRouters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('No border routers discovered on this network',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            )
          else
            Card(
              child: Column(
                children: network.borderRouters.asMap().entries.map((e) {
                  final r    = e.value;
                  final last = e.key == network.borderRouters.length - 1;
                  return Column(children: [
                    ListTile(
                      leading: Icon(Icons.device_hub, color: cs.primary),
                      title: Text(
                        r.vendorName.isNotEmpty && r.modelName.isNotEmpty
                            ? '${r.vendorName} ${r.modelName}' : r.serviceName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: r.host.isNotEmpty || r.txt['tv'] != null
                          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (r.host.isNotEmpty)
                                Text('${r.host}:${r.port}',
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                              if (r.txt['tv'] != null)
                                Text('Thread ${r.txt['tv']}',
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                            ])
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute<void>(builder: (_) => ThreadBorderRouterDetailScreen(router: r))),
                    ),
                    if (!last) Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                  ]);
                }).toList(),
              ),
            ),
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 10), child: SectionLabel('Dataset')),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: fields.map((f) => _InfoPair(label: f.label, value: f.value)).toList(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _InfoPair extends StatelessWidget {
  const _InfoPair({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No-credentials empty state
// ─────────────────────────────────────────────────────────────────────────────

class NoCredentialsHint extends StatelessWidget {
  const NoCredentialsHint({required this.onAdd, super.key});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.memory_outlined, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 20),
          Text('No Thread credentials',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Add your Thread network credentials before commissioning Thread devices. '
            'You can import them from Android or enter the dataset hex manually.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Add credentials'), onPressed: onAdd),
        ]),
      ),
    );
  }
}
