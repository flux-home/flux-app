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

  static const _kHost        = 'ctrl_host';
  static const _kPort        = 'ctrl_port';
  static const _kPsk         = 'ctrl_psk';          // hex32 keyed by controller ID
  static const _kDtlsId      = 'ctrl_dtls_id';      // DTLS identity — same as controller ID
  static const _kRzvUrl      = 'ctrl_rzv_url';      // rendezvous URL keyed by controller ID (ADR-0006)

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

  /// True when at least one controller PSK has been stored — i.e. a hub has
  /// been set up at some point, even if it is currently unreachable. Lets the
  /// UI distinguish "no hub configured yet" from "hub configured but offline".
  static Future<bool> hasAnyPsk() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().any((k) => k.startsWith('${_kPsk}_'));
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

  /// Removes the stored PSK for [hostname] (reverts to plain CoAP).
  static Future<void> clearPsk(String hostname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_kPsk}_$hostname');
  }

  /// The DTLS identity stored for [controllerId] (defaults to the id itself).
  static Future<String> loadDtlsId(String controllerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_kDtlsId}_$controllerId') ?? controllerId;
  }

  /// Rendezvous URL for off-LAN signaling (ADR-0006), per controller.
  static Future<void> saveRendezvousUrl(String controllerId, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_kRzvUrl}_$controllerId', url);
  }

  static Future<String?> loadRendezvousUrl(String controllerId) async {
    final prefs = await SharedPreferences.getInstance();
    final u = prefs.getString('${_kRzvUrl}_$controllerId');
    return (u == null || u.isEmpty) ? null : u;
  }

  /// The controller ID of the (first) paired hub — the key used for the remote
  /// path when LAN discovery is unavailable. Null if no hub is configured.
  static Future<String?> firstControllerId() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().firstWhere(
        (k) => k.startsWith('${_kPsk}_'), orElse: () => '');
    return key.isEmpty ? null : key.substring('${_kPsk}_'.length);
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
