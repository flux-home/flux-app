import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/ota_progress.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/models/switch_link.dart';
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

              // ── Linked devices (switch only) ──────────────────────────────
              if (d.deviceType.isSwitch || d.deviceType == DeviceType.contactSensor) ...[
                const SectionLabel('Linked devices'),
                _LinkedDevicesSection(device: d),
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
// Contact sensor linked actions card
// ─────────────────────────────────────────────────────────────────────────────────

class _ContactLinksCard extends StatelessWidget {
  const _ContactLinksCard({required this.device});
  final MatterDevice device;

  Future<void> _openPicker(
    BuildContext context,
    List<String> current,
    void Function(List<String>) onConfirm,
  ) async {
    final targets = context.read<DeviceProvider>().linkableTargets(
      excludingDeviceId: device.id,
      requiresOnOff: true,
    );
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No controllable devices found')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _TargetPickerSheet(
        targets:  targets,
        selected: Set<String>.from(current),
      ),
    );
    if (picked == null || !context.mounted) return;
    onConfirm(picked.toList());
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final link     = provider.contactLinkFor(device.id);
    final base     = link ?? ContactLink(sourceDeviceId: device.id);

    void save(ContactLink updated) => provider.upsertContactLink(updated);

    return Card(
      color: cs.surface,
      child: Column(
        children: [
          _ContactActionRow(
            label:   'When opened',
            icon:    Icons.meeting_room_outlined,
            targets: base.onOpen,
            onEdit:  () => _openPicker(context, base.onOpen,
                (t) => save(base.withOpen(t))),
          ),
          Divider(height: 1, indent: 16, endIndent: 16,
              color: cs.outlineVariant),
          _ContactActionRow(
            label:   'When closed',
            icon:    Icons.sensor_door_outlined,
            targets: base.onClose,
            onEdit:  () => _openPicker(context, base.onClose,
                (t) => save(base.withClose(t))),
          ),
        ],
      ),
    );
  }
}

