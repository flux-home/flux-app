import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';

import 'package:matter_home/services/controller_transport/controller_transport.dart';
import 'package:matter_home/services/controller_transport/default_transport.dart';
import 'package:matter_home/models/basic_info.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/matter_device.dart' show DeviceKind;
import 'package:matter_home/models/energy_role.dart';
import 'package:matter_home/models/fabric_descriptor.dart';
import 'package:matter_home/models/share_result.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/wifi_network.dart';
import 'package:matter_home/services/cluster_parser.dart' show parseBasicInfo;
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;

export 'package:matter_home/services/proto/flux.pb.dart'
    show ControllerInfo, Device, DeviceList;
// FluxControllerEndpoint moved into the transport module; re-export so existing
// importers of this file are unaffected.
export 'package:matter_home/services/controller_transport/controller_transport.dart'
    show FluxControllerEndpoint;

// ── FluxCoapService ──────────────────────────────────────────────────────────

/// Unified CoAP/DTLS client for the Flux Controller.
///
/// **Resource map** (all payloads binary protobuf, Content-Format 42):
/// ```
/// GET  /info                         → ControllerInfo
/// GET  /thread/dataset               → ThreadDataset  (read-only: the
///                                      controller owns its mesh — the app
///                                      never writes a dataset to it)
/// POST /thread/join                  ← ThreadJoinRequest → ThreadJoinResult
/// POST /thread/create                → StatusResponse (form a new network)
/// POST /thread/epskc                 ← ThreadEphemeralKeyRequest → ThreadEphemeralKeyResult
/// GET  /thread/epskc                 → ThreadEphemeralKeyResult
/// DEL  /thread/epskc                 → (stop the ephemeral-key session)
/// GET  /devices                      → DeviceList
/// POST /devices                      ← RenameDeviceRequest → StatusResponse
/// POST /devices/meta                 ← DeviceMeta → StatusResponse
/// GET  /rooms                        → RoomList
/// PUT  /rooms                        ← RoomList → RoomList (ids assigned)
/// DEL  /devices?id=<hex>             → StatusResponse
/// POST /commission                   ← CommissionRequest → CommissionResult
/// GET  /events?id=<hex>    Observe   → DeviceStateEvent
/// POST /command                      ← DeviceCommand → BoolResult
/// POST /write                        ← WriteAttrRequest → BoolResult
/// POST /read                         ← ReadRequest → BoolResult (data via Observe)
/// ```
class FluxCoapService implements MatterPort {

  FluxCoapService(this.endpoint, {ControllerTransport? transport})
      : _transport = transport ?? defaultControllerTransport(endpoint);

  final FluxControllerEndpoint endpoint;
  final ControllerTransport    _transport;
  bool _disposed = false;

  // Per-node observe stream subscriptions.
  final Map<int, StreamSubscription<TransportEvent>> _subscriptions = {};

  final _deviceStateCtrl      = StreamController<DeviceStateEvent>.broadcast();
  final _commissionEventsCtrl = StreamController<String>.broadcast();

  // ── MatterPort streams ─────────────────────────────────────────────────────

  @override
  Stream<DeviceStateEvent> get deviceStateUpdates => _deviceStateCtrl.stream;

  @override
  Stream<String> get commissionEvents => _commissionEventsCtrl.stream;

  /// Optional reachability signal: invoked with `true` whenever the controller
  /// answers a request and `false` on a timeout/connection failure.
  /// [HubConnection] wires this to drive the app-wide online state.
  void Function(bool reachable)? onReachability;

  // ── Low-level helpers — delegate raw CoAP to the transport ─────────────────
  // The transport may run on a background isolate, keeping the DTLS handshake
  // off the UI thread. This class keeps only proto encode/decode + typed API.

  static const _timeout5   = Duration(seconds: 5);
  static const _timeout15  = Duration(seconds: 15); // DTLS handshake can take ~10s
  static const _timeout30  = Duration(seconds: 30);
  static const _timeout45  = Duration(seconds: 45); // full cluster dump (whole tree)

