/// One entry from the OperationalCredentials Fabrics attribute (cluster 0x003E).
class FabricDescriptor {
  const FabricDescriptor({
    required this.fabricIndex,
    required this.fabricId,
    required this.nodeId,
    required this.vendorId,
    required this.label,
  });

  final int    fabricIndex; // 1-based index on the device
  final String fabricId;    // pre-formatted "0x…"
  final String nodeId;      // pre-formatted "0x…"
  final String vendorId;    // pre-formatted "0xXXXX"
  final String label;       // user-set label, may be empty

  factory FabricDescriptor.fromMap(Map<dynamic, dynamic> m) =>
      FabricDescriptor(
        fabricIndex: (m['fabricIndex'] as num).toInt(),
        fabricId:    m['fabricId']  as String? ?? '',
        nodeId:      m['nodeId']    as String? ?? '',
        vendorId:    m['vendorId']  as String? ?? '',
        label:       m['label']     as String? ?? '',
      );
}
