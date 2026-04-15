import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/matter_device.dart';
import '../../models/ota_progress.dart';
import '../widgets/dot_matrix_painter.dart';
import '../../providers/device_provider.dart';
import '../../services/dcl_service.dart';
import '../../services/matter_port.dart';
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

  Future<void> _identify(MatterDevice d) async {    if (_identifying) return;
    setState(() => _identifying = true);
    await context.read<MatterClusterPort>().identify(d.nodeId);
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

              // ── Software updates ─────────────────────────────────────────
              _OtaSection(device: d),

              // ── Network type ──────────────────────────────────────────────
              if (d.networkType != NetworkType.unknown) ...[
                const SectionLabel('Network'),
                Card(
                  color: cs.surface,
                  child: ListTile(
                    leading: Icon(
                      switch (d.networkType) {
                        NetworkType.wifi     => Icons.wifi,
                        NetworkType.thread   => Icons.memory_outlined,
                        NetworkType.ethernet => Icons.settings_ethernet,
                        NetworkType.unknown  => Icons.device_unknown_outlined,
                      },
                      color: cs.primary,
                    ),
                    title: Text(d.networkType.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(switch (d.networkType) {
                      NetworkType.wifi     => 'IEEE 802.11 Wi-Fi',
                      NetworkType.thread   => 'IEEE 802.15.4 Thread mesh',
                      NetworkType.ethernet => 'Ethernet / IP',
                      NetworkType.unknown  => '',
                    }),
                  ),
                ),
                const SizedBox(height: 20),
              ],

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
// OTA update section
// ─────────────────────────────────────────────────────────────────────────────

enum _OtaCheckState { idle, checking, upToDate, updateAvailable, noOtaUrl, missingInfo, error }

class _OtaSection extends StatefulWidget {
  final MatterDevice device;
  const _OtaSection({required this.device});

  @override
  State<_OtaSection> createState() => _OtaSectionState();
}

class _OtaSectionState extends State<_OtaSection> {
  _OtaCheckState   _check        = _OtaCheckState.idle;
  DclUpdateResult? _result;
  String           _errorMessage = '';
  bool             _flashing     = false;
  bool             _dryRun       = true;   // safe default

  @override
  void initState() {
    super.initState();
    // Restore in-progress OTA if we navigated away mid-update.
    final progress = context.read<DeviceProvider>().otaProgressFor(widget.device.id);
    if (progress != null) {
      _flashing = true;
    } else {
      // Auto-check DCL as soon as the widget is live.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runCheck();
      });
    }
  }

  static int? _parseHexId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = (raw.startsWith('0x') || raw.startsWith('0X')) ? raw.substring(2) : raw;
    return int.tryParse(s, radix: 16);
  }

  Future<void> _runCheck() async {
    final view = context.read<DeviceProvider>().viewFor(widget.device.id);
    final vid  = _parseHexId(view?.vendorId);
    final pid  = _parseHexId(view?.productId);
    final cur  = view?.softwareVersionNum;
    if (vid == null || pid == null || cur == null) {
      setState(() => _check = _OtaCheckState.missingInfo);
      return;
    }
    setState(() { _check = _OtaCheckState.checking; _result = null; _errorMessage = ''; });
    try {
      final r = await DclService().checkForUpdate(vid: vid, pid: pid, currentVersion: cur);
      if (!mounted) return;
      setState(() {
        _result = r;
        if (!r.isUpdateAvailable)    _check = _OtaCheckState.upToDate;
        else if (r.otaUrl.isEmpty)   _check = _OtaCheckState.noOtaUrl;
        else                         _check = _OtaCheckState.updateAvailable;
      });
    } on DclNotFoundError {
      if (mounted) setState(() { _check = _OtaCheckState.error; _errorMessage = 'Device not found in DCL'; });
    } on DclNetworkError catch (e) {
      if (mounted) setState(() { _check = _OtaCheckState.error; _errorMessage = e.message; });
    } catch (e) {
      if (mounted) setState(() { _check = _OtaCheckState.error; _errorMessage = e.toString(); });
    }
  }

  Future<void> _startFlash() async {
    final r = _result;
    if (r == null || r.otaUrl.isEmpty) return;
    context.read<DeviceProvider>().clearOtaProgress(widget.device.id);
    setState(() => _flashing = true);
    final ok = await context.read<MatterFabricPort>().downloadAndFlash(
      nodeId:              widget.device.nodeId,
      otaUrl:              r.otaUrl,
      targetVersion:       r.latestVersion ?? 0,
      targetVersionString: r.latestVersionString ?? '',
      dryRun:              _dryRun,
      endpoint:            context.read<DeviceProvider>()
                               .viewFor(widget.device.id)?.otaEndpoint ?? 0,
    );
    if (!ok && mounted) setState(() => _flashing = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final view     = provider.viewFor(widget.device.id);
    if (view?.otaSupported != true) return const SizedBox.shrink();

    final otaProgress = _flashing ? provider.otaProgressFor(widget.device.id) : null;

    // Clear terminal state once shown so it doesn't reappear on next visit.
    if (_flashing && otaProgress?.isTerminal == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          provider.clearOtaProgress(widget.device.id);
          setState(() => _flashing = false);
        }
      });
    }

    final cs             = Theme.of(context).colorScheme;
    final currentVersion = view?.softwareVersion ?? '';
    final newVersion     = _result?.latestVersionString ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Software Version'),
        Card(
          color: cs.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Version header ──────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current version',
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                          const SizedBox(height: 3),
                          Text(
                            currentVersion.isNotEmpty ? currentVersion : '—',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ),
                    // Right-side status indicator
                    if (_check == _OtaCheckState.checking)
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cs.primary),
                      )
                    else if (_check == _OtaCheckState.upToDate)
                      Icon(Icons.check_circle_outline,
                          size: 18, color: Colors.green.shade400)
                    else if (_check == _OtaCheckState.error)
                      GestureDetector(
                        onTap: _runCheck,
                        child: Icon(Icons.warning_amber_outlined,
                            size: 18, color: Colors.orange.shade400),
                      )
                    else if (!_flashing &&
                        (_check == _OtaCheckState.upToDate ||
                         _check == _OtaCheckState.noOtaUrl))
                      GestureDetector(
                        onTap: _runCheck,
                        child: Icon(Icons.refresh,
                            size: 18, color: cs.onSurfaceVariant),
                      ),
                  ],
                ),

                // ── Error message (below version) ───────────────────────────
                if (_check == _OtaCheckState.error) ...[
                  const SizedBox(height: 4),
                  Text(_errorMessage,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],

                // ── Missing info ────────────────────────────────────────────
                if (_check == _OtaCheckState.missingInfo) ...[
                  const SizedBox(height: 4),
                  Text('Open the device screen first to load version info',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],

                // ── No OTA URL ──────────────────────────────────────────────
                if (!_flashing && _check == _OtaCheckState.noOtaUrl) ...[
                  const SizedBox(height: 6),
                  Text(
                    newVersion.isNotEmpty
                        ? '$newVersion available — no download URL in DCL'
                        : 'Update available — no download URL in DCL',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],

                // ── Upgrade button or in-progress display ───────────────────
                if (_flashing) ...[
                  const SizedBox(height: 16),
                  _buildProgress(context, cs, otaProgress),
                ] else if (_check == _OtaCheckState.updateAvailable) ...[
                  const SizedBox(height: 14),
                  // Dry-run toggle
                  Row(
                    children: [
                      Expanded(
                        child: Text('Dry run',
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant)),
                      ),
                      Switch.adaptive(
                          value: _dryRun,
                          onChanged: (v) => setState(() => _dryRun = v)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _startFlash,

                    child: Text(
                      newVersion.isNotEmpty
                          ? 'Upgrade to $newVersion'
                          : 'Upgrade',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProgress(BuildContext context, ColorScheme cs, OtaProgressState? p) {
    final phase    = p?.phase ?? 'download';
    final progress = p?.progress;

    final glyphText = progress != null ? '$progress%' : '--';

    final litColor = switch (phase) {
      'complete' => Colors.green.shade400,
      'dryrun'   => Colors.blue.shade400,
      'error'    => Colors.orange.shade400,
      _          => Colors.white,
    };

    final (String title, String subtitle) = switch (phase) {
      'download'   => ('Downloading',      'Fetching firmware from DCL'),
      'querying'   => ('Waiting',          'Device is querying the provider'),
      'installing' => ('Installing',       'Transferring firmware to device'),
      'applying'   => ('Applying',         'Device is installing the image'),
      'dryrun'     => ('Dry run complete', 'Transfer succeeded — apply skipped'),
      'complete'   => ('Update complete',  'Device will reboot shortly'),
      'error'      => ('Update failed',    p?.message ?? 'Unknown error'),
      _            => ('Updating',         ''),
    };

    final showCancel = phase != 'complete' && phase != 'dryrun' && phase != 'error';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dot-matrix percentage / status
        SizedBox(
          height: 56,
          child: CustomPaint(
            painter: DotMatrixPainter(
              text:     glyphText,
              litColor: litColor,
              dimColor: Colors.white12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        if (showCancel) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              await context.read<MatterFabricPort>().cancelOta();
              if (mounted) setState(() => _flashing = false);
            },

            child: const Text('Cancel'),
          ),
        ],
      ],
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
    final view = context.watch<DeviceProvider>().viewFor(device.id);

    // Helper: only show a row if the value is non-null and non-empty.
    List<Widget> rows = [];
    void add(String label, String? value, {bool mono = false, bool link = false}) {
      if (value == null || value.isEmpty) return;
      rows.add(InfoRow(label: label, value: value, mono: mono, link: link));
    }

    // ── Identity ───────────────────────────────────────────────────────
    add('Product',    view?.displayProductName);
    add('Vendor',     view?.vendorName);
    add('Vendor ID',  view?.vendorId,  mono: true);
    add('Product ID', view?.productId, mono: true);
    add('Part no.',   view?.partNumber);

    // ── Versions ───────────────────────────────────────────────────────
    add('Hardware',   view?.hwVersion);
    add('Firmware',   view?.softwareVersion);

    // ── Manufacturing ──────────────────────────────────────────────────
    add('Mfg. date',  view?.manufacturingDate);

    // ── Device type / node ─────────────────────────────────────────────
    add('Type',       device.deviceType.displayName);
    add('Network',    device.networkType == NetworkType.unknown
        ? null : device.networkType.label);
    add('Node ID',
        '0x${device.nodeId.toRadixString(16).padLeft(16, '0').toUpperCase()}',
        mono: true);
    add('Commissioned', _formatDate(device.commissionedAt));

    // ── Identifiers ────────────────────────────────────────────────────
    add('Serial no.', view?.serialNumber, mono: true);
    add('Unique ID',  view?.uniqueId,     mono: true);

    // ── Links ──────────────────────────────────────────────────────────
    add('Product URL', view?.productUrl, link: true);

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


