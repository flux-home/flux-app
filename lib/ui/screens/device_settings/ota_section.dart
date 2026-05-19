import 'package:flutter/material.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/ota_progress.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/dcl_service.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/ui/widgets/dot_matrix_painter.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:matter_home/utils/hex_utils.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OTA update section
// ─────────────────────────────────────────────────────────────────────────────

enum OtaCheckState { idle, checking, upToDate, updateAvailable, noOtaUrl, missingInfo, error }

class OtaSection extends StatefulWidget {
  const OtaSection({required this.device, super.key});
  final MatterDevice device;

  @override
  State<OtaSection> createState() => _OtaSectionState();
}

class _OtaSectionState extends State<OtaSection> {
  OtaCheckState    _check        = OtaCheckState.idle;
  DclUpdateResult? _result;
  String           _errorMessage = '';
  bool             _flashing     = false;

  @override
  void initState() {
    super.initState();
    final progress = context.read<DeviceProvider>().otaProgressFor(widget.device.id);
    if (progress != null) {
      _flashing = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runCheck();
      });
    }
  }

  Future<void> _runCheck() async {
    final view = context.read<DeviceProvider>().viewFor(widget.device.id);
    final vid  = parseHexId(view?.vendorId);
    final pid  = parseHexId(view?.productId);
    final cur  = view?.softwareVersionNum;
    if (vid == null || pid == null || cur == null) {
      setState(() => _check = OtaCheckState.missingInfo);
      return;
    }
    setState(() { _check = OtaCheckState.checking; _result = null; _errorMessage = ''; });
    try {
      final r = await DclService().checkForUpdate(vid: vid, pid: pid, currentVersion: cur);
      if (!mounted) return;
      setState(() {
        _result = r;
        _check  = !r.isUpdateAvailable ? OtaCheckState.upToDate
                : r.otaUrl.isEmpty     ? OtaCheckState.noOtaUrl
                : OtaCheckState.updateAvailable;
      });
    } on DclNotFoundError {
      if (mounted) setState(() { _check = OtaCheckState.error; _errorMessage = 'Device not found in DCL'; });
    } on DclNetworkError catch (e) {
      if (mounted) setState(() { _check = OtaCheckState.error; _errorMessage = e.message; });
    } on Exception catch (e) {
      if (mounted) setState(() { _check = OtaCheckState.error; _errorMessage = e.toString(); });
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
      dryRun:              false,
      endpoint:            context.read<DeviceProvider>().viewFor(widget.device.id)?.otaEndpoint ?? 0,
    );
    if (!ok && mounted) setState(() => _flashing = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final view     = provider.viewFor(widget.device.id);
    if (view?.otaSupported != true) return const SizedBox.shrink();

    final otaProgress = _flashing ? provider.otaProgressFor(widget.device.id) : null;

    if (_flashing && (otaProgress?.isTerminal ?? false)) {
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
                    if (_check == OtaCheckState.checking)
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                    else if (_check == OtaCheckState.upToDate)
                      Icon(Icons.check_circle_outline, size: 18, color: Colors.green.shade400)
                    else if (_check == OtaCheckState.error)
                      GestureDetector(onTap: _runCheck, child: Icon(Icons.warning_amber_outlined, size: 18, color: Colors.orange.shade400))
                    else if (!_flashing && (_check == OtaCheckState.upToDate || _check == OtaCheckState.noOtaUrl))
                      GestureDetector(onTap: _runCheck, child: Icon(Icons.refresh, size: 18, color: cs.onSurfaceVariant)),
                  ],
                ),
                if (_check == OtaCheckState.error) ...[
                  const SizedBox(height: 4),
                  Text(_errorMessage, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (_check == OtaCheckState.missingInfo) ...[
                  const SizedBox(height: 4),
                  Text('Open the device screen first to load version info', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
                if (!_flashing && _check == OtaCheckState.noOtaUrl) ...[
                  const SizedBox(height: 6),
                  Text(
                    newVersion.isNotEmpty ? '$newVersion available — no download URL in DCL' : 'Update available — no download URL in DCL',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
                if (_flashing) ...[
                  const SizedBox(height: 16),
                  _buildProgress(context, cs, otaProgress),
                ] else if (_check == OtaCheckState.updateAvailable) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _startFlash,
                    child: Text(newVersion.isNotEmpty ? 'Upgrade to $newVersion' : 'Upgrade',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
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
      'download'   => ('Downloading',  'Fetching firmware from DCL'),
      'querying'   => ('Waiting',      'Device is querying the provider'),
      'installing' => ('Installing',   'Transferring firmware to device'),
      'applying'   => ('Applying',     'Device is installing the image'),
      'complete'   => ('Update complete', 'Device will reboot shortly'),
      'error'      => ('Update failed', p?.message ?? 'Unknown error'),
      _            => ('Updating', ''),
    };

    final showCancel = phase != 'complete' && phase != 'dryrun' && phase != 'error';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: CustomPaint(painter: DotMatrixPainter(text: glyphText, litColor: litColor, dimColor: Colors.white12)),
        ),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
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
