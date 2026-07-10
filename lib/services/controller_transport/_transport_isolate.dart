import 'dart:async';
import 'dart:isolate';

import 'package:matter_home/services/controller_transport/controller_transport.dart';
import 'package:matter_home/services/controller_transport/in_process_transport.dart';

// ── Isolate wire protocol ─────────────────────────────────────────────────────
// All messages are plain data (sendable across isolate ports). The isolate
// hosts an InProcessTransport (the real CoAP/DTLS client) and marshals commands
// to it, so the DTLS handshake/crypto runs off the UI isolate.

class TransportInit {
  const TransportInit(this.replyPort, this.endpoint);
  final SendPort replyPort;
  final FluxControllerEndpoint endpoint;
}

/// Isolate → main handshake: the command port to send requests to, and whether
/// the CoAP client was built successfully.
class TransportReady {
  const TransportReady(this.commandPort, this.ok);
  final SendPort commandPort;
  final bool ok;
}

class ReqMsg {
  const ReqMsg(this.id, this.request);
  final int id;
  final TransportRequest request;
}

class RespMsg {
  const RespMsg(this.id, this.response);
  final int id;
  final TransportResponse response;
}

class ObserveMsg {
  const ObserveMsg(this.observeId, this.path, this.query);
  final int observeId;
  final String path;
  final Map<String, String>? query;
}

class EventMsg {
  const EventMsg(this.observeId, this.event);
  final int observeId;
  final TransportEvent event;
}

class CancelObserveMsg {
  const CancelObserveMsg(this.observeId);
  final int observeId;
}

class ReconnectMsg {
  const ReconnectMsg(this.id);
  final int id;
}

class DoneMsg {
  const DoneMsg(this.id);
  final int id;
}

class DisposeMsg {
  const DisposeMsg();
}

/// Isolate entrypoint (top-level for `Isolate.spawn`). Owns the CoAP/DTLS client
/// via an [InProcessTransport] and services messages from the main isolate.
Future<void> transportIsolateEntry(TransportInit init) async {
  final commands = ReceivePort();

  InProcessTransport transport;
  try {
    transport = InProcessTransport(init.endpoint);
  } on Object {
    init.replyPort.send(TransportReady(commands.sendPort, false));
    commands.close();
    return;
  }
  init.replyPort.send(TransportReady(commands.sendPort, true));

  final observes = <int, StreamSubscription<TransportEvent>>{};

  await for (final msg in commands) {
    if (msg is ReqMsg) {
      transport.request(msg.request).then(
          (resp) => init.replyPort.send(RespMsg(msg.id, resp)),
          onError: (_) =>
              init.replyPort.send(RespMsg(msg.id, TransportResponse.unreachable)));
    } else if (msg is ObserveMsg) {
      observes[msg.observeId] = transport
          .observe(msg.path, query: msg.query)
          .listen((ev) => init.replyPort.send(EventMsg(msg.observeId, ev)));
    } else if (msg is CancelObserveMsg) {
      await observes.remove(msg.observeId)?.cancel();
    } else if (msg is ReconnectMsg) {
      await transport.reconnect();
      init.replyPort.send(DoneMsg(msg.id));
    } else if (msg is DisposeMsg) {
      for (final s in observes.values) {
        await s.cancel();
      }
      await transport.dispose();
      commands.close();
      break;
    }
  }
}
