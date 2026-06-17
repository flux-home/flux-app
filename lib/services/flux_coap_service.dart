import 'dart:async';

import 'package:coap/coap.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';

import 'package:matter_home/models/basic_info.dart';
import 'package:matter_home/models/commissionable_device.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/fabric_descriptor.dart';
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
/// **Resource map** (all payloads binary protobuf, Content-Format 42):
/// ```
/// GET  /info                         → ControllerInfo
/// GET  /thread/dataset               → ThreadDataset
/// PUT  /thread/dataset               ← ThreadDataset
/// GET  /devices                      → DeviceList
/// POST /devices                      ← RenameDeviceRequest → StatusResponse
/// DEL  /devices?id=<hex>             → StatusResponse
/// POST /commission                   ← CommissionRequest → CommissionResult
/// GET  /events?id=<hex>    Observe   → DeviceStateEvent
/// POST /command                      ← DeviceCommand → BoolResult
/// POST /write                        ← WriteAttrRequest → BoolResult
/// POST /read                         ← ReadRequest → BoolResult (data via Observe)
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
        config: _DtlsConfig(),
        pskCredentialsCallback: (_) => PskCredentials(
          identity:     (endpoint.dtlsIdentity ?? endpoint.host).codeUnits,
          preSharedKey: psk,
        ),
      );
    }
    return CoapClient(endpoint.coapUri('/'));
  }

  // ── DTLS connection recovery ───────────────────────────────────────────────
  // The DTLS session is established once and reused. If the controller reboots
  // (or the session otherwise drops) the old client is permanently dead — every
  // send then throws "Not connected!" or times out. Rebuild it on failure so the
  // connection re-establishes instead of failing forever. Single-flighted so
  // concurrent failures rebuild once.
  Future<void>? _reconnecting;

  Future<void> _reconnect() {
    final inflight = _reconnecting;
    if (inflight != null) return inflight;
    final f = () async {
      try { _client.close(); } on Exception catch (_) {}
      if (!_disposed) _client = _buildClient();
    }();
    _reconnecting = f.whenComplete(() => _reconnecting = null);
    return _reconnecting!;
  }

  /// Sends [req], recovering from a dead DTLS session. On a connection-level
  /// error (e.g. "Not connected!") the request never reached the controller, so
  /// we reconnect and retry once. On a timeout the controller may be mid-operation
  /// (a commission can take ~60s), so we rebuild for the next call but do not
  /// resend — and let the timeout propagate.
  Future<CoapResponse> _send(CoapRequest req, Duration timeout,
      {bool retryOnConnError = true}) async {
    try {
      return await _client.send(req).timeout(timeout);
    } on TimeoutException {
      unawaited(_reconnect());
      rethrow;
    } on Exception catch (e) {
      if (_disposed) rethrow;
      // Non-idempotent calls (e.g. POST /commission) must NOT be resent: the
      // controller may still be mid-operation, and a resend starts a second,
      // overlapping device commission that wedges the device. Reconnect for the
      // next call, but surface this error instead of retrying.
      if (!retryOnConnError) {
        unawaited(_reconnect());
        rethrow;
      }
      debugPrint('FluxCoapService: connection error ($e) — reconnecting and retrying once');
      await _reconnect();
      return await _client.send(req).timeout(timeout);
    }
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
      final resp = await _send(req, t);
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
      final resp = await _send(req, timeout);
      if (resp.code.isSuccess) return Uint8List.fromList(resp.payload);
      return null;
    } on Exception catch (e) {
      debugPrint('FluxCoapService PUT $path: $e');
      return null;
    }
  }

  Future<Uint8List?> _post(String path, Uint8List body,
      {Duration timeout = _timeout30, bool retryOnConnError = true}) async {
    try {
      final req  = CoapRequest.post(endpoint.coapUri(path),
          payload: body, contentFormat: _proto, accept: _proto);
      final resp = await _send(req, timeout, retryOnConnError: retryOnConnError);
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
      final resp = await _send(req, _timeout5);
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

  // ── Commission-then-handoff — POST /commission ───────────────────────────

  /// Hands a device the phone has just BLE-commissioned (onto its throwaway
  /// fabric) over to the controller.  The phone opened an ECM window and passes
  /// the window's [passcode] + [discriminator]; the controller rediscovers the
  /// device over Thread, performs PASE, and commissions it onto its OWN fabric
  /// with its own CA — so no device CSR ever leaves the controller.  On success
  /// the controller registers + subscribes the device itself.
  ///
  /// [CommissionResult.fabricId] is the RAW (uncompressed) controller fabric id;
  /// the caller matches it against the device's Fabrics attribute before
  /// removing its throwaway fabric.  [nodeId] of 0 lets the controller assign one.
  Future<$proto.CommissionResult?> commission({
    required int passcode,
    required int discriminator,
    int          nodeId        = 0,
    String       name          = '',
    int          vendorId      = 0,
    int          productId     = 0,
    int          deviceType    = 0,
    String       deviceAddress = '',
    int          devicePort    = 0,
  }) async {
    final req = $proto.CommissionRequest()
      ..passcode      = passcode
      ..discriminator = discriminator
      ..nodeId        = Int64(nodeId)
      ..name          = name
      ..vendorId      = vendorId
      ..productId     = productId
      ..deviceType    = deviceType
      ..deviceAddress = deviceAddress
      ..devicePort    = devicePort;
    // /commission is non-idempotent and long-running (the controller blocks up
    // to ~120s). Keep it confirmable so the CoAP client reliably awaits the
    // reply; do NOT auto-retry on a connection error (a resend would be a second
    // commission). Duplicate requests from CoAP retransmits are made harmless on
    // the controller by its idempotency cache (replays the cached result for the
    // same device within a short window) + in-flight guard.
    final body = await _post('/commission', req.writeToBuffer(),
        timeout: const Duration(seconds: 150), retryOnConnError: false);
    if (body == null) return null;
    try { return $proto.CommissionResult.fromBuffer(body); }
    on Exception catch (e) {
      debugPrint('FluxCoapService.commission: $e');
      return null;
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
                () => startSubscription(nodeId))
              .catchError((Object e) {
                debugPrint('FluxCoapService sub $nodeId retry error: $e');
                return false;
              });
          }
        },
        onDone: () {
          debugPrint('FluxCoapService sub $nodeId done');
          _subscriptions.remove(nodeId);
          if (!_disposed) {
            _deviceStateCtrl.add(SubscriptionResubscribingEvent(nodeId, 0));
            Future.delayed(const Duration(seconds: 5),
                () => startSubscription(nodeId))
              .catchError((Object e) {
                debugPrint('FluxCoapService sub $nodeId retry error: $e');
                return false;
              });
          }
        },
      );
      return true;
    } catch (e) {
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

  static $proto.CommandArg _arg(String name,
      {bool? boolVal, int? uintVal, int? intVal, String? strVal}) {
    final a = $proto.CommandArg()..name = name;
    if (boolVal != null)      a.boolVal = boolVal;
    else if (uintVal != null) a.uintVal = uintVal;
    else if (intVal  != null) a.intVal  = intVal;
    else if (strVal  != null) a.strVal  = strVal;
    return a;
  }

  Future<bool> _sendCmd(
    int nodeId, int clusterId, int commandId, List<$proto.CommandArg> args, {
    int endpoint = 1, Duration timeout = _timeout30,
  }) async {
    final cmd = $proto.DeviceCommand()
      ..nodeId     = Int64(nodeId)
      ..endpointId = endpoint
      ..clusterId  = clusterId
      ..commandId  = commandId
      ..args.addAll(args);
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
      _sendCmd(nodeId, _clOnOff, on ? 1 : 0, []);

  @override
  Future<bool> setLevel(int nodeId, int level) =>
      _sendCmd(nodeId, _clLevel, 4, [
        _arg('level',          uintVal: level),
        _arg('transitionTime', uintVal: 0),
        _arg('optionsMask',    uintVal: 0),
        _arg('optionsOverride',uintVal: 0),
      ]);

  @override
  Future<bool> stepLevel(int nodeId, {required bool stepUp}) =>
      _sendCmd(nodeId, _clLevel, 6, [
        _arg('stepMode',       uintVal: stepUp ? 0 : 1),
        _arg('stepSize',       uintVal: 25),
        _arg('transitionTime', uintVal: 2),
        _arg('optionsMask',    uintVal: 0),
        _arg('optionsOverride',uintVal: 0),
      ]);

  // ── Window Covering ────────────────────────────────────────────────────────

  static const _clCovering = 0x0102;

  @override Future<bool> coveringUp(int n)   => _sendCmd(n, _clCovering, 0, []);
  @override Future<bool> coveringDown(int n) => _sendCmd(n, _clCovering, 1, []);
  @override Future<bool> coveringStop(int n) => _sendCmd(n, _clCovering, 2, []);
  @override
  Future<bool> coveringGoToLift(int nodeId, int percent100ths) =>
      _sendCmd(nodeId, _clCovering, 5, [_arg('liftPercent100thsValue', uintVal: percent100ths)]);

  // ── Color Control ──────────────────────────────────────────────────────────

  static const _clColor = 0x0300;

  @override
  Future<bool> setColorTemperature(int nodeId, int mireds) =>
      _sendCmd(nodeId, _clColor, 0x0A, [
        _arg('colorTemperatureMireds', uintVal: mireds),
        _arg('transitionTime',         uintVal: 0),
        _arg('optionsMask',            uintVal: 0),
        _arg('optionsOverride',        uintVal: 0),
      ]);

  // ── Door Lock ──────────────────────────────────────────────────────────────

  static const _clLock = 0x0101;

  @override
  Future<bool> lockDoor(int nodeId, {String? pin}) =>
      _sendCmd(nodeId, _clLock, 0,
          pin != null && pin.isNotEmpty ? [_arg('PINCode', strVal: pin)] : []);

  @override
  Future<bool> unlockDoor(int nodeId, {String? pin}) =>
      _sendCmd(nodeId, _clLock, 1,
          pin != null && pin.isNotEmpty ? [_arg('PINCode', strVal: pin)] : []);

  // ── Identify ───────────────────────────────────────────────────────────────

  static const _clIdentify = 0x0003;

  @override
  Future<void> identify(int nodeId, {int seconds = 15}) async {
    try {
      // Identify lives on the application endpoint (1), not the root endpoint
      // (0) — endpoint 0 returns UNSUPPORTED_CLUSTER (0xC3). Matches every other
      // cluster command, which all target endpoint 1.
      await _sendCmd(nodeId, _clIdentify, 0,
          [_arg('identifyTime', uintVal: seconds)]);
    } on Exception catch (_) {}
  }

  // ── WriteAttribute — POST /write ──────────────────────────────────────────

  Future<bool> _writeAttr(
    int nodeId, {
    required int clusterId,
    required int attrId,
    int? intVal,
    bool? boolVal,
    String? jsonVal,
    int endpointId = 0xFFFF, // 0xFFFF = auto (endpoint 1)
  }) async {
    final req = $proto.WriteAttrRequest()
      ..nodeId     = Int64(nodeId)
      ..endpointId = endpointId
      ..clusterId  = clusterId
      ..attrId     = attrId;
    if (intVal != null)  req.intVal  = intVal;
    if (boolVal != null) req.boolVal = boolVal;
    if (jsonVal != null) req.jsonVal = jsonVal;
    final body = await _post('/write', req.writeToBuffer(), timeout: _timeout30);
    if (body == null) return false;
    return $proto.BoolResult.fromBuffer(body).success;
  }

  static const int _clThermostat = 0x0201;
  static const int _clFan        = 0x0202;

  @override
  Future<bool> writeHeatingSetpoint(int nodeId, int centidegrees) =>
      _writeAttr(nodeId, clusterId: _clThermostat, attrId: 0x0012, intVal: centidegrees);

  @override
  Future<bool> writeSystemMode(int nodeId, int mode) =>
      _writeAttr(nodeId, clusterId: _clThermostat, attrId: 0x001C, intVal: mode);

  @override
  Future<bool> setFanMode(int nodeId, int mode) =>
      _writeAttr(nodeId, clusterId: _clFan, attrId: 0x0000, intVal: mode);

  @override
  Future<bool> setFanPercent(int nodeId, int percent) =>
      _writeAttr(nodeId, clusterId: _clFan, attrId: 0x0002, intVal: percent);

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
    // Register the listener BEFORE sending the POST so the Observe response
    // cannot arrive in the gap between _post completing and listen() being
    // called (broadcast streams do not buffer — a missed event is lost).
    final completer = Completer<Map<String, dynamic>>();
    late StreamSubscription<DeviceStateEvent> sub;
    sub = deviceStateUpdates.listen((ev) {
      if (ev is SubscriptionUpdateEvent && ev.nodeId == nodeId) {
        if (!completer.isCompleted) completer.complete(ev.attrs);
        sub.cancel();
      }
    });

    try {
      final req = $proto.ReadRequest()
        ..nodeId = Int64(nodeId)
        ..endpointIds.addAll(endpoints)
        ..clusterIds.addAll(clusters)
        ..attrIds.addAll(attrs);
      final body = await _post('/read', req.writeToBuffer(), timeout: _timeout30);
      if (body == null) { sub.cancel(); return null; }
      final ok = $proto.BoolResult.fromBuffer(body).success;
      if (!ok) { sub.cancel(); return null; }

      // Wait for attrs to arrive via the /events?id= Observe stream.
      try {
        return await completer.future.timeout(timeout);
      } on TimeoutException catch (_) {
        sub.cancel();
        return null;
      }
    } on Exception catch (e) {
      sub.cancel();
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
    // BasicInformation cluster attributes are string-valued (vendor name,
    // product name, serial, etc.).  The Attr proto only carries bool/int/long
    // — no string field.  Any read response would arrive with empty keys, and
    // updating the cache with those empty strings would overwrite a valid
    // snapshot.  Return null so callers leave the cache unchanged.
    return null;
  }

  @override
  Future<List<FabricDescriptor>?> readFabrics(int nodeId) async {
    // Hub-managed devices: read via firmware /read (cluster 0x003E attr 0x0001)
    // Stub — returns empty list until firmware exposes a direct Fabrics read.
    // TODO: implement once firmware support is available.
    return const [];
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

  // ── MatterFabricPort ───────────────────────────────────────────────────────

  @override
  Future<ShareDeviceResult?> shareDevice(int nodeId,
      {int vendorId = 0, int productId = 0}) async => null;

  /// Remove a device — DELETE /devices?id=<hex>
  @override
  Future<bool> removeDevice(int nodeId) =>
      _delete('/devices', query: {'id': nodeId.toRadixString(16).padLeft(16, '0')});

  @override
  Future<List<CommissionableDevice>> discoverCommissionableNodes() async => const [];

  @override
  Future<String?> getFabricId() async {
    final info = await getInfo();
    return info != null ? info.fabricId.toHexString() : null;
  }

  @override Future<bool> downloadAndFlash({
    required int nodeId, required String otaUrl,
    required int targetVersion, required String targetVersionString,
    bool dryRun = false, int endpoint = 0,
  }) async => false;
  @override Future<bool> cancelOta() async => false;
  @override Future<List<ThreadBorderRouter>> discoverThreadNetworks() async => const [];
  @override Future<String?> readSystemThreadCredentials() async => null;
  @override Future<ThreadNetworkDiagnostics?> readThreadNetworkDiagnostics(int n) async => null;

  // ── MatterCommissionPort — BLE stays on local MatterChannel ───────────────

  @override
  Future<ShareDeviceResult?> openCommissioningWindow(int nodeId) async =>
      null; // ECM window opens on the local MatterChannel

  @override
  Future<bool> removeFabric(int nodeId, int fabricIndex) async =>
      false; // RemoveFabric runs on the local MatterChannel

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
  }) async => CommissionResult.err('Hub does not commission — use local MatterChannel');

  @override
  Future<CommissionResult> commissionViaCode({required String setupCode}) async =>
      CommissionResult.err('Hub does not commission — use local MatterChannel');

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

// ── DTLS CoAP config ──────────────────────────────────────────────────────────
//
// OpenSSL 3.0 does NOT include PSK cipher suites in its default cipher list.
// We must explicitly set them so the ClientHello includes ciphers that the
// firmware's mbedTLS actually supports.  securityLevel=0 drops the minimum
// key-length floor that OpenSSL 3 enforces by default (level 1), which would
// otherwise silently exclude some PSK suites.
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
