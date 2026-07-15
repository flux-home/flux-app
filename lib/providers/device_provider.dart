import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/switch_group.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_live_data.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/energy_history.dart';
import 'package:matter_home/models/energy_prices.dart';
import 'package:matter_home/models/energy_role.dart';
import 'package:matter_home/models/energy_summary.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/ota_progress.dart';
import 'package:matter_home/models/room.dart';
import 'package:matter_home/models/persisted_snapshot.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:uuid/uuid.dart';

enum DeviceProviderState { idle, loading, error }

class DeviceProvider extends ChangeNotifier {
  // ── Constructor ───────────────────────────────────────────────────────────

  /// [channel] is [NullMatterPort] until a controller is found, then becomes
  /// the live [FluxCoapService] via [adoptHubMode] — see `docs/controller-only-control.md`.
  DeviceProvider(this._store, MatterPort channel, {
    FluxCoapService? controllerService,
  })  : _channel     = channel,
        _ctrlService = controllerService {
    _load();
    _deviceStateSub = _channel.deviceStateUpdates.listen(_onDeviceStateEvent);
    Future.microtask(_startAllSubscriptions);
    if (_ctrlService != null) Future.microtask(syncWithController);
  }

  /// Wires this provider to the app-wide [HubConnection] so that any later
  /// service swap (background discovery, the Flux Hub "↺" button, re-adding a
  /// controller) is adopted automatically.  Without this, swapping the service
  /// in [HubConnection] would leave this provider running against the old —
  /// now disposed — [FluxCoapService].
  void attachHubConnection(HubConnection hub) {
    _hubConn = hub;
    hub.addListener(_onHubConnectionChanged);
  }

  HubConnection? _hubConn;

  void _onHubConnectionChanged() {
    final svc = _hubConn?.service;
    if (svc != null && !identical(svc, _ctrlService)) {
      unawaited(adoptHubMode(svc));
    }
  }
  final DeviceStore _store;
  MatterPort _channel;
  /// Non-null in hub mode — used to reconcile the device list with the
  /// controller's NVS on startup and to seed [isOnline] from [Device.reachable].
  FluxCoapService? _ctrlService;
  final _uuid = const Uuid();

  DeviceProviderState state = DeviceProviderState.idle;
  String? errorMessage;
  List<MatterDevice> _devices = [];

  // ── Rooms ───────────────────────────────────────────────────────────────────
  // "No Room" is always the first entry and is never stored to disk.
  List<Room> _rooms = [Room.noRoom];

  // ── In-memory caches ──────────────────────────────────────────────────────
  final Map<String, DeviceLiveData>        _liveCache     = {};
  final Map<String, String>                _clusterCache  = {}; // deviceId → JSON
  final Map<String, OtaProgressState>      _otaProgress   = {};
  final Map<String, PersistedSnapshot>     _snapshots     = {};

  // ── Automation rules ────────────────────────────────────────────────────
  final List<AutomationRule> _rules               = [];
  final Map<String, int>     _lastSwitchPressTime = {}; // debounce

  final Set<int> _subscribedNodeIds = {};

  /// Timers that fire a fallback [refreshDevice] if a subscription does not
  /// deliver an `established` event within [_kEstablishTimeout].
  final Map<String, Timer?> _establishTimeouts = {};

  /// Tracks which devices have already had their snapshot flushed after the
  /// first `established` event this session.  Prevents redundant disk writes.
  final Set<String> _establishedThisSession = {};

  bool _disposed = false;

  StreamSubscription<DeviceStateEvent>? _deviceStateSub;

  // ── Public device list ────────────────────────────────────────────────────

  /// Raw commissioning records.  Most screens should use [deviceViewsByRoom] or
  /// [viewFor] instead — those carry merged live state.
  List<MatterDevice> get devices => List.unmodifiable(_devices);

  /// Rooms in creation order ("No Room" is always first).
  List<Room> get rooms => List.unmodifiable(_rooms);

  /// Devices grouped by room, in room creation order.
  /// Every room appears in the list regardless of whether it has devices,
  /// so the home screen always renders the section header.
  List<(Room, List<DeviceView>)> get deviceViewsByRoom {
    return _rooms.map((room) {
      final views = _devices
          .where((d) => d.roomId == room.id)
          .map((d) => DeviceView(d, _liveCache[d.id]))
          .toList();
      return (room, views);
    }).toList();
  }

  /// Flat list of all devices as merged [DeviceView]s (across every room).
  /// Used by the category screens, which filter rather than group by room.
  List<DeviceView> get deviceViews =>
      _devices.map((d) => DeviceView(d, _liveCache[d.id])).toList();

  /// Controller-side Modbus devices (synthetic node-id range). Drives the
  /// Modbus devices management screen.
  List<DeviceView> get modbusDevices =>
      deviceViews.where((v) => v.isModbus).toList();

  /// The app's (authoritative, user-editable) name for the device with [nodeId],
  /// or null if unknown. Lets views resolve names locally instead of trusting
  /// stale names baked into controller-side data (e.g. the energy-history log).
  String? deviceNameForNode(int nodeId) {
    for (final d in _devices) {
      if (d.nodeId == nodeId) return d.name;
    }
    return null;
  }

  /// Live whole-home energy picture aggregated by [EnergyRole] across all
  /// devices. Drives the home-screen energy-flow overview.
  ///
  /// When a paired hub is unreachable the readings can't be current, so the
  /// picture is invalidated (empty) rather than showing the last cached flow.
  /// Per-device, unreachable devices are excluded by [EnergySummary.fromDevices].
  EnergySummary get energySummary {
    if (_hubConn != null && _hubConn!.hasConfiguredHub && !_hubConn!.isOnline) {
      return const EnergySummary();
    }
    return EnergySummary.fromDevices(deviceViews);
  }

  // ── 24-hour energy history ──────────────────────────────────────────────────
  // Fetched on demand from the controller's GET /energy/history and cached so
  // reopening the Energy view is instant; refreshed on pull-to-refresh.

  EnergyHistoryData? _energyHistory;
  bool _energyHistoryLoading = false;
  Future<void>? _energyHistoryInflight;

  /// Last-fetched 24-hour energy history, or null if never loaded / hub-less.
  EnergyHistoryData? get energyHistory => _energyHistory;
  bool get energyHistoryLoading => _energyHistoryLoading;

  /// Fetch the last 24 hours of energy history from the controller (15-min
  /// buckets). No-op without a controller. Concurrent calls are coalesced; a
  /// transient failure leaves any previously-loaded history in place.
  Future<void> fetchEnergyHistory() {
    final inflight = _energyHistoryInflight;
    if (inflight != null) return inflight;
    final svc = _ctrlService;
    if (svc == null) return Future.value();

    _energyHistoryLoading = true;
    notifyListeners();

    final f = () async {
      final now = DateTime.now();
      final to = now.millisecondsSinceEpoch ~/ 1000;
      final from = to - 24 * 3600;
      // The history chart plots aggregate consumption only, so skip the
      // per-device series — it's the bulk of the payload.
      final h = await svc.getEnergyHistory(
          from: from, to: to, includeDeviceSeries: false);
      if (_disposed) return;
      if (h != null) _energyHistory = EnergyHistoryData.fromProto(h);
    }();
    _energyHistoryInflight = f.whenComplete(() {
      _energyHistoryInflight = null;
      _energyHistoryLoading = false;
      if (!_disposed) notifyListeners();
    });
    return _energyHistoryInflight!;
  }

