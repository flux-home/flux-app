import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Payload entry widget  (QR scan tab  +  manual pairing-code tab)
// ─────────────────────────────────────────────────────────────────────────────

enum _EntryMode { qr, manual }

class PayloadEntry extends StatefulWidget {
  const PayloadEntry({
    required this.onScan,
    required this.onCodeEntered,
    required this.parsed,
    required this.rawPayload,
    required this.parsing,
    required this.parseError,
    this.onViewDetails,
    super.key,
  });
  final VoidCallback onScan;
  final Future<void> Function(String) onCodeEntered;
  final ParsedPayload? parsed;
  final String? rawPayload;
  final bool parsing;
  final String? parseError;
  final VoidCallback? onViewDetails;

  @override
  State<PayloadEntry> createState() => _PayloadEntryState();
}

class _PayloadEntryState extends State<PayloadEntry> {
  _EntryMode _mode = _EntryMode.qr;

  final _qrCtrl     = TextEditingController();
  final _manualCtrl = TextEditingController();

  @override
  void dispose() {
    _qrCtrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  static String _digits(String s) => s.replaceAll(RegExp('[^0-9]'), '');

  void _submitManual() {
    final d = _digits(_manualCtrl.text);
    if (d.length == 11) widget.onCodeEntered(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_EntryMode>(
          segments: const [
            ButtonSegment(value: _EntryMode.qr, icon: Icon(Icons.qr_code_scanner, size: 16), label: Text('QR Code')),
            ButtonSegment(
              value: _EntryMode.manual,
              icon: Icon(Icons.dialpad_outlined, size: 16),
              label: Text('Manual Code'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 16),
        if (_mode == _EntryMode.qr) _buildQrTab(context, cs),
        if (_mode == _EntryMode.manual) _buildManualTab(context, cs),
      ],
    );
  }

  Widget _buildQrTab(BuildContext context, ColorScheme cs) {
    final scanned  = widget.parsed != null;
    final scanColor = scanned ? const Color(0xFF34A853) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: widget.onScan,
          icon: widget.parsing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(scanned ? Icons.check_circle_outline : Icons.qr_code_scanner, color: scanColor),
          label: Text(scanned ? 'QR scanned ✓' : 'Scan QR code', style: TextStyle(color: scanColor)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: scanned ? const Color(0xFF34A853) : Colors.white54)),
        ),

        if (scanned && widget.rawPayload != null) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: QrImageView(data: widget.rawPayload!, size: 88),
              ),
              const SizedBox(width: 14),
              if (widget.onViewDetails != null)
                OutlinedButton.icon(
                  onPressed: widget.onViewDetails,
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('View details'),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ],
          ),
        ],

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('or paste payload', style: TextStyle(fontSize: 12)),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),

        TextField(
          controller: _qrCtrl,
          decoration: InputDecoration(
            labelText: 'Setup payload string',
            hintText: 'MT:Y.K9042C00KA0648G00',
            prefixIcon: const Icon(Icons.content_paste_outlined),
            border: const OutlineInputBorder(),
            errorText: widget.parseError,
            suffixIcon: _qrCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _qrCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onCodeEntered(v.trim());
          },
          onChanged: (v) => setState(() {}),
        ),
        if (_qrCtrl.text.trim().isNotEmpty && widget.parsed == null && !widget.parsing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonal(
              onPressed: () => widget.onCodeEntered(_qrCtrl.text.trim()),
              child: const Text('Parse payload'),
            ),
          ),
      ],
    );
  }

  Widget _buildManualTab(BuildContext context, ColorScheme cs) {
    final digits  = _digits(_manualCtrl.text);
    final ready   = digits.length == 11;
    final hasError = widget.parseError != null && !widget.parsing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the 11-digit code printed on the device or its packaging.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _manualCtrl,
          decoration: InputDecoration(
            labelText: 'Pairing code',
            hintText: '1234-567-8901',
            prefixIcon: const Icon(Icons.dialpad_outlined),
            border: const OutlineInputBorder(),
            errorText: hasError ? widget.parseError : null,
            counterText: '${digits.length}/11',
            suffixIcon: _manualCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _manualCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [_ManualCodeFormatter()],
          style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 4),
          textAlign: TextAlign.center,
          onChanged: (v) {
            setState(() {});
            if (_digits(v).length == 11) _submitManual();
          },
          onSubmitted: (_) => _submitManual(),
        ),
        const SizedBox(height: 12),
        if (widget.parsing)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),
          )
        else if (widget.parsed != null) ...[
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF34A853)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Code recognised — ${widget.parsed!.suggestedName}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF34A853)),
                ),
              ),
            ],
          ),
        ] else if (ready && !widget.parsing) ...[
          FilledButton.tonal(onPressed: _submitManual, child: const Text('Verify code')),
        ],
      ],
    );
  }
}

// ── TextInputFormatter for XXXXX-XXXXXX manual codes ─────────────────────────

class _ManualCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text
        .replaceAll(RegExp('[^0-9]'), '')
        .substring(0, newValue.text.replaceAll(RegExp('[^0-9]'), '').length.clamp(0, 11));
    if (digits.isEmpty) return TextEditingValue.empty;
    final String formatted;
    if (digits.length <= 4) {
      formatted = digits;
    } else if (digits.length <= 7) {
      formatted = '${digits.substring(0, 4)}-${digits.substring(4)}';
    } else {
      formatted = '${digits.substring(0, 4)}-${digits.substring(4, 7)}-${digits.substring(7)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
