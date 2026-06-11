import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/matter_channel.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/ui/widgets/info_row.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _ThreadNetwork {
  const _ThreadNetwork({
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

// ── Main screen ───────────────────────────────────────────────────────────────

class ThreadSettingsScreen extends StatefulWidget {
  const ThreadSettingsScreen({super.key});

  @override
  State<ThreadSettingsScreen> createState() => _ThreadSettingsScreenState();
}

class _ThreadSettingsScreenState extends State<ThreadSettingsScreen> {
  bool _loading = true;
  bool _scanning = false;
  ThreadDataset? _active;
  List<ThreadDataset> _datasets = [];
  List<_ThreadNetwork> _networks = [];
  List<ThreadBorderRouter> _routersCache = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadThenScan();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  /// Loads persisted data instantly, then fires a background scan.
  Future<void> _loadThenScan() async {
    setState(() { _loading = true; _error = null; });

    final datasets = await ThreadSettingsService.loadDatasets();
    final active   = await ThreadSettingsService.loadActive();
    final savedHex = await ThreadSettingsService.load();
    final cached   = await ThreadSettingsService.loadRouters();

    if (mounted) {
      setState(() {
        _datasets      = datasets;
        _active        = active;
        _routersCache  = cached;
        _networks      = _buildNetworks(savedHex, cached);
        _loading       = false;
        _scanning      = true;
      });
    }

    await _runScan();
  }

  Future<void> _runScan() async {
    setState(() { _scanning = true; _error = null; });
    try {
      final results = await Future.wait([
        ThreadSettingsService.load(),
        // Thread border router discovery is local phone mDNS (_meshcop._udp)
        // — always use MatterChannel regardless of controller mode.
        context.read<MatterChannel>().discoverThreadNetworks(),
      ]);
      final savedHex = results[0] as String;
      final routers  = results[1] as List<ThreadBorderRouter>;
      await ThreadSettingsService.saveRouters(routers);
      if (mounted) {
        setState(() {
          _routersCache = routers;
          _networks     = _buildNetworks(savedHex, routers);
          _scanning     = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) setState(() { _scanning = false; _error = e.toString(); });
    }
  }

  Future<void> _reload() async {
    final datasets = await ThreadSettingsService.loadDatasets();
    final active   = await ThreadSettingsService.loadActive();
    final savedHex = await ThreadSettingsService.load();
    if (!mounted) return;
    setState(() {
      _datasets = datasets;
      _active   = active;
      _networks = _buildNetworks(savedHex, _routersCache);
    });
  }

  List<_ThreadNetwork> _buildNetworks(String savedHex, List<ThreadBorderRouter> routers) {
    final savedClean = savedHex.replaceAll(RegExp(r'\s'), '');
    final savedFields = ThreadTlvDecoder.decode(savedClean);
    String? savedName;
    String? savedXp;
    for (final f in savedFields) {
      if (f.label == 'Network Name') savedName = f.value;
      if (f.label == 'Ext PAN ID')   savedXp   = f.value;
    }

    final byName = <String, List<ThreadBorderRouter>>{};
    for (final r in routers) {
      byName.putIfAbsent(r.networkName, () => []).add(r);
    }

    final networks = <_ThreadNetwork>[];

    if (savedName != null) {
      final matchingRouters = byName.remove(savedName) ?? [];
      networks.add(_ThreadNetwork(
        networkName:    savedName,
        extPanId:       savedXp ?? '',
        borderRouters:  matchingRouters,
        isConfigured:   true,
        configuredHex:  savedHex,
      ));
    }

    for (final entry in byName.entries) {
      networks.add(_ThreadNetwork(
        networkName:   entry.key,
        extPanId:      entry.value.first.extPanId,
        borderRouters: entry.value,
        isConfigured:  false,
      ));
    }

    return networks;
  }

  // ── Dataset actions ───────────────────────────────────────────────────────

  Future<void> _selectDataset(ThreadDataset ds) async {
    await ThreadSettingsService.setActive(ds.hex);
    await _reload();
  }


  // ── OS import ─────────────────────────────────────────────────────────────

  Future<void> _importFromOs() async {
    try {
      final hex = await context.read<MatterChannel>().readSystemThreadCredentials();
      if (!mounted || hex == null || hex.isEmpty) return;
      final name = ThreadTlvDecoder.networkName(hex) ?? hex.substring(0, 8.clamp(0, hex.length));
      final ds   = ThreadDataset(label: name, hex: hex);
      await ThreadSettingsService.addDataset(ds);
      await ThreadSettingsService.setActive(ds.hex);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" imported and set as active')),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'PLAY_SERVICES_UNAVAILABLE'
          ? 'Google Play Services is not available. Enter your Thread dataset manually.'
          : 'Import failed: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final allNets = _networks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread'),
        actions: [
          IconButton(
            icon: _scanning
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_outlined),
            tooltip: 'Scan',
            onPressed: _scanning ? null : _runScan,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon:  const Icon(Icons.add),
        label: const Text('Add credentials'),
        onPressed: () => _showAddCredentials(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _datasets.isEmpty
          ? _NoCredentialsHint(onAdd: () => _showAddCredentials(context))
          : allNets.isEmpty
          ? Center(
              child: Text(
                _error != null
                    ? 'Scan failed: $_error'
                    : _scanning
                    ? 'Scanning for Thread networks…'
                    : 'No Thread networks found.\nTap ↻ to scan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: allNets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final net = allNets[i];
                return Card(
                  child: ListTile(
                    leading: net.isConfigured
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF34A853))
                        : Icon(Icons.router_outlined, color: cs.onSurfaceVariant),
                    title: Text(
                      net.networkName,
                      style: TextStyle(
                        fontWeight: net.isConfigured ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${net.borderRouters.length} border router'
                      '${net.borderRouters.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute<void>(
                        builder: (_) => net.isConfigured
                            ? _ActiveNetworkDetailScreen(
                                active:   _active!,
                                network:  net,
                                scanning: _scanning,
                              )
                            : _ThreadNetworkScreen(network: net),
                      ),
                    ).then((_) => _reload()),
                  ),
                );
              },
            ),
    );
  }

  // ── Add credentials bottom sheet ────────────────────────────────────────────

  Future<void> _showAddCredentials(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: SectionLabel('Add Thread Credentials'),
              ),
              FilledButton.icon(
                icon:  const Icon(Icons.download_rounded, size: 18),
                label: const Text('Import from OS Thread Network'),
                onPressed: () {
                  Navigator.pop(context);
                  _importFromOs();
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon:  const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Add manually'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const _ThreadDatasetDetailScreen(
                        initialHex:   '',
                        initialLabel: '',
                        isNew:        true,
                      ),
                    ),
                  ).then((_) => _reload());
                },
              ),
              if (_datasets.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: SectionLabel('Saved datasets'),
                ),
                ..._datasets.map(
                  (ds) => ListTile(
                    dense: true,
                    leading: Icon(
                      _active == ds
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_off,
                      color: _active == ds
                          ? const Color(0xFF34A853)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    title: Text(ds.label, style: const TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      _selectDataset(ds);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── No-credentials empty state ───────────────────────────────────────────────

class _NoCredentialsHint extends StatelessWidget {
  const _NoCredentialsHint({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.memory_outlined, size: 56,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              'No Thread credentials',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your Thread network credentials before commissioning '
              'Thread devices. You can import them from Android or enter '
              'the dataset hex manually.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              icon:  const Icon(Icons.add),
              label: const Text('Add credentials'),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active network detail ────────────────────────────────────────────────────

/// Detail screen for the active Thread network — shows Dataset and Border Routers.
class _ActiveNetworkDetailScreen extends StatefulWidget {
  const _ActiveNetworkDetailScreen({
    required this.active,
    required this.scanning,
    this.network,
  });
  final ThreadDataset    active;
  final _ThreadNetwork?  network;
  final bool             scanning;

  @override
  State<_ActiveNetworkDetailScreen> createState() =>
      _ActiveNetworkDetailScreenState();
}

class _ActiveNetworkDetailScreenState
    extends State<_ActiveNetworkDetailScreen> {
  bool _pushing = false;

  Future<void> _pushToController() async {
    final svc = context.read<HubConnection>().service;
    if (svc == null) return;

    final hex = widget.active.hex.replaceAll(RegExp(r'\s'), '');
    if (hex.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No dataset to push (empty dataset)')),
      );
      return;
    }

    setState(() => _pushing = true);
    try {
      final bytes = List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      );
      final ok = await svc.postThreadDataset(
        Uint8List.fromList(bytes),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Thread dataset pushed to controller ✓'
            : 'Push failed — check controller logs'),
      ));
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _pushing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final svc = context.watch<HubConnection>().service;
    final active  = widget.active;
    final network  = widget.network;
    final scanning  = widget.scanning;

    return Scaffold(
      appBar: AppBar(
        title: Text(active.label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Dataset — nav tile ───────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Icon(Icons.key_outlined, color: cs.onSurfaceVariant),
              title: const Text('Dataset'),
              subtitle: Text(
                active.label,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => _ThreadDatasetDetailScreen(
                    initialHex:   active.hex,
                    initialLabel: active.label,
                    isActive:     true,
                  ),
                ),
              ),
            ),
          ),

          // ── Push to Controller ──────────────────────────────────────────
          if (svc != null && !active.isEmpty) ...[  // only in controller mode
            const SizedBox(height: 4),
            Card(
              child: ListTile(
                leading: _pushing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.upload_outlined, color: cs.primary),
                title: const Text('Push to Controller'),
                subtitle: const Text(
                    'Store this dataset on the Flux Controller'),
                onTap: _pushing ? null : _pushToController,
              ),
            ),
          ],

          const SizedBox(height: 4),

          // ── Border Routers ───────────────────────────────────────────────
          Card(
            child: network == null || network!.borderRouters.isEmpty
                ? ListTile(
                    leading: Icon(
                      scanning ? Icons.sync : Icons.wifi_find_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                    title: Text(
                      scanning ? 'Scanning…' : 'Not detected on local network',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : Column(
                    children: network!.borderRouters.asMap().entries.map((e) {
                      final r    = e.value;
                      final last = e.key == network!.borderRouters.length - 1;
                      final name = r.vendorName.isNotEmpty && r.modelName.isNotEmpty
                          ? '${r.vendorName} ${r.modelName}'
                          : r.serviceName;
                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.device_hub, color: cs.primary),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: r.txt['tv'] != null
                                ? Text(
                                    'Thread ${r.txt['tv']}',
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                  )
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => _BorderRouterDetailScreen(router: r),
                              ),
                            ),
                          ),
                          if (!last)
                            Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                        ],
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Thread network detail ─────────────────────────────────────────────────────

class _ThreadNetworkScreen extends StatelessWidget {
  const _ThreadNetworkScreen({required this.network});
  final _ThreadNetwork network;

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

          // ── Border routers ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 10),
            child: SectionLabel('Border routers'),
          ),
          if (network.borderRouters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'No border routers discovered on this network',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            )
          else
            Card(
              child: Column(
                children: network.borderRouters.asMap().entries.map((e) {
                  final r    = e.value;
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
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (r.txt['tv'] != null)
                                    Text(
                                      'Thread ${r.txt['tv']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => _BorderRouterDetailScreen(router: r),
                          ),
                        ),
                      ),
                      if (!last)
                        Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                    ],
                  );
                }).toList(),
              ),
            ),

          // ── Dataset fields ─────────────────────────────────────────
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: SectionLabel('Dataset'),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: fields.map((f) => InfoRow(label: f.label, value: f.value)).toList(),
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

// ── Border router detail ──────────────────────────────────────────────────────

const _kTxtFieldInfo = <String, ({String name, String description})>{
  'rv': (name: 'Revision',         description: 'The Thread version. Usually 1 or higher.'),
  'nn': (name: 'Network Name',     description: 'Human-readable name of the Thread mesh.'),
  'xp': (name: 'Extended PAN ID',  description: '64-bit hex ID that uniquely identifies this mesh.'),
  'tv': (name: 'Thread Version',   description: 'Specific stack version (e.g. 1.3.0).'),
  'vn': (name: 'Vendor Name',      description: 'Manufacturer of the border router device.'),
  'mn': (name: 'Model Name',       description: 'Model of the border router device.'),
  'at': (name: 'Active Timestamp', description: '64-bit value ensuring all devices have the latest settings.'),
  'sq': (name: 'Sequence Number',  description: 'Increments every time the network configuration changes.'),
  'sb': (name: 'State Bitmap',     description: 'Connectivity and service flags for this border router.'),
  'bb': (name: 'BBR Sequence',     description: 'Backbone Border Router sequence number.'),
  'dn': (name: 'Domain Name',      description: 'Thread domain name (Thread 1.2+).'),
  'id': (name: 'Border Agent ID',  description: '128-bit unique identifier for this border agent.'),
};

class _BorderRouterDetailScreen extends StatelessWidget {
  const _BorderRouterDetailScreen({required this.router});
  final ThreadBorderRouter router;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final title = router.vendorName.isNotEmpty && router.modelName.isNotEmpty
        ? '${router.vendorName} ${router.modelName}'
        : router.serviceName;

    final knownKeys   = _kTxtFieldInfo.keys.toList();
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
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
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
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final key  = orderedKeys[i];
                final val  = router.txt[key] ?? '';
                final info = _kTxtFieldInfo[key];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:        cs.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            key,
                            style: TextStyle(
                              fontFamily:  'monospace',
                              fontSize:    12,
                              fontWeight:  FontWeight.bold,
                              color:       cs.onPrimaryContainer,
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
                                  fontFamily:  'monospace',
                                  fontSize:    13,
                                  fontWeight:  FontWeight.w500,
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

// ── Thread dataset detail ─────────────────────────────────────────────────────

class _ThreadDatasetDetailScreen extends StatefulWidget {
  const _ThreadDatasetDetailScreen({
    required this.initialHex,
    required this.initialLabel,
    this.isNew    = false,
    this.isActive = false,
  });
  final String initialHex;
  final String initialLabel;
  final bool   isNew;
  final bool   isActive;

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
    _hexCtrl   = TextEditingController(text: widget.initialHex);
    _labelCtrl = TextEditingController(text: widget.initialLabel);
    _hexCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete dataset?'),
        content: Text(
          widget.isActive
              ? '"${widget.initialLabel}" is your active dataset. '
                'Deleting it will clear the active selection and '
                'Thread commissioning will require new credentials.'
              : 'Delete "${widget.initialLabel}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      await ThreadSettingsService.removeDataset(
          widget.initialHex.replaceAll(RegExp(r'\s'), ''));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final clean = _hexCtrl.text.replaceAll(RegExp(r'\s'), '');
    final name  = _labelCtrl.text.trim().isNotEmpty
        ? _labelCtrl.text.trim()
        : ThreadTlvDecoder.networkName(clean) ??
              (clean.isNotEmpty ? clean.substring(0, 8.clamp(0, clean.length)) : 'Unnamed dataset');
    final updated = ThreadDataset(label: name, hex: clean);

    if (widget.isNew) {
      if (clean.isNotEmpty) await ThreadSettingsService.addDataset(updated);
    } else {
      await ThreadSettingsService.updateDataset(
        widget.initialHex.replaceAll(RegExp(r'\s'), ''),
        updated,
      );
    }

    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thread dataset saved'), duration: Duration(seconds: 2)),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final cleanHex = _hexCtrl.text.replaceAll(RegExp(r'\s'), '');
    final fields   = ThreadTlvDecoder.decode(cleanHex);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Add dataset' : 'Edit dataset'),
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete dataset',
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: Icon(_saved ? Icons.check : Icons.save_outlined),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Name ──────────────────────────────────────────────────
          const Padding(padding: EdgeInsets.fromLTRB(4, 4, 4, 10), child: SectionLabel('Name')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _labelCtrl,
                decoration: InputDecoration(
                  labelText:   'Dataset name',
                  hintText:    'e.g. Home Thread Network',
                  border:      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled:      true,
                  fillColor:   cs.surfaceContainerHighest,
                  helperText:  'Leave blank to use the name decoded from the TLV',
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Decoded fields ─────────────────────────────────────────
          if (fields.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 10), child: SectionLabel('Decoded fields')),
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

          // ── Hex input ──────────────────────────────────────────────
          const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 10), child: SectionLabel('Hex (TLV)')),
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
                                  const SnackBar(
                                    content:  Text('Dataset copied'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _hexCtrl,
                    maxLines:   null,
                    style: const TextStyle(
                      fontFamily:   'monospace',
                      fontSize:     12,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      border:    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText:  'Paste hex dataset…',
                      filled:    true,
                      fillColor: cs.surfaceContainerHighest,
                    ),
                    keyboardType:      TextInputType.multiline,
                    inputFormatters:   [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F\s]'))],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
