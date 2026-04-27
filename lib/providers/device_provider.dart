import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/device_live_data.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/ota_progress.dart';
import 'package:matter_home/models/room.dart';
import 'package:matter_home/models/switch_link.dart';
import 'package:matter_home/models/persisted_snapshot.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:uuid/uuid.dart';

enum DeviceProviderState { idle, loading, error }

class DeviceProvider extends ChangeNotifier {
  // ── Constructor ───────────────────────────────────────────────────────────

  DeviceProvider(this._store, this._channel) {
    _load();
    _deviceStateSub = _channel.deviceStateUpdates.listen(_onDeviceStateEvent);
    Future.microtask(_startAllSubscriptions);
  }
  final DeviceStore _store;
  final MatterPort _channel;
  final _uuid = const Uuid();

  DeviceProviderState state = DeviceProviderState.idle;
  String? errorMessage;
  List<MatterDevice> _devices = [];

  // ── Rooms ───────────────────────────────────────────────────────────────────
  // "No Room" is always the first entry and is never stored to disk.
  List<Room> _rooms = [Room.noRoom];

  // ── In-memory caches ──────────────────────────────────────────────────────
  final Map<String, DeviceLiveData>     _liveCache     = {};
  final Map<String, String>             _clusterCache  = {}; // deviceId → JSON
  final Map<String, OtaProgressState>   _otaProgress   = {};
  final Map<String, PersistedSnapshot>  _snapshots     = {};

  // ── Switch links (in-app binding table) ───────────────────────────────────
  // Keyed by source deviceId.  Execution happens when a press event is
  // received on any endpoint listed in the link's pressEndpoints.
  final Map<String, List<SwitchLink>> _switchLinks        = {};
  final Map<String, int>              _lastSwitchPressTime = {}; // debounce: deviceId → last switchPressTime
  final Map<String, ContactLink>      _contactLinks        = {};
  final Map<String, bool>             _lastContactState    = {}; // debounce: deviceId → last acted state

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

  /// Raw commissioning records.  Most screens should use [deviceViews] or
  /// [viewFor] instead — those carry merged live state.
  List<MatterDevice> get devices => List.unmodifiable(_devices);

  /// All devices as merged [DeviceView] objects (commissioning record + live).
  List<DeviceView> get deviceViews => _devices.map((d) => DeviceView(d, _liveCache[d.id])).toList();

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

