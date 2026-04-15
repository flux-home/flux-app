import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/ui/widgets/info_row.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

/// locally-configured dataset that matches this PAN.
class _ThreadNetwork {
  // raw hex if isConfigured

  const _ThreadNetwork({
    required this.networkName,
    required this.extPanId,
    required this.borderRouters,
    required this.isConfigured,
    this.configuredHex,
  });
  final String networkName;
  final String extPanId; // from mDNS or decoded from dataset
  final List<ThreadBorderRouter> borderRouters;
  final bool isConfigured; // true if this matches the saved hex dataset
  final String? configuredHex;
}

class ThreadSettingsScreen extends StatefulWidget {
  const ThreadSettingsScreen({super.key});

  @override
  State<ThreadSettingsScreen> createState() => _ThreadSettingsScreenState();
}

class _ThreadSettingsScreenState extends State<ThreadSettingsScreen> {
  bool _scanning = false;
  List<_ThreadNetwork> _networks = [];
  bool _hasCachedData = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  /// On open: restore cached routers immediately, then let the user rescan.
  Future<void> _loadCached() async {
    final results = await Future.wait([ThreadSettingsService.load(), ThreadSettingsService.loadRouters()]);
    final savedHex = results[0] as String;
    final cached = results[1] as List<ThreadBorderRouter>;
    final networks = _buildNetworks(savedHex, cached);
    if (mounted) {
      setState(() {
        _networks = networks;
        _hasCachedData = cached.isNotEmpty;
      });
    }
  }

