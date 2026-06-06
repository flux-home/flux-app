import 'package:flutter/foundation.dart' show immutable;

/// The result of opening an Enhanced Commissioning Mode (ECM) window on a device.
/// Contains everything needed to display a Matter sharing QR code + manual code.
@immutable
class ShareDeviceResult {
  const ShareDeviceResult({
    required this.qrCodePayload,
    required this.manualPairingCode,
    this.ipv6Address = '',
  });

  /// The Matter QR code payload string (e.g. "MT:Y.K90IRV01YZT0648G00").
  /// Pass directly to `QrImageView` from `qr_flutter`.
  final String qrCodePayload;

  /// The manual pairing code (11 or 21 digits) returned by the CHIP SDK
  /// (e.g. "36177801605").  Display this to users who cannot scan the QR code.
  final String manualPairingCode;

  /// Thread IPv6 address of the device at the time the ECW was opened.
  /// Populated by the Android bridge via `ChipDeviceController.getIpAddress()`.
  /// Empty string on iOS (not yet implemented) or if the SDK couldn't resolve it.
  /// When non-empty, the Flux Controller uses this to skip mDNS discovery and
  /// connect directly — bypassing the Ethernet/Thread mDNS namespace split.
  final String ipv6Address;

  /// Returns the manual pairing code as plain digits (no separators).
  String get formattedManualCode {
    final d = manualPairingCode.replaceAll(RegExp(r'\D'), '');
    if (d.length <= 4) return d;
    if (d.length <= 7) return '${d.substring(0, 4)}-${d.substring(4)}';
    return '${d.substring(0, 4)}-${d.substring(4, 7)}-${d.substring(7)}';
  }
}
