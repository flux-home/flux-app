/// A Matter device discovered on the local network via DNS-SD (_matterc._udp).
///
/// Fields mirror [DiscoveredDevice.java] from the CHIP SDK.
class CommissionableDevice {
  const CommissionableDevice({
    required this.discriminator,
    required this.ipAddress,
    required this.port,
    required this.deviceType,
    required this.vendorId,
    required this.productId,
    required this.commissioningMode,
    required this.deviceName,
    required this.instanceName,
  });

  final int    discriminator;
  final String ipAddress;
  final int    port;
  final int    deviceType;
  final int    vendorId;
  final int    productId;
  /// Raw enum name from the SDK: "EnhancedWindowOpen", "BasicWindowOpen",
  /// or "WindowNotOpen".
  final String commissioningMode;
  final String deviceName;
  final String instanceName;

  bool get isEnhanced => commissioningMode == 'EnhancedWindowOpen';
  bool get isBasic    => commissioningMode == 'BasicWindowOpen';

  String get displayName =>
      deviceName.isNotEmpty ? deviceName : 'Unknown device';

  String get modeLabel => switch (commissioningMode) {
    'EnhancedWindowOpen' => 'Enhanced',
    'BasicWindowOpen'    => 'Basic',
    _                    => 'Not open',
  };

  factory CommissionableDevice.fromMap(Map<String, dynamic> m) =>
      CommissionableDevice(
        discriminator:    (m['discriminator']  as num).toInt(),
        ipAddress:         m['ipAddress']       as String? ?? '',
        port:             (m['port']            as num).toInt(),
        deviceType:       (m['deviceType']      as num).toInt(),
        vendorId:         (m['vendorId']        as num).toInt(),
        productId:        (m['productId']       as num).toInt(),
        commissioningMode: m['commissioningMode'] as String? ?? 'WindowNotOpen',
        deviceName:        m['deviceName']       as String? ?? '',
        instanceName:      m['instanceName']     as String? ?? '',
      );
}
