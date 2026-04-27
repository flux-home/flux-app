import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/ota_progress.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/services/cluster_parser.dart';
import 'package:matter_home/services/dcl_service.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart';
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

class DeviceInfoScreen extends StatelessWidget {
  const DeviceInfoScreen({required this.device, super.key});
  final MatterDevice device;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final view = context.watch<DeviceProvider>().viewFor(device.id);

    // Helper: only show a row if the value is non-null and non-empty.
    final rows = <Widget>[];
    void add(String label, String? value, {bool mono = false, bool link = false}) {
      if (value == null || value.isEmpty) return;
      rows.add(InfoRow(label: label, value: value, mono: mono, link: link));
    }

    // ── Identity ───────────────────────────────────────────────────────
    add('Product', view?.displayProductName);
    add('Vendor', view?.vendorName);
    add('Product ID', view?.productId, mono: true);
    add('Part no.', view?.partNumber);

    // ── Versions ───────────────────────────────────────────────────────
    add('Hardware', view?.hwVersion);
    add('Firmware', view?.softwareVersion);

    // ── Manufacturing ──────────────────────────────────────────────────
    add('Mfg. date', view?.manufacturingDate);

    // ── Device type / node ─────────────────────────────────────────────
    add('Type', device.deviceType.displayName);
    add('Network', device.networkType == NetworkType.unknown ? null : device.networkType.label);
    add('Node ID', '0x${device.nodeId.toRadixString(16).padLeft(16, '0').toUpperCase()}', mono: true);
    add('Commissioned', _formatDate(device.commissionedAt));

    // ── Identifiers ────────────────────────────────────────────────────
    add('Serial no.', view?.serialNumber, mono: true);
    add('Unique ID', view?.uniqueId, mono: true);

    // ── Links ──────────────────────────────────────────────────────────
    add('Product URL', view?.productUrl, link: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device info', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        child: Text('Loading…', style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : Column(children: rows),
            ),
          ),

          const SizedBox(height: 20),

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
                      builder: (_) => ThreadDiagScreen(device: device),
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
                      builder: (_) => ClusterInspectorScreen(device: device),
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


// ─────────────────────────────────────────────────────────────────────────────────
// Battery card
// ─────────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────────
// Linked devices summary tile — shows target device chips, taps into config
// ─────────────────────────────────────────────────────────────────────────────────

class _AutomationsSummaryTile extends StatelessWidget {
  const _AutomationsSummaryTile({required this.device});
  final MatterDevice device;

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final rules    = context.watch<DeviceProvider>().rulesFor(device.id);
    // Collect unique target device IDs across all rules.
    final targetIds = rules
        .expand((r) => r.targetDeviceIds)
        .toSet()
        .toList();