  /// Scan the network, persist results, refresh UI.
  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ThreadSettingsService.load(),
        context.read<MatterFabricPort>().discoverThreadNetworks(),
      ]);
      final savedHex = results[0] as String;
      final routers = results[1] as List<ThreadBorderRouter>;

      await ThreadSettingsService.saveRouters(routers);

      final networks = _buildNetworks(savedHex, routers);
      if (mounted) {
        setState(() {
          _networks = networks;
          _hasCachedData = true;
          _scanning = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _scanning = false;
        });
      }
    }
  }

  List<_ThreadNetwork> _buildNetworks(String savedHex, List<ThreadBorderRouter> routers) {
    final savedClean = savedHex.replaceAll(RegExp(r'\s'), '');
    final savedFields = ThreadTlvDecoder.decode(savedClean);
    String? savedName;
    String? savedXp;
    for (final f in savedFields) {
      if (f.label == 'Network Name') savedName = f.value;
      if (f.label == 'Ext PAN ID') savedXp = f.value;
    }

    final byName = <String, List<ThreadBorderRouter>>{};
    for (final r in routers) {
      byName.putIfAbsent(r.networkName, () => []).add(r);
    }

    final networks = <_ThreadNetwork>[];

    if (savedName != null) {
      final matchingRouters = byName.remove(savedName) ?? [];
      networks.add(
        _ThreadNetwork(
          networkName: savedName,
          extPanId: savedXp ?? '',
          borderRouters: matchingRouters,
          isConfigured: true,
          configuredHex: savedHex,
        ),
      );
    }

    for (final entry in byName.entries) {
      networks.add(
        _ThreadNetwork(
          networkName: entry.key,
          extPanId: entry.value.first.extPanId,
          borderRouters: entry.value,
          isConfigured: false,
        ),
      );
    }

    return networks;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Thread')),
      body: Column(
        children: [
          // ── Thread credentials button ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.key_outlined),
                label: const Text('Thread credentials'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const _ThreadCredentialsScreen()),
                ).then((_) => _loadCached()),
              ),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
            ),

          // ── Network list ────────────────────────────────────────────
          Expanded(
            child: _networks.isEmpty && !_scanning
                ? Center(
                    child: Text(
                      _hasCachedData
                          ? 'No Thread networks found'
                          : 'Tap "Scan for networks" to discover Thread networks',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _networks.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final net = _networks[i];
                      final cs2 = Theme.of(ctx).colorScheme;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.router_outlined,
                            color: net.isConfigured ? cs2.primary : cs2.onSurfaceVariant,
                          ),
                          title: Text(net.networkName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: net.borderRouters.isNotEmpty
                              ? Text(
                                  '${net.borderRouters.length} border router'
                                  '${net.borderRouters.length == 1 ? '' : 's'}',
                                  style: TextStyle(fontSize: 12, color: cs2.onSurfaceVariant),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (net.isConfigured)
                                Chip(
                                  label: const Text('Configured', style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: cs2.primaryContainer,
                                  labelStyle: TextStyle(color: cs2.onPrimaryContainer),
                                  side: BorderSide.none,
                                  padding: EdgeInsets.zero,
                                ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute<void>(builder: (_) => _ThreadNetworkScreen(network: net)),
                          ).then((_) => _loadCached()),
                        ),
                      );
                    },
                  ),
          ),

          // ── Scan button (bottom) ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _scanning ? null : _scan,
                child: _scanning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Scanning…'),
                        ],
                      )
                    : const Text('Scan for networks'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread credentials screen — configured dataset + Android credential store
// ---------------------------------------------------------------------------

class _ThreadCredentialsScreen extends StatefulWidget {
  const _ThreadCredentialsScreen();

  @override
  State<_ThreadCredentialsScreen> createState() => _ThreadCredentialsScreenState();
}

class _ThreadCredentialsScreenState extends State<_ThreadCredentialsScreen> {
  List<ThreadDataset> _datasets = [];
  ThreadDataset? _active;
  bool _loading = true;

  // Android import state
  bool _reading = false;
  bool _hasRead = false;
  List<ThreadDataset> _androidCreds = [];
  String? _readError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final results = await Future.wait([ThreadSettingsService.loadDatasets(), ThreadSettingsService.loadActive()]);
    if (mounted) {
      setState(() {
        _datasets = results[0]! as List<ThreadDataset>;
        _active = results[1] as ThreadDataset?;
        _loading = false;
      });
    }
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  Future<void> _selectDataset(ThreadDataset ds) async {
    await ThreadSettingsService.setActive(ds.hex);
    if (mounted) setState(() => _active = ds);
  }

  // ── Add / Edit ─────────────────────────────────────────────────────────────

  Future<void> _addDataset() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const _ThreadDatasetDetailScreen(initialHex: '', initialLabel: '', isNew: true),
      ),
    );
    await _reload();
  }

  Future<void> _editDataset(ThreadDataset ds) async {
    final isActive = _active == ds;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _ThreadDatasetDetailScreen(initialHex: ds.hex, initialLabel: ds.label, isActive: isActive),
      ),
    );
    await _reload();
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _deleteDataset(ThreadDataset ds) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete dataset'),
        content: Text('Remove "${ds.label}" from your credential set?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ThreadSettingsService.removeDataset(ds.hex);
      await _reload();
    }
  }

  // ── Android import ─────────────────────────────────────────────────────────

  Future<void> _readFromAndroid() async {
    setState(() {
      _reading = true;
      _readError = null;
      _androidCreds = [];
      _hasRead = false;
    });
    try {
      final hex = await context.read<MatterFabricPort>().readAndroidThreadCredentials();

      if (hex == null) {
        if (mounted) {
          setState(() {
            _readError = 'Failed to contact credential store';
            _reading = false;
            _hasRead = true;
          });
        }
        return;
      }
      if (hex.isEmpty) {
        if (mounted) {
          setState(() {
            _reading = false;
            _hasRead = true;
          });
        }
        return;
      }

      final name = ThreadTlvDecoder.networkName(hex) ?? hex.substring(0, 8.clamp(0, hex.length));
      if (mounted) {
        setState(() {
          _androidCreds = [ThreadDataset(label: name, hex: hex)];
          _reading = false;
          _hasRead = true;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _readError = e.toString();
          _reading = false;
          _hasRead = true;
        });
      }
    }
  }

  Future<void> _importFromAndroid(ThreadDataset ds) async {
    await ThreadSettingsService.addDataset(ds);
    await ThreadSettingsService.setActive(ds.hex);
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${ds.label}" imported and set as active')));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Thread credentials')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Credential set ─────────────────────────────────────
                const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 6), child: SectionLabel('Credential set')),

                // "Empty dataset" is always the first option.
                _DatasetTile(
                  dataset: ThreadDataset.empty,
                  isActive: _active?.isEmpty ?? false,
                  onSelect: () => _selectDataset(ThreadDataset.empty),
                ),

                if (_datasets.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ..._datasets.map(
                    (ds) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _DatasetTile(
                        dataset: ds,
                        isActive: _active == ds,
                        onSelect: () => _selectDataset(ds),
                        onEdit: () => _editDataset(ds),
                        onDelete: () => _deleteDataset(ds),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_outlined, size: 18),
                  label: const Text('Add dataset'),
                  onPressed: _addDataset,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),

                const SizedBox(height: 24),

                // ── Android credential store ───────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: SectionLabel('Android credential store'),
                ),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.android, color: cs.primary),
                        title: const Text('Read from Android'),
                        subtitle: const Text('Load Thread credentials stored by other apps'),
                        trailing: _reading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_outlined),
                        onTap: _reading ? null : _readFromAndroid,
                      ),

                      if (_readError != null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(_readError!, style: TextStyle(color: cs.error, fontSize: 12)),
                        ),
                      ],

                      if (_androidCreds.isNotEmpty) ...[
                        Divider(height: 1, color: cs.outlineVariant),
                        ..._androidCreds.map((c) {
                          final alreadySaved = _datasets.any((d) => d == c);
                          final isActive = _active == c;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isActive ? Icons.check_circle_outline : Icons.circle_outlined,
                              color: isActive ? cs.primary : cs.onSurfaceVariant,
                              size: 20,
                            ),
                            title: Text(c.label, style: const TextStyle(fontSize: 13)),
                            trailing: isActive
                                ? _activeChip(cs)
                                : alreadySaved
                                ? TextButton(onPressed: () => _selectDataset(c), child: const Text('Set active'))
                                : TextButton(onPressed: () => _importFromAndroid(c), child: const Text('Import')),
                          );
                        }),
                      ],

                      if (!_reading && _androidCreds.isEmpty && _readError == null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            _hasRead
                                ? 'Picker was cancelled or no credential was selected.'
                                : 'Tap "Read from Android" — a system picker will let you choose which Thread network to share.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _activeChip(ColorScheme cs) => Chip(
    label: const Text('Active', style: TextStyle(fontSize: 11)),
    visualDensity: VisualDensity.compact,
    backgroundColor: cs.primaryContainer,
    labelStyle: TextStyle(color: cs.onPrimaryContainer),
    side: BorderSide.none,
    padding: EdgeInsets.zero,
  );
}

