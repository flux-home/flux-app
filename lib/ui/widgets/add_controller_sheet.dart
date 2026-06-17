import 'package:flutter/material.dart';
import 'package:matter_home/ui/screens/qr_scanner_screen.dart';

/// Bottom sheet for pairing a Flux Controller: scan its QR code, or enter
/// the 32-hex-character PSK manually. Pops with the raw scan/PSK string, or
/// null if dismissed.
class AddControllerSheet extends StatefulWidget {
  const AddControllerSheet({super.key});

  @override
  State<AddControllerSheet> createState() => _AddControllerSheetState();
}

class _AddControllerSheetState extends State<AddControllerSheet> {
  final _hexCtrl   = TextEditingController();
  bool  _showManual = false;

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  void _confirmHex() {
    final hex = _hexCtrl.text.replaceAll(RegExp(r'\s'), '');
    if (hex.isNotEmpty) Navigator.of(context).pop(hex);
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final hexLen = _hexCtrl.text.replaceAll(RegExp(r'\s'), '').length;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: cs.onSurface.withAlpha(40),
                borderRadius: BorderRadius.circular(2)),
          )),

          Text('Add Controller',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Scan the QR code on the controller label to connect securely.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _scanQr,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            label: const Text('Scan QR code'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
          ),

          const SizedBox(height: 12),

          if (!_showManual)
            TextButton(
              onPressed: () => setState(() => _showManual = true),
              child: const Text('Enter PSK manually'),
            )
          else ...[
            TextField(
              controller: _hexCtrl,
              autofocus: true,
              keyboardType: TextInputType.text,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'e.g. a1b2c3d4e5f60718…',
                labelText: 'PSK (32 hex characters)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                counterText: '$hexLen / 32',
              ),
              maxLength: 36,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirmHex(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: hexLen == 32 ? _confirmHex : null,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('Confirm'),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
