import 'package:flutter/foundation.dart' show immutable;

/// The result of opening an Enhanced Commissioning Mode (ECM) window on a device.
/// Contains everything needed to display a Matter sharing QR code + manual code.
@immutable
class ShareDeviceResult {
  const ShareDeviceResult({
    required this.qrCodePayload,
    required this.manualPairingCode,
  });

  /// The Matter QR code payload string (e.g. "MT:Y.K90IRV01YZT0648G00").
  /// Pass directly to `QrImageView` from `qr_flutter`.
  final String qrCodePayload;

  /// The 11-digit manual pairing code returned by the CHIP SDK
  /// (e.g. "36177801605").  Display this to users who cannot scan the QR code.
  final String manualPairingCode;

  /// Returns the manual pairing code as plain digits (no separators).
  String get formattedManualCode {
    final d = manualPairingCode.replaceAll(RegExp(r'\D'), '');
    if (d.length <= 4) return d;
    if (d.length <= 7) return '${d.substring(0, 4)}-${d.substring(4)}';
    return '${d.substring(0, 4)}-${d.substring(4, 7)}-${d.substring(7)}';
  }
}
