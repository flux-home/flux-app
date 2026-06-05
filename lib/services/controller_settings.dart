import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Optional manual IP override for the Flux Controller.
///
/// The primary discovery path is mDNS ([FluxControllerDiscovery]).
/// This is only consulted when mDNS times out — useful on networks where
/// multicast is blocked or the user is on a different subnet.
class ControllerSettings {
  const ControllerSettings({required this.host, required this.port});

  final String host;
  final int    port;

  static const _kHost   = 'ctrl_host';
  static const _kPort   = 'ctrl_port';
  static const _kPsk    = 'ctrl_psk';     // hex32 keyed by controller ID
  static const _kDtlsId = 'ctrl_dtls_id'; // DTLS identity — same as controller ID, stored for clarity

  static Future<ControllerSettings?> loadManualOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final host  = prefs.getString(_kHost);
    if (host == null || host.isEmpty) return null;
    return ControllerSettings(host: host, port: prefs.getInt(_kPort) ?? 5684);
  }

  /// Returns the stored PSK for the given controller [hostname], or null if
  /// no PSK has been configured (plain CoAP — migration phase).
  static Future<Uint8List?> loadPsk(String hostname) async {
    final prefs = await SharedPreferences.getInstance();
    final hex   = prefs.getString('${_kPsk}_$hostname');
    if (hex == null || hex.length != 32) return null;
    try {
      return Uint8List.fromList(List.generate(
          16, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
    } on FormatException catch (_) { return null; }
  }

  /// Persists a 16-byte [psk] for [hostname].
  static Future<void> savePsk(String hostname, Uint8List psk,
      {String? dtlsIdentity}) async {
    assert(psk.length == 16, 'PSK must be exactly 16 bytes');
    final prefs = await SharedPreferences.getInstance();
    final hex = psk.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString('${_kPsk}_$hostname', hex);
    if (dtlsIdentity != null) {
      await prefs.setString('${_kDtlsId}_$hostname', dtlsIdentity);
    }
  }

  /// Returns the stored DTLS identity for [hostname], or null.
  static Future<String?> loadDtlsIdentity(String hostname) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_kDtlsId}_$hostname');
  }

  /// Removes the stored PSK for [hostname] (reverts to plain CoAP).
  static Future<void> clearPsk(String hostname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_kPsk}_$hostname');
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHost, host);
    await prefs.setInt   (_kPort, port);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHost);
    await prefs.remove(_kPort);
  }
}
