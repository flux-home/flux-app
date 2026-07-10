import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:matter_home/services/controller_transport/_transport_isolate.dart';
import 'package:matter_home/services/controller_transport/controller_transport.dart';
import 'package:matter_home/services/controller_transport/in_process_transport.dart';

/// [ControllerTransport] that runs the CoAP/DTLS client on a **background
/// isolate**, so the DTLS handshake/crypto can never block the UI thread.
///
/// If the isolate fails to start (or dies), it transparently degrades to an
/// in-process client — functionally identical to before, never worse.
class IsolateTransport implements ControllerTransport {
  IsolateTransport(this.endpoint) {
    unawaited(_spawn());
  }

  final FluxControllerEndpoint endpoint;

  final _ready = Completer<void>();
  Isolate?  _isolate;
  SendPort? _cmd;                       // set when the isolate is usable
  InProcessTransport? _fallback;        // set when we degrade to in-process
  bool _disposed = false;

  int _nextId = 0;
  int _nextObserveId = 0;
  final _pending      = <int, Completer<TransportResponse>>{};
  final _reconnects   = <int, Completer<void>>{};
  final _observeCtrls = <int, StreamController<TransportEvent>>{};

  Future<void> _spawn() async {
    final rx = ReceivePort();
    rx.listen(_onMessage);
    final errors = ReceivePort()..listen((_) => _degrade('isolate error'));
    final exits  = ReceivePort()..listen((_) => _degrade('isolate exit'));
    try {
      _isolate = await Isolate.spawn(
        transportIsolateEntry,
        TransportInit(rx.sendPort, endpoint),
        onError: errors.sendPort,
        onExit:  exits.sendPort,
        debugName: 'flux-controller-transport',
      );
    } on Object catch (e) {
      _degrade('spawn failed: $e');
    }
  }

  void _onMessage(dynamic msg) {
    if (msg is TransportReady) {
      if (msg.ok) {
        _cmd = msg.commandPort;
        if (!_ready.isCompleted) _ready.complete();
      } else {
        _degrade('isolate reported client build failure');
      }
    } else if (msg is RespMsg) {
      _pending.remove(msg.id)?.complete(msg.response);
    } else if (msg is EventMsg) {
      final c = _observeCtrls[msg.observeId];
      if (c == null || c.isClosed) return;
      c.add(msg.event);
      if (msg.event.kind == TransportEventKind.done) {
        _observeCtrls.remove(msg.observeId);
        c.close();
      }
    } else if (msg is DoneMsg) {
      _reconnects.remove(msg.id)?.complete();
    }
  }

  /// Fall back to an in-process client and fail-forward everything in flight.
  void _degrade(String reason) {
    if (_disposed || _fallback != null) return;
    debugPrint('IsolateTransport: degrading to in-process ($reason)');
    _fallback = InProcessTransport(endpoint);
    _cmd = null;
    if (!_ready.isCompleted) _ready.complete();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(TransportResponse.unreachable);
    }
    _pending.clear();
    for (final c in _reconnects.values) {
      if (!c.isCompleted) c.complete();
    }
    _reconnects.clear();
    // Nudge live observers so callers re-subscribe (which will use the fallback).
    for (final ctrl in _observeCtrls.values) {
      if (!ctrl.isClosed) {
        ctrl.add(const TransportEvent(TransportEventKind.error,
            error: 'transport degraded'));
      }
    }
  }

  @override
  Future<TransportResponse> request(TransportRequest r) async {
    await _ready.future;
    if (_fallback != null) return _fallback!.request(r);
    final id = _nextId++;
    final c = Completer<TransportResponse>();
    _pending[id] = c;
    _cmd!.send(ReqMsg(id, r));
    return c.future;
  }

  @override
  Stream<TransportEvent> observe(String path, {Map<String, String>? query}) {
    final id   = _nextObserveId++;
    final ctrl = StreamController<TransportEvent>();
    _observeCtrls[id] = ctrl;

    unawaited(_ready.future.then((_) {
      if (ctrl.isClosed) return;
      if (_fallback != null) {
        final sub = _fallback!
            .observe(path, query: query)
            .listen(ctrl.add, onError: ctrl.addError, onDone: ctrl.close);
        ctrl.onCancel = () {
          _observeCtrls.remove(id);
          return sub.cancel();
        };
      } else {
        ctrl.onCancel = () {
          _observeCtrls.remove(id);
          _cmd?.send(CancelObserveMsg(id));
        };
        _cmd!.send(ObserveMsg(id, path, query));
      }
    }));

    return ctrl.stream;
  }

  @override
  Future<void> reconnect() async {
    await _ready.future;
    if (_fallback != null) return _fallback!.reconnect();
    final id = _nextId++;
    final c = Completer<void>();
    _reconnects[id] = c;
    _cmd!.send(ReconnectMsg(id));
    return c.future;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _cmd?.send(const DisposeMsg());
    await _fallback?.dispose();
    for (final ctrl in _observeCtrls.values) {
      if (!ctrl.isClosed) await ctrl.close();
    }
    _observeCtrls.clear();
    // Give the isolate a moment to dispose its client, then kill it.
    Future.delayed(const Duration(seconds: 1), () => _isolate?.kill());
  }
}