  // ── Day-ahead energy prices ──────────────────────────────────────────────────

  EnergyPrices? _energyPrices;
  bool _energyPricesLoading = false;
  Future<void>? _energyPricesInflight;
  $proto.PricingConfig? _pricingConfig; // tariff markup + VAT applied to prices

  /// Last-fetched day-ahead price curve, or null if never loaded / pricing
  /// disabled on the controller. Prices are gross (tariff markup + VAT applied).
  EnergyPrices? get energyPrices => _energyPrices;
  bool get energyPricesLoading => _energyPricesLoading;

  /// The controller's pricing config (tariff markup, VAT, provider…), if loaded.
  $proto.PricingConfig? get pricingConfig => _pricingConfig;

  /// Fetch the day-ahead price curve (GET /prices) + tariff config, and build
  /// the gross consumer prices. No-op without a controller; coalesced.
  Future<void> fetchEnergyPrices() {
    final inflight = _energyPricesInflight;
    if (inflight != null) return inflight;
    final svc = _ctrlService;
    if (svc == null) return Future.value();

    _energyPricesLoading = true;
    notifyListeners();

    final f = () async {
      final cfg = await svc.getPricingConfig();
      final c = await svc.getPrices();
      if (_disposed) return;
      if (cfg != null) _pricingConfig = cfg;
      if (c != null) {
        _energyPrices = EnergyPrices.fromProto(
          c,
          markupUeurPerKwh: _pricingConfig?.markupUeurPerKwh ?? 0,
          vatPercent: _pricingConfig?.vatPercent ?? 0,
        );
      }
    }();
    _energyPricesInflight = f.whenComplete(() {
      _energyPricesInflight = null;
      _energyPricesLoading = false;
      if (!_disposed) notifyListeners();
    });
    return _energyPricesInflight!;
  }

  /// Update the tariff (grid fees + levies + taxes as [markupUeurPerKwh], and
  /// [vatPercent]) on the controller, preserving the rest of the config, then
  /// re-fetch so prices reflect the real consumer price. Returns false on error.
  Future<bool> updateTariff({
    required int markupUeurPerKwh,
    required int vatPercent,
    required int feedInUeurPerKwh,
  }) async {
    final svc = _ctrlService;
    if (svc == null) return false;
    final cfg = _pricingConfig ?? await svc.getPricingConfig();
    if (cfg == null) return false;
    cfg
      ..markupUeurPerKwh = markupUeurPerKwh
      ..vatPercent = vatPercent
      ..feedInUeurPerKwh = feedInUeurPerKwh;
    final ok = await svc.setPricingConfig(cfg);
    if (ok) {
      _pricingConfig = cfg;
      await fetchEnergyPrices();
    }
    return ok;
  }

  /// Returns a merged [DeviceView] for [id], or null if the device is unknown.
  DeviceView? viewFor(String id) {
    final idx = _indexById(id);
    if (idx < 0) return null;
    return DeviceView(_devices[idx], _liveCache[_devices[idx].id]);
  }

