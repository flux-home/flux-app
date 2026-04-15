import 'package:matter_home/services/matter_channel.dart' show MatterChannel;

/// Device basic information from the Matter BasicInformation cluster (0x0028).
/// Returned by [MatterChannel.readBasicInfo].
class BasicInfo {

  const BasicInfo({
    required this.productName,
    required this.vendorName,
    required this.vendorId,
    required this.productId,
    required this.hwVersion,
    required this.softwareVersion,
    required this.softwareVersionNum,
    required this.manufacturingDate,
    required this.partNumber,
    required this.productUrl,
    required this.serialNumber,
    required this.uniqueId,
  });
  final String productName;
  final String vendorName;
  final String vendorId;          // pre-formatted "0xXXXX", empty if absent
  final String productId;         // pre-formatted "0xXXXX", empty if absent
  final String hwVersion;
  final String softwareVersion;   // human-readable string, e.g. "1.2.0"
  final int?   softwareVersionNum;// uint32 from SoftwareVersion attribute (for DCL comparison)
  final String manufacturingDate;
  final String partNumber;
  final String productUrl;
  final String serialNumber;
  final String uniqueId;

  /// Convenience: returns [value] when non-empty, otherwise null.
  static String? nonEmpty(String value) => value.isEmpty ? null : value;
}