// ── Dataset tile ──────────────────────────────────────────────────────────────

class _DatasetTile extends StatelessWidget {
  const _DatasetTile({
    required this.dataset,
    required this.isActive,
    required this.onSelect,
    this.onEdit,
    this.onDelete,
  });
  final ThreadDataset dataset;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final subtitle = dataset.isEmpty
        ? 'No credentials — device joins via MeshCoP'
        : dataset.hex.length > 24
        ? '${dataset.hex.substring(0, 24)}…'
        : dataset.hex;

    return Card(
      color: isActive ? cs.primaryContainer.withAlpha(80) : null,
      child: ListTile(
        leading: Icon(
          isActive ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isActive ? cs.primary : cs.onSurfaceVariant,
        ),
        title: Text(dataset.label, style: TextStyle(fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontFamily: dataset.isEmpty ? null : 'monospace', fontSize: 11, color: cs.onSurfaceVariant),
        ),
        trailing: dataset.isEmpty
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit',
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                    ),
                ],
              ),
        onTap: isActive ? null : onSelect,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread network detail — border routers + dataset
// ---------------------------------------------------------------------------

class _ThreadNetworkScreen extends StatelessWidget {
  const _ThreadNetworkScreen({required this.network});
  final _ThreadNetwork network;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          // ── Border routers ─────────────────────────────────────────────
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 6), child: SectionLabel('Border routers')),
          if (network.borderRouters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('No border routers discovered on this network', style: TextStyle(fontSize: 13)),
            )
          else
            Card(
              child: Column(
                children: network.borderRouters.asMap().entries.map((e) {
                  final r = e.value;
                  final last = e.key == network.borderRouters.length - 1;
                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.device_hub, color: cs.primary),
                        title: Text(
                          r.vendorName.isNotEmpty && r.modelName.isNotEmpty
                              ? '${r.vendorName} ${r.modelName}'
                              : r.serviceName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: r.host.isNotEmpty || r.txt['tv'] != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (r.host.isNotEmpty)
                                    Text(
                                      '${r.host}:${r.port}',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                    ),
                                  if (r.txt['tv'] != null)
                                    Text(
                                      'Thread ${r.txt['tv']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (_) => _BorderRouterDetailScreen(router: r)),
                        ),
                      ),
                      if (!last) Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                    ],
                  );
                }).toList(),
              ),
            ),

          // ── Dataset details (configured network only) ─────────────────
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 6), child: SectionLabel('Dataset')),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: fields.map((f) => InfoRow(label: f.label, value: f.value)).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _ThreadDatasetDetailScreen(initialHex: '', initialLabel: '', isNew: true),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit dataset'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Border router detail — all TXT record fields with descriptions
// ---------------------------------------------------------------------------

