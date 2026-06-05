import 'dart:async';
import 'dart:typed_data';

import 'package:coap/coap.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';

import 'package:matter_home/models/basic_info.dart';
import 'package:matter_home/models/commissionable_device.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/network_diagnostics.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/models/wifi_network.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;

export 'package:matter_home/services/proto/flux.pb.dart'
    show ControllerInfo, Device, DeviceList;

// ── Endpoint ────────────────────────────────────────────────────────────────

/// Resolved Flux Controller CoAP address.
///
/// [psk] — 16-byte pre-shared key for DTLS on port 5684 (required).
/// Obtained by scanning the QR code on the device label.
class FluxControllerEndpoint {
  const FluxControllerEndpoint({
    required this.host,
    required this.port,
    this.psk,
    this.dtlsIdentity,  // e.g. 'flux-controller-e25311' from QR id= field
  });

  final String     host;
  final int        port;
  final Uint8List? psk;
  /// DTLS PSK identity sent during handshake.
  /// Defaults to [host] when null (IP address fallback).
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

// ── FluxCoapService ──────────────────────────────────────────────────────────

/// Unified CoAP/DTLS client for the Flux Controller.
///
/// Replaces both the former HTTP [FluxControllerService] and the old
/// WebSocket port.
///
/// **Resource map** (all payloads binary protobuf, Content-Format 42):
/// ```
/// GET  /info                         → ControllerInfo
/// GET  /thread/dataset               → ThreadDataset
/// PUT  /thread/dataset               ← ThreadDataset
/// GET  /devices                      → DeviceList
/// POST /devices                      ← RenameDeviceRequest → StatusResponse
/// DEL  /devices?id=<hex>             → StatusResponse
/// POST /commission                   ← CommissionNotify → StatusResponse (async)
/// GET  /events/commission  Observe   → CommissionUpdate { event | result }
/// GET  /events?id=<hex>    Observe   → DeviceStateEvent
/// POST /command                      ← DeviceCommand → BoolResult
/// POST /read                         ← ReadRequest   → BoolResult (data via Observe)
/// POST /fabric/window                ← OpenWindowRequest → WindowResult
/// POST /fabric/discover              ← DiscoverRequest   → DiscoverResult
/// ```
class FluxCoapService implements MatterPort {

  FluxCoapService(this.endpoint) {
    _client = _buildClient();
  }

  final FluxControllerEndpoint endpoint;
  late CoapClient _client;
  bool _disposed = false;

  // Per-node Observe relations
  final Map<int, CoapObserveClientRelation> _subscriptions = {};

  final _deviceStateCtrl      = StreamController<DeviceStateEvent>.broadcast();
  final _commissionEventsCtrl = StreamController<String>.broadcast();

  // ── MatterPort streams ─────────────────────────────────────────────────────

  @override
  Stream<DeviceStateEvent> get deviceStateUpdates => _deviceStateCtrl.stream;

  @override
  Stream<String> get commissionEvents => _commissionEventsCtrl.stream;

  // ── CoAP client factory ────────────────────────────────────────────────────

  CoapClient _buildClient() {
    if (endpoint.hasDtls) {
      final psk = endpoint.psk!;
      return CoapClient(
        endpoint.coapUri('/'),
        pskCredentialsCallback: (_) => PskCredentials(
          identity:     (endpoint.dtlsIdentity ?? endpoint.host).codeUnits,
          preSharedKey: psk,
        ),
      );
    }
    return CoapClient(endpoint.coapUri('/'));
  }

  // ── Low-level CoAP helpers ─────────────────────────────────────────────────

  static const _proto    = CoapMediaType.applicationOctetStream;
  static const _timeout5   = Duration(seconds: 5);
  static const _timeout15  = Duration(seconds: 15); // DTLS handshake can take ~10s
  static const _timeout30  = Duration(seconds: 30);

  Future<Uint8List?> _get(String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    // First request on a DTLS connection includes the handshake (~10s).
    // Use 15s as the default to give it enough headroom.
    final t = timeout ?? (endpoint.hasDtls ? _timeout15 : _timeout5);
    try {
      final req  = CoapRequest.get(endpoint.coapUri(path, query: query), accept: _proto);
      final resp = await _client.send(req).timeout(t);
      if (resp.code.isSuccess) return Uint8List.fromList(resp.payload);
      return null;
    } on Exception catch (e) {
      debugPrint('FluxCoapService GET $path: $e');
      return null;
    }
  }