class _ContactActionRow extends StatelessWidget {
  const _ContactActionRow({
    required this.label,
    required this.icon,
    required this.targets,
    required this.onEdit,
  });
  final String       label;
  final IconData     icon;
  final List<String> targets;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      leading: Icon(icon, color: cs.onSurfaceVariant, size: 20),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: targets.isEmpty
          ? Text('No linked devices',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))
          : _LinkedChips(deviceIds: targets),
      trailing: IconButton(
        icon: Icon(
          targets.isEmpty ? Icons.add_circle_outline : Icons.edit_outlined,
          color: cs.primary,
        ),
        tooltip: targets.isEmpty ? 'Link devices' : 'Edit links',
        onPressed: onEdit,
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Battery card
// ─────────────────────────────────────────────────────────────────────────────

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.battery});
  final BatteryInfo battery;

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final pct = battery.percent;
    final lvl = battery.chargeLevel;

    // Derive quality colour.
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
      label = switch (lvl) {
        0 => 'OK',
        1 => 'Warning',
        2 => 'Critical',
        _ => 'Unknown',
      };
    }

    return Card(
      color: cs.surface,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: pct != null
            ? LinearProgressIndicator(
                value:            pct / 100.0,
                backgroundColor:  cs.surfaceContainerHighest,
                valueColor:       AlwaysStoppedAnimation<Color>(color),
                borderRadius:     BorderRadius.circular(4),
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linked devices section
// ─────────────────────────────────────────────────────────────────────────────

class _LinkedDevicesSection extends StatelessWidget {
  const _LinkedDevicesSection({required this.device});
  final MatterDevice device;

  @override
  Widget build(BuildContext context) {
    if (device.deviceType == DeviceType.contactSensor) {
      return _ContactLinksCard(device: device);
    }

    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final links    = provider.linksFor(device.id);

    // Parse cluster cache to get virtual switch groups.
    final json     = provider.clusterCacheFor(device.id);
    final groups   = json != null
        ? extractSwitchGroups(
            extractReadings(parseClusters(json), device.deviceType))
        : <SwitchGroup>[];

    if (groups.isEmpty) {
      return Card(
        color: cs.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Open the device screen first to load button data.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
      );
    }

    return Card(
      color: cs.surface,
      child: Column(
        children: [
          for (int i = 0; i < groups.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 16, endIndent: 16,
                  color: cs.outlineVariant),
            _SwitchGroupRow(
              device:  device,
              group:   groups[i],
              link:    links.where((l) => l.switchGroup == groups[i].label)
                           .firstOrNull,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One row per virtual switch group
// ─────────────────────────────────────────────────────────────────────────────

class _SwitchGroupRow extends StatelessWidget {
  const _SwitchGroupRow({
    required this.device,
    required this.group,
    required this.link,
  });
  final MatterDevice  device;
  final SwitchGroup   group;
  final SwitchLink?   link;

  Future<void> _openPicker(BuildContext context) async {
    final provider = context.read<DeviceProvider>();
    final targets = provider.linkableTargets(
      excludingDeviceId: device.id,
      requiresOnOff: group.pressEndpoints.isNotEmpty,
      requiresLevel: group.cwEndpoints.isNotEmpty || group.ccwEndpoints.isNotEmpty,
    );

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No controllable devices found')),
      );
      return;
    }

    final current = Set<String>.from(link?.targetDeviceIds ?? []);

    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _TargetPickerSheet(
        targets:  targets,
        selected: current,
      ),
    );

    if (picked == null || !context.mounted) return;

    if (picked.isEmpty) {
      if (link != null) provider.removeSwitchLink(device.id, link!.id);
      return;
    }

    final updated = SwitchLink(
      id:              link?.id,
      sourceDeviceId:  device.id,
      switchGroup:     group.label,
      pressEndpoints:  group.pressEndpoints,
      cwEndpoints:     group.cwEndpoints,
      ccwEndpoints:    group.ccwEndpoints,
      targetDeviceIds: picked.toList(),
    );
    provider.upsertSwitchLink(updated);
  }

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final targets = link?.targetDeviceIds ?? [];

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      title: Text('Switch ${group.label}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: targets.isEmpty
          ? Text('No linked devices',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))
          : _LinkedChips(deviceIds: targets),
      trailing: IconButton(
        icon: Icon(
          targets.isEmpty ? Icons.add_circle_outline : Icons.edit_outlined,
          color: cs.primary,
        ),
        tooltip: targets.isEmpty ? 'Link devices' : 'Edit links',
        onPressed: () => _openPicker(context),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact chips showing linked device names
// ─────────────────────────────────────────────────────────────────────────────

class _LinkedChips extends StatelessWidget {
  const _LinkedChips({required this.deviceIds});
  final List<String> deviceIds;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final id in deviceIds)
          if (provider.viewFor(id) case final view?)
            Chip(
              label:     Text(view.name,
                  style: const TextStyle(fontSize: 11)),
              avatar:    Icon(view.deviceType.icon, size: 13),
              padding:   const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Target picker bottom sheet — multi-select list of controllable devices
// ─────────────────────────────────────────────────────────────────────────────

class _TargetPickerSheet extends StatefulWidget {
  const _TargetPickerSheet({required this.targets, required this.selected});
  final List<DeviceView>  targets;
  final Set<String>       selected;

  @override
  State<_TargetPickerSheet> createState() => _TargetPickerSheetState();
}

class _TargetPickerSheetState extends State<_TargetPickerSheet> {
  late final Set<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = Set<String>.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Link to devices',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _picked),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.targets.length,
              itemBuilder: (_, i) {
                final view = widget.targets[i];
                final selected = _picked.contains(view.id);
                return CheckboxListTile(
                  value:     selected,
                  secondary: Icon(view.deviceType.icon, color: cs.primary),
                  title:     Text(view.name),
                  subtitle:  Text(view.deviceType.displayName,
                      style: TextStyle(color: cs.onSurfaceVariant,
                          fontSize: 12)),
                  onChanged: (_) => setState(() {
                    if (selected) _picked.remove(view.id);
                    else          _picked.add(view.id);
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
