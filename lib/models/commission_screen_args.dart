/// Arguments passed to the `/commission` route when the target device was
/// already discovered on the network (e.g. from the Matter Settings nearby
/// list).
///
/// When present, [CommissionScreen] skips DNS-SD re-discovery and
/// commissions directly via IP using [ipAddress] + [port] +
/// [discriminator], deriving the setup PIN from [setupCode].
class CommissionScreenArgs {
  const CommissionScreenArgs({
    required this.setupCode,
    required this.ipAddress,
    this.port = 5540,
    this.discriminator = 0,
  });

  /// QR payload ("MT:…") or 11-digit manual pairing code.
  final String setupCode;

  /// IP address from mDNS discovery — used directly instead of re-running
  /// DNS-SD inside the commission flow.
  final String ipAddress;

  final int port;

  /// Discriminator from mDNS discovery.  Used to verify the correct device
  /// is being addressed when multiple devices share an IP subnet.
  final int discriminator;
}
