// On-device E2E for the flux-ice remote-access tunnel (app-0001 spike).
//
// Runs on a real Android device on the same LAN as the controller:
//   1. FluxIceChannel.start()  -> native JNI -> libjuice gathers -> offer SDP
//   2. POST the MAC'd offer to the controller's /remote/signal (DTLS-PSK)
//   3. session.setAnswer(controllerAnswer) -> ICE connects
//   4. CoAP GET /info through the loopback tunnel -> real response
//
//   flutter test integration_test/flux_ice_tunnel_test.dart -d <deviceId>
//
// Controller: unprovisioned -> well-known default PSK.
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matter_home/services/controller_transport/controller_transport.dart';
import 'package:matter_home/services/controller_transport/in_process_transport.dart';
import 'package:matter_home/services/flux_ice_channel.dart';

const _controllerHost = '192.168.1.134';
const _identity = 'flux-controller-e25311';
final _psk = Uint8List.fromList([
  0x2c, 0x15, 0x25, 0xa8, 0xcd, 0xf4, 0x09, 0x08,
  0xdb, 0x38, 0x0e, 0x07, 0x0a, 0xd9, 0x23, 0x5e,
]);

// ── protobuf hand-encoding (IceSignal isn't in the app's generated proto) ──
Uint8List _vlq(int n) {
  final b = <int>[];
  var v = n;
  do {
    var x = v & 0x7f;
    v >>= 7;
    if (v != 0) x |= 0x80;
    b.add(x);
  } while (v != 0);
  return Uint8List.fromList(b);
}

Uint8List _field(int tag, int wire, List<int> data, {int? varint}) {
  final key = (tag << 3) | wire;
  if (wire == 0) return Uint8List.fromList([key, ..._vlq(varint!)]);
  return Uint8List.fromList([key, ..._vlq(data.length), ...data]);
}

Uint8List _hkdfExpand(List<int> prk, List<int> info, int len) {
  final out = <int>[];
  var t = <int>[];
  var c = 1;
  while (out.length < len) {
    final h = Hmac(sha256, prk).convert([...t, ...info, c]);
    t = h.bytes;
    out.addAll(t);
    c++;
  }
  return Uint8List.fromList(out.sublist(0, len));
}

Uint8List _signalMac(int kind, List<int> sdp) {
  final key = _hkdfExpand(_psk, 'flux-remote-signal'.codeUnits, 32);
  return Uint8List.fromList(Hmac(sha256, key).convert([kind, ...sdp]).bytes);
}

Uint8List _buildOffer(String sdp) {
  final s = sdp.codeUnits;
  return Uint8List.fromList([
    ..._field(2, 2, s),                       // sdp
    ..._field(3, 2, _signalMac(0, s)),        // mac (kind OFFER=0)
    ..._field(4, 0, const [], varint: 1),     // proto_version
  ]);
}

/// Extract field 2 (sdp) from an IceSignal answer.
String _decodeAnswerSdp(Uint8List buf) {
  var i = 0;
  String sdp = '';
  while (i < buf.length) {
    final key = buf[i++];
    final tag = key >> 3;
    final wire = key & 7;
    if (wire == 0) {
      while (buf[i] & 0x80 != 0) {
        i++;
      }
      i++;
    } else if (wire == 2) {
      var len = 0, shift = 0;
      while (true) {
        final b = buf[i++];
        len |= (b & 0x7f) << shift;
        shift += 7;
        if (b & 0x80 == 0) break;
      }
      final val = buf.sublist(i, i + len);
      i += len;
      if (tag == 2) sdp = String.fromCharCodes(val);
    }
  }
  return sdp;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flux-ice remote tunnel: gather -> signal -> connect -> CoAP',
      (tester) async {
    // 1. Native gather (proves JNI -> libjuice on the real device).
    final session = await FluxIceChannel().start();
    expect(session, isNotNull, reason: 'flux_ice_mobile_start returned null');
    expect(session!.offer, contains('a=candidate'),
        reason: 'offer must carry a host candidate');

    // 2. Signal the offer to the controller.
    final signalTx = InProcessTransport(FluxControllerEndpoint(
      host: _controllerHost, port: 5684, psk: _psk, dtlsIdentity: _identity));
    final resp = await signalTx.request(TransportRequest(
      TransportMethod.post, 'remote/signal',
      body: _buildOffer(session.offer), timeoutMs: 25000));
    expect(resp.success, isTrue, reason: '/remote/signal must return 2.xx');
    final answer = _decodeAnswerSdp(resp.payload!);
    expect(answer, contains('a=candidate'));

    // 3. Feed the answer + wait for ICE.
    expect(await session.setAnswer(answer), isTrue);
    await session.awaitConnected(timeout: const Duration(seconds: 25));

    // 4. Real CoAP through the loopback tunnel.
    final port = await session.localPort();
    expect(port, greaterThan(0));
    final tunnelTx = InProcessTransport(FluxControllerEndpoint(
      host: '127.0.0.1', port: port, psk: _psk, dtlsIdentity: _identity));
    final info = await tunnelTx.request(
      TransportRequest(TransportMethod.get, 'info', timeoutMs: 15000));
    expect(info.success, isTrue, reason: 'tunneled GET /info must succeed');
    expect(info.payload, isNotNull);
    expect(info.payload!.isNotEmpty, isTrue);

    await session.stop();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
