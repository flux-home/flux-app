import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-controller credentials and remote-access settings, keyed by controller ID
/// (the mDNS hostname). Discovery itself is mDNS-only ([FluxControllerDiscovery]).
class ControllerSettings {
  static const _kPsk         = 'ctrl_psk';          // hex32 keyed by controller ID
  static const _kDtlsId      = 'ctrl_dtls_id';      // DTLS identity — same as controller ID
  static const _kRzvUrl      = 'ctrl_rzv_url';      // rendezvous URL keyed by controller ID (ADR-0006)
  static const _kStun        = 'ctrl_stun';         // STUN server "host:port" keyed by controller ID (ADR-0007)
  static const _kTurn        = 'ctrl_turn';         // TURN "host:port" keyed by controller ID (ADR-0004)
  static const _kTurnUser    = 'ctrl_turn_user';    // TURN username
  static const _kTurnPass    = 'ctrl_turn_pass';    // TURN credential


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

  /// Forgets one controller: removes every per-controller key (PSK, DTLS id,
  /// rendezvous URL, STUN/TURN) for [controllerId]. [clearPsk] alone left the
  /// DTLS id and remote-access config behind.
  static Future<void> clearController(String controllerId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _kPsk, _kDtlsId, _kRzvUrl, _kStun, _kTurn, _kTurnUser, _kTurnPass,
    ]) {
      await prefs.remove('${k}_$controllerId');
    }
  }

  /// Nukes every controller-related key (all `ctrl_*`): PSKs, DTLS ids,
  /// rendezvous URLs, STUN/TURN and the manual host/port override. Backs the
  /// "Remove controller" action's fallback so no orphaned key — e.g. a PSK the
  /// targeted clear missed because the live id was unknown — can keep the app
  /// believing a hub is still configured.
  static Future<void> clearAllControllers() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('ctrl_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
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

  /// STUN server ("host" or "host:port") for srflx gathering on the remote path
  /// (ADR-0007), per controller. Empty [server] clears it (falls back to the
  /// built-in Google default).
  static Future<void> saveStunServer(String controllerId, String server) async {
    final prefs = await SharedPreferences.getInstance();
    final s = server.trim();
    if (s.isEmpty) {
      await prefs.remove('${_kStun}_$controllerId');
    } else {
      await prefs.setString('${_kStun}_$controllerId', s);
    }
  }

  static Future<String?> loadStunServer(String controllerId) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('${_kStun}_$controllerId');
    return (s == null || s.isEmpty) ? null : s;
  }

  /// TURN relay (ADR-0004) for cross-NAT paths where srflx fails: server
  /// ("host" or "host:port") plus long-term credentials, per controller.
  static Future<void> saveTurn(String controllerId,
      {required String server, required String user, required String pass}) async {
    final prefs = await SharedPreferences.getInstance();
    Future<void> put(String k, String v) =>
        v.trim().isEmpty ? prefs.remove(k) : prefs.setString(k, v.trim());
    await put('${_kTurn}_$controllerId', server);
    await put('${_kTurnUser}_$controllerId', user);
    await put('${_kTurnPass}_$controllerId', pass);
  }

  /// Returns (server, user, pass); server is null when no TURN is configured.
  static Future<(String?, String?, String?)> loadTurn(String controllerId) async {
    final prefs = await SharedPreferences.getInstance();
    String? g(String k) {
      final v = prefs.getString('${k}_$controllerId');
      return (v == null || v.isEmpty) ? null : v;
    }
    return (g(_kTurn), g(_kTurnUser), g(_kTurnPass));
  }

  /// The controller ID of the (first) paired hub — the key used for the remote
  /// path when LAN discovery is unavailable. Null if no hub is configured.
  static Future<String?> firstControllerId() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().firstWhere(
        (k) => k.startsWith('${_kPsk}_'), orElse: () => '');
    return key.isEmpty ? null : key.substring('${_kPsk}_'.length);
  }

}
