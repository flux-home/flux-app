import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/matter_channel.dart';

// ── Route args ────────────────────────────────────────────────────────────────

class QrPayloadDetailArgs {
  final String       rawPayload;
  final ParsedPayload parsed;
  const QrPayloadDetailArgs({required this.rawPayload, required this.parsed});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class QrPayloadDetailScreen extends StatelessWidget {
  final QrPayloadDetailArgs args;
  const QrPayloadDetailScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    final p    = args.parsed;

    return Scaffold(
      appBar: AppBar(title: const Text('QR Payload Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── QR image ────────────────────────────────────────────────
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: args.rawPayload,
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Raw payload ─────────────────────────────────────────────
            _Section(
              label: 'Raw payload',
              child: _CopyableRow(
                value: args.rawPayload,
                style: tt.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Identifiers ─────────────────────────────────────────────
            _Section(
              label: 'Device identifiers',
              child: Column(
                children: [
                  _FieldRow('Vendor ID',
                      '0x${p.vendorId.toRadixString(16).padLeft(4,'0').toUpperCase()}'
                      '  (${p.vendorId})'),
                  _FieldRow('Product ID',
                      '0x${p.productId.toRadixString(16).padLeft(4,'0').toUpperCase()}'
                      '  (${p.productId})'),
                  _FieldRow(
                    'Discriminator',
                    '${p.discriminator}'
                    '${p.hasShortDiscriminator ? '  (short, 4-bit)' : '  (long, 12-bit)'}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Setup PIN ───────────────────────────────────────────────
            _Section(
              label: 'Setup PIN code',
              child: _PinRow(pin: p.setupPinCode),
            ),

            const SizedBox(height: 20),

            // ── Discovery capabilities ──────────────────────────────────
            _Section(
              label: 'Discovery capabilities',
              child: p.discoveryCapabilities.isEmpty
                  ? Text('None advertised',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: p.discoveryCapabilities
                          .map((c) => _CapabilityChip(c))
                          .toList(),
                    ),
            ),

            const SizedBox(height: 20),

            // ── Commissioning hint ──────────────────────────────────────
            _Section(
              label: 'Commissioning',
              child: _CommissionHint(parsed: p),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            )),
        const SizedBox(height: 8),
        Card(
          color: cs.surfaceContainerHighest,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: child,
          ),
        ),
      ],
    );
  }
}

// ── Copyable row (raw payload) ────────────────────────────────────────────────

class _CopyableRow extends StatelessWidget {
  final String value;
  final TextStyle? style;
  const _CopyableRow({required this.value, this.style});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(value, style: style)),
      IconButton(
        icon: const Icon(Icons.copy_outlined, size: 18),
        tooltip: 'Copy',
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard'),
                duration: Duration(seconds: 1)),
          );
        },
      ),
    ],
  );
}

// ── Key-value field row ───────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  const _FieldRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}

// ── Setup PIN row (masked / reveal) ──────────────────────────────────────────

class _PinRow extends StatefulWidget {
  final int pin;
  const _PinRow({required this.pin});
  @override
  State<_PinRow> createState() => _PinRowState();
}

class _PinRowState extends State<_PinRow> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final pinStr  = widget.pin.toString().padLeft(8, '0');
    final display = _visible ? pinStr : '••••••••';

    return Row(
      children: [
        Text(display,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              letterSpacing: _visible ? 3 : 1,
              color: _visible ? cs.onSurface : cs.onSurfaceVariant,
            )),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(_visible ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                     size: 18),
          tooltip: _visible ? 'Hide' : 'Reveal',
          onPressed: () => setState(() => _visible = !_visible),
        ),
        if (_visible)
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            tooltip: 'Copy PIN',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pinStr));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN copied'),
                    duration: Duration(seconds: 1)),
              );
            },
          ),
      ],
    );
  }
}

// ── Discovery capability chip ─────────────────────────────────────────────────

class _CapabilityChip extends StatelessWidget {
  final DiscoveryCapability cap;
  const _CapabilityChip(this.cap);

  static const _labels = <DiscoveryCapability, String>{
    DiscoveryCapability.ble:         'BLE',
    DiscoveryCapability.onNetwork:   'On-Network (IP)',
    DiscoveryCapability.softAp:      'Soft AP',
    DiscoveryCapability.wifiPaf:     'Wi-Fi PAF',
    DiscoveryCapability.nfc:         'NFC',
    DiscoveryCapability.unknown:     'Unknown',
  };

  static const _icons = <DiscoveryCapability, IconData>{
    DiscoveryCapability.ble:       Icons.bluetooth,
    DiscoveryCapability.onNetwork: Icons.lan_outlined,
    DiscoveryCapability.softAp:    Icons.wifi_tethering_outlined,
    DiscoveryCapability.wifiPaf:   Icons.wifi_outlined,
    DiscoveryCapability.nfc:       Icons.nfc_outlined,
    DiscoveryCapability.unknown:   Icons.help_outline,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(_icons[cap] ?? Icons.help_outline, size: 16,
                   color: cs.onSecondaryContainer),
      label: Text(_labels[cap] ?? cap.name),
      labelStyle: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: cs.onSecondaryContainer),
      backgroundColor: cs.secondaryContainer,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ── Commissioning method hint ─────────────────────────────────────────────────

class _CommissionHint extends StatelessWidget {
  final ParsedPayload parsed;
  const _CommissionHint({required this.parsed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    String method;
    IconData icon;
    String detail;

    if (parsed.hasBle && parsed.hasOnNetwork) {
      method = 'BLE preferred, IP available';
      icon   = Icons.bluetooth;
      detail = 'This device supports both BLE and IP commissioning. '
               'BLE is recommended for first-time setup.';
    } else if (parsed.hasBle) {
      method = 'BLE only';
      icon   = Icons.bluetooth;
      detail = 'This device must be commissioned over Bluetooth LE.';
    } else if (parsed.hasOnNetwork) {
      method = 'IP / On-Network only';
      icon   = Icons.lan_outlined;
      detail = 'This device is already on the network and must be '
               'commissioned over IP.';
    } else {
      method = 'Unknown';
      icon   = Icons.help_outline;
      detail = 'No known discovery capability advertised.';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(method, style: tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 2),
              Text(detail, style: tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
