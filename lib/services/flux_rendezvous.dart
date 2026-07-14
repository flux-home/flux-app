import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// App-side rendezvous signaling client (flux-interface ADR-0004/0006).
///
/// Delivers the MAC-authenticated ICE offer to the user-hosted store-and-forward
/// mailbox and long-polls for the controller's answer. The mailbox is derived
/// from the shared PSK, so app and controller agree without any handshake; the
/// box only ever sees opaque, MAC-signed bytes (ADR-0003). Plain HTTP is fine —
/// the MAC, not TLS, is the signaling security boundary.
///
/// Pass [signalOffer] as the callback to `HubConnection.connectViaRemoteTunnel`.
class FluxRendezvous {
  FluxRendezvous({required this.baseUrl, required this.psk, this.onLog})
      : assert(psk.length == 16, 'PSK must be 16 bytes');

  final String baseUrl; // e.g. https://rzv.example.com  (no trailing slash needed)
  final Uint8List psk;

  /// Optional diagnostics sink — each signaling step is reported here (and to
  /// logcat) so an off-LAN attempt can be debugged from the phone screen.
  final void Function(String msg)? onLog;

  static const _pollAttempts   = 6;  // server long-polls ~25s each
  static const _postTimeout    = Duration(seconds: 30); // cellular cold-connect can be slow
  static const _pollTimeout    = Duration(seconds: 35); // > server long-poll (25s)

  /// mailbox = base32(HMAC-SHA256(psk, "flux-rendezvous-mailbox")), lowercase.
  late final String mailbox = _base32(
      Uint8List.fromList(Hmac(sha256, psk)
          .convert('flux-rendezvous-mailbox'.codeUnits)
          .bytes));

  String get _base => baseUrl.replaceAll(RegExp(r'/+$'), '');

  void _log(String m) {
    onLog?.call(m);
    debugPrint('flux-rzv: $m');
  }

  /// POST the offer, then long-poll for the answer SDP (null on failure).
  Future<String?> signalOffer(String offerSdp) async {
    final body = _buildIceSignal(offerSdp);
    _log('mailbox=${mailbox.substring(0, 8)}… POST offer → $_base');
    try {
      final post = await http
          .post(Uri.parse('$_base/$mailbox/offer'), body: body)
          .timeout(_postTimeout);
      if (post.statusCode ~/ 100 != 2) {
        _log('offer POST rejected: HTTP ${post.statusCode}');
        return null;
      }
      _log('offer POSTed (HTTP ${post.statusCode}); polling for answer…');
      for (var i = 0; i < _pollAttempts; i++) {
        final r = await http
            .get(Uri.parse('$_base/$mailbox/answer'))
            .timeout(_pollTimeout);
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
          _log('answer received (${r.bodyBytes.length} B)');
          return _decodeSdp(r.bodyBytes);
        }
        _log('poll ${i + 1}/$_pollAttempts: HTTP ${r.statusCode}, empty');
      }
      _log('no answer after $_pollAttempts polls (hub not answering?)');
    } on TimeoutException {
      _log('TIMEOUT reaching rendezvous — unreachable from this network?');
    } on Object catch (e) {
      _log('rendezvous unreachable: $e');
    }
    return null;
  }

  // ── IceSignal (proto) hand-encoding — matches the controller decode ───────
  // { sdp = 2 (string), mac = 3 (bytes), proto_version = 4 (uint32) }; kind
  // (field 1) omitted = OFFER (0), the proto3 default.

  Uint8List _buildIceSignal(String sdp) {
    final s = Uint8List.fromList(sdp.codeUnits);
    final b = BytesBuilder()
      ..add(_field(2, 2, data: s))
      ..add(_field(3, 2, data: _signalMac(0, s)))
      ..add(_field(4, 0, varint: 1));
    return b.toBytes();
  }

  /// mac = HMAC(HKDF-Expand(psk, "flux-remote-signal", 32), [kind] || sdp).
  Uint8List _signalMac(int kind, Uint8List sdp) {
    final key = _hkdfExpand(psk, 'flux-remote-signal'.codeUnits, 32);
    return Uint8List.fromList(
        Hmac(sha256, key).convert([kind, ...sdp]).bytes);
  }

  /// Extract field 2 (sdp) from an IceSignal answer.
  String _decodeSdp(Uint8List buf) {
    var i = 0;
    var sdp = '';
    while (i < buf.length) {
      final key = buf[i++];
      final tag = key >> 3;
      final wire = key & 7;
      if (wire == 0) {
        while (i < buf.length && buf[i] & 0x80 != 0) {
          i++;
        }
        i++;
      } else if (wire == 2) {
        var len = 0;
        var shift = 0;
        while (true) {
          final x = buf[i++];
          len |= (x & 0x7f) << shift;
          shift += 7;
          if (x & 0x80 == 0) break;
        }
        final val = buf.sublist(i, i + len);
        i += len;
        if (tag == 2) sdp = String.fromCharCodes(val);
      }
    }
    return sdp;
  }

  static Uint8List _hkdfExpand(List<int> prk, List<int> info, int len) {
    final out = <int>[];
    var t = <int>[];
    var c = 1;
    while (out.length < len) {
      t = Hmac(sha256, prk).convert([...t, ...info, c]).bytes;
      out.addAll(t);
      c++;
    }
    return Uint8List.fromList(out.sublist(0, len));
  }

  static Uint8List _vlq(int n) {
    final o = <int>[];
    var v = n;
    do {
      var x = v & 0x7f;
      v >>= 7;
      if (v != 0) x |= 0x80;
      o.add(x);
    } while (v != 0);
    return Uint8List.fromList(o);
  }

  static Uint8List _field(int tag, int wire, {List<int>? data, int? varint}) {
    final keyByte = (tag << 3) | wire;
    if (wire == 0) return Uint8List.fromList([keyByte, ..._vlq(varint!)]);
    return Uint8List.fromList([keyByte, ..._vlq(data!.length), ...data]);
  }

  static String _base32(Uint8List data) {
    const alpha = 'abcdefghijklmnopqrstuvwxyz234567'; // RFC4648 lowercase
    final out = StringBuffer();
    var buf = 0;
    var bits = 0;
    for (final b in data) {
      buf = (buf << 8) | b;
      bits += 8;
      while (bits >= 5) {
        out.write(alpha[(buf >> (bits - 5)) & 0x1f]);
        bits -= 5;
      }
    }
    if (bits > 0) out.write(alpha[(buf << (5 - bits)) & 0x1f]);
    return out.toString();
  }
}
