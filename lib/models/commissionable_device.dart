import 'package:matter_home/services/matter_vendors.dart';

/// A Matter device discovered on the local network via DNS-SD (_matterc._udp).
///
/// Fields mirror [DiscoveredDevice.java] from the CHIP SDK, extended with
/// the PH (pairing hint) and ICD TXT keys.
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
    required this.pairingHint,
    required this.isIcd,
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
  /// PH TXT key — pairing hint bitmask.  0 when absent.
  final int    pairingHint;
  /// True when the ICD TXT key equals "1" (sleepy / battery device).
  final bool   isIcd;

  bool get isEnhanced => commissioningMode == 'EnhancedWindowOpen';
  bool get isBasic    => commissioningMode == 'BasicWindowOpen';
  bool get isOpen     => isEnhanced || isBasic;

  /// Human-readable vendor name, or null when VID is absent / unknown.
  String? get vendorName => vendorId > 0 ? kMatterVendors[vendorId] : null;

  /// Best available display name: vendor name, then DN, then "Unknown device".
  String get displayName {
    final vendor = vendorName;
    if (vendor != null && vendor.isNotEmpty) {
      return deviceName.isNotEmpty ? '$vendor — $deviceName' : vendor;
    }
    return deviceName.isNotEmpty ? deviceName : 'Unknown device';
  }

  String get modeLabel => switch (commissioningMode) {
    'EnhancedWindowOpen' => 'Enhanced',
    'BasicWindowOpen'    => 'Basic',
    _                    => 'Not open',
  };

  /// Decodes the PH bitmask into a short, user-facing instruction.
  /// Returns null when no known bits are set.
  ///
  /// Bit assignments per Matter Core spec §4.3.1 Table 4-3.
  String? get pairingHintText {
    if (pairingHint == 0) return null;
    // Ordered from most specific to least — return the first match.
    const bits = <int, String>{
      0x0008: 'Press the reset button',
      0x0200: 'Hold reset button until LED changes',
      0x0400: 'Hold reset button until LED blinks',
      0x0010: 'Press the setup button',
      0x0800: 'Hold setup button until LED changes',
      0x1000: 'Hold setup button until LED blinks',
      0x0001: 'Power cycle the device',
      0x0040: 'Device restarts automatically',
      0x0080: 'Follow manufacturer instructions',
    };
    for (final entry in bits.entries) {
      if (pairingHint & entry.key != 0) return entry.value;
    }
    return null;
  }

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
        pairingHint:      (m['pairingHint']      as num?)?.toInt() ?? 0,
        isIcd:             m['isIcd']            as bool? ?? false,
      );
}