  Future<Uint8List?> _request(TransportMethod method, String path, {
    Map<String, String>? query,
    Uint8List? body,
    Duration? timeout,
    bool retryOnConnError = true,
  }) async {
    final t = timeout ?? (endpoint.hasDtls ? _timeout15 : _timeout5);
    final r = await _transport.request(TransportRequest(
      method, path,
      query: query,
      body: body,
      timeoutMs: t.inMilliseconds,
      retryOnConnError: retryOnConnError,
    ));
    onReachability?.call(r.ok);
    lastTransportError = r.ok
        ? null
        : (r.error ?? 'no response from ${endpoint.host}:${endpoint.port}');
    return r.success ? r.payload : null;
  }

  /// Why the most recent request failed, or null if it succeeded.
  ///
  /// Requests deliberately return null rather than throwing, so this is the only
  /// way for the connection FSM to tell a DTLS rejection from a timeout from an
  /// unreachable host — all three used to surface as the same empty result.
  String? lastTransportError;

  Future<Uint8List?> _get(String path, {Map<String, String>? query, Duration? timeout}) =>
      _request(TransportMethod.get, path, query: query, timeout: timeout);

  Future<Uint8List?> _put(String path, Uint8List body, {Duration timeout = _timeout5}) =>
      _request(TransportMethod.put, path, body: body, timeout: timeout);

  Future<Uint8List?> _post(String path, Uint8List body,
          {Duration timeout = _timeout30, bool retryOnConnError = true}) =>
      _request(TransportMethod.post, path, body: body,
          timeout: timeout, retryOnConnError: retryOnConnError);

  Future<bool> _delete(String path, {Map<String, String>? query}) async {
    final r = await _transport.request(TransportRequest(
        TransportMethod.delete, path, query: query,
        timeoutMs: _timeout5.inMilliseconds));
    onReachability?.call(r.ok);
    return r.success;
  }

  // ── Config resources ───────────────────────────────────────────────────────

  Future<$proto.ControllerInfo?> getInfo() async {
    final b = await _get('/info');
    if (b == null) return null;
    try { return $proto.ControllerInfo.fromBuffer(b); }
    on Exception catch (e) { debugPrint('FluxCoapService getInfo: $e'); return null; }
  }

  /// The hub's remote-access config (GET /remote/config → RemoteConfig).
  /// Null if unset/unreachable or on a decode error.
  Future<$proto.RemoteConfig?> getRemoteConfig() async {
    final b = await _get('/remote/config');
    if (b == null) return null;
    try { return $proto.RemoteConfig.fromBuffer(b); }
    on Exception catch (e) { debugPrint('FluxCoapService getRemoteConfig: $e'); return null; }
  }

  /// The controller's configured rendezvous URL (RemoteConfig.rendezvous_url)
  /// read over the LAN. Lets the app auto-learn where to signal for off-LAN
  /// access instead of the user typing it. Null if unset/unreachable.
  Future<String?> getRendezvousUrl() async {
    final u = (await getRemoteConfig())?.rendezvousUrl ?? '';
    return u.isEmpty ? null : u;
  }

