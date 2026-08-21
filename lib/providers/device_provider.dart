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
import 'package:matter_home/models/solar_forecast.dart';
import 'package:matter_home/models/energy_role.dart';
import 'package:matter_home/models/energy_summary.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/room.dart';
import 'package:matter_home/models/persisted_snapshot.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:matter_home/services/energy_cache.dart';
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

  /// Completed buckets kept on the phone, so a launch paints before the network
  /// answers. Null until [attachEnergyCache] runs.
  EnergyCache? _energyCache;
  void attachEnergyCache(EnergyCache cache) {
    _energyCache = cache;
    unawaited(loadCachedHistory());
  }

  /// Timeline series the user has switched off; everything else is drawn, so a
  /// series added by a later version arrives visible rather than hidden.
  List<String> get chartHidden => _store.loadChartHidden();
  Future<void> setChartHidden(List<String> keys) async {
    await _store.saveChartHidden(keys);
    notifyListeners();
  }

  /// The Energy view's card order, as the user arranged it.
  List<String>? get energyCardOrder => _store.loadEnergyCardOrder();
  Future<void> setEnergyCardOrder(List<String> keys) async {
    await _store.saveEnergyCardOrder(keys);
    notifyListeners();
  }
  MatterPort _channel;
  /// Non-null in hub mode — used to reconcile the device list with the
  /// controller's NVS on startup and to seed [isOnline] from [Device.reachable].
  FluxCoapService? _ctrlService;
  final _uuid = const Uuid();

  DeviceProviderState state = DeviceProviderState.idle;
  List<MatterDevice> _devices = [];

  // ── Rooms ───────────────────────────────────────────────────────────────────
  // "No Room" is always the first entry and is never stored to disk.
  List<Room> _rooms = [Room.noRoom];

  // ── In-memory caches ──────────────────────────────────────────────────────
  final Map<String, DeviceLiveData>        _liveCache     = {};
  final Map<String, String>                _clusterCache  = {}; // deviceId → JSON
  final Map<String, PersistedSnapshot>     _snapshots     = {};

  // ── Automation rules ────────────────────────────────────────────────────
  final List<AutomationRule> _rules               = [];
  final Map<String, int>     _lastSwitchPressTime = {}; // debounce

  /// Keyed by the full device key — a Matter and a Modbus device may share a
  /// node id, and subscribing to one must not suppress the other.
  final Set<(DeviceKind, int)> _subscribedNodeIds = {};

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

  /// The current name for the device, or null if unknown.
  ///
  /// Reads the local cache, which now tracks the controller — the point is no
  /// longer local authority but freshness: names baked into controller-side
  /// *data* (e.g. a row written into the energy-history log weeks ago) are
  /// snapshots and go stale, while this follows renames.
  ///
  /// Keyed by (kind, nodeId): a node id alone does not identify a device.
  String? deviceNameForNode(int nodeId, {DeviceKind kind = DeviceKind.matter}) {
    for (final d in _devices) {
      if (d.nodeId == nodeId && d.kind == kind) return d.name;
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

  /// Fetch the last 24 hours of energy history from the controller (1-hour
  /// buckets). No-op without a controller. Concurrent calls are coalesced; a
  /// transient failure leaves any previously-loaded history in place.
  static const _bucket = Duration(hours: 1);
  static const _window = Duration(hours: 24);

  /// Paints the cached window immediately, then asks the controller only for what
  /// it cannot already know.
  ///
  /// A completed bucket never changes, so re-fetching 24 hours on every launch
  /// was a slow round trip to re-learn facts already on the phone. The fetch is
  /// now anchored at the end of the newest cached bucket — usually minutes of
  /// data, and a full window only on a first run or after a long absence.
  ///
  /// It deliberately re-fetches the newest cached bucket's own hour as well: that
  /// hour was complete when cached, but the request that produced it may have cut
  /// a *later* partial hour, and starting one bucket early costs one bucket and
  /// closes that seam.
  int _historyOffsetDays = 0;

  /// How many days back the Energy view is looking. 0 = the last 24 hours.
  int get historyOffsetDays => _historyOffsetDays;

  /// Moves the window and shows whatever the cache already holds for it before
  /// asking the controller for the rest.
  ///
  /// This is the reason the cache exists in a form that keeps six weeks rather
  /// than one day: stepping back a day is instant for any day already visited,
  /// and costs one request for a day that is not.
  Future<void> setHistoryOffsetDays(int days) async {
    final next = days < 0 ? 0 : days;
    if (next == _historyOffsetDays) return;
    _historyOffsetDays = next;
    notifyListeners();
    await loadCachedHistory();
    await fetchEnergyHistory();
  }

  /// The window currently being shown, as (from, to).
  (DateTime, DateTime) get historyWindow {
    final to = DateTime.now().subtract(Duration(days: _historyOffsetDays));
    return (to.subtract(_window), to);
  }

  Future<void> loadCachedHistory() async {
    if (_energyCache == null) return;
    final rows = _energyCache!.load();
    if (rows.isEmpty) return;
    final window = _rowsIn(rows, historyWindow);
    if (window.isEmpty) return;
    _energyHistory = EnergyHistoryData.fromRows(window, bucket: _bucket);
    debugPrint('EnergyCache: painted ${window.length} cached bucket(s) '
        'before any fetch');
    notifyListeners();
  }

  /// The cached rows whose bucket start falls inside [w].
  List<EnergyBucketRow> _rowsIn(
      Map<int, EnergyBucketRow> rows, (DateTime, DateTime) w) {
    final (from, to) = w;
    return [
      for (final r in rows.values)
        if (() {
          final t = DateTime.fromMillisecondsSinceEpoch(r.epoch * 1000,
              isUtc: true).toLocal();
          return !t.isBefore(from) && t.isBefore(to);
        }())
          r,
    ];
  }

  Future<void> fetchEnergyHistory() {
    final inflight = _energyHistoryInflight;
    if (inflight != null) return inflight;
    final svc = _ctrlService;
    if (svc == null) return Future.value();

    _energyHistoryLoading = true;
    notifyListeners();

    final f = () async {
      final w = historyWindow;
      final cache = _energyCache;
      final cached = cache?.load() ?? const <int, EnergyBucketRow>{};
      var to = w.$2.millisecondsSinceEpoch ~/ 1000;
      var from = w.$1.millisecondsSinceEpoch ~/ 1000;

      if (_historyOffsetDays == 0) {
        // Live window: only the tail, when the cache already covers it.
        final newestEnd = cache?.newestEnd(cached, _bucket);
        if (newestEnd != null) {
          final tailFrom =
              newestEnd.subtract(_bucket).millisecondsSinceEpoch ~/ 1000;
          if (tailFrom > from) from = tailFrom;
        }
      } else {
        // A past day is fixed history: if the cache already has every hour of
        // it, there is nothing to ask for. Every hour, not merely some — a
        // partially cached day would otherwise never be completed.
        final have = _rowsIn(cached, w).length;
        final want = _window.inSeconds ~/ _bucket.inSeconds;
        if (have >= want) {
          _energyHistory = EnergyHistoryData.fromRows(
              _rowsIn(cached, w), bucket: _bucket);
          return;
        }
      }

      // 1-hour buckets keep the payload small even with the per-device series
      // included — the controller re-aggregates server-side.
      debugPrint('EnergyCache: fetching ${((to - from) / 3600).round()} h '
          '(offset ${_historyOffsetDays}d, ${cached.length} cached)');
      final h = await svc.getEnergyHistory(from: from, to: to, bucketSeconds: 3600);
      if (_disposed) return;
      if (h == null) return;

      final fresh = EnergyHistoryData.fromProto(h);
      if (cache == null) {
        _energyHistory = fresh;
        return;
      }
      // Merge, then rebuild the window from the merged set rather than from the
      // response: a tail fetch holds only the newest hour or two, and showing it
      // alone would blank the chart every 30 seconds.
      final merged = await cache.merge(fresh.toRows());
      final window = _rowsIn(merged, historyWindow);
      _energyHistory = window.isEmpty
          ? fresh
          : EnergyHistoryData.fromRows(window, bucket: _bucket,
              timeSynced: fresh.timeSynced);
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

  SolarForecastData? _solarForecast;
  Future<void>? _solarInflight;

  /// The controller's PV production forecast, or null when it has none (feature
  /// disabled, or never fetched).
  SolarForecastData? get solarForecast => _solarForecast;

  $proto.SolarConfig? _solarConfig;

  /// The site model behind the forecast, or null until fetched.
  $proto.SolarConfig? get solarConfig => _solarConfig;

  Future<$proto.SolarConfig?> fetchSolarConfig() async {
    final svc = _ctrlService;
    if (svc == null) return null;
    final cfg = await svc.getSolarConfig();
    if (cfg != null) {
      _solarConfig = cfg;
      notifyListeners();
    }
    return cfg;
  }

  /// Writes the site model, then re-fetches the forecast: every field here
  /// changes the prediction, so leaving the old curve on screen would show a
  /// forecast for a roof that no longer exists.
  Future<bool> updateSolarConfig($proto.SolarConfig cfg) async {
    final svc = _ctrlService;
    if (svc == null) return false;
    final ok = await svc.setSolarConfig(cfg);
    if (ok) {
      _solarConfig = cfg;
      await fetchSolarForecast();
      notifyListeners();
    }
    return ok;
  }

  /// Fetches the forecast, coalescing concurrent callers. Silent on failure: a
  /// forecast is an enhancement, and a house with it switched off must not see
  /// an error every 30 seconds.
  Future<void> fetchSolarForecast() {
    final inflight = _solarInflight;
    if (inflight != null) return inflight;
    final svc = _ctrlService;
    if (svc == null) return Future.value();
    final f = svc.getSolarForecast().then((p) {
      if (p == null) return;
      final next = SolarForecastData.fromProto(p);
      _solarForecast = next.isEmpty ? null : next;
      notifyListeners();
    });
    _solarInflight = f.whenComplete(() => _solarInflight = null);
    return _solarInflight!;
  }
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

  /// Consecutive syncs where the controller reported zero devices while we knew
  /// of some. Guards the purge below against a one-off empty answer.
  int _emptyListStreak = 0;

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
      // Hand the local layout over BEFORE reconciling. Reconcile takes the
      // controller's room and role as authoritative, and on the very first sync
      // those are empty — so the other order would wipe this phone's layout a
      // moment before uploading it.
      await _uploadLocalLayoutOnce();
      await _reconcileWithController();
    } finally {
      _syncInFlight = false;
    }
  }

  /// Hands this phone's pre-existing rooms and energy roles to the controller,
  /// exactly once.
  ///
  /// Before rooms moved, both lived only here. On the first sync with a
  /// room-capable controller the layout would otherwise simply be gone: room
  /// UUIDs cannot be translated locally, and the controller has no rooms yet.
  ///
  /// Deliberately one-shot and recorded persistently. Re-running it later would
  /// resurrect rooms the user had since deleted on the controller — the upload
  /// is a hand-off, not a sync.
  ///
  /// Skipped entirely if the controller already has rooms: that means another
  /// phone has already done this, and its layout wins over this one's stale copy.
  Future<void> _uploadLocalLayoutOnce() async {
    final svc = _ctrlService;
    if (svc == null || _store.layoutUploaded) return;

    final existing = await svc.getRooms();
    if (existing == null) return;          // transport failure — try again later

    final legacyRooms = _store.loadLegacyRooms();
    final assignments = _store.loadLegacyRoomAssignments();

    if (existing.isEmpty && legacyRooms.isNotEmpty) {
      final stored = await svc.setRooms(
          [for (final (_, name) in legacyRooms) $proto.Room(name: name)]);
      if (stored == null) return;

      // setRooms answers in the order sent, so position maps a legacy UUID to
      // the id the controller just issued.
      final uuidToId = <String, int>{};
      for (var i = 0; i < legacyRooms.length && i < stored.length; i++) {
        uuidToId[legacyRooms[i].$1] = stored[i].id;
      }
      _rooms = [Room.noRoom, for (final r in stored) Room(id: r.id, name: r.name)];
      await _persistRooms();

      for (var i = 0; i < _devices.length; i++) {
        final newId = uuidToId[assignments[_devices[i].id]];
        if (newId == null) continue;
        if (await svc.setDeviceMeta(_devices[i].nodeId,
            kind: _devices[i].kind, roomId: newId)) {
          _devices[i] = _devices[i].copyWith(roomId: newId);
        }
      }
      debugPrint('DeviceProvider: uploaded ${stored.length} local room(s)');
    }

    // Energy roles survive locally (they are an enum, not a UUID), so push them
    // regardless of whether there were rooms to move.
    for (final d in _devices) {
      if (d.energyRole == EnergyRole.none) continue;
      await svc.setDeviceMeta(d.nodeId, kind: d.kind, energyRole: d.energyRole);
    }

    await _store.markLayoutUploaded();
    await _persist();
    notifyListeners();
  }

  /// Pushes this phone's device names to the controller, once.
  ///
  /// Names were app-authoritative, so before adoption starts the controller must
  /// be given the ones the user actually chose. Only devices the controller
  /// already knows are touched, and only where the local name differs — a
  /// device the user never renamed keeps whatever the controller has.
  Future<void> _uploadLocalNamesOnce(
      FluxCoapService svc, List<$proto.Device> raw) async {
    if (_store.namesUploaded) return;

    var pushed = 0;
    for (final cd in raw) {
      final nodeId = cd.nodeId.toInt();
      final kind   = DeviceKind.fromWire(cd.kind.value);
      final idx = _devices.indexWhere((d) => d.nodeId == nodeId && d.kind == kind);
      if (idx == -1) continue;

      final local = _devices[idx].name;
      if (local.isEmpty || local == cd.name) continue;
      if (await svc.setDeviceMeta(nodeId, kind: kind, name: local)) pushed++;
    }
    await _store.markNamesUploaded();
    if (pushed > 0) debugPrint('DeviceProvider: uploaded $pushed device name(s)');
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

    // Hand this phone's names over before the adoption below can overwrite
    // them. The controller's name for a Matter device comes from Basic Info at
    // commissioning ("IKEA of Sweden", "Test Vendor 1"), so adopting first would
    // replace the user's own names with vendor strings.
    await _uploadLocalNamesOnce(svc, raw);

    // Refresh the room cache from the controller, which owns the list. Without
    // this the cache is only ever written by this phone's own create/delete, so
    // a room made on another phone (or with flux-ctl) would never appear here —
    // which is the disagreement the move to the controller was meant to end.
    // Null means a failed read, so keep the cached list rather than blanking it.
    var changed = false;

    final ctrlRooms = await svc.getRooms();
    if (ctrlRooms != null) {
      final fresh = [
        Room.noRoom,
        for (final r in ctrlRooms) Room(id: r.id, name: r.name),
      ];
      if (fresh.length != _rooms.length ||
          !fresh.every((r) => _rooms.any((c) => c.id == r.id && c.name == r.name))) {
        _rooms = fresh;
        await _persistRooms();
        changed = true;
      }
    }

    final now   = DateTime.now();
    final controllerKeys = <(DeviceKind, int)>{};

    for (final cd in raw) {
      final nodeId = cd.nodeId.toInt();
      final cdKind = DeviceKind.fromWire(cd.kind.value);
      controllerKeys.add((cdKind, nodeId));
      final idx = _devices.indexWhere(
          (d) => d.nodeId == nodeId && d.kind == cdKind);

      if (idx == -1) {
        // Device on controller but not locally — add it.
        final dt = cd.deviceType > 0
            ? DeviceType.fromMatterDeviceTypeId(cd.deviceType)
            : DeviceType.unknown;
        // The controller reports the kind, so nothing here has to infer it from
        // the magnitude of nodeId. It still doesn't report the transport for real
        // Matter nodes, so leave those as `unknown` — the info screen hides the
        // Network row rather than falsely labelling them Thread.
        final kind = DeviceKind.fromWire(cd.kind.value);
        final networkType = kind == DeviceKind.modbus
            ? NetworkType.modbus
            : NetworkType.unknown;
        final device = MatterDevice(
          id:             _uuid.v4(),
          kind:           kind,
          name:           cd.name.isNotEmpty ? cd.name : 'Device $nodeId',
          deviceType:     dt,
          nodeId:         nodeId,
          commissionedAt: now,
          lastModified:   now,
          networkType:    networkType,
          managedBy:      ManagedBy.controller,
          isOnline:       cd.reachable,
          // The controller owns these, so adopt them rather than defaulting —
          // otherwise a re-added device comes back roomless and unassigned,
          // which is the bug this whole move fixes.
          roomId:         cd.roomId,
          energyRole:     EnergyRole.fromWire(cd.energyRole.value),
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
        // Already known — re-seed from the controller, which owns room and
        // energy role. Local edits already went through it, so it is never
        // behind: taking its answer here is what keeps two phones in agreement.
        //
        // Suppressed until the hand-off has happened: until then the local copy
        // is the only copy, and adopting the controller's empty answer would
        // destroy it. A failed upload leaves the flag clear, so this stays
        // suppressed and the layout survives to be retried.
        final ctrlRole = EnergyRole.fromWire(cd.energyRole.value);
        if (_store.layoutUploaded &&
            (_devices[idx].roomId != cd.roomId ||
             _devices[idx].energyRole != ctrlRole)) {
          _devices[idx] =
              _devices[idx].copyWith(roomId: cd.roomId, energyRole: ctrlRole);
          changed = true;
        }
        // Name is in the same controller-owned record. Only adopt a non-empty
        // one: an empty name means the controller never learned it, and
        // adopting that would blank a perfectly good local name.
        if (_store.namesUploaded &&
            cd.name.isNotEmpty && _devices[idx].name != cd.name) {
          _devices[idx] = _devices[idx].copyWith(name: cd.name);
          changed = true;
        }
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
        // Adopt the controller's device type when it changes. Reconcile used to
        // seed the type only at creation time, so a record stored with a wrong
        // type stayed wrong forever — that's how a tado thermostat, once
        // mis-detected as a humidity sensor, kept rendering without thermostat
        // controls even after the controller had relearned it. Only overwrite
        // with a type we recognise, so a controller reporting 0/unknown can
        // never erase a good local value.
        if (cd.deviceType > 0) {
          final fromController = DeviceType.fromMatterDeviceTypeId(cd.deviceType);
          if (fromController != DeviceType.unknown &&
              fromController != _devices[idx].deviceType) {
            debugPrint('DeviceProvider: device type for $nodeId '
                '${_devices[idx].deviceType.name} → ${fromController.name}');
            _devices[idx] = _devices[idx].copyWith(deviceType: fromController);
            changed = true;
          }
        }
      }
    }

    // Drop controller-managed devices the controller no longer reports.
    // Phone-commissioned devices are never auto-removed here — they live in the
    // local CHIP fabric and are owned by this app.
    //
    // Matched on the whole key (kind, nodeId), like every other lookup: a node
    // id alone does not identify a device.
    //
    // One empty list never purges. It used to: an empty-but-non-null reply was
    // treated as authoritative, so a single odd answer from a controller that
    // was up but not yet serving its registry would delete every device here.
    // They come back on the next sync, but as NEW records — new ids, so the
    // live-state cache keyed by id is orphaned and every card goes blank. Two
    // consecutive empty answers are needed before believing the home is empty.
    if (raw.isEmpty && _devices.any((d) => d.managedBy == ManagedBy.controller)) {
      _emptyListStreak++;
      if (_emptyListStreak < 2) {
        debugPrint('DeviceProvider: controller reported 0 devices while '
            '${_devices.length} are known — ignoring once');
        if (changed) { await _persist(); notifyListeners(); }
        return;
      }
    } else {
      _emptyListStreak = 0;
    }

    final stale = _devices
        .where((d) =>
            d.managedBy == ManagedBy.controller &&
            !controllerKeys.contains((d.kind, d.nodeId)))
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

    // No role push from here any more: the controller owns the assignment and
    // this method just reconciled against it. Pushing a phone-side copy back is
    // what let the two drift apart.
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
    for (final key in List<(DeviceKind, int)>.of(_subscribedNodeIds)) {
      try {
        await _channel.stopSubscription(key.$2, kind: key.$1);
      } on Exception catch (_) {}
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


  // ── Subscription event handler ────────────────────────────────────────────

  void _onDeviceStateEvent(DeviceStateEvent event) {
    // Match on the full key (kind, nodeId).
    //
    // An event whose kind is `unknown` comes from a controller that does not set
    // it. Fall back to the node id and say so, loudly: strict matching here
    // dropped EVERY live update against such a controller, and the symptom was
    // blank device cards with a perfectly healthy connection — nothing in the
    // logs, nothing failing. A noisy line beats silent data loss.
    var candidates = _devices
        .where((d) => d.nodeId == event.nodeId && d.kind == event.kind);
    if (candidates.isEmpty && event.kind == DeviceKind.unknown) {
      debugPrint('DeviceProvider: event for ${event.nodeId} carries no kind — '
          'controller too old? falling back to node-id match');
      candidates = _devices.where((d) => d.nodeId == event.nodeId);
    }
    if (candidates.isEmpty) return;
    final device = candidates.first;

    switch (event) {
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
    // Thermostats report humidity and temperature alongside their own cluster,
    // so they must be matched before the bare-sensor checks below — otherwise a
    // thermostat with no On/Off cluster infers humiditySensor and loses its
    // controls. These keys come only from Thermostat (0x0201).
    if (event.containsKey('heatingSetptCenti') ||
        event.containsKey('systemMode') ||
        event.containsKey('localTempCenti')) {
      return DeviceType.thermostat;
    }
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
    final key = (device.kind, device.nodeId);
    if (_subscribedNodeIds.contains(key)) return;
    _subscribedNodeIds.add(key);
    final ok = await _channel.startSubscription(device.nodeId, kind: device.kind);
    if (!ok) {
      _subscribedNodeIds.remove(key);
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
    _subscribedNodeIds.remove((device.kind, device.nodeId));
    await _channel.stopSubscription(device.nodeId, kind: device.kind);
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



  // ── Room management ───────────────────────────────────────────────────────────────────

  /// Creates a room and returns it with the controller-issued id.
  ///
  /// Returns null if the controller is unreachable: the id can only come from
  /// it, so there is nothing sensible to invent locally — a phone-side id would
  /// be exactly the divergence this replaced.
  Future<Room?> createRoom(String name) async {
    final svc = _ctrlService;
    if (svc == null) return null;

    final wire = [
      for (final r in _rooms.where((r) => !r.isNoRoom))
        $proto.Room(id: r.id, name: r.name),
      $proto.Room(name: name),   // id 0 → create
    ];
    final stored = await svc.setRooms(wire);
    if (stored == null) return null;

    _rooms = [Room.noRoom, for (final r in stored) Room(id: r.id, name: r.name)];
    await _persistRooms();
    notifyListeners();
    // The new room is the one whose name matches and whose id we did not have.
    final knownIds = wire.map((r) => r.id).where((id) => id != 0).toSet();
    for (final r in stored) {
      if (!knownIds.contains(r.id)) return Room(id: r.id, name: r.name);
    }
    return null;
  }

  /// Deletes [roomId]. Devices in it fall back to No Room, controller-side.
  Future<bool> deleteRoom(int roomId) async {
    final svc = _ctrlService;
    if (svc == null) return false;
    final stored = await svc.setRooms([
      for (final r in _rooms.where((r) => !r.isNoRoom && r.id != roomId))
        $proto.Room(id: r.id, name: r.name),
    ]);
    if (stored == null) return false;
    _rooms = [Room.noRoom, for (final r in stored) Room(id: r.id, name: r.name)];
    for (var i = 0; i < _devices.length; i++) {
      if (_devices[i].roomId == roomId) {
        _devices[i] = _devices[i].copyWith(roomId: Room.noRoomId);
      }
    }
    await _persistRooms();
    await _persist();
    notifyListeners();
    return true;
  }

  /// Assigns [deviceId] to [roomId].  Pass [Room.noRoomId] to unassign.
  ///
  /// Writes through to the controller first: it owns the membership, and a
  /// local-only assignment is what used to vanish on re-add.
  Future<bool> assignRoom(String deviceId, int roomId) async {
    final idx = _indexById(deviceId);
    if (idx < 0) return false;
    final d = _devices[idx];

    final svc = _ctrlService;
    if (svc != null) {
      final ok = await svc.setDeviceMeta(d.nodeId, kind: d.kind, roomId: roomId);
      if (!ok) return false;
    }
    _devices[idx] = d.copyWith(roomId: roomId);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Assigns [deviceId] an [EnergyRole] for the home energy-flow overview.
  /// Pass [EnergyRole.none] to remove it from the overview.
  Future<bool> assignEnergyRole(String deviceId, EnergyRole role) async {
    final idx = _indexById(deviceId);
    if (idx < 0) return false;
    final d = _devices[idx];

    final svc = _ctrlService;
    if (svc != null) {
      // The controller stores the role itself (not just the derived log class),
      // so the difference between e.g. a car charger and a heat pump survives a
      // reinstall instead of living only on this phone.
      final ok = await svc.setDeviceMeta(d.nodeId, kind: d.kind, energyRole: role);
      if (!ok) return false;
    }
    _devices[idx] = d.copyWith(energyRole: role);
    await _persist();
    notifyListeners();
    return true;
  }

  // ── Share / rename / remove ───────────────────────────────────────────────


  /// Renames a device, writing through to the controller.
  ///
  /// The name lives in the same controller-owned metadata record as room and
  /// energy role, so a local-only rename would be undone by the next sync.
  /// Returns false if the controller rejected it or was unreachable — in which
  /// case the local name is left alone rather than showing an edit that will
  /// silently revert.
  Future<bool> renameDevice(String deviceId, String newName) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return false;
    final d = _devices[idx];

    final svc = _ctrlService;
    if (svc != null && d.managedBy == ManagedBy.controller) {
      final ok = await svc.setDeviceMeta(d.nodeId, kind: d.kind, name: newName);
      if (!ok) return false;
    }
    _devices[idx] = d.copyWith(name: newName, lastModified: DateTime.now());
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> removeDevice(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return false;
    final device = _devices[idx];
    await _stopSubscription(device);
    _establishTimeouts.remove(deviceId)?.cancel();
    // Always notify the controller — it tracks all registered nodes regardless
    // of who commissioned them.
    await _ctrlService?.removeDevice(device.nodeId, kind: device.kind);
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
