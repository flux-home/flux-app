import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen QR scanner that also accepts a manually typed code.
///
/// Returns the raw scanned/entered string via [Navigator.pop].
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final _manualCtrl = TextEditingController();
  bool _scanned = false;
  bool _manualMode = false;
  double _zoom = 0.4; // 0.4 → 1.0 maps to 1.8× → 3.0× display

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.setZoomScale(_zoom);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  // ── Pinch-to-zoom ─────────────────────────────────────────────────────────

  double _baseZoom = 0.4;
  void _onScaleStart(ScaleStartDetails _) => _baseZoom = _zoom;
  void _onScaleUpdate(ScaleUpdateDetails d) {
    final z = (_baseZoom + (d.scale - 1) * 0.3).clamp(0.0, 1.0);
    if ((z - _zoom).abs() > 0.01) {
      setState(() => _zoom = z);
      _controller.setZoomScale(_zoom);
    }
  }

  // ── Camera scan ───────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_scanned || _manualMode) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null && code.isNotEmpty) {
      _scanned = true;
      Navigator.of(context).pop(code);
    }
  }

  // ── Manual entry ──────────────────────────────────────────────────────────

  void _confirmManual() {
    // Strip any dashes the formatter inserted before handing off the raw digits.
    final code = _manualCtrl.text.replaceAll('-', '').trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // No AppBar — full-screen camera, back arrow from system gesture.
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: Stack(
          children: [
            // ── Camera feed ──────────────────────────────────────────────────
            MobileScanner(controller: _controller, onDetect: _onDetect),

            // ── Scan-area overlay (hidden in manual mode) ─────────────────────
            if (!_manualMode) const _ScanOverlay(),

            // ── System-chrome: back + torch ───────────────────────────────────
            SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flash_on_outlined, color: Colors.white),
                    onPressed: _controller.toggleTorch,
                    tooltip: 'Toggle torch',
                  ),
                ],
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
                        zoom: _zoom,
                        onZoomOut: () {
                          final z = (_zoom - 0.15).clamp(0.0, 1.0);
                          setState(() => _zoom = z);
                          _controller.setZoomScale(z);
                        },
                        onZoomIn: () {
                          final z = (_zoom + 0.15).clamp(0.0, 1.0);
                          setState(() => _zoom = z);
                          _controller.setZoomScale(z);
                        },
                        onManualTap: () => setState(() => _manualMode = true),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _ScanBottomBar extends StatelessWidget {
  const _ScanBottomBar({
    required this.zoom,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onManualTap,
    super.key,
  });
  final double zoom;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onManualTap;

  @override
  Widget build(BuildContext context) {
    // zoom 0.0–1.0 → display as e.g. "1.0×" … "3.0×"  (linear 1–3×)
    final displayZoom = 1.0 + zoom * 2.0;

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
          // ── Zoom split-pill ───────────────────────────────────────────────
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                // − button
                Expanded(
                  child: GestureDetector(
                    onTap: onZoomOut,
                    behavior: HitTestBehavior.opaque,
                    child: const Center(child: Icon(Icons.remove, color: Colors.white, size: 18)),
                  ),
                ),
                // Divider + zoom label
                Container(width: 1, height: 20, color: Colors.white24),
                SizedBox(
                  width: 56,
                  child: Center(
                    child: Text(
                      '${displayZoom.toStringAsFixed(1)}×',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.white24),
                // + button
                Expanded(
                  child: GestureDetector(
                    onTap: onZoomIn,
                    behavior: HitTestBehavior.opaque,
                    child: const Center(child: Icon(Icons.add, color: Colors.white, size: 18)),
                  ),
                ),
              ],
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
            inputFormatters: [_ManualCodeFormatter()],
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

  static const double _radius = 22; // matches _kCardShape in device_card.dart

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 40),
      width: cutoutSize,
      height: cutoutSize,
    );
    final rRect = RRect.fromRectAndRadius(cutoutRect, const Radius.circular(_radius));

    // ── Scrim + border ────────────────────────────────────────────────────
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

// ── Manual pairing code formatter ─────────────────────────────────────────────
//
// Spec §5.1.4: 11-digit decimal code (XXXXX-XXXXXX).
// Digits beyond 11 are discarded.  A single dash is inserted after digit 5.
// The commissioner must receive raw digits — _confirmManual strips the dash.

class _ManualCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text
        .replaceAll(RegExp('[^0-9]'), '')
        .substring(0, newValue.text.replaceAll(RegExp('[^0-9]'), '').length.clamp(0, 11));

    if (digits.isEmpty) return TextEditingValue.empty;

    final formatted = digits.length > 5 ? '${digits.substring(0, 5)}-${digits.substring(5)}' : digits;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
