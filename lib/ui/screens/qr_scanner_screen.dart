import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:matter_home/ui/widgets/manual_code_formatter.dart';

/// Full-screen QR scanner that also accepts a manually typed code.
///
/// Returns the raw scanned/entered string via [Navigator.pop].
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _manualCtrl = TextEditingController();
  bool _scanned = false;
  bool _manualMode = false;
  // ignore: unused_field
  CameraController? _cameraController;

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  // ── Camera scan ───────────────────────────────────────────────────────────

  void _onScan(Code code) {
    if (_scanned || _manualMode) return;
    final text = code.text;
    if (text != null && text.isNotEmpty) {
      _scanned = true;
      Navigator.of(context).pop(text);
    }
  }

  // ── Manual entry ──────────────────────────────────────────────────────────

  void _confirmManual() {
    final code = _manualCtrl.text.replaceAll('-', '').trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera + ZXing scanner ─────────────────────────────────────────
          ReaderWidget(
            onScan: _onScan,
            codeFormat: Format.qrCode,
            showScannerOverlay: false,   // we draw our own cutout below
            showFlashlight: true,
            showGallery: false,
            showToggleCamera: false,
            allowPinchZoom: true,
            scanDelay: const Duration(milliseconds: 200),
            scanDelaySuccess: const Duration(milliseconds: 500),
            actionButtonsAlignment: Alignment.topRight,
            actionButtonsPadding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 4,
              right: 4,
            ),
            actionButtonsBackgroundColor: Colors.transparent,
            onControllerCreated: (controller, error) {
              _cameraController = controller;
            },
            loading: const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 56),
                    SizedBox(height: 16),
                    Text(
                      'STARTING CAMERA',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Scan-area overlay (hidden in manual mode) ─────────────────────
          if (!_manualMode) const _ScanOverlay(),

          // ── Back button (top left) ────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // ── Bottom panel ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _manualMode
                  ? _ManualEntryPanel(
                      key: const ValueKey('manual'),
                      controller: _manualCtrl,
                      onConfirm: _confirmManual,
                      onCancel: () => setState(() {
                        _manualMode = false;
                        _manualCtrl.clear();
                      }),
                    )
                  : _ScanBottomBar(
                      key: const ValueKey('scan'),
                      onManualTap: () => setState(() => _manualMode = true),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _ScanBottomBar extends StatelessWidget {
  const _ScanBottomBar({
    required this.onManualTap,
    super.key,
  });
  final VoidCallback onManualTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 40, 24, 24 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Pinch hint ────────────────────────────────────────────────────
          const Text(
            'PINCH TO ZOOM',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 12),

          // ── Enter manually pill ───────────────────────────────────────────
          GestureDetector(
            onTap: onManualTap,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(24),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_outlined, size: 18, color: Colors.white70),
                  SizedBox(width: 10),
                  Text(
                    'Enter code manually',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Manual entry panel ────────────────────────────────────────────────────────

class _ManualEntryPanel extends StatelessWidget {
  const _ManualEntryPanel({required this.controller, required this.onConfirm, required this.onCancel, super.key});
  final TextEditingController controller;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withAlpha(240),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),

          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [ManualCodeFormatter()],
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 15),
            decoration: InputDecoration(
              hintText: '1234-567-8910',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Colors.white24, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Colors.white24, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Colors.white60, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onConfirm(),
          ),

          const SizedBox(height: 12),

          // Confirm — white filled pill
          GestureDetector(
            onTap: onConfirm,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(color: Colors.white.withAlpha(230), borderRadius: BorderRadius.circular(26)),
              child: const Center(
                child: Text(
                  'Confirm',
                  style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Cancel — ghost pill
          GestureDetector(
            onTap: onCancel,
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: const Center(
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scan overlay ──────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _OverlayPainter(cutoutSize: 240), child: SizedBox.expand());
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.cutoutSize});
  final double cutoutSize;

  static const double _radius = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 40),
      width: cutoutSize,
      height: cutoutSize,
    );
    final rRect = RRect.fromRectAndRadius(cutoutRect, const Radius.circular(_radius));

    canvas
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
          Path()..addRRect(rRect),
        ),
        Paint()..color = Colors.black.withAlpha(210),
      )
      ..drawRRect(
        rRect,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
