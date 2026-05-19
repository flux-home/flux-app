/// Parses a hex string (optionally prefixed with "0x" or "0X") into an [int].
/// Returns null if [raw] is null, empty, or not valid hex.
int? parseHexId(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final s = (raw.startsWith('0x') || raw.startsWith('0X')) ? raw.substring(2) : raw;
  return int.tryParse(s, radix: 16);
}
