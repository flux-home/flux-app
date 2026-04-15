import 'package:matter_home/services/matter_vendors.dart';

// ── Discovery capability ───────────────────────────────────────────────────

enum DiscoveryCapability { ble, onNetwork, softAp, wifiPaf, nfc, unknown }

// ── Parsed setup payload ───────────────────────────────────────────────────

class ParsedPayload {

  const ParsedPayload({
    required this.vendorId,
    required this.productId,
    required this.discriminator,
    required this.hasShortDiscriminator,
    required this.discoveryCapabilities,
    required this.setupPinCode,
  });
  final int vendorId;
  final int productId;
  final int discriminator;
  final bool hasShortDiscriminator;
  final List<DiscoveryCapability> discoveryCapabilities;

  /// Setup PIN code encoded in the QR payload (up to 27 bits).
  final int setupPinCode;

  bool get hasBle       => discoveryCapabilities.contains(DiscoveryCapability.ble);
  bool get hasOnNetwork => discoveryCapabilities.contains(DiscoveryCapability.onNetwork);
  bool get prefersBle   => hasBle;

  /// True when the payload did not encode any discovery capabilities
  /// (e.g. 11-digit manual pairing codes).  In that case both BLE and IP
  /// commissioning are potentially available and the user should choose.
  bool get capabilitiesUnknown => discoveryCapabilities.isEmpty;

  bool get canUseBle => hasBle || capabilitiesUnknown;
  bool get canUseIp  => hasOnNetwork || capabilitiesUnknown;

  /// Suggested device name derived from the vendor ID (CSA registry lookup).
  String get suggestedName => kMatterVendors[vendorId] ?? 'Unknown';
}

// ── Commission result ──────────────────────────────────────────────────────

class CommissionResult {

  const CommissionResult._({
    required this.success,
    this.nodeId,
    this.deviceTypeId,
    this.error,
  });

  factory CommissionResult.ok({required int nodeId, int? deviceTypeId}) =>
      CommissionResult._(success: true, nodeId: nodeId, deviceTypeId: deviceTypeId);

  factory CommissionResult.err(String error) =>
      CommissionResult._(success: false, error: error);
  final bool    success;
  final int?    nodeId;
  final int?    deviceTypeId;
  final String? error;
}

// ── Device state result ────────────────────────────────────────────────────

class DeviceStateResult {

  const DeviceStateResult({
    required this.isOnline,
    this.isOn,
    this.brightnessLevel,
  });
  final bool isOnline;
  final bool? isOn;
  final int?  brightnessLevel;
}