  /// Returns a merged [DeviceView] for [id], or null if the device is unknown.
  DeviceView? viewFor(String id) {
    final idx = _indexById(id);
    if (idx < 0) return null;
    return DeviceView(_devices[idx], _liveCache[_devices[idx].id]);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _establishTimeouts.values) {
      t?.cancel();
    }
    _establishTimeouts.clear();
    _deviceStateSub?.cancel();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  void _load() {
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
      return d;
    }).toList();

    // Seed the live cache from snapshots so home-screen tiles show the
    // last-known state immediately — before any subscription arrives.
    for (final device in _devices) {
      final snap = _snapshots[device.id];
      if (snap != null) {
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

  /// Persists both the commissioning records and the live-state snapshots.
  Future<void> _persist() async {
    await _store.saveDevices(_devices);
    await _store.saveSnapshots(_snapshots);
  }

  /// Persists the user-created rooms list (excludes the sentinel).
  Future<void> _persistRooms() => _store.saveRooms(_rooms);

  /// Captures the current live cache for [deviceId] into [_snapshots] and
  /// writes both stores to disk.  Called only at explicit checkpoints
  /// (first established event, user action, successful poll) — never from
  /// the subscription hot path.
  Future<void> _flushSnapshot(String deviceId) async {
    final live = _liveCache[deviceId];
    if (live == null) return;
    _snapshots[deviceId] = PersistedSnapshot.capture(deviceId, live);
    await _persist();
  }

  // ── Live cache helpers ────────────────────────────────────────────────────

  /// Returns the raw live cache for [deviceId].
  /// Prefer [viewFor] when you also need commissioning fields.
  DeviceLiveData? liveDataFor(String deviceId) => _liveCache[deviceId];

  String? clusterCacheFor(String deviceId) => _clusterCache[deviceId];
  OtaProgressState? otaProgressFor(String deviceId) => _otaProgress[deviceId];

  // ── Switch link management ──────────────────────────────────────────────────

  /// All links whose source is [deviceId], in insertion order.
  List<SwitchLink> linksFor(String deviceId) =>
      List.unmodifiable(_switchLinks[deviceId] ?? const []);

  /// All commissioned devices that accept commands matching the switch group.
  ///
  /// [requiresOnOff]  include devices that accept On/Off commands (press).
  /// [requiresLevel]  include devices that accept LevelControl commands (CW/CCW).
  ///
  /// A device is included when it satisfies *any* of the requested capabilities
  /// so that a device supporting only OnOff is still offered even when the
  /// group also has CW/CCW endpoints.
  List<DeviceView> linkableTargets({
    String? excludingDeviceId,
    bool requiresOnOff = true,
    bool requiresLevel = false,
  }) {
    return _devices
        .where((d) => d.id != excludingDeviceId)
        .map((d) => DeviceView(d, _liveCache[d.id]))
        .where((v) {
          final id = v.id;
          if (requiresOnOff) {
            final ok = v.deviceType.hasOnOff ||
                (_liveCache[id]?.attrs.containsKey('onOff') ?? false);
            if (ok) return true;
          }
          if (requiresLevel) {
            final ok = v.deviceType.hasBrightness ||
                (_liveCache[id]?.attrs.containsKey('level') ?? false);
            if (ok) return true;
          }
          return false;
        })
        .toList();
  }

  /// Adds or replaces a [SwitchLink] for its source device.
  void upsertSwitchLink(SwitchLink link) {
    final list = _switchLinks.putIfAbsent(link.sourceDeviceId, () => []);
    final idx  = list.indexWhere((l) => l.id == link.id);
    if (idx >= 0) list[idx] = link; else list.add(link);
    notifyListeners();
  }

  /// Removes the link identified by [linkId] from [sourceDeviceId].
  void removeSwitchLink(String sourceDeviceId, String linkId) {
    _switchLinks[sourceDeviceId]?.removeWhere((l) => l.id == linkId);
    notifyListeners();
  }

  // ── Contact link management ──────────────────────────────────────────────

  ContactLink? contactLinkFor(String deviceId) => _contactLinks[deviceId];

  void upsertContactLink(ContactLink link) {
    _contactLinks[link.sourceDeviceId] = link;
    notifyListeners();
  }

  void removeContactLink(String sourceDeviceId) {
    _contactLinks.remove(sourceDeviceId);
    notifyListeners();
  }

  void clearOtaProgress(String deviceId) {
    _otaProgress.remove(deviceId);
    notifyListeners();
  }

  void cacheClusterJson(String deviceId, String json) {
    _clusterCache[deviceId] = json;
    // No notifyListeners needed — detail screen reads this directly.
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
    NetworkType networkType,
  ) async {
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
    );

    _devices.add(device);
    await _persist();
    state = DeviceProviderState.idle;
    notifyListeners();

    unawaited(refreshDevice(device.id));
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

  // ── Refresh (on-demand one-shot read) ─────────────────────────────────────

  Future<void> refreshDevice(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    final device = _devices[idx];

    final deviceState = await _channel.readDeviceState(device.nodeId);

    if (!deviceState.isOnline) {
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
    await _channel.removeDevice(device.nodeId);
    _devices.removeAt(idx);
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

  /// Executes contact-sensor links when [contactState] transitions.
  ///
  /// [prevContact] is the value from the live cache *before* the current
  /// update was merged, so a true transition (null→value excluded) fires once.
  void _handleContactChange(
    String deviceId,
    Map<String, dynamic> attrs,
    bool? prevContact,
  ) {
    if (!attrs.containsKey('contactState')) return;
    final newState = attrs['contactState'] as bool?;
    if (newState == null) return;
    // Skip the first reading (no previous state to transition from).
    if (prevContact == null) return;
    // Skip if the state hasn't changed.
    if (newState == prevContact) return;

    final link = _contactLinks[deviceId];
    if (link == null) return;

    // true  = closed, false = open (BooleanState semantics).
    final targets = newState ? link.onClose : link.onOpen;
    for (final targetId in targets) {
      unawaited(toggle(targetId));
    }
  }

  /// Called on every subscription update.  When the event carries a new
  /// [switchPressTime]
  ///
  /// Using [switchPressTime] rather than [switchCurrentEndpoint] > 0 correctly
  /// handles the BILRESA scroll wheel, which fires InitialPress + ShortRelease
  /// so rapidly that both events arrive in the same subscription report and
  /// [switchCurrentEndpoint] is already 0 by the time Dart processes the map.
  void _handleSwitchPress(String deviceId, Map<String, dynamic> attrs) {
    // Only process updates that contain a press event.
    final pressTime = attrs['switchPressTime'] as int?;
    if (pressTime == null) return;

    // Deduplicate: skip if we already acted on this exact timestamp.
    if (pressTime == (_lastSwitchPressTime[deviceId] ?? 0)) return;
    _lastSwitchPressTime[deviceId] = pressTime;

    // switchLastEndpoint is set by the press and not cleared by the release,
    // so it reliably holds the endpoint even after rapid press+release.
    final ep = (attrs['switchLastEndpoint'] as int?) ?? 0;
    if (ep == 0) return;

    final links = _switchLinks[deviceId] ?? [];
    for (final link in links) {
      if (link.pressEndpoints.contains(ep)) {
        for (final targetId in link.targetDeviceIds) {
          unawaited(toggle(targetId));
        }
      } else if (link.cwEndpoints.contains(ep)) {
        for (final targetId in link.targetDeviceIds) {
          unawaited(stepBrightness(targetId, up: true));
        }
      } else if (link.ccwEndpoints.contains(ep)) {
        for (final targetId in link.targetDeviceIds) {
          unawaited(stepBrightness(targetId, up: false));
        }
      }
    }
  }
}
