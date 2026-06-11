import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/fabric_descriptor.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/ota_progress.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/switch_group.dart';
import 'package:collection/collection.dart';
import 'package:matter_home/services/cluster_parser.dart';
import 'package:matter_home/services/dcl_service.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/ui/screens/cluster_inspector_screen.dart';
import 'package:matter_home/ui/screens/thread_diag_screen.dart';
import 'package:matter_home/ui/widgets/dot_matrix_painter.dart';
import 'package:matter_home/ui/widgets/info_row.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main settings screen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({required this.device, super.key});
  final MatterDevice device;

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  bool _identifying = false;

  Future<void> _identify(MatterDevice d) async {
    if (_identifying) return;
    setState(() => _identifying = true);
    await context.read<MatterClusterPort>().identify(d.nodeId);
    await Future<void>.delayed(const Duration(seconds: 15));
    if (mounted) setState(() => _identifying = false);
  }

  Future<void> _shareDevice(BuildContext context, MatterDevice d) async {
    final view      = context.read<DeviceProvider>().viewFor(d.id);
    final vendorId  = _parseHexId(view?.vendorId)  ?? 0;
    final productId = _parseHexId(view?.productId) ?? 0;
    final port      = context.read<MatterFabricPort>();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ShareBottomSheet(
        device: d,
        vendorId: vendorId,
        productId: productId,
        port: port,
      ),
    );
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
    if ((confirmed ?? false) && context.mounted) {
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
          decoration: const InputDecoration(labelText: 'Device name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
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
            title: const Text('Device settings', style: TextStyle(fontWeight: FontWeight.bold)),
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
              // ── Identify + Share buttons ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _identifying ? null : () => _identify(d),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _identifying
                                ? const SizedBox(
                                    key: ValueKey('spinner'),
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.lightbulb_outline,
                                    key: ValueKey('icon'), size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(_identifying ? 'Identifying…' : 'Identify'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _shareDevice(context, d),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Share'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Room ─────────────────────────────────────────────────────────
              const SectionLabel('Room'),
              _RoomTile(device: d),
              const SizedBox(height: 20),

              // ── Software updates ────────────────────────────────────────────
              _OtaSection(device: d),

              // ── Tools ─────────────────────────────────────────────────────
              // ── Battery ───────────────────────────────────────────────────────────
              if (context.watch<DeviceProvider>().viewFor(d.id)?.batteryInfo
                  case final BatteryInfo bat when bat.hasData) ...[
                const SectionLabel('Battery'),
                _BatteryCard(battery: bat),
                const SizedBox(height: 20),
              ],

              // ── Linked devices ────────────────────────────────────────────
              if (d.deviceType.isSwitch || d.deviceType == DeviceType.contactSensor) ...[
                const SectionLabel('Linked devices'),
                _AutomationsSummaryTile(device: d),
                const SizedBox(height: 20),
              ],

              const SectionLabel('Tools'),
              Card(
                color: cs.surface,
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: cs.primary),
                  title: const Text('Device info'),
                  subtitle: const Text('Type, node ID, hardware, clusters'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DeviceInfoScreen(device: d),
                    ),
                  ),
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
// Room tile + picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.device});
  final MatterDevice device;

  Future<void> _showSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _RoomPickerSheet(deviceId: device.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final d        = provider.findById(device.id) ?? device;
    final rooms    = provider.rooms;
    final room     = rooms.firstWhere(
      (r) => r.id == d.roomId,
      orElse: () => rooms.first,
    );

    return Card(
      color: cs.surface,
      child: ListTile(
        leading: Icon(Icons.meeting_room_outlined, color: cs.primary),
        title: Text(room.name),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        onTap: () => _showSheet(context),
      ),
    );
  }
}

class _RoomPickerSheet extends StatefulWidget {
  const _RoomPickerSheet({required this.deviceId});
  final String deviceId;

  @override
  State<_RoomPickerSheet> createState() => _RoomPickerSheetState();
}

class _RoomPickerSheetState extends State<_RoomPickerSheet> {
  Future<void> _createRoom(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New room'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Room name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final room = await context.read<DeviceProvider>().createRoom(name);
    if (!context.mounted) return;
    await context.read<DeviceProvider>().assignRoom(widget.deviceId, room.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final device   = provider.findById(widget.deviceId);
    final rooms    = provider.rooms;
    final currentRoomId = device?.roomId ?? rooms.first.id;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'Room',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final room in rooms)
                  RadioListTile<String>(
                    value:      room.id,
                    groupValue: currentRoomId,
                    secondary:  Icon(
                      Icons.meeting_room_outlined,
                      color: room.id == currentRoomId
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    title: Text(room.name),
                    onChanged: (_) async {
                      await provider.assignRoom(widget.deviceId, room.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.add_circle_outline, color: cs.primary),
                  title: Text(
                    'New room',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => _createRoom(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTA update section
// ─────────────────────────────────────────────────────────────────────────────

enum _OtaCheckState { idle, checking, upToDate, updateAvailable, noOtaUrl, missingInfo, error }

class _OtaSection extends StatefulWidget {
  const _OtaSection({required this.device});
  final MatterDevice device;

  @override
  State<_OtaSection> createState() => _OtaSectionState();
}

class _OtaSectionState extends State<_OtaSection> {
  _OtaCheckState _check = _OtaCheckState.idle;
  DclUpdateResult? _result;
  String _errorMessage = '';
  bool _flashing = false;

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
    final vid = _parseHexId(view?.vendorId);
    final pid = _parseHexId(view?.productId);
    final cur = view?.softwareVersionNum;
    if (vid == null || pid == null || cur == null) {
      setState(() => _check = _OtaCheckState.missingInfo);
      return;
    }
    setState(() {
      _check = _OtaCheckState.checking;
      _result = null;
      _errorMessage = '';
    });
    try {
      final r = await DclService().checkForUpdate(vid: vid, pid: pid, currentVersion: cur);
      if (!mounted) return;
      setState(() {
        _result = r;
        if (!r.isUpdateAvailable) {
          _check = _OtaCheckState.upToDate;
        } else if (r.otaUrl.isEmpty) {
          _check = _OtaCheckState.noOtaUrl;
        } else {
          _check = _OtaCheckState.updateAvailable;
        }
      });
    } on DclNotFoundError {
      if (mounted) {
        setState(() {
          _check = _OtaCheckState.error;
          _errorMessage = 'Device not found in DCL';
        });
      }
    } on DclNetworkError catch (e) {
      if (mounted) {
        setState(() {
          _check = _OtaCheckState.error;
          _errorMessage = e.message;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _check = _OtaCheckState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _startFlash() async {
    final r = _result;
    if (r == null || r.otaUrl.isEmpty) return;
    context.read<DeviceProvider>().clearOtaProgress(widget.device.id);
    setState(() => _flashing = true);
    final ok = await context.read<MatterFabricPort>().downloadAndFlash(
      nodeId: widget.device.nodeId,
      otaUrl: r.otaUrl,
      targetVersion: r.latestVersion ?? 0,
      targetVersionString: r.latestVersionString ?? '',
      dryRun: false,
      endpoint: context.read<DeviceProvider>().viewFor(widget.device.id)?.otaEndpoint ?? 0,
    );
    if (!ok && mounted) setState(() => _flashing = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final view = provider.viewFor(widget.device.id);
    if (view?.otaSupported != true) return const SizedBox.shrink();

    final otaProgress = _flashing ? provider.otaProgressFor(widget.device.id) : null;

    // Clear terminal state once shown so it doesn't reappear on next visit.
    if (_flashing && (otaProgress?.isTerminal ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          provider.clearOtaProgress(widget.device.id);
          setState(() => _flashing = false);
        }
      });
    }

    final cs = Theme.of(context).colorScheme;
    final currentVersion = view?.softwareVersion ?? '';
    final newVersion = _result?.latestVersionString ?? '';

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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current version', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          const SizedBox(height: 3),
                          Text(
                            currentVersion.isNotEmpty ? currentVersion : '—',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ),
                    // Right-side status indicator
                    if (_check == _OtaCheckState.checking)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                      )
                    else if (_check == _OtaCheckState.upToDate)
                      Icon(Icons.check_circle_outline, size: 18, color: Colors.green.shade400)
                    else if (_check == _OtaCheckState.error)
                      GestureDetector(
                        onTap: _runCheck,
                        child: Icon(Icons.warning_amber_outlined, size: 18, color: Colors.orange.shade400),
                      )
                    else if (!_flashing && (_check == _OtaCheckState.upToDate || _check == _OtaCheckState.noOtaUrl))
                      GestureDetector(
                        onTap: _runCheck,
                        child: Icon(Icons.refresh, size: 18, color: cs.onSurfaceVariant),
                      ),
                  ],
                ),

                // ── Error message (below version) ───────────────────────────
                if (_check == _OtaCheckState.error) ...[
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // ── Missing info ────────────────────────────────────────────
                if (_check == _OtaCheckState.missingInfo) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Open the device screen first to load version info',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],

                // ── No OTA URL ──────────────────────────────────────────────
                if (!_flashing && _check == _OtaCheckState.noOtaUrl) ...[
                  const SizedBox(height: 6),
                  Text(
                    newVersion.isNotEmpty
                        ? '$newVersion available — no download URL in DCL'
                        : 'Update available — no download URL in DCL',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],

                // ── Upgrade button or in-progress display ───────────────────
                if (_flashing) ...[
                  const SizedBox(height: 16),
                  _buildProgress(context, cs, otaProgress),
                ] else if (_check == _OtaCheckState.updateAvailable) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _startFlash,

                    child: Text(
                      newVersion.isNotEmpty ? 'Upgrade to $newVersion' : 'Upgrade',
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
    final phase = p?.phase ?? 'download';
    final progress = p?.progress;

    final glyphText = progress != null ? '$progress%' : '--';

    final litColor = switch (phase) {
      'complete' => Colors.green.shade400,
      'dryrun' => Colors.blue.shade400,
      'error' => Colors.orange.shade400,
      _ => Colors.white,
    };

    final (String title, String subtitle) = switch (phase) {
      'download' => ('Downloading', 'Fetching firmware from DCL'),
      'querying' => ('Waiting', 'Device is querying the provider'),
      'installing' => ('Installing', 'Transferring firmware to device'),
      'applying' => ('Applying', 'Device is installing the image'),
      'complete' => ('Update complete', 'Device will reboot shortly'),
      'error' => ('Update failed', p?.message ?? 'Unknown error'),
      _ => ('Updating', ''),
    };

    final showCancel = phase != 'complete' && phase != 'dryrun' && phase != 'error';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dot-matrix percentage / status
        SizedBox(
          height: 56,
          child: CustomPaint(
            painter: DotMatrixPainter(text: glyphText, litColor: litColor, dimColor: Colors.white12),
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
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
// Share device bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

int? _parseHexId(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final s = (raw.startsWith('0x') || raw.startsWith('0X')) ? raw.substring(2) : raw;
  return int.tryParse(s, radix: 16);
}

enum _ShareState { loading, active, expired, error }

class _ShareBottomSheet extends StatefulWidget {
  const _ShareBottomSheet({
    required this.device,
    required this.vendorId,
    required this.productId,
    required this.port,
  });

  final MatterDevice device;
  final int vendorId;
  final int productId;
  final MatterFabricPort port;

  @override
  State<_ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<_ShareBottomSheet> {
  static const _windowSeconds = 300;

  _ShareState       _state = _ShareState.loading;
  ShareDeviceResult? _result;
  String            _errorMessage = '';
  Timer?            _timer;
  int               _secondsLeft = _windowSeconds;

  @override
  void initState() {
    super.initState();
    _openWindow();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Logic ────────────────────────────────────────────────────────────────

  Future<void> _openWindow() async {
    _timer?.cancel();
    setState(() {
      _state       = _ShareState.loading;
      _result      = null;
      _errorMessage = '';
      _secondsLeft = _windowSeconds;
    });
    try {
      final res = await widget.port.shareDevice(
        widget.device.nodeId,
        vendorId:  widget.vendorId,
        productId: widget.productId,
      );
      if (!mounted) return;
      if (res == null) {
        setState(() {
          _state        = _ShareState.error;
          _errorMessage = 'Device did not respond. Is it reachable?';
        });
        return;
      }
      setState(() {
        _result      = res;
        _state       = _ShareState.active;
        _secondsLeft = _windowSeconds;
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state        = _ShareState.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _secondsLeft = 0;
          _state = _ShareState.expired;
          t.cancel();
        }
      });
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // ── Title ──────────────────────────────────────────────────────
          Text(
            'Share device',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.device.name,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 24),
          // ── State-dependent body ────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_state) {
              _ShareState.loading => _buildLoading(cs),
              _ShareState.active  => _buildActive(cs),
              _ShareState.expired => _buildExpired(cs),
              _ShareState.error   => _buildError(cs),
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoading(ColorScheme cs) {
    return Padding(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          CircularProgressIndicator(color: cs.primary, strokeWidth: 2.5),
          const SizedBox(height: 20),
          Text(
            'Opening commissioning window…',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Active (QR code + countdown) ────────────────────────────────────────

  Widget _buildActive(ColorScheme cs) {
    final result = _result!;
    final countdown = _countdownColor(cs);
    return Padding(
      key: const ValueKey('active'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // QR code
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: QrImageView(
              data: result.qrCodePayload,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),
          // Instruction
          Text(
            'Open any Matter app and scan the code above',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          // Manual pairing code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.formattedManualCode,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: result.manualPairingCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pairing code copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(Icons.copy_outlined, size: 18, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manual pairing code',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          // Countdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 16, color: countdown),
              const SizedBox(width: 6),
              Text(
                _formatCountdown(),
                style: TextStyle(
                  fontSize: 13,
                  color: countdown,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Expired ───────────────────────────────────────────────────────────────

  Widget _buildExpired(ColorScheme cs) {
    return Padding(
      key: const ValueKey('expired'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Icon(Icons.hourglass_disabled_outlined, size: 52, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text(
            'Window expired',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'The 5-minute commissioning window has closed.\nOpen a new one to try again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openWindow,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  // ── Error ───────────────────────────────────────────────────────────────────

  Widget _buildError(ColorScheme cs) {
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 52, color: cs.error),
          const SizedBox(height: 16),
          const Text(
            'Could not open window',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openWindow,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatCountdown() {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')} remaining';
  }

  Color _countdownColor(ColorScheme cs) {
    if (_secondsLeft > 120) return Colors.green.shade400;
    if (_secondsLeft > 60)  return Colors.orange.shade400;
    return cs.error;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device info sub-screen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({required this.device, super.key});
  final MatterDevice device;

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  List<FabricDescriptor>? _fabrics;
  bool _fabricsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFabrics();
  }

  Future<void> _loadFabrics() async {
    setState(() => _fabricsLoading = true);
    try {
      final port = context.read<MatterClusterPort>();
      final fabrics = await port.readFabrics(widget.device.nodeId);
      if (mounted) setState(() { _fabrics = fabrics; _fabricsLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _fabrics = null; _fabricsLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final view = context.watch<DeviceProvider>().viewFor(widget.device.id);

    final rows = <Widget>[];
    void add(String label, String? value, {bool mono = false, bool link = false}) {
      if (value == null || value.isEmpty) return;
      rows.add(InfoRow(label: label, value: value, mono: mono, link: link));
    }

    add('Product',    view?.displayProductName);
    add('Vendor',     view?.vendorName);
    add('Product ID', view?.productId,   mono: true);
    add('Part no.',   view?.partNumber);
    add('Hardware',   view?.hwVersion);
    add('Firmware',   view?.softwareVersion);
    add('Mfg. date',  view?.manufacturingDate);
    add('Type',       widget.device.deviceType.displayName);
    add('Network',    widget.device.networkType == NetworkType.unknown
        ? null : widget.device.networkType.label);
    add('Node ID', '0x${widget.device.nodeId.toRadixString(16).padLeft(16, '0').toUpperCase()}',
        mono: true);
    add('Commissioned', _formatDate(widget.device.commissionedAt));
    add('Serial no.', view?.serialNumber, mono: true);
    add('Unique ID',  view?.uniqueId,     mono: true);
    add('Product URL', view?.productUrl, link: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device info', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Identity / versions ───────────────────────────────────────────
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

          // ── Commissioned fabrics ──────────────────────────────────────────
          _FabricsCard(
            fabrics: _fabrics,
            loading: _fabricsLoading,
            onRefresh: _loadFabrics,
          ),

          const SizedBox(height: 20),

          // ── Diagnostics / inspect ─────────────────────────────────────────
          Card(
            color: cs.surface,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.hub_outlined, color: cs.primary),
                  title: const Text('Thread diagnostics'),
                  subtitle: const Text('Channel, role, neighbours, routing table'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ThreadDiagScreen(device: widget.device),
                    ),
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                ListTile(
                  leading: Icon(Icons.manage_search, color: cs.primary),
                  title: const Text('Inspect clusters'),
                  subtitle: const Text('View all Matter clusters and attributes'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ClusterInspectorScreen(device: widget.device),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
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

// ── Commissioned fabrics card ─────────────────────────────────────────────────

class _FabricsCard extends StatelessWidget {
  const _FabricsCard({
    required this.fabrics,
    required this.loading,
    required this.onRefresh,
  });

  final List<FabricDescriptor>? fabrics;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget body;
    if (loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (fabrics == null || fabrics!.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Text(
          fabrics == null ? 'Could not read fabrics' : 'No fabrics found',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    } else {
      body = Column(
        children: fabrics!.asMap().entries.map((entry) {
          final i = entry.key;
          final f = entry.value;
          final isLast = i == fabrics!.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: _FabricRow(fabric: f),
              ),
              if (!isLast) Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
            ],
          );
        }).toList(),
      );
    }

    return Card(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Icon(Icons.lan_outlined, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loading
                        ? 'Commissioned fabrics — loading…'
                        : 'Commissioned fabrics'
                            '\${fabrics != null ? " (\${fabrics!.length})" : ""}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cs.onSurfaceVariant),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: loading ? null : onRefresh,
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          body,
        ],
      ),
    );
  }
}

class _FabricRow extends StatelessWidget {
  const _FabricRow({required this.fabric});
  final FabricDescriptor fabric;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final mono = TextStyle(fontFamily: 'monospace', fontSize: 12, color: cs.onSurface);
    final dim  = TextStyle(fontSize: 11, color: cs.onSurfaceVariant);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28, height: 28,
          margin: const EdgeInsets.only(top: 2, right: 12),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            '\${fabric.fabricIndex}',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fabric.label.isNotEmpty)
                Text(fabric.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Row(children: [Text('Fabric ', style: dim), Text(fabric.fabricId, style: mono)]),
              Row(children: [Text('Node   ', style: dim), Text(fabric.nodeId,   style: mono)]),
              Row(children: [Text('Vendor ', style: dim), Text(fabric.vendorId, style: mono)]),
            ],
          ),
        ),
      ],
    );
  }
}


class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.battery});
  final BatteryInfo battery;

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final pct = battery.percent;
    final lvl = battery.chargeLevel;
    final Color color;
    final IconData icon;
    if (pct != null) {
      color = pct > 60 ? Colors.green.shade400
            : pct > 20 ? Colors.orange.shade400
            : Colors.red.shade400;
      icon  = pct > 60 ? Icons.battery_full
            : pct > 20 ? Icons.battery_3_bar
            : Icons.battery_alert;
    } else {
      color = lvl == 0 ? Colors.green.shade400
            : lvl == 1 ? Colors.orange.shade400
            : Colors.red.shade400;
      icon  = lvl == 0 ? Icons.battery_full
            : lvl == 1 ? Icons.battery_3_bar
            : Icons.battery_alert;
    }
    final String label;
    if (pct != null) {
      label = '$pct %';
    } else {
      label = switch (lvl) { 0 => 'OK', 1 => 'Warning', 2 => 'Critical', _ => 'Unknown' };
    }
    return Card(
      color: cs.surface,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: pct != null
            ? LinearProgressIndicator(
                value: pct / 100.0,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linked devices summary tile → pushes to connections screen
// ─────────────────────────────────────────────────────────────────────────────

class _AutomationsSummaryTile extends StatelessWidget {
  const _AutomationsSummaryTile({required this.device});
  final MatterDevice device;

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final connections = context.watch<DeviceProvider>().connectionsFor(device.id);
    final targetIds   = connections.map((c) => c.targetDeviceId).toSet().toList();

    return Card(
      color: cs.surface,
      child: ListTile(
        title: targetIds.isEmpty
            ? Text('No linked devices',
                style: TextStyle(color: cs.onSurfaceVariant))
            : Wrap(
                spacing: 6, runSpacing: 4,
                children: _DeviceChips(deviceIds: targetIds).chips(context),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _ConnectionsScreen(device: device),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connections screen — one card per (target device × slot)
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionsScreen extends StatelessWidget {
  const _ConnectionsScreen({required this.device});
  final MatterDevice device;

  List<SwitchGroup> _groups(DeviceProvider provider) {
    final json = provider.clusterCacheFor(device.id);
    if (json == null) return [];
    return extractSwitchGroups(
        extractReadings(parseClusters(json), device.deviceType));
  }

  @override
  Widget build(BuildContext context) {
    final provider    = context.watch<DeviceProvider>();
    final connections = provider.connectionsFor(device.id);
    final groups      = _groups(provider);
    final cs          = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Linked devices')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          for (final conn in connections)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ConnectionCard(
                source:     device,
                connection: conn,
                groups:     groups,
              ),
            ),
          const SizedBox(height: 4),
          if (groups.isEmpty && device.deviceType.isSwitch)
              Card(
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16,
                          color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Open the device screen first so button data can load.',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          Card(
            color: cs.surface,
            child: ListTile(
              leading: Icon(Icons.add_circle_outline, color: cs.primary),
              title: const Text('Connect a device'),
              enabled: !device.deviceType.isSwitch || groups.isNotEmpty,
              onTap: groups.isNotEmpty || !device.deviceType.isSwitch
                  ? () => showModalBottomSheet<void>(
                      context:            context,
                      isScrollControlled: true,
                      useSafeArea:        true,
                      backgroundColor:    cs.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      builder: (_) => _AddConnectionSheet(
                        source: device,
                        groups: groups,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection card: target device + gesture summary + edit tap
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.source,
    required this.connection,
    required this.groups,
  });
  final MatterDevice       source;
  final DeviceConnection   connection;
  final List<SwitchGroup>  groups;

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final view   = context.read<DeviceProvider>().viewFor(connection.targetDeviceId);
    if (view == null) return const SizedBox.shrink();

    // Gesture summary pills
    final pills = <Widget>[];
    for (final rule in connection.rules) {
      pills.add(_GesturePill(rule: rule));
    }

    return Card(
      color: cs.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet<void>(
          context:            context,
          isScrollControlled: true,
          useSafeArea:        true,
          backgroundColor:    cs.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (_) => _ConnectionDetailSheet(
            source:     source,
            connection: connection,
            targetView: view,
            groups:     groups,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Device icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(view.deviceType.icon,
                    size: 20, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              // Name + pills
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(view.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        if (connection.switchGroup != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Slot ${connection.switchGroup}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSecondaryContainer)),
                          ),
                      ],
                    ),
                    if (pills.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: pills),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gesture pill — compact label for a rule in the connection card
// ─────────────────────────────────────────────────────────────────────────────

class _GesturePill extends StatelessWidget {
  const _GesturePill({required this.rule});
  final AutomationRule rule;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_triggerIcon(rule.trigger), size: 11,
              color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(rule.action.label,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

IconData _triggerIcon(TriggerType t) => switch (t) {
  TriggerType.switchPress  => Icons.radio_button_checked_outlined,
  TriggerType.switchCw     => Icons.keyboard_arrow_up,
  TriggerType.switchCcw    => Icons.keyboard_arrow_down,
  TriggerType.contactOpen  => Icons.meeting_room_outlined,
  TriggerType.contactClose => Icons.sensor_door_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────
// Connection detail sheet — per-gesture action dropdowns + delete
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionDetailSheet extends StatefulWidget {
  const _ConnectionDetailSheet({
    required this.source,
    required this.connection,
    required this.targetView,
    required this.groups,
  });
  final MatterDevice      source;
  final DeviceConnection  connection;
  final DeviceView        targetView;
  final List<SwitchGroup> groups;

  @override
  State<_ConnectionDetailSheet> createState() => _ConnectionDetailSheetState();
}

class _ConnectionDetailSheetState extends State<_ConnectionDetailSheet> {
  // mutable state: trigger → selected action (null = disabled)
  late final Map<TriggerType, AutomationAction?> _selections;

  @override
  void initState() {
    super.initState();
    _selections = {};
    for (final rule in widget.connection.rules) {
      _selections[rule.trigger] = rule.action;
    }
  }

  List<TriggerType> get _triggers {
    if (widget.source.deviceType == DeviceType.contactSensor) {
      return [TriggerType.contactOpen, TriggerType.contactClose];
    }
    final group = widget.groups.firstWhereOrNull(
        (g) => g.label == widget.connection.switchGroup);
    if (group == null) return [TriggerType.switchPress];
    return [
      if (group.pressEndpoints.isNotEmpty) TriggerType.switchPress,
      if (group.cwEndpoints.isNotEmpty)    TriggerType.switchCw,
      if (group.ccwEndpoints.isNotEmpty)   TriggerType.switchCcw,
    ];
  }

  bool get _hasOnOff   => widget.targetView.deviceType.hasOnOff   ||
      (context.read<DeviceProvider>()
          .liveDataFor(widget.targetView.id)?.attrs.containsKey('onOff') ?? false);
  bool get _hasBrightness => widget.targetView.deviceType.hasBrightness ||
      (context.read<DeviceProvider>()
          .liveDataFor(widget.targetView.id)?.attrs.containsKey('level') ?? false);
  bool get _isThermostat  => widget.targetView.deviceType == DeviceType.thermostat ||
      (context.read<DeviceProvider>()
          .liveDataFor(widget.targetView.id)?.attrs.containsKey('localTempCenti') ?? false);

  void _save() {
    final provider = context.read<DeviceProvider>();
    // Delete all existing rules for this connection then recreate from selections.
    provider.disconnectTarget(
      sourceDeviceId: widget.source.id,
      targetDeviceId: widget.connection.targetDeviceId,
      switchGroup:    widget.connection.switchGroup,
    );
    final group = widget.groups.firstWhereOrNull(
        (g) => g.label == widget.connection.switchGroup);
    for (final entry in _selections.entries) {
      final action = entry.value;
      if (action == null) continue;
      provider.upsertRule(AutomationRule(
        sourceDeviceId: widget.source.id,
        trigger:        entry.key,
        switchGroup:    widget.connection.switchGroup,
        endpoints:      _endpointsFor(entry.key, group),
        action:         action,
        targetDeviceIds: [widget.connection.targetDeviceId],
      ));
    }
    Navigator.pop(context);
  }

  List<int> _endpointsFor(TriggerType t, SwitchGroup? group) => switch (t) {
    TriggerType.switchPress => group?.pressEndpoints ?? [],
    TriggerType.switchCw    => group?.cwEndpoints    ?? [],
    TriggerType.switchCcw   => group?.ccwEndpoints   ?? [],
    _                       => [],
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final triggers = _triggers;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.targetView.deviceType.icon,
                      size: 18, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.targetView.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (widget.connection.switchGroup != null)
                      Text('Slot ${widget.connection.switchGroup}',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                )),
              ]),
            ),
            const Divider(height: 24, indent: 24, endIndent: 24),
            // Gesture rows
            for (final trigger in triggers)
              _GestureActionRow(
                trigger:     trigger,
                selected:    _selections[trigger],
                actions:     actionsFor(
                  trigger:       trigger,
                  hasOnOff:      _hasOnOff,
                  hasBrightness: _hasBrightness,
                  isThermostat:  _isThermostat,
                ),
                onChanged: (a) => setState(() => _selections[trigger] = a),
              ),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(children: [
                OutlinedButton.icon(
                  icon:  const Icon(Icons.link_off, size: 16),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error),
                  ),
                  onPressed: () {
                    context.read<DeviceProvider>().disconnectTarget(
                      sourceDeviceId: widget.source.id,
                      targetDeviceId: widget.connection.targetDeviceId,
                      switchGroup:    widget.connection.switchGroup,
                    );
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// One gesture row inside the detail sheet
class _GestureActionRow extends StatelessWidget {
  const _GestureActionRow({
    required this.trigger,
    required this.selected,
    required this.actions,
    required this.onChanged,
  });
  final TriggerType              trigger;
  final AutomationAction?        selected;
  final List<AutomationAction?>  actions;
  final ValueChanged<AutomationAction?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (actions.isEmpty || (actions.length == 1 && actions.first == null)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(children: [
        Icon(_triggerIcon(trigger), size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(trigger.label,
              style: TextStyle(fontSize: 13, color: cs.onSurface)),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AutomationAction?>(
              value:        actions.contains(selected) ? selected : null,
              isExpanded:   true,
              style:        TextStyle(fontSize: 13, color: cs.onSurface),
              dropdownColor: cs.surfaceContainerHigh,
              items: [
                for (final a in actions)
                  DropdownMenuItem(
                    value: a,
                    child: Text(
                      a?.label ?? '— none —',
                      style: TextStyle(
                          fontSize: 13,
                          color: a == null
                              ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                              : cs.onSurface),
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add connection sheet — pick a target device, smart preset applied
// ─────────────────────────────────────────────────────────────────────────────

class _AddConnectionSheet extends StatelessWidget {
  const _AddConnectionSheet({required this.source, required this.groups});
  final MatterDevice      source;
  final List<SwitchGroup> groups;

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    // All devices that have at least one compatible action, excluding self.
    final candidates = provider.linkableTargets(excludingDeviceId: source.id);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text('Connect a device',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text('No compatible devices found.',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (_, i) {
                    final v = candidates[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(v.deviceType.icon,
                            size: 18, color: cs.onPrimaryContainer),
                      ),
                      title:    Text(v.name),
                      subtitle: Text(v.deviceType.displayName,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      onTap: () {
                        provider.connectDevice(
                          sourceDeviceId: source.id,
                          sourceType:     source.deviceType,
                          targetDeviceId: v.id,
                          switchGroups:   groups,
                        );
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device chips helper (used in summary tile)
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceChips {
  const _DeviceChips({required this.deviceIds});
  final List<String> deviceIds;

  List<Widget> chips(BuildContext context) {
    final provider = context.read<DeviceProvider>();
    return [
      for (final id in deviceIds)
        if (provider.viewFor(id) case final view?)
          Chip(
            label:    Text(view.name, style: const TextStyle(fontSize: 11)),
            avatar:   Icon(view.deviceType.icon, size: 13),
            padding:  const EdgeInsets.symmetric(horizontal: 4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
    ];
  }
}
