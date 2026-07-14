// On-device E2E for the OFF-LAN remote path (app-0003): the full FSM remote
// branch through the rendezvous, exactly as HubConnection._tryRemote() runs it.
//
//   1. HubConnection.connectViaRemoteTunnel(signalOffer: FluxRendezvous.signalOffer)
//      - native gather (host + srflx via stun.l.google.com)
//      - POST MAC'd offer to the rendezvous mailbox
//      - controller long-poll picks it up, answers into the mailbox
//      - app polls the answer, feeds it, ICE connects
//   2. CoAP GET /info through the loopback tunnel -> real ControllerInfo
//
//   flutter test integration_test/flux_rendezvous_tunnel_test.dart -d <deviceId>
//
// Requires: rendezvous server reachable at _rendezvousUrl, and the controller's
// /remote/config pointed at the same URL with enabled=true.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matter_home/services/flux_rendezvous.dart';
import 'package:matter_home/services/hub_connection.dart';

// Override for the across-NAT run with:
//   --dart-define=RZV_URL=http://[<public-ipv6>]:8080
const _rendezvousUrl =
    String.fromEnvironment('RZV_URL', defaultValue: 'http://192.168.1.144:8080');
const _identity = 'flux-controller-e25311';
final _psk = Uint8List.fromList([
  0x2c, 0x15, 0x25, 0xa8, 0xcd, 0xf4, 0x09, 0x08,
  0xdb, 0x38, 0x0e, 0x07, 0x0a, 0xd9, 0x23, 0x5e,
]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('remote FSM via rendezvous: offer -> answer -> connect -> CoAP',
      (tester) async {
    final rzv = FluxRendezvous(baseUrl: _rendezvousUrl, psk: _psk);
    // ignore: avoid_print
    print('rendezvous mailbox = ${rzv.mailbox}');

    final hub = HubConnection(null);
    final ok = await hub.connectViaRemoteTunnel(
      controllerPsk: _psk,
      signalOffer:   rzv.signalOffer,
      dtlsIdentity:  _identity,
      stunHost:      'stun.l.google.com',
      stunPort:      19302,
    );
    expect(ok, isTrue, reason: 'remote tunnel bring-up (FluxRendezvous) failed');

    // The tunnel is up and installed as the active service — read real info.
    final info = await hub.service!.getInfo();
    expect(info, isNotNull, reason: 'tunneled GET /info returned null');
    // ignore: avoid_print
    print('tunneled ControllerInfo: fw=${info!.firmwareVersion} '
        'host=${info.hostname} eth=${info.ethernetIp} up=${info.uptimeSeconds}s');
    expect(info.firmwareVersion, isNotEmpty);

    hub.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