const _kTxtFieldInfo = <String, ({String name, String description})>{
  'rv': (name: 'Revision', description: 'The Thread version. Usually 1 or higher.'),
  'nn': (name: 'Network Name', description: 'Human-readable name of the Thread mesh.'),
  'xp': (name: 'Extended PAN ID', description: '64-bit hex ID that uniquely identifies this mesh.'),
  'tv': (name: 'Thread Version', description: 'Specific stack version (e.g. 1.3.0).'),
  'vn': (name: 'Vendor Name', description: 'Manufacturer of the border router device.'),
  'mn': (name: 'Model Name', description: 'Model of the border router device.'),
  'at': (name: 'Active Timestamp', description: '64-bit value ensuring all devices have the latest settings.'),
  'sq': (name: 'Sequence Number', description: 'Increments every time the network configuration changes.'),
  'sb': (name: 'State Bitmap', description: 'Connectivity and service flags for this border router.'),
  'bb': (name: 'BBR Sequence', description: 'Backbone Border Router sequence number.'),
  'dn': (name: 'Domain Name', description: 'Thread domain name (Thread 1.2+).'),
  'id': (name: 'Border Agent ID', description: '128-bit unique identifier for this border agent.'),
};

class _BorderRouterDetailScreen extends StatelessWidget {
  const _BorderRouterDetailScreen({required this.router});
  final ThreadBorderRouter router;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = router.vendorName.isNotEmpty && router.modelName.isNotEmpty
        ? '${router.vendorName} ${router.modelName}'
        : router.serviceName;