    return Card(
      color: cs.surface,
      child: ListTile(
        title: targetIds.isEmpty
            ? Text('No linked devices',
                style: TextStyle(color: cs.onSurfaceVariant))
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _DeviceChips(deviceIds: targetIds).chips(context),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _AutomationsScreen(device: device),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// Automations screen — full gesture configuration (pushed)
// ─────────────────────────────────────────────────────────────────────────────────

class _AutomationsScreen extends StatelessWidget {
  const _AutomationsScreen({required this.device});
  final MatterDevice device;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Linked devices')),
      body: _AutomationsSection(device: device),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// Automations section — dispatches to switch or contact variant
// ─────────────────────────────────────────────────────────────────────────────────

class _AutomationsSection extends StatelessWidget {
  const _AutomationsSection({required this.device});
  final MatterDevice device;

  @override
  Widget build(BuildContext context) {
    if (device.deviceType == DeviceType.contactSensor) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [_ContactAutomationsCard(device: device)],
      );
    }
    final provider = context.watch<DeviceProvider>();
    final json     = provider.clusterCacheFor(device.id);
    final groups   = json != null
        ? extractSwitchGroups(extractReadings(parseClusters(json), device.deviceType))
        : <SwitchGroup>[];

    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Open the device screen first to load button data.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13),
          ),
        ),
      );
    }

    final rules = provider.rulesFor(device.id);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        for (int i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: _SwitchSlotSection(
              device: device,
              group:  groups[i],
              rules:  rules.where((r) => r.switchGroup == groups[i].label).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// One slot: header + three gesture rows (press / CW / CCW)
// ─────────────────────────────────────────────────────────────────────────────────

class _SwitchSlotSection extends StatelessWidget {
  const _SwitchSlotSection({
    required this.device,
    required this.group,
    required this.rules,
  });
  final MatterDevice       device;
  final SwitchGroup        group;
  final List<AutomationRule> rules;

  AutomationRule? _ruleFor(TriggerType t) =>
      rules.where((r) => r.trigger == t).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'SLOT ${group.label}',
            style: TextStyle(
              fontSize: 10, letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        _GestureRow(
          device:    device,
          trigger:   TriggerType.switchPress,
          endpoints: group.pressEndpoints,
          group:     group.label,
          rule:      _ruleFor(TriggerType.switchPress),
        ),
        Divider(height: 1, indent: 44, endIndent: 0, color: cs.outlineVariant),
        _GestureRow(
          device:    device,
          trigger:   TriggerType.switchCw,
          endpoints: group.cwEndpoints,
          group:     group.label,
          rule:      _ruleFor(TriggerType.switchCw),
        ),
        Divider(height: 1, indent: 44, endIndent: 0, color: cs.outlineVariant),
        _GestureRow(
          device:    device,
          trigger:   TriggerType.switchCcw,
          endpoints: group.ccwEndpoints,
          group:     group.label,
          rule:      _ruleFor(TriggerType.switchCcw),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// Contact sensor: when opened / when closed rows
// ─────────────────────────────────────────────────────────────────────────────────

class _ContactAutomationsCard extends StatelessWidget {
  const _ContactAutomationsCard({required this.device});
  final MatterDevice device;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final rules = context.watch<DeviceProvider>().rulesFor(device.id);

    AutomationRule? ruleFor(TriggerType t) =>
        rules.where((r) => r.trigger == t).firstOrNull;

    return Card(
      color: cs.surface,
      child: Column(
        children: [
          _GestureRow(
            device:  device,
            trigger: TriggerType.contactOpen,
            group:   null,
            endpoints: const [],
            rule:    ruleFor(TriggerType.contactOpen),
          ),
          Divider(height: 1, indent: 44, endIndent: 0, color: cs.outlineVariant),
          _GestureRow(
            device:  device,
            trigger: TriggerType.contactClose,
            group:   null,
            endpoints: const [],
            rule:    ruleFor(TriggerType.contactClose),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// One gesture row: icon + label + current rule summary + edit button
// ─────────────────────────────────────────────────────────────────────────────────

class _GestureRow extends StatelessWidget {
  const _GestureRow({
    required this.device,
    required this.trigger,
    required this.endpoints,
    required this.group,
    required this.rule,
  });
  final MatterDevice    device;
  final TriggerType     trigger;
  final List<int>       endpoints;
  final String?         group;
  final AutomationRule? rule;

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context:          context,
      isScrollControlled: true,
      useSafeArea:      true,
      backgroundColor:  Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AutomationEditSheet(
        device:    device,
        trigger:   trigger,
        endpoints: endpoints,
        group:     group,
        existing:  rule,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final hasRule = rule != null && rule!.targetDeviceIds.isNotEmpty;

    final triggerIcon = _triggerIcon(trigger);

    return InkWell(
      onTap: () => _openSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Gesture icon
            SizedBox(
              width: 28,
              child: Icon(triggerIcon, size: 16,
                  color: hasRule ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
            // Trigger label
            SizedBox(
              width: 90,
              child: Text(
                trigger.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasRule ? FontWeight.w600 : FontWeight.normal,
                  color: hasRule ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
            // Action + targets or empty indicator
            Expanded(
              child: hasRule
                  ? Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _ActionBadge(action: rule!.action),
                        ..._DeviceChips(deviceIds: rule!.targetDeviceIds).chips(context),
                      ],
                    )
                  : Text(
                      '—',
                      style: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                        fontSize: 13,
                      ),
                    ),
            ),
            // Add/edit icon
            Icon(
              hasRule ? Icons.edit_outlined : Icons.add_circle_outline,
              size: 18,
              color: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _triggerIcon(TriggerType t) => switch (t) {
  TriggerType.switchPress    => Icons.radio_button_checked_outlined,
  TriggerType.switchCw       => Icons.keyboard_arrow_up,
  TriggerType.switchCcw      => Icons.keyboard_arrow_down,
  TriggerType.contactOpen    => Icons.meeting_room_outlined,
  TriggerType.contactClose   => Icons.sensor_door_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────────
// Action badge
// ─────────────────────────────────────────────────────────────────────────────────

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action});
  final AutomationAction action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        action.label,
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// Device chips helper
// ─────────────────────────────────────────────────────────────────────────────────

class _DeviceChips {
  const _DeviceChips({required this.deviceIds});
  final List<String> deviceIds;

  List<Widget> chips(BuildContext context) {
    final provider = context.read<DeviceProvider>();
    return [
      for (final id in deviceIds)
        if (provider.viewFor(id) case final view?)
          Chip(
            label:      Text(view.name, style: const TextStyle(fontSize: 11)),
            avatar:     Icon(view.deviceType.icon, size: 13),
            padding:    const EdgeInsets.symmetric(horizontal: 4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// Edit sheet: action picker + live-filtered device list
// ─────────────────────────────────────────────────────────────────────────────────

class _AutomationEditSheet extends StatefulWidget {
  const _AutomationEditSheet({
    required this.device,
    required this.trigger,
    required this.endpoints,
    required this.group,
    required this.existing,
  });
  final MatterDevice    device;
  final TriggerType     trigger;
  final List<int>       endpoints;
  final String?         group;
  final AutomationRule? existing;

  @override
  State<_AutomationEditSheet> createState() => _AutomationEditSheetState();
}

class _AutomationEditSheetState extends State<_AutomationEditSheet> {
  late AutomationAction _action;
  late Set<String>      _targets;

  @override
  void initState() {
    super.initState();
    _action  = widget.existing?.action ?? suggestedActions(widget.trigger).first;
    _targets = Set<String>.from(widget.existing?.targetDeviceIds ?? []);
  }

  void _onActionChanged(AutomationAction a) {
    setState(() {
      _action = a;
      // Remove targets that no longer support the new action.
      final provider = context.read<DeviceProvider>();
      final valid = provider
          .linkableTargets(excludingDeviceId: widget.device.id, action: _action)
          .map((v) => v.id)
          .toSet();
      _targets = _targets.intersection(valid);
    });
  }

  Future<void> _save() async {
    final provider = context.read<DeviceProvider>();
    if (_targets.isEmpty) {
      if (widget.existing != null) provider.removeRule(widget.existing!.id);
    } else {
      provider.upsertRule(AutomationRule(
        id:              widget.existing?.id,
        sourceDeviceId:  widget.device.id,
        trigger:         widget.trigger,
        switchGroup:     widget.group,
        endpoints:       widget.endpoints,
        action:          _action,
        targetDeviceIds: _targets.toList(),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final ordered = suggestedActions(widget.trigger);
    final targets = context.read<DeviceProvider>()
        .linkableTargets(excludingDeviceId: widget.device.id, action: _action);

    String title = widget.trigger.label;
    if (widget.group != null) title = 'Slot ${widget.group} — $title';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─ Handle + title ────────────────────────────────────────
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Icon(_triggerIcon(widget.trigger), size: 18, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // ─ Action chips ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text('Action',
                  style: TextStyle(
                    fontSize: 11, letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  )),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  for (final a in ordered)
                    ChoiceChip(
                      label:    Text(a.label),
                      selected: _action == a,
                      onSelected: (_) => _onActionChanged(a),
                    ),
                ],
              ),
            ),

            // ─ Device list ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text('Devices',
                  style: TextStyle(
                    fontSize: 11, letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  )),
            ),
            if (targets.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Text('No compatible devices found.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  itemBuilder: (_, i) {
                    final v        = targets[i];
                    final selected = _targets.contains(v.id);
                    return CheckboxListTile(
                      value:     selected,
                      secondary: Icon(v.deviceType.icon, color: cs.primary),
                      title:     Text(v.name),
                      subtitle:  Text(v.deviceType.displayName,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      onChanged: (_) => setState(() {
                        if (selected) { _targets.remove(v.id); }
                        else          { _targets.add(v.id); }
                      }),
                    );
                  },
                ),
              ),

            // ─ Save button ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  if (widget.existing != null) ...[
                    OutlinedButton.icon(
                      icon:  const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error),
                      ),
                      onPressed: () {
                        context.read<DeviceProvider>().removeRule(widget.existing!.id);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
