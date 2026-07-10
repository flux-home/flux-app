import 'dart:typed_data';

/// Resolved Flux Controller CoAP address.
///
/// [psk] — 16-byte pre-shared key for DTLS on port 5684 (required for coaps).
/// Obtained by scanning the QR code on the device label. Lives here (not in
/// `flux_coap_service.dart`) so it can cross the isolate boundary without
/// dragging the CoAP stack along.
class FluxControllerEndpoint {
  const FluxControllerEndpoint({
    required this.host,
    required this.port,
    this.psk,
    this.dtlsIdentity, // e.g. 'flux-controller-e25311' from QR id= field
  });

  final String     host;
  final int        port;
  final Uint8List? psk;

  /// DTLS PSK identity sent during handshake. Defaults to [host] when null.
  final String?    dtlsIdentity;

  bool get hasDtls => psk != null && psk!.length == 16;

  Uri coapUri(String path, {Map<String, String>? query}) => Uri(
        scheme:          hasDtls ? 'coaps' : 'coap',
        host:            host,
        port:            port,
        path:            path,
        queryParameters: query,
      );

  @override
  String toString() => '${hasDtls ? "coaps" : "coap"}://$host:$port';
}

// ─────────────────────────────────────────────────────────────────────────────

enum TransportMethod { get, put, post, delete }

/// One request/response CoAP operation. All bodies are opaque bytes (protobuf
/// or JSON) — the transport is content-agnostic.
class TransportRequest {
  const TransportRequest(
    this.method,
    this.path, {
    this.query,
    this.body,
    this.timeoutMs = 15000,
    this.retryOnConnError = true,
  });

  final TransportMethod       method;
  final String                path;
  final Map<String, String>?  query;
  final Uint8List?            body;
  final int                   timeoutMs;
  final bool                  retryOnConnError;
}

class TransportResponse {
  const TransportResponse({required this.ok, required this.success, this.payload});

  /// A response was received — i.e. the controller is reachable.
  final bool ok;

  /// The response carried a 2.xx success code.
  final bool success;

  final Uint8List? payload;

  /// Timeout / connection failure — controller unreachable.
  static const unreachable = TransportResponse(ok: false, success: false);
}

enum TransportEventKind { data, error, done }

/// An observe-stream notification (CoAP Observe on `/events`).
class TransportEvent {
  const TransportEvent(this.kind, {this.payload, this.error});
  final TransportEventKind kind;
  final Uint8List?         payload; // for kind == data
  final String?            error;   // for kind == error
}

/// Raw CoAP/DTLS transport to the controller. Implemented either in-process
/// ([InProcessTransport]) or on a background isolate ([IsolateTransport]) — the
/// isolate variant keeps the DTLS handshake/crypto off the UI thread.
abstract interface class ControllerTransport {
  /// Perform a one-shot request. Never throws — returns
  /// [TransportResponse.unreachable] on timeout/connection failure.
  Future<TransportResponse> request(TransportRequest r);

  /// Start a CoAP Observe on [path]; emits data/error/done until the returned
  /// stream is cancelled (which cancels the observe).
  Stream<TransportEvent> observe(String path, {Map<String, String>? query});

  /// Tear down and rebuild the underlying connection (e.g. after the DTLS
  /// session dies).
  Future<void> reconnect();

  Future<void> dispose();
}