  /// Enable/disable off-LAN remote access on the hub, optionally seeding the
  /// rendezvous URL. Read-modify-write, because the controller's PUT is a full
  /// replace — so the hub's existing STUN/TURN/proto fields must be preserved.
  /// LAN-only: the controller rejects relayed writes (ADR-0012), so this
  /// returns false when attempted off-LAN. Returns true on success.
  Future<bool> setRemoteEnabled(bool enabled, {String? rendezvousUrl}) async {
    final cfg = await getRemoteConfig() ?? $proto.RemoteConfig();
    cfg.enabled = enabled;
    if (rendezvousUrl != null && rendezvousUrl.isNotEmpty) {
      cfg.rendezvousUrl = rendezvousUrl;
    }
    final resp = await _put('/remote/config', cfg.writeToBuffer());
    return resp != null;
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


  /// Joins the controller to an existing (foreign) Thread network via Thread 1.4
  /// credential sharing — POST /thread/join.  The controller browses
  /// `_meshcop-e._udp` itself and connects to the border agent whose ephemeral
  /// session is live (the other ecosystem's share sheet must be open), so no
  /// address is passed; [ephemeralKey] is the code that app shows.
  ///
  /// [migrate] moves the controller's existing mesh onto the new network via
  /// MGMT_PENDING_SET after [delayMs] (whole mesh transitions together — safe
  /// with commissioned devices).  With [migrate] false the controller adopts
  /// immediately, only safe when it has no children.
  ///
  /// Long-running (foreign DTLS EC-JPAKE handshake + dataset fetch); not
  /// idempotent, so no auto-retry.  Returns the [ThreadJoinResult] (check
  /// `.success`), or null on transport failure.
  Future<$proto.ThreadJoinResult?> joinThreadNetwork({
    required String ephemeralKey,
    bool   migrate = true,
    int    delayMs = 0,
  }) async {
    final req = $proto.ThreadJoinRequest()
      ..ephemeralKey = ephemeralKey
      ..apply        = !migrate
      ..migrate      = migrate
      ..delayMs      = delayMs;
    final b = await _post('/thread/join', req.writeToBuffer(),
        timeout: const Duration(seconds: 45), retryOnConnError: false);
    if (b == null) return null;
    try { return $proto.ThreadJoinResult.fromBuffer(b); }
    on Exception catch (e) {
      debugPrint('FluxCoapService.joinThreadNetwork: $e');
      return null;
    }
  }

  /// Has the controller form a brand-new Thread network of its own — POST
  /// /thread/create.  Generates fresh credentials (network key / PAN ID /
  /// extended PAN ID) and migrates any existing mesh onto it.
  ///
  /// Two uses: bootstrap a mesh when the controller has none, and the inverse
  /// of [joinThreadNetwork] — leave a network shared with another ecosystem and
  /// go back to an independent mesh.  Devices commissioned to the controller
  /// follow the migration; the other ecosystem's hubs stay on the old network.
  ///
  /// Empty request body — there is nothing to parameterise; the controller
  /// generates the credentials.  Returns the [StatusResponse] (`code == 0` on
  /// success), or null on transport failure / if the controller does not
  /// implement the endpoint.
  Future<$proto.StatusResponse?> createThreadNetwork() async {
    final b = await _post('/thread/create', Uint8List(0),
        timeout: const Duration(seconds: 45), retryOnConnError: false);
    if (b == null) return null;
    try { return $proto.StatusResponse.fromBuffer(b); }
    on Exception catch (e) {
      debugPrint('FluxCoapService.createThreadNetwork: $e');
      return null;
    }
  }

  /// Starts Thread 1.4 credential *sharing* (the SHARE side) — POST
  /// /thread/epskc.  The controller (border router) generates a one-time
  /// passcode, starts its ephemeral-key (`_meshcop-e._udp`) session, and
  /// returns the [ThreadEphemeralKeyResult] with the `otpc` to show the user
  /// and the current `state`.  Another ecosystem's app then joins using that
  /// code.  [timeoutSeconds] bounds the session (0 = controller default 120s,
  /// max 600). Returns null on transport failure.
  Future<$proto.ThreadEphemeralKeyResult?> startThreadShare({
    int timeoutSeconds = 300,
  }) async {
    final req = $proto.ThreadEphemeralKeyRequest()..timeoutSeconds = timeoutSeconds;
    // Not idempotent: a retry after reconnect starts a SECOND ephemeral-key
    // session, invalidating the code already shown to the user.
    final b = await _post('/thread/epskc', req.writeToBuffer(),
        retryOnConnError: false);
    return _decodeEpskc(b, 'startThreadShare');
  }

  /// Current state of the ephemeral-key session — GET /thread/epskc. Poll this
  /// to follow the join: "Started" (waiting) → "Connected" → "Accepted"
  /// (the other ecosystem retrieved the credentials). "Stopped"/"Disabled"
  /// means the session ended (timeout or cancelled).
  Future<$proto.ThreadEphemeralKeyResult?> getThreadShareState() async =>
      _decodeEpskc(await _get('/thread/epskc'), 'getThreadShareState');

  /// Stops an active ephemeral-key session — DELETE /thread/epskc.
  Future<bool> stopThreadShare() => _delete('/thread/epskc');

  $proto.ThreadEphemeralKeyResult? _decodeEpskc(Uint8List? b, String where) {
    if (b == null) return null;
    try { return $proto.ThreadEphemeralKeyResult.fromBuffer(b); }
    on Exception catch (e) {
      debugPrint('FluxCoapService.$where: $e');
      return null;
    }
  }

  Future<List<$proto.Device>?> getDeviceList() async {
    final b = await _get('/devices');
    if (b == null) return null;
    try { return $proto.DeviceList.fromBuffer(b).devices; }
    on Exception catch (e) { debugPrint('FluxCoapService getDeviceList: $e'); return null; }
  }

  /// Energy usage aggregated into fixed-width time buckets over [from, to]
  /// (epoch seconds), [bucketSeconds] wide (default 900 = 15 min). Values are
  /// watt-hours per bucket, summed per device class. Null on a transient read
  /// failure. See GET /energy/history.
  ///
  /// [includeDeviceSeries] false adds `series=0`, telling the controller to skip
  /// the per-device breakdown (the bulk of the payload) — used by views that
  /// only need the aggregate buckets (e.g. the consumption history chart).
  Future<$proto.EnergyHistory?> getEnergyHistory({
    required int from,
    required int to,
    int bucketSeconds = 900,
    bool includeDeviceSeries = true,
  }) async {
    final b = await _get('/energy/history', query: {
      'from': '$from',
      'to': '$to',
      'bucket': '$bucketSeconds',
      if (!includeDeviceSeries) 'series': '0',
    }, timeout: _timeout30);
    if (b == null) return null;
    try { return $proto.EnergyHistory.fromBuffer(b); }
    on Exception catch (e) {
      debugPrint('FluxCoapService getEnergyHistory: $e');
      return null;
    }
  }

  /// The current + upcoming day-ahead price curve (GET /prices), or null on a
  /// transient read failure / when pricing is disabled.
  Future<$proto.PriceCurve?> getPrices() async {
    final b = await _get('/prices', timeout: _timeout15);
    if (b == null) return null;
    try { return $proto.PriceCurve.fromBuffer(b); }
    on Exception catch (e) {
      debugPrint('FluxCoapService getPrices: $e');
      return null;
    }
  }

  /// Pricing acquisition + tariff settings (GET /prices/config).
  Future<$proto.PricingConfig?> getPricingConfig() async {
    final b = await _get('/prices/config', timeout: _timeout15);
    if (b == null) return null;
    try { return $proto.PricingConfig.fromBuffer(b); }
    on Exception catch (e) {
      debugPrint('FluxCoapService getPricingConfig: $e');
      return null;
    }
  }

  /// Persist pricing config (POST /prices/config). Send the full config — it
  /// replaces the stored one.
  Future<bool> setPricingConfig($proto.PricingConfig cfg) async {
    final resp = await _post('/prices/config', cfg.writeToBuffer());
    return resp != null;
  }

  /// Push the user's energy-role assignments so the controller classifies the
  /// energy log by role (which node is PV / battery / grid) instead of guessing
  /// from the Modbus profile. [nodeToClass] maps node id → flux_EnergyClass code
  /// (1=grid, 2=pv, 3=load, 4=battery); it's the full set (replaces the stored
  /// map). See POST /energy/roles.
  // ── Rooms & device metadata ────────────────────────────────────────────
  // The controller owns rooms, room membership and energy roles; the app caches
  // them. Held phone-side they disagreed between phones and were wiped whenever
  // a device was re-added.

  /// The controller's room list (GET /rooms). Null on a transport failure —
  /// distinct from an empty list, which means "no rooms yet".
  Future<List<$proto.Room>?> getRooms() async {
    final b = await _get('/rooms');
    if (b == null) return null;
    try { return $proto.RoomList.fromBuffer(b).rooms; }
    on Exception catch (e) { debugPrint('FluxCoapService getRooms: $e'); return null; }
  }

  /// Replace the whole room list (PUT /rooms) and return it as stored.
  ///
  /// A room with id 0 is a creation request; the controller assigns the id, so
  /// the reply is the only way to learn it — hence a list back rather than a
  /// bool. Omitting an existing room deletes it, and any device left pointing at
  /// it falls back to No Room controller-side.
  Future<List<$proto.Room>?> setRooms(List<$proto.Room> rooms) async {
    final body = $proto.RoomList(rooms: rooms).writeToBuffer();
    final b = await _put('/rooms', body);
    if (b == null) return null;
    try { return $proto.RoomList.fromBuffer(b).rooms; }
    on Exception catch (e) { debugPrint('FluxCoapService setRooms: $e'); return null; }
  }

  /// Partial update of controller-owned device metadata (POST /devices/meta).
  ///
  /// Only the arguments passed are written. That distinction matters: 0 is a
  /// real value for both room ("No Room") and energy role ("none"), so clearing
  /// either has to be expressible without also clearing the other.
  Future<bool> setDeviceMeta(
    int nodeId, {
    required DeviceKind kind,
    String? name,
    int? roomId,
    EnergyRole? energyRole,
  }) async {
    final meta = $proto.DeviceMeta()
      ..nodeId = Int64(nodeId)
      ..kind   = $proto.DeviceKind.valueOf(kind.wire) ??
                 $proto.DeviceKind.DEVICE_KIND_UNKNOWN;
    if (name != null)       meta.name    = name;
    if (roomId != null)     meta.roomId  = roomId;
    if (energyRole != null) {
      meta.energyRole = $proto.EnergyRole.valueOf(energyRole.wire) ??
                        $proto.EnergyRole.ENERGY_ROLE_UNSPECIFIED;
    }
    final resp = await _post('/devices/meta', meta.writeToBuffer());
    return resp != null;
  }

  // ── Modbus devices ──────────────────────────────────────────────────────
  // The controller polls Modbus TCP/UDP devices and exposes them as ordinary
  // (synthetic-node-id) devices in /devices. Only provisioning is Modbus-specific.

  /// Scan the controller's own subnet for Modbus devices — GET /modbus/discovered.
  /// The controller runs a ~20 s /24 scan and replies via a separate CoAP
  /// response, so a generous timeout is used.
  Future<$proto.ModbusDiscovered?> scanModbusDevices() async {
    final b = await _get('/modbus/discovered', timeout: const Duration(seconds: 30));
    if (b == null) return null;
    try { return $proto.ModbusDiscovered.fromBuffer(b); }
    on Exception catch (e) { debugPrint('FluxCoapService scanModbusDevices: $e'); return null; }
  }

  /// Add/update a Modbus device — POST /modbus/devices. The controller persists
  /// the config, registers it under a synthetic node id, and starts polling.
  /// Callers should re-read /devices (syncWithController) to pick it up.
  Future<bool> addModbusDevice($proto.ModbusDeviceConfig cfg) async {
    final resp = await _post('/modbus/devices', cfg.writeToBuffer());
    return resp != null;
  }

  /// Remove a Modbus device — DELETE /modbus/devices?id=<hex>.
  Future<bool> removeModbusDevice(int nodeId) =>
      _delete('/modbus/devices',
          query: {'id': nodeId.toRadixString(16).padLeft(16, '0')});

  // ── Commission — POST /commission ────────────────────────────────────────

  /// Hands a commissionable device to the controller by [passcode] +
  /// [discriminator] alone — the controller locates the device itself (its own
  /// SRP server table for devices on its Thread mesh, plus a commissionable
  /// DNS-SD browse on the LAN), performs PASE, and commissions it onto its OWN
  /// fabric with its own CA — so no device CSR ever leaves the controller.  On
  /// success the controller registers + subscribes the device itself.
  ///
  /// Two callers: direct handover (a shared/printed pairing code forwarded
  /// verbatim — set [shortDiscriminator] when a manual 11-digit code only
  /// carries the 4-bit short form) and commission-then-handoff (the ECM window
  /// the phone opened after its Pass-1 BLE commissioning).
  ///
  /// [CommissionResult.fabricId] is the RAW (uncompressed) controller fabric id;
  /// the commission-then-handoff caller matches it against the device's Fabrics
  /// attribute before removing its throwaway fabric.  [nodeId] of 0 lets the
  /// controller assign one.
  Future<$proto.CommissionResult?> commission({
    required int passcode,
    required int discriminator,
    bool         shortDiscriminator = false,
    int          nodeId     = 0,
    String       name       = '',
    int          vendorId   = 0,
    int          productId  = 0,
    int          deviceType = 0,
  }) async {
    final req = $proto.CommissionRequest()
      ..passcode           = passcode
      ..discriminator      = discriminator
      ..shortDiscriminator = shortDiscriminator
      ..nodeId             = Int64(nodeId)
      ..name               = name
      ..vendorId           = vendorId
      ..productId          = productId
      ..deviceType         = deviceType;
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

  /// Pending re-subscribe timer per node — at most ONE in flight. A dropped
  /// observe emits BOTH `error` and `done`, and a closed CoAP client emits `done`
  /// for every live observe, so an unguarded retry per event doubled the number
  /// of observes on every flap (2 -> 4 -> 8), duplicating device events.
  final Map<int, Timer> _subRetryTimers = {};
  final Map<int, int>   _subRetryAttempt = {};

  static const _subRetryBase = Duration(seconds: 2);
  static const _subRetryMax  = Duration(seconds: 60);

  @override
  Future<bool> startSubscription(int nodeId,
      {DeviceKind kind = DeviceKind.matter}) async {
    await stopSubscription(nodeId, kind: kind);
    void scheduleRetry() {
      if (_disposed) return;
      if (_subRetryTimers.containsKey(nodeId)) return; // already queued
      final attempt = (_subRetryAttempt[nodeId] ?? 0) + 1;
      _subRetryAttempt[nodeId] = attempt;
      // Exponential backoff, capped — a permanently-failing hub (wrong PSK,
      // powered off) must not be re-handshaked every 5s per device forever.
      var delay = _subRetryBase * (1 << (attempt - 1).clamp(0, 5));
      if (delay > _subRetryMax) delay = _subRetryMax;
      _subRetryTimers[nodeId] = Timer(delay, () {
        _subRetryTimers.remove(nodeId);
        // Re-check at FIRE time: a retry armed before dispose() used to run on
        // the dead service and add to a closed StreamController.
        if (_disposed) return;
        startSubscription(nodeId, kind: kind).catchError((Object e) {
          debugPrint('FluxCoapService sub $nodeId retry error: $e');
          return false;
        });
      });
    }

    final hexId = nodeId.toRadixString(16).padLeft(16, '0');
    // Send the kind explicitly: the controller can infer it from the node id
    // alone today, but only because no id is reused across kinds — don't lean
    // on that.
    _subscriptions[nodeId] = _transport.observe('/events',
        query: {'id': hexId, 'kind': '${kind.wire}'}).listen(
      (ev) {
        switch (ev.kind) {
          case TransportEventKind.data:
            onReachability?.call(true);
            _subRetryAttempt.remove(nodeId); // healthy again — reset backoff
            if (ev.payload != null) _handleStateBytes(nodeId, ev.payload!);
          case TransportEventKind.error:
            debugPrint('FluxCoapService sub $nodeId error: ${ev.error}');
            _deviceStateCtrl.add(
                SubscriptionErrorEvent(nodeId, ev.error ?? '', kind: kind));
            scheduleRetry();
          case TransportEventKind.done:
            debugPrint('FluxCoapService sub $nodeId done');
            _subscriptions.remove(nodeId);
            _deviceStateCtrl.add(
                SubscriptionResubscribingEvent(nodeId, 0, kind: kind));
            scheduleRetry();
        }
      },
      onError: (Object e) {
        debugPrint('FluxCoapService sub $nodeId stream error: $e');
        _deviceStateCtrl.add(
            SubscriptionErrorEvent(nodeId, e.toString(), kind: kind));
        scheduleRetry();
      },
    );
    return true;
  }

  @override
  Future<void> stopSubscription(int nodeId,
      {DeviceKind kind = DeviceKind.matter}) async {
    _subRetryTimers.remove(nodeId)?.cancel();
    final sub = _subscriptions.remove(nodeId);
    await sub?.cancel();
  }

  // ── Commission progress — GET /commission/events (Observe) ────────────────

  /// Observes the controller's commissioning-progress stream.  Each event
  /// carries the latest stage of the in-flight POST /commission (`seq` is
  /// monotonic; seq 0 = nothing happened yet — filtered out here).  Advisory,
  /// UI-only: transport errors end the stream silently; the [commission]
  /// reply stays the source of truth for success/failure.  Cancel the
  /// subscription once the commission completes.
  Stream<$proto.CommissionEvent> observeCommissionEvents() {
    late StreamController<$proto.CommissionEvent> ctrl;
    StreamSubscription<TransportEvent>? sub;
    var lastSeq = 0;
    ctrl = StreamController(
      onListen: () {
        sub = _transport.observe('/commission/events').listen(
          (ev) {
            if (ev.kind != TransportEventKind.data || ev.payload == null) {
              return;
            }
            try {
              final e = $proto.CommissionEvent.fromBuffer(ev.payload!);
              // seq 0 = idle snapshot on register; repeats = stale re-notify.
              if (e.seq == 0 || e.seq == lastSeq) return;
              lastSeq = e.seq;
              if (!ctrl.isClosed) ctrl.add(e);
            } on Exception catch (e) {
              debugPrint('FluxCoapService.observeCommissionEvents: $e');
            }
          },
          onError: (Object e) {
            debugPrint('FluxCoapService.observeCommissionEvents: $e');
          },
        );
      },
      onCancel: () async => sub?.cancel(),
    );
    return ctrl.stream;
  }

  void _handleStateBytes(int nodeId, Uint8List bytes) {
    try {
      if (bytes.isEmpty) return;
      final ev = $proto.DeviceStateEvent.fromBuffer(bytes);
      _deviceStateCtrl.add(_toAppEvent(ev));
    } on Exception catch (e) {
      debugPrint('FluxCoapService._handleStateBytes: $e');
    }
  }

  DeviceStateEvent _toAppEvent($proto.DeviceStateEvent ev) {
    final nodeId = ev.nodeId.toInt();
    // Carry the kind through: a device is (kind, nodeId), so an event decoded
    // without it would be matched against the wrong device — or, for a Modbus
    // device, against nothing at all, silently stopping its readings.
    final kind = DeviceKind.fromWire(ev.kind.value);
    switch (ev.type) {
      case $proto.DeviceEventType.DEVICE_EVENT_ESTABLISHED:
        return SubscriptionEstablishedEvent(nodeId, kind: kind);
      case $proto.DeviceEventType.DEVICE_EVENT_ERROR:
        return SubscriptionErrorEvent(nodeId, ev.error, kind: kind);
      case $proto.DeviceEventType.DEVICE_EVENT_RESUBSCRIBING:
        return SubscriptionResubscribingEvent(nodeId, 0, kind: kind);
      case $proto.DeviceEventType.DEVICE_EVENT_ATTRS_UPDATE:
        final attrs = <String, dynamic>{};
        for (final a in ev.update.attrs) {
          if (a.hasBoolVal())      attrs[a.key] = a.boolVal;
          else if (a.hasIntVal())  attrs[a.key] = a.intVal;
          else if (a.hasLongVal()) attrs[a.key] = a.longVal.toInt();
        }
        return SubscriptionUpdateEvent(nodeId, attrs, kind: kind);
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
    // Not idempotent: stepLevel / covering / lock commands would be applied
    // twice if the request landed but its response was lost. The retry runs on a
    // new DTLS session with a new token, so controller-side dedup can't suppress it.
    final body = await _post('/command', cmd.writeToBuffer(), timeout: timeout,
        retryOnConnError: false);
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
    // Parse the BasicInformation cluster (0x0028) out of the controller's
    // cluster dump (GET /devices/clusters). The phone is no longer on the
    // device fabric, so this is the only path to the string-valued attributes.
    return parseBasicInfo(await readClusters(nodeId));
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

  // Coalesces concurrent cluster-dump fetches for the same (node, full) request.
  // device-detail kicks off readBasicInfo and readClusters in parallel, so
  // without this each open fires two reads at once. Keyed by (node, full) so a
  // targeted detail read and a full inspector read don't accidentally share.
  final Map<int, Future<String?>> _clusterDumpInflight = {};

  /// Cluster/attribute dump for [n], read by the controller over its CASE
  /// session and returned as the JSON `parseClusters` expects
  /// (`[{endpoint, clusterId, attributes:[{id, value}]}]`). The phone is off the
  /// device fabric post-handoff, so reads must go through the controller.
  ///
  /// [full] true reads the whole tree (Cluster Inspector); false (default) reads
  /// only the static metadata device-detail needs (BasicInfo + Descriptor +
  /// OnOff) — live readings arrive via the subscription. Single-flighted so
  /// concurrent callers share one read.
  @override
  Future<String?> readClusters(int n, {bool full = false}) {
    final key = (n << 1) | (full ? 1 : 0);
    final inflight = _clusterDumpInflight[key];
    if (inflight != null) return inflight;
    final f = _fetchClusterDump(n, full);
    _clusterDumpInflight[key] = f;
    f.whenComplete(() => _clusterDumpInflight.remove(key));
    return f;
  }

  Future<String?> _fetchClusterDump(int n, bool full) async {
    // The full read traverses the whole tree on the controller (up to ~25s on a
    // lossy mesh); wait longer than the controller does so we still receive its
    // reply (even "[]") rather than timing out first.
    final body = await _get('/devices/clusters',
        query: {
          'id': n.toRadixString(16).padLeft(16, '0'),
          if (full) 'full': '1',
        },
        timeout: full ? _timeout45 : _timeout30);
    if (body == null) return null;
    final s = utf8.decode(body, allowMalformed: true);
    return s.isEmpty ? null : s;
  }

  // ── MatterFabricPort ───────────────────────────────────────────────────────

  /// Remove a device — DELETE /devices?id=<hex>
  @override
  Future<bool> removeDevice(int nodeId, {DeviceKind kind = DeviceKind.matter}) =>
      _delete('/devices', query: {
        'id': nodeId.toRadixString(16).padLeft(16, '0'),
        'kind': '${kind.wire}',
      });

  @override Future<String?> readSystemThreadCredentials() async => null;

  @override
  Future<String?> getFabricId() async {
    final info = await getInfo();
    return info != null ? info.fabricId.toHexString() : null;
  }

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
    // Detach the reachability callback first: a late timeout on this (now dead)
    // service must not write connection state for whatever replaced it.
    onReachability = null;
    for (final t in _subRetryTimers.values) {
      t.cancel();
    }
    _subRetryTimers.clear();
    _subRetryAttempt.clear();
    for (final sub in _subscriptions.values) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    unawaited(_transport.dispose());
    _deviceStateCtrl.close();
    _commissionEventsCtrl.close();
  }
}
