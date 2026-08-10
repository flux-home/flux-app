import 'package:flutter/foundation.dart' show immutable;

/// A saved Thread Operational Dataset entry.
///
/// [hex] is a raw TLV hex string (whitespace is stripped before use).
/// When [hex] is empty the entry represents the "Empty dataset" option:
/// commission the device onto Thread without pre-configuring credentials —
/// the device will acquire an active dataset from a border router via MeshCoP.
@immutable
class ThreadDataset {
  // TLV hex; '' = empty / no credentials

  const ThreadDataset({required this.label, required this.hex});

  factory ThreadDataset.fromJson(Map<String, dynamic> m) =>
      ThreadDataset(label: m['label'] as String? ?? '', hex: m['hex'] as String? ?? '');
  final String label; // user-visible name
  final String hex;

  /// True when this entry represents the "Empty dataset" option.
  bool get isEmpty => hex.trim().isEmpty;

  /// Built-in sentinel for "no Thread credentials".
  static const empty = ThreadDataset(label: 'Empty dataset', hex: '');

  Map<String, dynamic> toJson() => {'label': label, 'hex': hex};

  /// Two datasets are equal when their stripped hexes match.
  @override
  bool operator ==(Object other) =>
      other is ThreadDataset && other.hex.replaceAll(RegExp(r'\s'), '') == hex.replaceAll(RegExp(r'\s'), '');

  @override
  int get hashCode => hex.replaceAll(RegExp(r'\s'), '').hashCode;
}
