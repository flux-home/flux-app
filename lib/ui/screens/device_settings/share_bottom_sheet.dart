import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Share device bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

enum _ShareState { loading, active, expired, error }

class ShareBottomSheet extends StatefulWidget {
  const ShareBottomSheet({
    required this.device,
    required this.vendorId,
    required this.productId,
    required this.port,
    super.key,
  });
  final MatterDevice   device;
  final int            vendorId;
  final int            productId;
  final MatterFabricPort port;

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  static const _windowSeconds = 300;

  _ShareState        _state       = _ShareState.loading;
  ShareDeviceResult? _result;
  String             _errorMessage = '';
  Timer?             _timer;
  int                _secondsLeft = _windowSeconds;

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

  Future<void> _openWindow() async {
    _timer?.cancel();
    setState(() { _state = _ShareState.loading; _result = null; _errorMessage = ''; _secondsLeft = _windowSeconds; });
    try {
      final res = await widget.port.shareDevice(widget.device.nodeId,
          vendorId: widget.vendorId, productId: widget.productId);
      if (!mounted) return;
      if (res == null) {
        setState(() { _state = _ShareState.error; _errorMessage = 'Device did not respond. Is it reachable?'; });
        return;
      }
      setState(() { _result = res; _state = _ShareState.active; _secondsLeft = _windowSeconds; });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() { _state = _ShareState.error; _errorMessage = e.toString(); });
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) { _secondsLeft = 0; _state = _ShareState.expired; t.cancel(); }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: cs.onSurfaceVariant.withAlpha(80), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Share device', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(widget.device.name, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_state) {
              _ShareState.loading  => _buildLoading(cs),
              _ShareState.active   => _buildActive(cs),
              _ShareState.expired  => _buildExpired(cs),
              _ShareState.error    => _buildError(cs),
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLoading(ColorScheme cs) => Padding(
    key: const ValueKey('loading'),
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(children: [
      CircularProgressIndicator(color: cs.primary, strokeWidth: 2.5),
      const SizedBox(height: 20),
      Text('Opening commissioning window…', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
    ]),
  );

  Widget _buildActive(ColorScheme cs) {
    final result    = _result!;
    final countdown = _countdownColor(cs);
    return Padding(
      key: const ValueKey('active'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: QrImageView(data: result.qrCodePayload, version: QrVersions.auto, size: 220,
              backgroundColor: Colors.white, padding: const EdgeInsets.all(12)),
        ),
        const SizedBox(height: 20),
        Text('Open any Matter app and scan the code above',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(result.formattedManualCode,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 2)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: result.manualPairingCode));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pairing code copied'), duration: Duration(seconds: 2)));
              },
              child: Icon(Icons.copy_outlined, size: 18, color: cs.onSurfaceVariant),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text('Manual pairing code', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timer_outlined, size: 16, color: countdown),
          const SizedBox(width: 6),
          Text(_formatCountdown(), style: TextStyle(fontSize: 13, color: countdown,
              fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ]),
    );
  }

  Widget _buildExpired(ColorScheme cs) => Padding(
    key: const ValueKey('expired'),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: Column(children: [
      Icon(Icons.hourglass_disabled_outlined, size: 52, color: cs.onSurfaceVariant),
      const SizedBox(height: 16),
      const Text('Window expired', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('The 5-minute commissioning window has closed.\nOpen a new one to try again.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
      const SizedBox(height: 24),
      FilledButton.icon(onPressed: _openWindow, icon: const Icon(Icons.refresh), label: const Text('Try again')),
    ]),
  );

  Widget _buildError(ColorScheme cs) => Padding(
    key: const ValueKey('error'),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: Column(children: [
      Icon(Icons.error_outline, size: 52, color: cs.error),
      const SizedBox(height: 16),
      const Text('Could not open window', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          maxLines: 3, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 24),
      FilledButton.icon(onPressed: _openWindow, icon: const Icon(Icons.refresh), label: const Text('Try again')),
    ]),
  );

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