  @override
  void dispose() {
    _disposed = true;
    _hubConn?.removeListener(_onHubConnectionChanged);
    for (final t in _establishTimeouts.values) {
      t?.cancel();
    }
    _establishTimeouts.clear();
    _deviceStateSub?.cancel();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  void _load() {
    _rules.addAll(_store.loadRules());
    _snapshots.addAll(_store.loadSnapshots());
    // Rooms: sentinel first, then persisted user-created rooms.
    _rooms = [Room.noRoom, ..._store.loadRooms()];

    _devices = _store.loadDevices().map((d) {
      // Legacy fix: devices stored before device-type mapping may have
      // onOffLight as a stale commissioning fallback for thermostats.
      if (d.deviceType == DeviceType.onOffLight) {
        final snap = _snapshots[d.id];
        if (snap?.state['localTempCenti'] != null) {
          return d.copyWith(deviceType: DeviceType.thermostat);
        }
      }
      // Legacy fix: older builds hardcoded every controller device to Thread.
      // Correct Modbus nodes to Modbus and drop the bogus Thread label on other
      // controller nodes (we can't yet tell Wi-Fi from Thread) so the info
      // screen stops mislabelling them. Mirrors the repair in reconcile.
      final normalized = _normalizeControllerNetworkType(d);
      if (normalized != d.networkType) {
        return d.copyWith(networkType: normalized);
      }
      return d;
    }).toList();

    // Seed the live cache from snapshots so home-screen tiles show the
    // last-known state immediately — before any subscription arrives.
    for (final device in _devices) {
      final snap = _snapshots[device.id];
      if (snap != null) {
        // Seed the persisted cluster dump (static metadata) so the device view
        // can render device-info + readings + controllability without a read.
        if (snap.clusterJson != null) _clusterCache[device.id] = snap.clusterJson!;
        // Merge the full persisted attribute map (same keys as subscription
        // events) then mark stale so the UI dims until a live update arrives.
        final basicInfo = snap.productName != null
            ? BasicInfoCache(productName: snap.productName)
            : BasicInfoCache.empty;
        _liveCache[device.id] = DeviceLiveData(
          updatedAt: DateTime.now(),
          isStale: false, // merge() resets this; markStale() restores it
          basicInfo: basicInfo,
        ).merge(snap.state).markStale();
      }
    }

    notifyListeners();
  }

  // ── Controller reconciliation ─────────────────────────────────────────────────

  /// The correct [NetworkType] for a controller-managed device given what we can
  /// determine locally: Modbus nodes (synthetic node id) are Modbus; the bogus
  /// Thread label older builds stamped on every controller node is downgraded to
  /// unknown (we can't yet distinguish Wi-Fi from Thread). Genuine Wi-Fi/Ethernet
  /// labels — only ever set from real commissioning data — are preserved, as are
  /// phone-managed devices.
  static NetworkType _normalizeControllerNetworkType(MatterDevice d) {
    if (d.isModbus) return NetworkType.modbus;
    if (d.managedBy == ManagedBy.controller &&
        d.networkType == NetworkType.thread) {
      return NetworkType.unknown;
    }
    return d.networkType;
  }

  bool _syncInFlight = false;

  /// Public entry point for refreshing the device list from the controller.
  ///
  /// Safe to call from anywhere and as often as needed — pull-to-refresh, the
  /// app-resume lifecycle hook, the periodic foreground poll, or the Flux Hub
  /// "↺" button.  Concurrent calls are coalesced into the in-flight one.
  /// No-op when not in hub mode.
  Future<void> syncWithController() async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      await _reconcileWithController();
    } finally {
      _syncInFlight = false;
    }
  }

  /// Reconciles the local device list with the controller’s list so the two
  /// stay in sync without an app restart.  Three things happen:
  ///  1. Controller devices not in the local store are added automatically
  ///     (e.g. commissioned on a previous session or from another phone) and
  ///     their subscriptions started so live state flows immediately.
  ///  2. [isOnline] is re-seeded from [Device.reachable] for known devices.
  ///  3. Controller-managed devices the controller no longer reports are
  ///     removed locally (e.g. deleted from another phone) — the controller is
  ///     the source of truth for controller-managed nodes.
  ///
  /// A `null` device list (transient CoAP/DTLS failure) leaves the list
  /// untouched; an empty-but-non-null list is treated as authoritative.
  Future<void> _reconcileWithController() async {
    final svc = _ctrlService;
    if (svc == null) return;

    final raw = await svc.getDeviceList();
    if (raw == null) return; // transient failure — never wipe on a failed read

    var changed = false;
    final now   = DateTime.now();
    final controllerNodeIds = <int>{};

    for (final cd in raw) {
      final nodeId = cd.nodeId.toInt();
      controllerNodeIds.add(nodeId);
      final idx = _devices.indexWhere((d) => d.nodeId == nodeId);

      if (idx == -1) {
        // Device on controller but not locally — add it.
        final dt = cd.deviceType > 0
            ? DeviceType.fromMatterDeviceTypeId(cd.deviceType)
            : DeviceType.unknown;
        // Modbus devices carry a synthetic node id (>= FLUX_MODBUS_NODE_BASE) and
        // are reliably identifiable here. The controller doesn't (yet) report the
        // transport for real Matter nodes, so leave those as `unknown` — the info
        // screen hides the Network row rather than falsely labelling them Thread.
        final networkType = nodeId >= 0x0100000000000000
            ? NetworkType.modbus
            : NetworkType.unknown;
        final device = MatterDevice(
          id:             _uuid.v4(),
          name:           cd.name.isNotEmpty ? cd.name : 'Device $nodeId',
          deviceType:     dt,
          nodeId:         nodeId,
          commissionedAt: now,
          lastModified:   now,
          networkType:    networkType,
          managedBy:      ManagedBy.controller,
          isOnline:       cd.reachable,
        );
        _devices.add(device);
        changed = true;
        // Start the subscription so the freshly-discovered device delivers
        // live state without waiting for the next launch.  Guarded against
        // double-subscribe by _subscribedNodeIds.
        unawaited(_startSubscription(device));
        debugPrint('DeviceProvider: added controller device '
            '$nodeId (${device.name})');
      } else {
        // Already known — re-seed online state from controller’s reachable flag.
        if (_devices[idx].isOnline != cd.reachable) {
          _devices[idx] = _devices[idx].copyWith(isOnline: cd.reachable);
          changed = true;
        }
        // Repair the network type for records persisted by older builds, which
        // hardcoded every controller device to Thread. Modbus nodes become
        // Modbus; a bogus Thread on a controller node is downgraded to unknown
        // (we can't tell Wi-Fi from Thread yet). Genuine Wi-Fi/Ethernet labels
        // — which only come from real commissioning data — are left intact.
        final existing = _devices[idx];
        final corrected = _normalizeControllerNetworkType(existing);
        if (corrected != existing.networkType) {
          _devices[idx] = existing.copyWith(networkType: corrected);
          changed = true;
        }
      }
    }

    // Drop controller-managed devices the controller no longer reports.
    // Phone-commissioned devices are never auto-removed here — they live in the
    // local CHIP fabric and are owned by this app.
    final stale = _devices
        .where((d) =>
            d.managedBy == ManagedBy.controller &&
            !controllerNodeIds.contains(d.nodeId))
        .map((d) => d.id)
        .toList();
    for (final id in stale) {
      await _purgeControllerDevice(id);
      changed = true;
    }

    if (changed) {
      await _persist();
      notifyListeners();
    }

    // Keep the controller's energy-log classification in sync with the user's
    // role assignments (cheap; the controller just replaces its override map).
    unawaited(_syncEnergyRoles());
  }

  /// Local-only removal of a controller-managed device that the controller has
  /// already dropped.  Stops the subscription and purges caches but — unlike
  /// [removeDevice] — does NOT call the controller or local CHIP fabric, since
  /// the node is already gone on the controller side.
  Future<void> _purgeControllerDevice(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    await _stopSubscription(_devices[idx]);
    _establishTimeouts.remove(deviceId)?.cancel();
    final idx2 = _indexById(deviceId);
    if (idx2 != -1) _devices.removeAt(idx2);
    _liveCache.remove(deviceId);
    _clusterCache.remove(deviceId);
    _snapshots.remove(deviceId);
    debugPrint('DeviceProvider: purged stale controller device $deviceId');
  }

  // ── Hub connection ────────────────────────────────────────────────────────

  /// Switches this provider from the inert [NullMatterPort] placeholder (or a
  /// stale controller) over to the live [FluxCoapService] once the Flux
  /// Controller is discovered/reconnected.  Device control is always
  /// controller-proxied (`POST /command` / `/write` / `/read` + `GET /events`
  /// — see `docs/controller-only-control.md`); there is no local-CHIP control
  /// path to fall back to.
  ///
  /// Stops all subscriptions on the old channel, rewires the event listener
  /// to the CoAP service, restarts subscriptions, and runs reconciliation.
  Future<void> adoptHubMode(FluxCoapService svc) async {
    if (_disposed) return;
    // Idempotent: re-adopting the same service (e.g. listener + explicit call)
    // must not tear down and rebuild healthy subscriptions.
    if (identical(svc, _ctrlService)) return;

    // Tear down existing subscriptions and listener.
    await _deviceStateSub?.cancel();
    _deviceStateSub = null;
    for (final nodeId in List<int>.of(_subscribedNodeIds)) {
      try { await _channel.stopSubscription(nodeId); } on Exception catch (_) {}
    }
    _subscribedNodeIds.clear();

    // Cancel any pending establish-fallback timers.
    for (final t in _establishTimeouts.values) t?.cancel();
    _establishTimeouts.clear();
    _establishedThisSession.clear();

    // Swap to the hub channel.
    _channel    = svc;
    _ctrlService = svc;

    // Rewire event listener and restart subscriptions.
    _deviceStateSub = _channel.deviceStateUpdates.listen(_onDeviceStateEvent);
    await _startAllSubscriptions();
    await syncWithController();
  }

  /// Persists both the commissioning records and the live-state snapshots.
  Future<void> _persist() async {
    await _store.saveDevices(_devices);
    await _store.saveSnapshots(_snapshots);
  }

  Future<void> _persistRules() => _store.saveRules(_rules);

  /// Persists the user-created rooms list (excludes the sentinel).
  Future<void> _persistRooms() => _store.saveRooms(_rooms);

  /// Captures the current live cache for [deviceId] into [_snapshots] and
  /// writes both stores to disk.  Called only at explicit checkpoints
  /// (first established event, user action, successful poll) — never from
  /// the subscription hot path.
  Future<void> _flushSnapshot(String deviceId) async {
    final live = _liveCache[deviceId];
    if (live == null) return;
    // Preserve the cached cluster dump — it isn't part of live state, so a plain
    // capture would drop it on every checkpoint.
    _snapshots[deviceId] = PersistedSnapshot.capture(deviceId, live,
        clusterJson: _clusterCache[deviceId] ?? _snapshots[deviceId]?.clusterJson);
    await _persist();
  }

  // ── Live cache helpers ────────────────────────────────────────────────────

  /// Returns the raw live cache for [deviceId].
  /// Prefer [viewFor] when you also need commissioning fields.
  DeviceLiveData? liveDataFor(String deviceId) => _liveCache[deviceId];

  String? clusterCacheFor(String deviceId) => _clusterCache[deviceId];
  OtaProgressState? otaProgressFor(String deviceId) => _otaProgress[deviceId];

  // ── Automation rule management ────────────────────────────────────────────

  /// All rules whose source is [deviceId].
  List<AutomationRule> rulesFor(String deviceId) =>
      _rules.where((r) => r.sourceDeviceId == deviceId).toList();

  /// Devices that can be targeted by [action], excluding [excludingDeviceId].
  List<DeviceView> linkableTargets({
    String? excludingDeviceId,
    AutomationAction? action,
  }) {
    return _devices
        .where((d) => d.id != excludingDeviceId)
        .map((d) => DeviceView(d, _liveCache[d.id]))
        .where((v) => action == null || _supportsAction(v, action))
        .toList();
  }

  bool _supportsAction(DeviceView v, AutomationAction action) {
    final live = _liveCache[v.id];
    return switch (action) {
      AutomationAction.toggle ||
      AutomationAction.turnOn  ||
      AutomationAction.turnOff =>
          v.deviceType.hasOnOff || (live?.attrs.containsKey('onOff') ?? false) ||
          v.deviceType == DeviceType.thermostat || (live?.attrs.containsKey('systemMode') ?? false),
      AutomationAction.thermostatOff =>
          v.deviceType == DeviceType.thermostat || (live?.attrs.containsKey('systemMode') ?? false),
      AutomationAction.brightnessStepUp ||
      AutomationAction.brightnessStepDown =>
          v.deviceType.hasBrightness || (live?.attrs.containsKey('level') ?? false),
      AutomationAction.thermostatSetpointUp ||
      AutomationAction.thermostatSetpointDown =>
          v.deviceType == DeviceType.thermostat ||
          (live?.attrs.containsKey('localTempCenti') ?? false),
    };
  }

  void upsertRule(AutomationRule rule) {
    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) { _rules[idx] = rule; } else { _rules.add(rule); }
    unawaited(_persistRules());
    notifyListeners();
  }

  void removeRule(String ruleId) {
    _rules.removeWhere((r) => r.id == ruleId);
    unawaited(_persistRules());
    notifyListeners();
  }

  void clearOtaProgress(String deviceId) {
    _otaProgress.remove(deviceId);
    notifyListeners();
  }

  void cacheClusterJson(String deviceId, String json) {
    // Never cache an empty/failed dump ("[]") — that would pin the device to no
    // data and suppress the re-read that would recover it.
    if (json.isEmpty || json == '[]') return;
    _clusterCache[deviceId] = json;
    // Persist it (static metadata) so future opens — and cold launches — render
    // device-info/readings/controllability without re-reading from the
    // controller. Best-effort; no notifyListeners (detail screen reads directly).
    final prev = _snapshots[deviceId] ?? PersistedSnapshot(deviceId: deviceId);
    _snapshots[deviceId] = prev.withClusterJson(json);
    unawaited(_persist());
  }

  /// Applies [transform] to the live cache entry for [deviceId], creating a
  /// blank entry if none exists.  Always calls [notifyListeners].
  void _mergeLiveCache(String deviceId, DeviceLiveData Function(DeviceLiveData) transform) {
    _liveCache[deviceId] = transform(_liveCache[deviceId] ?? DeviceLiveData(updatedAt: DateTime.now(), isStale: false));
    notifyListeners();
  }

  void updateBasicInfo(
    String deviceId,
    String? productName,
    String? serial,
    String? swVersion, {
    String? vendorName,
    String? vendorId,
    String? productId,
    String? hwVersion,
    String? manufacturingDate,
    String? partNumber,
    String? productUrl,
    String? uniqueId,
    int? swVersionNum,
  }) {
    _mergeLiveCache(
      deviceId,
      (e) => e.withBasicInfo(
        serial,
        swVersion,
        productName,
        vendorName: vendorName,
        vendorId: vendorId,
        productId: productId,
        hwVersion: hwVersion,
        manufacturingDate: manufacturingDate,
        partNumber: partNumber,
        productUrl: productUrl,
        uniqueId: uniqueId,
        swVersionNum: swVersionNum,
      ),
    );
    // Persist the product name into the snapshot so it survives cold restarts.
    if (productName != null && productName.isNotEmpty) {
      unawaited(_flushSnapshot(deviceId));
    }
  }

  void updateOtaSupport(String deviceId, {required bool supported, int endpoint = 0}) {
    _mergeLiveCache(deviceId, (e) => e.withOtaSupported(value: supported, endpoint: endpoint));
  }

  /// Searches for the OTA Requestor cluster (0x002A) across all endpoints.
  Future<void> detectAndUpdateOtaSupport(String deviceId) async {
    if (liveDataFor(deviceId)?.otaSupported != null) return;
    final device = findById(deviceId);
    if (device == null) return;

    const otaClusterId = 0x002A;
    int? foundEndpoint;

    final ep0 = await _channel.readServerClusterList(device.nodeId);
    if (ep0.contains(otaClusterId)) {
      foundEndpoint = 0;
    } else {
      for (final ep in await _channel.readPartsList(device.nodeId)) {
        final clusters = await _channel.readServerClusterList(device.nodeId, endpoint: ep);
        if (clusters.contains(otaClusterId)) {
          foundEndpoint = ep;
          break;
        }
      }
    }
    updateOtaSupport(deviceId, supported: foundEndpoint != null, endpoint: foundEndpoint ?? 0);
  }

  // ── Subscription event handler ────────────────────────────────────────────

  void _onDeviceStateEvent(DeviceStateEvent event) {
    final candidates = _devices.where((d) => d.nodeId == event.nodeId);
    if (candidates.isEmpty) return;
    final device = candidates.first;

    switch (event) {
      case OtaProgressEvent():
        _otaProgress[device.id] = OtaProgressState(
          phase:    event.phase,
          progress: event.progress,
          message:  event.message,
        );
        notifyListeners();

      case SubscriptionErrorEvent() || SubscriptionResubscribingEvent():
        // Mark cache stale but keep values — UI shows last known state dimmed.
        final existing = _liveCache[device.id];
        if (existing != null && !existing.isStale) {
          _liveCache[device.id] = existing.markStale();
          notifyListeners();
        }

      case SubscriptionEstablishedEvent():
        // Cancel the fallback-read timer — the subscription is healthy.
        _establishTimeouts[device.id]?.cancel();
        _establishTimeouts[device.id] = null;
        // The initial data report arrives as a SubscriptionUpdateEvent
        // immediately after, so no attrs to merge here.
        // Flush snapshot once per session so the next cold start has a
        // complete, accurate attribute map.
        if (_establishedThisSession.add(device.id)) {
          unawaited(_flushSnapshot(device.id));
        }

      case SubscriptionUpdateEvent():
        _applyStateUpdate(device, event.attrs);
    }
  }

  // ── Subscription management ────────────────────────────────────────────────

  /// Merges new attribute values into the live cache.
  void _applyStateUpdate(MatterDevice device, Map<String, dynamic> attrs) {
    // Capture contact state BEFORE the merge so we can detect transitions.
    final prevContact = _liveCache[device.id]?.contactState;

    final existing = _liveCache[device.id];
    _liveCache[device.id] = existing != null ? existing.merge(attrs) : DeviceLiveData.fromUpdate(attrs);

    // Execute any in-app switch links triggered by this event.
    _handleSwitchPress(device.id, attrs);
    // Execute any contact sensor links triggered by a state transition.
    _handleContactChange(device.id, attrs, prevContact);

    // ── Energy odometer (live device readout, not app-side history) ───────────
    //
    // CumulativeEnergyImported arrives once in the initial report (and
    // occasionally on large jumps).  PeriodicEnergyImported arrives on every
    // measurement interval once the device has PERE firmware support.
    //
    // A fresh cumulative value is stored verbatim; when only a periodic delta
    // arrives, add it to the last known cumulative so the odometer keeps ticking
    // between exact reads.  Both values come straight from the device — this is
    // display, not estimation.  (Long-term history/tracking lives on the Flux
    // controller, not the app.)

    final newCumulativeMwh    = attrs['cumulativeEnergyMwh']       as int?;
    final periodicMwh         = attrs['periodicEnergyMwh']         as int?;
    final periodicExportedMwh = attrs['periodicEnergyExportedMwh'] as int?;

    if (newCumulativeMwh == null && periodicMwh != null && periodicMwh > 0) {
      final baseline = _liveCache[device.id]?.cumulativeEnergyMwh ?? 0;
      final cacheUpdate = <String, dynamic>{'cumulativeEnergyMwh': baseline + periodicMwh};

      if (periodicExportedMwh != null && periodicExportedMwh > 0) {
        final exportBaseline = _liveCache[device.id]?.cumulativeEnergyExportedMwh ?? 0;
        cacheUpdate['cumulativeEnergyExportedMwh'] = exportBaseline + periodicExportedMwh;
      }

      _liveCache[device.id] = _liveCache[device.id]!.merge(cacheUpdate);
    }

    // Infer device type from subscription attributes when the stored type
    // is unknown or is a stale commissioning fallback.
    final storedType = device.deviceType;
    if (storedType == DeviceType.unknown || storedType == DeviceType.onOffLight) {
      final inferred = _inferTypeFromEvent(attrs);
      if (inferred != null) {
        final idx2 = _indexById(device.id);
        if (idx2 != -1) {
          _devices[idx2] = _devices[idx2].copyWith(deviceType: inferred);
          unawaited(_persist());
        }
      }
    }

    // Update persisted isOnline flag only on transition false → true
    // (avoids a disk write on every subscription event).
    final idx = _indexById(device.id);
    if (idx != -1 && !_devices[idx].isOnline) {
      _devices[idx] = _devices[idx].copyWith(isOnline: true);
      unawaited(_persist());
    }
    notifyListeners();
  }

  static const _kEstablishTimeout = Duration(seconds: 15);

  Future<void> _startAllSubscriptions() async {
    // Start all subscriptions in parallel so every device gets its first
    // established event at roughly the same time regardless of device count.
    await Future.wait([for (final device in _devices) _startSubscription(device)]);
    for (final device in _devices) {
      if (device.deviceType == DeviceType.unknown) {
        unawaited(_resolveUnknownDeviceType(device));
      }
    }
  }

  DeviceType? _inferTypeFromEvent(Map<String, dynamic> event) {
    if (event.containsKey('contactState')) return DeviceType.contactSensor;
    if (event.containsKey('occupancy')) return DeviceType.occupancySensor;
    if (event.containsKey('airQuality')) return DeviceType.airQualitySensor;
    if (event.containsKey('humidityCenti') && !event.containsKey('onOff')) {
      return DeviceType.humiditySensor;
    }
    if (event.containsKey('tempMeasureCenti') && !event.containsKey('onOff')) {
      return DeviceType.temperatureSensor;
    }
    return null;
  }

  Future<void> _resolveUnknownDeviceType(MatterDevice device) async {
    try {
      final typeId = await _channel.readDeviceTypeId(device.nodeId);
      if (typeId == null) return;
      final resolved = DeviceType.fromMatterDeviceTypeId(typeId);
      if (resolved == DeviceType.unknown) return;
      final idx = _indexById(device.id);
      if (idx == -1) return;
      _devices[idx] = _devices[idx].copyWith(deviceType: resolved);
      await _persist();
      notifyListeners();
    } on Exception catch (_) {}
  }

  Future<void> _startSubscription(MatterDevice device) async {
    if (_subscribedNodeIds.contains(device.nodeId)) return;
    _subscribedNodeIds.add(device.nodeId);
    final ok = await _channel.startSubscription(device.nodeId);
    if (!ok) {
      _subscribedNodeIds.remove(device.nodeId);
      return;
    }
    // Controller-managed devices deliver state exclusively via CoAP Observe.
    // The fallback read goes through FluxCoapService._readAttrs which POSTs
    // /read and waits for a SubscriptionUpdateEvent.  If the Observe isn't
    // fully established yet the response can never arrive, _readAttrs times
    // out, readDeviceState returns isOnline:false, and refreshDevice marks
    // the device offline — hiding every control in the detail screen.
    // Skip the timer for controller devices; the subscription delivers state
    // data when the controller sends it.
    if (device.managedBy == ManagedBy.controller) return;

    // Arm a fallback: if the SDK doesn't deliver an `established` event within
    // the timeout, do a one-shot read to unblock the stale UI.
    _establishTimeouts[device.id]?.cancel();
    _establishTimeouts[device.id] = Timer(_kEstablishTimeout, () {
      if (!_disposed) unawaited(refreshDevice(device.id));
    });
  }

  Future<void> _stopSubscription(MatterDevice device) async {
    _subscribedNodeIds.remove(device.nodeId);
    await _channel.stopSubscription(device.nodeId);
  }

  // ── Commission lifecycle (called by CommissioningController) ─────────────

  /// Signals that commissioning has started; sets [state] to loading so the
  /// home screen shows a progress indicator.
  void beginCommissioning() {
    state = DeviceProviderState.loading;
    notifyListeners();
  }

  /// Registers a successfully commissioned device: persists it, seeds the live
  /// cache with a one-shot read, and starts its subscription.
  ///
  /// Called by CommissioningController once the CHIP SDK reports success.
  Future<MatterDevice> registerCommissionedDevice(
    CommissionResult result,
    String name,
    NetworkType networkType, {
    ManagedBy managedBy = ManagedBy.phone,
  }) async {
    final deviceType = result.deviceTypeId != null
        ? DeviceType.fromMatterDeviceTypeId(result.deviceTypeId!)
        : DeviceType.onOffLight;

    final now = DateTime.now();
    final device = MatterDevice(
      id: _uuid.v4(),
      name: name,
      deviceType: deviceType,
      nodeId: result.nodeId!,
      commissionedAt: now,
      lastModified: now,
      networkType: networkType,
      managedBy: managedBy,
    );

    _devices.add(device);
    await _persist();
    state = DeviceProviderState.idle;
    notifyListeners();

    // For controller-managed devices, readDeviceState goes through
    // FluxCoapService._readAttrs which requires the CoAP Observe to be
    // established first. Calling refreshDevice before startSubscription
    // completes causes _readAttrs to time out and marks the device offline.
    // Skip the immediate refresh; the subscription delivers the initial data,
    // and the 15-second establish-fallback timer fires a refresh if needed.
    if (managedBy != ManagedBy.controller) {
      unawaited(refreshDevice(device.id));
    }
    unawaited(_startSubscription(device));

    return device;
  }

  /// Signals that commissioning ended without producing a device (failure or
  /// user cancellation).  [error] is null when the user cancelled intentionally.
  void failCommissioning(String? error) {
    if (error != null) {
      state = DeviceProviderState.error;
      errorMessage = error;
    } else if (state == DeviceProviderState.loading) {
      state = DeviceProviderState.idle;
    }
    notifyListeners();
  }

  // ── Control ───────────────────────────────────────────────────────────────

  Future<void> toggle(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    final device = _devices[idx];
    // Allow toggle if the device type declares on/off capability OR if the
    // subscription has already delivered an onOff attribute (e.g. IKEA APLSTUGA
    // reports device type airQualitySensor but accepts On/Off commands).
    final hasOnOff = device.deviceType.hasOnOff ||
        (_liveCache[deviceId]?.attrs.containsKey('onOff') ?? false);
    if (!hasOnOff) return;

    // Use live cache as source of truth so toggle direction is always correct.
    final currentOn = _liveCache[deviceId]?.isOn ?? false;
    final newOn = !currentOn;

    // Optimistic update — immediate UI feedback before the round-trip.
    _mergeLiveCache(deviceId, (e) => e.merge({'onOff': newOn}));
    final ok = await _channel.toggleDevice(device.nodeId, on: newOn);
    if (ok) {
      await _flushSnapshot(deviceId);
    } else {
      // Roll back to the previous value on failure.
      _mergeLiveCache(deviceId, (e) => e.merge({'onOff': currentOn}));
    }
  }

  Future<void> setBrightness(String deviceId, double value) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    final level = (value * 254).round().clamp(0, 254);
    // Update live cache immediately for responsive slider feedback.
    _mergeLiveCache(deviceId, (e) => e.merge({'level': level}));
    await _channel.setLevel(_devices[idx].nodeId, level);
    await _flushSnapshot(deviceId);
  }

  /// Sends a StepWithOnOff command: steps brightness up or down by ~10 %.
  /// Does not optimistically update the cache — the subscription delivers
  /// the real new level within the subscription interval.
  Future<void> stepBrightness(String deviceId, {required bool up}) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    final hasBrightness = _devices[idx].deviceType.hasBrightness ||
        (_liveCache[deviceId]?.attrs.containsKey('level') ?? false);
    if (!hasBrightness) return;
    await _channel.stepLevel(_devices[idx].nodeId, stepUp: up);
  }

  Future<void> coveringUp(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    await _channel.coveringUp(_devices[idx].nodeId);
  }

  Future<void> coveringDown(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    await _channel.coveringDown(_devices[idx].nodeId);
  }

  Future<void> coveringStop(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    await _channel.coveringStop(_devices[idx].nodeId);
  }

  Future<void> coveringGoToLift(String deviceId, int percent100ths) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    _mergeLiveCache(deviceId, (e) => e.merge({'liftPercent100ths': percent100ths}));
    await _channel.coveringGoToLift(_devices[idx].nodeId, percent100ths);
  }

  Future<void> setFanMode(String deviceId, int mode) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    _mergeLiveCache(deviceId, (e) => e.merge({'fanMode': mode}));
    await _channel.setFanMode(_devices[idx].nodeId, mode);
  }

  Future<void> setFanPercent(String deviceId, int percent) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    _mergeLiveCache(deviceId, (e) => e.merge({'fanPercent': percent}));
    await _channel.setFanPercent(_devices[idx].nodeId, percent);
  }

  Future<void> setColorTemperature(String deviceId, int mireds) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    _mergeLiveCache(deviceId, (e) => e.merge({'colorTempMireds': mireds}));
    await _channel.setColorTemperature(_devices[idx].nodeId, mireds);
  }

  /// Sends LockDoor command. Returns true on success, false on failure.
  Future<bool> lockDoor(String deviceId, {String? pin}) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return false;
    return _channel.lockDoor(_devices[idx].nodeId, pin: pin);
  }

  /// Sends UnlockDoor command. Returns true on success, false on failure.
  Future<bool> unlockDoor(String deviceId, {String? pin}) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return false;
    return _channel.unlockDoor(_devices[idx].nodeId, pin: pin);
  }

  // ── Refresh (on-demand one-shot read) ─────────────────────────────────────

  Future<void> refreshDevice(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    final device = _devices[idx];

    final deviceState = await _channel.readDeviceState(device.nodeId);

    if (!deviceState.isOnline) {
      // For controller-managed devices, readDeviceState uses
      // FluxCoapService._readAttrs which can time out if the CoAP Observe
      // isn't established yet.  Don't mark offline from a timed-out read —
      // the subscription is the authoritative source and will deliver state
      // when the Observe is ready.
      if (device.managedBy == ManagedBy.controller) return;
      _devices[idx] = device.copyWith(isOnline: false);
      await _persist();
      notifyListeners();
      return;
    }

    final typeIdRaw = await _channel.readDeviceTypeId(device.nodeId);
    final newType = typeIdRaw != null ? DeviceType.fromMatterDeviceTypeId(typeIdRaw) : device.deviceType;

    if (newType == DeviceType.thermostat) {
      final thermo = await _channel.readThermostat(device.nodeId);
      if (thermo != null) {
        _mergeLiveCache(
          deviceId,
          (e) => e.merge({
            if (deviceState.isOn != null) 'onOff': deviceState.isOn,
            if (deviceState.brightnessLevel != null) 'level': deviceState.brightnessLevel,
            if (thermo.localTempCenti != null) 'localTempCenti': thermo.localTempCenti,
            if (thermo.heatingSetptCenti != null) 'heatingSetptCenti': thermo.heatingSetptCenti,
            if (thermo.coolingSetptCenti != null) 'coolingSetptCenti': thermo.coolingSetptCenti,
            if (thermo.systemMode != null) 'systemMode': thermo.systemMode,
            if (thermo.controlSequence != null) 'controlSequence': thermo.controlSequence,
            if (thermo.minHeatSetptCenti != null) 'minHeatSetptCenti': thermo.minHeatSetptCenti,
            if (thermo.maxHeatSetptCenti != null) 'maxHeatSetptCenti': thermo.maxHeatSetptCenti,
            if (thermo.minCoolSetptCenti != null) 'minCoolSetptCenti': thermo.minCoolSetptCenti,
            if (thermo.maxCoolSetptCenti != null) 'maxCoolSetptCenti': thermo.maxCoolSetptCenti,
            if (thermo.absMinHeatSetptCenti != null) 'absMinHeatSetptCenti': thermo.absMinHeatSetptCenti,
            if (thermo.absMaxHeatSetptCenti != null) 'absMaxHeatSetptCenti': thermo.absMaxHeatSetptCenti,
            if (thermo.absMinCoolSetptCenti != null) 'absMinCoolSetptCenti': thermo.absMinCoolSetptCenti,
            if (thermo.absMaxCoolSetptCenti != null) 'absMaxCoolSetptCenti': thermo.absMaxCoolSetptCenti,
          }),
        );
      }
    } else {
      _mergeLiveCache(
        deviceId,
        (e) => e.merge({
          if (deviceState.isOn != null) 'onOff': deviceState.isOn,
          if (deviceState.brightnessLevel != null) 'level': deviceState.brightnessLevel,
        }),
      );
    }

    // Update commissioning record with the resolved device type and online state.
    _devices[idx] = device.copyWith(isOnline: true, deviceType: newType);

    // Checkpoint: flush live state to snapshot so it survives a cold restart.
    await _flushSnapshot(deviceId);
    notifyListeners();
  }

  Future<void> refreshAll() async {
    for (final d in _devices) {
      await refreshDevice(d.id);
    }
  }



  // ── Room management ───────────────────────────────────────────────────────────────────

  /// Creates a new room with [name] and appends it in creation order.
  Future<Room> createRoom(String name) async {
    final room = Room(id: _uuid.v4(), name: name);
    _rooms = [..._rooms, room];
    await _persistRooms();
    notifyListeners();
    return room;
  }

  /// Renames [roomId] to [name].  Silently ignores the "No Room" sentinel.
  Future<void> renameRoom(String roomId, String name) async {
    if (roomId == Room.noRoomId) return;
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx < 0) return;
    _rooms = [..._rooms]..[idx] = _rooms[idx].copyWith(name: name);
    await _persistRooms();
    notifyListeners();
  }

  /// Deletes [roomId] and moves its devices to "No Room".
  /// Silently ignores the "No Room" sentinel.
  Future<void> deleteRoom(String roomId) async {
    if (roomId == Room.noRoomId) return;
    _rooms = _rooms.where((r) => r.id != roomId).toList();
    final affected = _devices
        .asMap()
        .entries
        .where((e) => e.value.roomId == roomId)
        .map((e) => e.key)
        .toList();
    for (final idx in affected) {
      _devices[idx] = _devices[idx].copyWith(roomId: Room.noRoomId);
    }
    await Future.wait([_persistRooms(), if (affected.isNotEmpty) _persist()]);
    notifyListeners();
  }

  /// Assigns [deviceId] to [roomId].  Pass [Room.noRoomId] to unassign.
  Future<void> assignRoom(String deviceId, String roomId) async {
    final idx = _indexById(deviceId);
    if (idx < 0) return;
    _devices[idx] = _devices[idx].copyWith(roomId: roomId);
    await _persist();
    notifyListeners();
  }

  /// Assigns [deviceId] an [EnergyRole] for the home energy-flow overview.
  /// Pass [EnergyRole.none] to remove it from the overview.
  Future<void> assignEnergyRole(String deviceId, EnergyRole role) async {
    final idx = _indexById(deviceId);
    if (idx < 0) return;
    _devices[idx] = _devices[idx].copyWith(energyRole: role);
    await _persist();
    notifyListeners();
    // Push the full role map so the controller classifies the energy log by
    // role (fixes e.g. a PV source on a Matter plug). Fire-and-forget; a full
    // resync also runs on every controller reconcile.
    unawaited(_syncEnergyRoles());
  }

  /// Sends the current energy-role assignments to the controller (full set).
  /// No-op without a controller.
  Future<void> _syncEnergyRoles() async {
    final svc = _ctrlService;
    if (svc == null) return;
    final map = <int, int>{};
    for (final d in _devices) {
      final cls = d.energyRole.controllerClass;
      if (cls != null) map[d.nodeId] = cls;
    }
    await svc.setEnergyRoles(map);
  }
  // ── Share / rename / remove ───────────────────────────────────────────────

  Future<bool> shareWithGoogleHome(String deviceId) async {
    final device = findById(deviceId);
    if (device == null) return false;
    final result = await _channel.shareDevice(device.nodeId);
    if (result != null) {
      final idx = _indexById(deviceId);
      _devices[idx] = device.copyWith(sharedWithGoogleHome: true);
      await _persist();
      notifyListeners();
    }
    return result != null;
  }

  Future<void> renameDevice(String deviceId, String newName) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    _devices[idx] = _devices[idx].copyWith(name: newName, lastModified: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<bool> removeDevice(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return false;
    final device = _devices[idx];
    await _stopSubscription(device);
    _establishTimeouts.remove(deviceId)?.cancel();
    // Always notify the controller — it tracks all registered nodes regardless
    // of who commissioned them.
    await _ctrlService?.removeDevice(device.nodeId);
    // Non-controller-managed devices (e.g. a failed-handoff orphan still on
    // the phone's throwaway fabric) get an extra removeDevice call on the
    // active channel — a no-op once that channel is the controller proxy and
    // _ctrlService is the same instance, but still correct if it isn't.
    if (device.managedBy != ManagedBy.controller) {
      await _channel.removeDevice(device.nodeId);
    }
    // Re-look up after awaits — list may have changed during the async gap.
    final idx2 = _indexById(deviceId);
    if (idx2 != -1) _devices.removeAt(idx2);
    _liveCache.remove(deviceId);
    _clusterCache.remove(deviceId);
    _snapshots.remove(deviceId);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> clearAllDevices() async {
    for (final d in _devices) {
      await _stopSubscription(d);
    }
    _devices.clear();
    _liveCache.clear();
    _clusterCache.clear();
    _snapshots.clear();
    await _persist();
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  MatterDevice? findById(String id) {
    final idx = _indexById(id);
    return idx >= 0 ? _devices[idx] : null;
  }

  int _indexById(String id) => _devices.indexWhere((d) => d.id == id);

  // ── Switch-link execution ──────────────────────────────────────────────────────────

  void _handleContactChange(
    String deviceId,
    Map<String, dynamic> attrs,
    bool? prevContact,
  ) {
    if (!attrs.containsKey('contactState')) return;
    final newState = attrs['contactState'] as bool?;
    if (newState == null || prevContact == null || newState == prevContact) return;
    // true = closed, false = open (BooleanState semantics).
    final trigger = newState ? TriggerType.contactClose : TriggerType.contactOpen;
    for (final rule in _rules.where((r) => r.sourceDeviceId == deviceId && r.trigger == trigger)) {
      for (final targetId in rule.targetDeviceIds) {
        unawaited(_executeAction(targetId, rule.action));
      }
    }
  }

  void _handleSwitchPress(String deviceId, Map<String, dynamic> attrs) {
    final pressTime = attrs['switchPressTime'] as int?;
    if (pressTime == null) return;
    if (pressTime == (_lastSwitchPressTime[deviceId] ?? 0)) return;
    _lastSwitchPressTime[deviceId] = pressTime;

    final ep = (attrs['switchLastEndpoint'] as int?) ?? 0;
    if (ep == 0) return;

    for (final rule in _rules.where((r) => r.sourceDeviceId == deviceId && r.trigger.isSwitch)) {
      if (!rule.endpoints.contains(ep)) continue;
      for (final targetId in rule.targetDeviceIds) {
        unawaited(_executeAction(targetId, rule.action));
      }
    }
  }

  // ── Action execution ─────────────────────────────────────────────────────────────

  Future<void> _executeAction(String deviceId, AutomationAction action) async {
    final device = findById(deviceId);
    if (device == null) return;
    switch (action) {
      case AutomationAction.toggle:
        // Thermostats: toggle SystemMode between Off(0) and Heat(4).
        if (device.deviceType == DeviceType.thermostat ||
            (_liveCache[deviceId]?.attrs.containsKey('systemMode') ?? false)) {
          final cur = _liveCache[deviceId]?.systemMode ?? 0;
          final next = cur == 0 ? 4 : 0;
          _mergeLiveCache(deviceId, (e) => e.merge({'systemMode': next}));
          await _channel.writeSystemMode(device.nodeId, next);
        } else {
          await toggle(deviceId);
        }
      case AutomationAction.turnOn:
        _mergeLiveCache(deviceId, (e) => e.merge({'onOff': true}));
        await _channel.toggleDevice(device.nodeId, on: true);
      case AutomationAction.turnOff:
        _mergeLiveCache(deviceId, (e) => e.merge({'onOff': false}));
        await _channel.toggleDevice(device.nodeId, on: false);
      case AutomationAction.thermostatOff:
        _mergeLiveCache(deviceId, (e) => e.merge({'systemMode': 0}));
        await _channel.writeSystemMode(device.nodeId, 0);
      case AutomationAction.brightnessStepUp:
        await stepBrightness(deviceId, up: true);
      case AutomationAction.brightnessStepDown:
        await stepBrightness(deviceId, up: false);
      case AutomationAction.thermostatSetpointUp:
        await _adjustSetpoint(deviceId, 1.0);
      case AutomationAction.thermostatSetpointDown:
        await _adjustSetpoint(deviceId, -1.0);
    }
  }

  Future<void> _adjustSetpoint(String deviceId, double deltaCelsius) async {
    final device = findById(deviceId);
    if (device == null) return;
    final currentMode = _liveCache[deviceId]?.systemMode;
    if (currentMode == null || currentMode == 0) {
      _mergeLiveCache(deviceId, (e) => e.merge({'systemMode': 4}));
      await _channel.writeSystemMode(device.nodeId, 4);
    }
    const defaultCenti = 2000;
    final current = _liveCache[deviceId]?.heatingSetptCenti ?? defaultCenti;
    final next = (current + (deltaCelsius * 100).round()).clamp(500, 3500);
    _mergeLiveCache(deviceId, (e) => e.merge({'heatingSetptCenti': next}));
    await _channel.writeHeatingSetpoint(device.nodeId, next);
  }

  // ── Connection API ─────────────────────────────────────────────────────────

  /// Groups rules for [sourceDeviceId] by (targetDeviceId, switchGroup).
  List<DeviceConnection> connectionsFor(String sourceDeviceId) {
    final rules = rulesFor(sourceDeviceId);
    final map = <(String, String?), List<AutomationRule>>{};
    for (final rule in rules) {
      for (final tid in rule.targetDeviceIds) {
        (map[(tid, rule.switchGroup)] ??= []).add(rule);
      }
    }
    return map.entries
        .map((e) => DeviceConnection(
              targetDeviceId: e.key.$1,
              switchGroup:    e.key.$2,
              rules:          e.value,
            ))
        .toList();
  }

  /// Returns the first slot label that has no existing rules for [sourceDeviceId].
  /// Falls back to the first slot if all are in use.
  String? nextFreeSlot(String sourceDeviceId, List<SwitchGroup> groups) {
    if (groups.isEmpty) return null;
    final usedSlots = _rules
        .where((r) => r.sourceDeviceId == sourceDeviceId && r.switchGroup != null)
        .map((r) => r.switchGroup!)
        .toSet();
    return groups
        .map((g) => g.label)
        .firstWhere((label) => !usedSlots.contains(label),
            orElse: () => groups.first.label);
  }

  /// Creates smart-preset rules connecting [sourceDeviceId] to [targetDeviceId].
  /// Derives gesture→action mapping from device-type capabilities.
  void connectDevice({
    required String         sourceDeviceId,
    required DeviceType     sourceType,
    required String         targetDeviceId,
    required List<SwitchGroup> switchGroups,
  }) {
    final targetView = viewFor(targetDeviceId);
    if (targetView == null) return;

    if (sourceType == DeviceType.contactSensor) {
      // Contact sensor presets
      if (_supportsAction(targetView, AutomationAction.thermostatOff)) {
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId,
          trigger:        TriggerType.contactOpen,
          action:         AutomationAction.thermostatOff,
          targetDeviceIds: [targetDeviceId],
        ));
      } else if (_supportsAction(targetView, AutomationAction.turnOn)) {
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId,
          trigger:        TriggerType.contactOpen,
          action:         AutomationAction.turnOn,
          targetDeviceIds: [targetDeviceId],
        ));
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId,
          trigger:        TriggerType.contactClose,
          action:         AutomationAction.turnOff,
          targetDeviceIds: [targetDeviceId],
        ));
      }
    } else {
      // Switch presets — assign to next free slot
      final slot = nextFreeSlot(sourceDeviceId, switchGroups);
      if (slot == null) return;
      final group = switchGroups.firstWhere((g) => g.label == slot);

      if (group.pressEndpoints.isNotEmpty) {
        upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId,
          trigger:        TriggerType.switchPress,
          switchGroup:    slot,
          endpoints:      group.pressEndpoints,
          action:         AutomationAction.toggle,
          targetDeviceIds: [targetDeviceId],
        ));
      }
      if (group.cwEndpoints.isNotEmpty) {
        final a = _supportsAction(targetView, AutomationAction.thermostatSetpointUp)
            ? AutomationAction.thermostatSetpointUp
            : _supportsAction(targetView, AutomationAction.brightnessStepUp)
                ? AutomationAction.brightnessStepUp
                : null;
        if (a != null) upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId,
          trigger:        TriggerType.switchCw,
          switchGroup:    slot,
          endpoints:      group.cwEndpoints,
          action:         a,
          targetDeviceIds: [targetDeviceId],
        ));
      }
      if (group.ccwEndpoints.isNotEmpty) {
        final a = _supportsAction(targetView, AutomationAction.thermostatSetpointDown)
            ? AutomationAction.thermostatSetpointDown
            : _supportsAction(targetView, AutomationAction.brightnessStepDown)
                ? AutomationAction.brightnessStepDown
                : null;
        if (a != null) upsertRule(AutomationRule(
          sourceDeviceId: sourceDeviceId,
          trigger:        TriggerType.switchCcw,
          switchGroup:    slot,
          endpoints:      group.ccwEndpoints,
          action:         a,
          targetDeviceIds: [targetDeviceId],
        ));
      }
    }
  }

  /// Removes all rules linking [sourceDeviceId] to [targetDeviceId] on [switchGroup].
  /// If a rule has multiple targets, only removes this target from it.
  void disconnectTarget({
    required String  sourceDeviceId,
    required String  targetDeviceId,
    required String? switchGroup,
  }) {
    final toProcess = _rules
        .where((r) =>
            r.sourceDeviceId == sourceDeviceId &&
            r.switchGroup    == switchGroup &&
            r.targetDeviceIds.contains(targetDeviceId))
        .toList();

    for (final rule in toProcess) {
      if (rule.targetDeviceIds.length == 1) {
        _rules.remove(rule);
      } else {
        final idx = _rules.indexWhere((r) => r.id == rule.id);
        _rules[idx] = rule.copyWith(
          targetDeviceIds: rule.targetDeviceIds
              .where((id) => id != targetDeviceId)
              .toList(),
        );
      }
    }
    _persistRules();
    notifyListeners();
  }
}