  Future<Uint8List?> _put(String path, Uint8List body,
      {Duration timeout = _timeout5}) async {
    try {
      final req  = CoapRequest.put(endpoint.coapUri(path),
          payload: body, contentFormat: _proto, accept: _proto);
      final resp = await _client.send(req).timeout(timeout);
      if (resp.code.isSuccess) return Uint8List.fromList(resp.payload);
      return null;
    } on Exception catch (e) {
      debugPrint('FluxCoapService PUT $path: $e');
      return null;
    }
  }

  Future<Uint8List?> _post(String path, Uint8List body,
      {Duration timeout = _timeout30}) async {
    try {
      final req  = CoapRequest.post(endpoint.coapUri(path),
          payload: body, contentFormat: _proto, accept: _proto);
      final resp = await _client.send(req).timeout(timeout);
      if (resp.code.isSuccess) return Uint8List.fromList(resp.payload);
      return null;
    } on Exception catch (e) {
      debugPrint('FluxCoapService POST $path: $e');
      return null;
    }
  }

  Future<bool> _delete(String path, {Map<String, String>? query}) async {
    try {
      final req  = CoapRequest.delete(endpoint.coapUri(path, query: query));
      final resp = await _client.send(req).timeout(_timeout5);
      return resp.code.isSuccess;
    } on Exception catch (e) {
      debugPrint('FluxCoapService DELETE $path: $e');
      return false;
    }
  }

  // ── Config resources ───────────────────────────────────────────────────────

  Future<$proto.ControllerInfo?> getInfo() async {
    final b = await _get('/info');
    if (b == null) return null;
    try { return $proto.ControllerInfo.fromBuffer(b); }
    on Exception catch (e) { debugPrint('FluxCoapService getInfo: $e'); return null; }
  }

  Future<$proto.ThreadDataset?> getThreadDataset() async {
    final b = await _get('/thread/dataset');
    if (b == null) return null;
    try { return $proto.ThreadDataset.fromBuffer(b); }
    on Exception catch (e) { debugPrint('FluxCoapService getThreadDataset: $e'); return null; }
  }

