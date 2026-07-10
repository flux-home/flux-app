import 'dart:async';
import 'dart:typed_data';

import 'package:coap/coap.dart';
import 'package:flutter/foundation.dart';

import 'package:matter_home/services/controller_transport/controller_transport.dart';

/// [ControllerTransport] that runs the CoAP/DTLS client on the current isolate.
/// This is the original behaviour (kept for tests + as the isolate's own worker
/// and a safe fallback). The DTLS handshake blocks this isolate, so on mobile
/// prefer the isolate-backed variant.
class InProcessTransport implements ControllerTransport {
  InProcessTransport(this.endpoint) {
    _client = _buildClient();
  }

  final FluxControllerEndpoint endpoint;
  late CoapClient _client;
  bool _disposed = false;

  static const _proto = CoapMediaType.applicationOctetStream;

  final Set<CoapObserveClientRelation> _relations = {};

  CoapClient _buildClient() {
    if (endpoint.hasDtls) {
      final psk = endpoint.psk!;
      return CoapClient(
        endpoint.coapUri('/'),
        config: _DtlsConfig(),
        pskCredentialsCallback: (_) => PskCredentials(
          identity:     (endpoint.dtlsIdentity ?? endpoint.host).codeUnits,
          preSharedKey: psk,
        ),
      );
    }
    return CoapClient(endpoint.coapUri('/'));
  }

  Future<void>? _reconnecting;

  @override
  Future<void> reconnect() {
    final inflight = _reconnecting;
    if (inflight != null) return inflight;
    final f = () async {
      try { _client.close(); } on Exception catch (_) {}
      if (!_disposed) _client = _buildClient();
    }();
    _reconnecting = f.whenComplete(() => _reconnecting = null);
    return _reconnecting!;
  }

  CoapRequest _build(TransportRequest r) {
    final uri = endpoint.coapUri(r.path, query: r.query);
    switch (r.method) {
      case TransportMethod.get:
        return CoapRequest.get(uri, accept: _proto);
      case TransportMethod.put:
        return CoapRequest.put(uri,
            payload: r.body ?? Uint8List(0), contentFormat: _proto, accept: _proto);
      case TransportMethod.post:
        return CoapRequest.post(uri,
            payload: r.body ?? Uint8List(0), contentFormat: _proto, accept: _proto);
      case TransportMethod.delete:
        return CoapRequest.delete(uri);
    }
  }

  @override
  Future<TransportResponse> request(TransportRequest r) async {
    final timeout = Duration(milliseconds: r.timeoutMs);
    CoapResponse resp;
    try {
      resp = await _client.send(_build(r)).timeout(timeout);
    } on TimeoutException {
      unawaited(reconnect());
      return TransportResponse.unreachable;
    } on Exception catch (e) {
      if (_disposed) return TransportResponse.unreachable;
      if (!r.retryOnConnError) {
        unawaited(reconnect());
        return TransportResponse.unreachable;
      }
      debugPrint('InProcessTransport ${r.path}: $e — reconnecting + retry once');
      await reconnect();
      try {
        resp = await _client.send(_build(r)).timeout(timeout);
      } on Exception {
        return TransportResponse.unreachable;
      }
    }
    return TransportResponse(
      ok:      true,
      success: resp.code.isSuccess,
      payload: Uint8List.fromList(resp.payload),
    );
  }

  @override
  Stream<TransportEvent> observe(String path, {Map<String, String>? query}) {
    final ctrl = StreamController<TransportEvent>();
    CoapObserveClientRelation? rel;

    ctrl.onCancel = () {
      if (rel != null) {
        _relations.remove(rel);
        try { _client.cancelObserveProactive(rel!); } on Exception catch (_) {}
      }
    };

    unawaited(() async {
      try {
        final req = CoapRequest.get(
            endpoint.coapUri(path, query: query), accept: _proto);
        rel = await _client.observe(req);
        _relations.add(rel!);
        rel!.listen(
          (resp) => ctrl.add(TransportEvent(TransportEventKind.data,
              payload: Uint8List.fromList(resp.payload))),
          onError: (Object e) =>
              ctrl.add(TransportEvent(TransportEventKind.error, error: e.toString())),
          onDone: () {
            ctrl.add(const TransportEvent(TransportEventKind.done));
            if (!ctrl.isClosed) ctrl.close();
          },
        );
      } on Exception catch (e) {
        ctrl.add(TransportEvent(TransportEventKind.error, error: e.toString()));
        if (!ctrl.isClosed) await ctrl.close();
      }
    }());

    return ctrl.stream;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final rel in _relations) {
      try { _client.cancelObserveReactive(rel); } on Exception catch (_) {}
    }
    _relations.clear();
    _client.close();
  }
}

// ── DTLS CoAP config ──────────────────────────────────────────────────────────
//
// OpenSSL 3.0 does NOT include PSK cipher suites in its default cipher list.
// We must explicitly set them so the ClientHello includes ciphers the firmware's
// mbedTLS supports. securityLevel=0 drops OpenSSL 3's minimum key-length floor
// (level 1), which would otherwise silently exclude some PSK suites.
class _DtlsConfig extends CoapConfigDefault {
  @override
  String? get dtlsCiphers =>
      'PSK-AES128-GCM-SHA256:'
      'PSK-AES256-GCM-SHA384:'
      'PSK-AES128-CCM8:'
      'PSK-AES256-CCM8:'
      'PSK-AES128-CBC-SHA256:'
      'PSK-AES256-CBC-SHA384:'
      'PSK-AES128-CBC-SHA:'
      'PSK-AES256-CBC-SHA';

  @override
  int? get openSslSecurityLevel => 0;
}