    // Build ordered field list: known fields first (in _kTxtFieldInfo order),
    // then any unknown keys alphabetically.
    final knownKeys = _kTxtFieldInfo.keys.toList();
    final unknownKeys = router.txt.keys.where((k) => !knownKeys.contains(k)).toList()..sort();
    final orderedKeys = [...knownKeys.where(router.txt.containsKey), ...unknownKeys];

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                router.host.isNotEmpty ? '${router.host}:${router.port}' : router.serviceName,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
      body: orderedKeys.isEmpty
          ? const Center(child: Text('No TXT record data available'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orderedKeys.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final key = orderedKeys[i];
                final val = router.txt[key] ?? '';
                final info = _kTxtFieldInfo[key];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Key badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            key,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (info != null) ...[
                                Text(info.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(info.description, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                const SizedBox(height: 6),
                              ],
                              SelectableText(
                                val.isNotEmpty ? val : '(empty)',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: val.isNotEmpty ? cs.primary : cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread dataset detail — all fields + hex editor
// ---------------------------------------------------------------------------

class _ThreadDatasetDetailScreen extends StatefulWidget {
  const _ThreadDatasetDetailScreen({
    required this.initialHex,
    required this.initialLabel,
    this.isNew = false,
    this.isActive = false,
  });
  final String initialHex;
  final String initialLabel;
  final bool isNew;
  final bool isActive;

  @override
  State<_ThreadDatasetDetailScreen> createState() => _ThreadDatasetDetailScreenState();
}

class _ThreadDatasetDetailScreenState extends State<_ThreadDatasetDetailScreen> {
  late TextEditingController _hexCtrl;
  late TextEditingController _labelCtrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _hexCtrl = TextEditingController(text: widget.initialHex);
    _labelCtrl = TextEditingController(text: widget.initialLabel);
    _hexCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final clean = _hexCtrl.text.replaceAll(RegExp(r'\s'), '');
    final name = _labelCtrl.text.trim().isNotEmpty
        ? _labelCtrl.text.trim()
        : ThreadTlvDecoder.networkName(clean) ??
              (clean.isNotEmpty ? clean.substring(0, 8.clamp(0, clean.length)) : 'Unnamed dataset');
    final updated = ThreadDataset(label: name, hex: clean);

    if (widget.isNew) {
      if (clean.isNotEmpty) await ThreadSettingsService.addDataset(updated);
    } else {
      await ThreadSettingsService.updateDataset(widget.initialHex.replaceAll(RegExp(r'\s'), ''), updated);
    }

    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thread dataset saved'), duration: Duration(seconds: 2)));
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cleanHex = _hexCtrl.text.replaceAll(RegExp(r'\s'), '');
    final fields = ThreadTlvDecoder.decode(cleanHex);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Add dataset' : 'Edit dataset'),
        actions: [
          IconButton(icon: Icon(_saved ? Icons.check : Icons.save_outlined), tooltip: 'Save', onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Name ──────────────────────────────────────────────────────
          const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 6), child: SectionLabel('Name')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _labelCtrl,
                decoration: InputDecoration(
                  labelText: 'Dataset name',
                  hintText: 'e.g. Home Thread Network',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  helperText: 'Leave blank to use the name decoded from the TLV',
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Decoded fields ─────────────────────────────────────────────
          if (fields.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 6), child: SectionLabel('Decoded fields')),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: fields.map((f) => InfoRow(label: f.label, value: f.value)).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Hex input ──────────────────────────────────────────────────
          const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 6), child: SectionLabel('Hex (TLV)')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Operational dataset',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        tooltip: 'Copy hex',
                        visualDensity: VisualDensity.compact,
                        onPressed: cleanHex.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(ClipboardData(text: cleanHex));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Dataset copied'), duration: Duration(seconds: 1)),
                                );
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _hexCtrl,
                    maxLines: null,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 0.5),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: 'Paste hex dataset…',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                    ),
                    keyboardType: TextInputType.multiline,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F\s]'))],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (!widget.isNew)
            OutlinedButton.icon(
              onPressed: () async {
                _hexCtrl.text = ThreadSettingsService.defaultDataset;
                _labelCtrl.text = '';
                await _save();
              },
              icon: const Icon(Icons.restore),
              label: const Text('Reset to default (NEST-PAN-26BA)'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