  Future<String?> getThreadDatasetHex() async {
    final ds = await getThreadDataset();
    if (ds == null || ds.tlv.isEmpty) return null;
    return ds.tlv.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  Future<bool> postThreadDataset(Uint8List tlv) async {
    final ds   = $proto.ThreadDataset()..tlv = tlv;
    final resp = await _put('/thread/dataset', ds.writeToBuffer());
    return resp != null;
  }

  Future<List<$proto.Device>?> getDeviceList() async {
    final b = await _get('/devices');
    if (b == null) return null;
    try { return $proto.DeviceList.fromBuffer(b).devices; }
    on Exception catch (e) { debugPrint('FluxCoapService getDeviceList: $e'); return null; }
  }

  // ── Commission resource ────────────────────────────────────────────────────

  /// Commissions a device via the controller.
  ///
  /// 1. Registers a CoAP Observe on `/events/commission`.
  /// 2. POSTs `CommissionNotify` to `/commission` — controller responds with
  ///    `StatusResponse{code=0}` immediately (non-blocking).
  /// 3. Waits for `CommissionUpdate{result{…}}` notifications via Observe.
  ///
  /// Returns the controller-assigned `node_id` on success, null on failure.
  Future<int?> sendCommissionNotify({
    required int    phoneNodeId,
    required String setupCode,
    String          ipv6Address = '',
  }) async {
    final resultCompleter = Completer<int?>();
    CoapObserveClientRelation? obs;
    // Gate: ignore Observe responses that arrive before the POST is accepted.
    // The firmware sends its last cached CommissionResult as the initial Observe
    // ACK — if a previous attempt failed, this would prematurely complete with
    // null before the new commission even starts.
    bool postAccepted = false;

    // 1. Register observe on /events/commission
    try {
      final req = CoapRequest.get(
        endpoint.coapUri('/events/commission'),
        accept: _proto,
      );
      obs = await _client.observe(req);
      obs.listen((resp) {
        if (!postAccepted) return; // ignore stale cached state
        if (_disposed || resultCompleter.isCompleted) return;
        final bytes = Uint8List.fromList(resp.payload);
        if (bytes.isEmpty) return;
        try {
          final cu = $proto.CommissionUpdate.fromBuffer(bytes);
          switch (cu.whichBody()) {
            case $proto.CommissionUpdate_Body.event:
              _commissionEventsCtrl.add(cu.event.text);
            case $proto.CommissionUpdate_Body.result:
              final r = cu.result;
              if (!r.success) {
                final msg = r.error.isNotEmpty ? r.error : 'Commission failed';
                debugPrint('FluxCoapService commission error: $msg');
                _commissionEventsCtrl.add('✗ Controller: $msg');
              }
              resultCompleter.complete(r.success ? r.nodeId.toInt() : null);
              if (obs != null && !obs.isCancelled) {
                _client.cancelObserveProactive(obs);
              }
            case $proto.CommissionUpdate_Body.notSet:
              break;
          }
        } on Exception catch (e) {
          debugPrint('FluxCoapService commission observe decode: $e');
        }
      }, onDone: () {
        if (!resultCompleter.isCompleted) resultCompleter.complete(null);
      }, onError: (Object e) {
        debugPrint('FluxCoapService commission observe error: $e');
        if (!resultCompleter.isCompleted) resultCompleter.complete(null);
      });
    } on Exception catch (e) {
      debugPrint('FluxCoapService: failed to observe /events/commission: $e');
    }

    // 2. POST commission request — returns StatusResponse{code=0} immediately
    final notify = $proto.CommissionNotify()
      ..nodeId      = Int64(phoneNodeId)
      ..setupCode   = setupCode
      ..ipv6Address = ipv6Address;
    final postResp = await _post('/commission', notify.writeToBuffer(),
        timeout: const Duration(seconds: 10));

    if (postResp == null) {
      const msg = 'POST /commission failed (no response)';
      debugPrint('FluxCoapService.sendCommissionNotify: $msg');
      _commissionEventsCtrl.add('✗ $msg');
      resultCompleter.complete(null);
    } else {
      try {
        final sr = $proto.StatusResponse.fromBuffer(postResp);
        if (sr.code != 0) {
          debugPrint('FluxCoapService commission rejected: ${sr.message}');
          _commissionEventsCtrl.add('✗ Controller rejected: ${sr.message}');
          resultCompleter.complete(null);
        } else {
          // POST accepted — open the gate so real Observe notifications flow.
          postAccepted = true;
        }
      } on Exception catch (_) {
        // Non-proto or empty body — assume accepted.
        postAccepted = true;
      }
    }

    // 3. Wait for CommissionUpdate.result via Observe (up to 120 s)
    try {
      return await resultCompleter.future.timeout(const Duration(seconds: 120));
    } on TimeoutException catch (_) {
      const msg = 'Commission timed out (120s) — no result from controller';
      debugPrint('FluxCoapService.sendCommissionNotify: $msg');
      _commissionEventsCtrl.add('✗ $msg');
      return null;
    } finally {
      if (obs != null && !obs.isCancelled) {
        try { _client.cancelObserveReactive(obs); } on Exception catch (_) {}
      }
    }
  }

  // ── MatterSubscriptionPort — GET /events?id=<hex> ─────────────────────────

  @override
  Future<bool> startSubscription(int nodeId) async {
    await stopSubscription(nodeId);
    try {
      final hexId = nodeId.toRadixString(16).padLeft(16, '0');
      final req   = CoapRequest.get(
        endpoint.coapUri('/events', query: {'id': hexId}),
        accept: _proto,
      );
      final relation = await _client.observe(req);
      _subscriptions[nodeId] = relation;
      relation.listen(
        (resp) => _handleStateResponse(nodeId, resp),
        onError: (Object e) {
          debugPrint('FluxCoapService sub $nodeId error: $e');
          _deviceStateCtrl.add(SubscriptionErrorEvent(nodeId, e.toString()));
          if (!_disposed) {
            Future.delayed(const Duration(seconds: 5),
                () => startSubscription(nodeId));
          }
        },
        onDone: () {
          debugPrint('FluxCoapService sub $nodeId done');
          _subscriptions.remove(nodeId);
          if (!_disposed) {
            _deviceStateCtrl.add(SubscriptionResubscribingEvent(nodeId, 0));
            Future.delayed(const Duration(seconds: 5),
                () => startSubscription(nodeId));
          }
        },
      );
      return true;
    } on Exception catch (e) {
      debugPrint('FluxCoapService.startSubscription($nodeId): $e');
      return false;
    }
  }

  @override
  Future<void> stopSubscription(int nodeId) async {
    final rel = _subscriptions.remove(nodeId);
    if (rel != null && !rel.isCancelled) {
      try { _client.cancelObserveProactive(rel); } on Exception catch (_) {}
    }
  }

  void _handleStateResponse(int nodeId, CoapResponse resp) {
    try {
      final bytes = Uint8List.fromList(resp.payload);
      if (bytes.isEmpty) return;
      final ev = $proto.DeviceStateEvent.fromBuffer(bytes);
      _deviceStateCtrl.add(_toAppEvent(ev));
    } on Exception catch (e) {
      debugPrint('FluxCoapService._handleStateResponse: $e');
    }
  }

  DeviceStateEvent _toAppEvent($proto.DeviceStateEvent ev) {
    final nodeId = ev.nodeId.toInt();
    switch (ev.type) {
      case $proto.DeviceEventType.DEVICE_EVENT_ESTABLISHED:
        return SubscriptionEstablishedEvent(nodeId);
      case $proto.DeviceEventType.DEVICE_EVENT_ERROR:
        return SubscriptionErrorEvent(nodeId, ev.error);
      case $proto.DeviceEventType.DEVICE_EVENT_RESUBSCRIBING:
        return SubscriptionResubscribingEvent(nodeId, 0);
      case $proto.DeviceEventType.DEVICE_EVENT_ATTRS_UPDATE:
        final attrs = <String, dynamic>{};
        for (final a in ev.update.attrs) {
          if (a.hasBoolVal())      attrs[a.key] = a.boolVal;
          else if (a.hasIntVal())  attrs[a.key] = a.intVal;
          else if (a.hasLongVal()) attrs[a.key] = a.longVal.toInt();
        }
        return SubscriptionUpdateEvent(nodeId, attrs);
      default:
        return SubscriptionErrorEvent(nodeId, 'unknown event type');
    }
  }

  // ── Cluster commands — POST /command ───────────────────────────────────────

  // Matter TLV minimal encoder
  static const _tlvStructStart  = 0x15;
  static const _tlvEndContainer = 0x18;
  static Uint8List _struct(List<int> f) =>
      Uint8List.fromList([_tlvStructStart, ...f, _tlvEndContainer]);
  static List<int> _u8(int t, int v)  => [0x24, t, v & 0xFF];
  static List<int> _u16(int t, int v) => [0x25, t, v & 0xFF, (v >> 8) & 0xFF];
  static List<int> _bytes(int t, List<int> b) => [0x30, t, b.length, ...b];
  static Uint8List _emptyStruct() => _struct([]);

  Future<bool> _sendCmd(
    int nodeId, int clusterId, int commandId, Uint8List payload, {
    int endpoint = 1, Duration timeout = _timeout30,
  }) async {
    final cmd = $proto.DeviceCommand()
      ..nodeId     = Int64(nodeId)
      ..endpointId = endpoint
      ..clusterId  = clusterId
      ..commandId  = commandId
      ..payload    = payload;
    final body = await _post('/command', cmd.writeToBuffer(), timeout: timeout);
    if (body == null) return false;
    try { return $proto.BoolResult.fromBuffer(body).success; }
    on Exception catch (_) { return false; }
  }

  // ── OnOff / Level ──────────────────────────────────────────────────────────

  static const _clOnOff = 0x0006;
  static const _clLevel = 0x0008;

  @override
  Future<bool> toggleDevice(int nodeId, {required bool on}) =>
      _sendCmd(nodeId, _clOnOff, on ? 1 : 0, _emptyStruct());

  @override
  Future<bool> setLevel(int nodeId, int level) =>
      _sendCmd(nodeId, _clLevel, 4,
          _struct([..._u8(0, level), ..._u16(1, 0), ..._u8(2, 0), ..._u8(3, 0)]));

  @override
  Future<bool> stepLevel(int nodeId, {required bool stepUp}) =>
      _sendCmd(nodeId, _clLevel, 6,
          _struct([
            ..._u8(0, stepUp ? 0 : 1),
            ..._u8(1, 25),
            ..._u16(2, 2),
            ..._u8(3, 0), ..._u8(4, 0),
          ]));

  // ── Window Covering ────────────────────────────────────────────────────────

  static const _clCovering = 0x0102;

  @override Future<bool> coveringUp(int n)   => _sendCmd(n, _clCovering, 0, _emptyStruct());
  @override Future<bool> coveringDown(int n) => _sendCmd(n, _clCovering, 1, _emptyStruct());
  @override Future<bool> coveringStop(int n) => _sendCmd(n, _clCovering, 2, _emptyStruct());
  @override
  Future<bool> coveringGoToLift(int nodeId, int percent100ths) =>
      _sendCmd(nodeId, _clCovering, 5, _struct([..._u16(0, percent100ths)]));

  // ── Color Control ──────────────────────────────────────────────────────────

  static const _clColor = 0x0300;

  @override
  Future<bool> setColorTemperature(int nodeId, int mireds) =>
      _sendCmd(nodeId, _clColor, 0x0A,
          _struct([..._u16(0, mireds), ..._u16(1, 0), ..._u8(2, 0), ..._u8(3, 0)]));

  // ── Door Lock ──────────────────────────────────────────────────────────────

  static const _clLock = 0x0101;

  @override
  Future<bool> lockDoor(int nodeId, {String? pin}) {
    final p = pin != null && pin.isNotEmpty
        ? _struct([..._bytes(0, pin.codeUnits)]) : _emptyStruct();
    return _sendCmd(nodeId, _clLock, 0, p);
  }

  @override
  Future<bool> unlockDoor(int nodeId, {String? pin}) {
    final p = pin != null && pin.isNotEmpty
        ? _struct([..._bytes(0, pin.codeUnits)]) : _emptyStruct();
    return _sendCmd(nodeId, _clLock, 1, p);
  }

  // ── Identify ───────────────────────────────────────────────────────────────

  static const _clIdentify = 0x0003;

  @override
  Future<void> identify(int nodeId, {int seconds = 15}) async {
    try {
      await _sendCmd(nodeId, _clIdentify, 0,
          _struct([..._u16(0, seconds)]), endpoint: 0);
    } on Exception catch (_) {}
  }

  // ── Thermostat / Fan — WriteAttribute (stubbed until firmware exposes it) ──

  @override Future<bool> writeHeatingSetpoint(int n, int c) async => false;
  @override Future<bool> writeSystemMode(int n, int m)       async => false;
  @override Future<bool> setFanMode(int n, int m)            async => false;
  @override Future<bool> setFanPercent(int n, int p)         async => false;

  // ── Reads — POST /read ─────────────────────────────────────────────────────
  //
  // The firmware dispatches read_attr commands on the CHIP task and returns
  // BoolResult immediately.  Actual attribute values arrive via the
  // /events?id= Observe stream.
  //
  // For callers that expect a synchronous result (readBasicInfo, readThermostat
  // etc.) we wait briefly for a DeviceStateEvent after the POST.

  Future<Map<String, dynamic>?> _readAttrs(
    int nodeId, {
    required List<int> endpoints,
    required List<int> clusters,
    required List<int> attrs,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final req = $proto.ReadRequest()
        ..nodeId = Int64(nodeId)
        ..endpointIds.addAll(endpoints)
        ..clusterIds.addAll(clusters)
        ..attrIds.addAll(attrs);
      final body = await _post('/read', req.writeToBuffer(), timeout: _timeout30);
      if (body == null) return null;
      final ok = $proto.BoolResult.fromBuffer(body).success;
      if (!ok) return null;

      // Wait for the attrs to arrive via the Observe stream.
      final completer = Completer<Map<String, dynamic>>();
      late StreamSubscription<DeviceStateEvent> sub;
      sub = deviceStateUpdates.listen((ev) {
        if (ev is SubscriptionUpdateEvent && ev.nodeId == nodeId) {
          if (!completer.isCompleted) completer.complete(ev.attrs);
          sub.cancel();
        }
      });
      try {
        return await completer.future.timeout(timeout);
      } on TimeoutException catch (_) {
        sub.cancel();
        return null;
      }
    } on Exception catch (e) {
      debugPrint('FluxCoapService._readAttrs $nodeId: $e');
      return null;
    }
  }

  @override
  Future<DeviceStateResult> readDeviceState(int nodeId) async {
    final a = await _readAttrs(nodeId,
        endpoints: [1], clusters: [_clOnOff, _clLevel], attrs: [0, 0]);
    if (a == null) return const DeviceStateResult(isOnline: false);
    return DeviceStateResult(
      isOnline:        true,
      isOn:            a['onOff'] as bool?,
      brightnessLevel: a['level'] as int?,
    );
  }

  @override
  Future<int?> readDeviceTypeId(int nodeId) async {
    final a = await _readAttrs(nodeId, endpoints: [1], clusters: [0x001D], attrs: [0]);
    return a?['deviceType'] as int?;
  }

  @override
  Future<BasicInfo?> readBasicInfo(int nodeId) async {
    final a = await _readAttrs(nodeId, endpoints: [0], clusters: [0x0028],
        attrs: [1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 13, 15, 18]);
    if (a == null) return null;
    String s(String k) => (a[k] ?? '').toString();
    return BasicInfo(
      vendorName:        s('vendorName'),
      vendorId:          s('vendorId'),
      productName:       s('productName'),
      productId:         s('productId'),
      hwVersion:         s('hwVersion'),
      softwareVersion:   s('swVersion'),
      softwareVersionNum: a['swVersionNum'] as int?,
      manufacturingDate: s('manufacturingDate'),
      partNumber:        s('partNumber'),
      productUrl:        s('productUrl'),
      serialNumber:      s('serialNumber'),
      uniqueId:          s('uniqueId'),
    );
  }

  @override
  Future<ThermostatState?> readThermostat(int nodeId) async {
    const c = 0x0201;
    final a = await _readAttrs(nodeId, endpoints: [1], clusters: [c],
        attrs: [0, 3, 4, 5, 6, 17, 18, 21, 22, 23, 24, 27, 28]);
    if (a == null) return null;
    int? g(String k) {
      final v = a[k] as int?;
      return (v == null || v == -32768 || v == -2147483648) ? null : v;
    }
    return ThermostatState(
      localTempCenti:       g('localTemp'),
      heatingSetptCenti:    g('heatingSetpoint'),
      coolingSetptCenti:    g('coolingSetpoint'),
      systemMode:           g('systemMode'),
      controlSequence:      g('controlSequence'),
      minHeatSetptCenti:    g('minHeatSetpt'),
      maxHeatSetptCenti:    g('maxHeatSetpt'),
      minCoolSetptCenti:    g('minCoolSetpt'),
      maxCoolSetptCenti:    g('maxCoolSetpt'),
      absMinHeatSetptCenti: g('absMinHeatSetpt'),
      absMaxHeatSetptCenti: g('absMaxHeatSetpt'),
      absMinCoolSetptCenti: g('absMinCoolSetpt'),
      absMaxCoolSetptCenti: g('absMaxCoolSetpt'),
    );
  }

  @override Future<List<int>> readServerClusterList(int n, {int endpoint = 0}) async => const [];
  @override Future<List<int>> readPartsList(int n) async => const [];
  @override Future<String?>  readClusters(int n)  async => null;
  @override
  Future<({int? importedMwh, int? exportedMwh})> readCumulativeEnergy(
    int n, {int endpoint = 1}) async => (importedMwh: null, exportedMwh: null);

  // ── MatterFabricPort ───────────────────────────────────────────────────────

  /// Open a commissioning window on a device — POST /fabric/window
  @override
  Future<ShareDeviceResult?> shareDevice(int nodeId,
      {int vendorId = 0, int productId = 0}) async {
    try {
      final req  = $proto.OpenWindowRequest()
        ..nodeId         = Int64(nodeId)
        ..timeoutSeconds = 180;
      final body = await _post('/fabric/window', req.writeToBuffer(),
          timeout: const Duration(seconds: 60));
      if (body == null) return null;
      final w = $proto.WindowResult.fromBuffer(body);
      if (!w.success) return null;
      return ShareDeviceResult(
        qrCodePayload:     w.setupCode,
        manualPairingCode: w.setupCode,
      );
    } on Exception catch (_) { return null; }
  }

  /// Remove a device — DELETE /devices?id=<hex>
  @override
  Future<bool> removeDevice(int nodeId) =>
      _delete('/devices', query: {'id': nodeId.toRadixString(16).padLeft(16, '0')});

  @override
  Future<List<CommissionableDevice>> discoverCommissionableNodes() async {
    try {
      final req  = $proto.DiscoverRequest()..timeoutSeconds = 10;
      final body = await _post('/fabric/discover', req.writeToBuffer(),
          timeout: const Duration(seconds: 15));
      if (body == null) return const [];
      return const []; // DiscoverResult.node_ids only; full device info tbd
    } on Exception catch (_) { return const []; }
  }

  @override
  Future<String?> getFabricId() async {
    final info = await getInfo();
    return info != null ? info.fabricId.toHexString() : null;
  }

  @override Future<int?> getVendorId() async => null;
  @override Future<bool> downloadAndFlash({
    required int nodeId, required String otaUrl,
    required int targetVersion, required String targetVersionString,
    bool dryRun = false, int endpoint = 0,
  }) async => false;
  @override Future<bool> cancelOta() async => false;
  @override Future<List<ThreadBorderRouter>> discoverThreadNetworks() async => const [];
  @override Future<String?> readSystemThreadCredentials() async => null;
  @override Future<ThreadNetworkDiagnostics?> readThreadNetworkDiagnostics(int n) async => null;
  @override Future<NetworkDiagnosticsReport?> runNetworkDiagnostics() async => null;

  // ── MatterCommissionPort — BLE stays on local MatterChannel ───────────────

  @override
  Future<ParsedPayload?> parsePayload(String payload) async => null;

  @override
  Future<CommissionResult> commissionDevice(String payload,
      {String? wifiSsid, String? wifiPassword, String? threadDatasetHex}) async =>
      CommissionResult.err('BLE commissioning uses local MatterChannel');

  @override
  Future<CommissionResult> commissionViaIp({
    required String ipAddress, required int discriminator,
    required int setupPinCode, int port = 5540,
  }) async => CommissionResult.err('Use CommissionNotify for hub commissioning');

  @override
  Future<CommissionResult> commissionViaCode({required String setupCode}) async =>
      CommissionResult.err('Use CommissionNotify for hub commissioning');

  @override Future<List<WifiNetwork>> scanWifiNetworks() async => const [];
  @override Future<void> provideCredentials({
    String? ssid, String? password, String? threadDatasetHex}) async {}

  // ── Discovery / probe ──────────────────────────────────────────────────────

  /// Probes the controller by attempting `GET /info` over CoAP.
  /// Returns the endpoint on success, null on failure.
  static Future<FluxControllerEndpoint?> probe(
      String host, int port, {Uint8List? psk, String? dtlsIdentity}) async {
    final ep  = FluxControllerEndpoint(
        host: host, port: port, psk: psk, dtlsIdentity: dtlsIdentity);
    final svc = FluxCoapService(ep);
    try {
      final info = await svc.getInfo();
      if (info != null) {
        debugPrint('FluxCoapService.probe: found ${info.hostname} '
            'fw=${info.firmwareVersion} at $ep');
        svc.dispose();
        return ep;
      }
    } on Exception catch (e) {
      debugPrint('FluxCoapService.probe $ep: $e');
    }
    svc.dispose();
    return null;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void dispose() {
    _disposed = true;
    for (final rel in _subscriptions.values) {
      try { _client.cancelObserveReactive(rel); } on Exception catch (_) {}
    }
    _subscriptions.clear();
    _client.close();
    _deviceStateCtrl.close();
    _commissionEventsCtrl.close();
  }
}
