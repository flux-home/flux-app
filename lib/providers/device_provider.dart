import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/device_live_data.dart';
import '../models/device_type.dart';
import '../models/device_view.dart';
import '../models/matter_device.dart';
import '../models/ota_progress.dart';
import '../models/persisted_snapshot.dart';
import '../services/device_store.dart';
import '../models/commission_models.dart';
import '../services/matter_port.dart';

enum DeviceProviderState { idle, loading, error }

class DeviceProvider extends ChangeNotifier {
  final DeviceStore _store;
  final MatterPort  _channel;
  final _uuid = const Uuid();

  DeviceProviderState state = DeviceProviderState.idle;
  String? errorMessage;
  List<MatterDevice> _devices = [];

  // ── In-memory caches ──────────────────────────────────────────────────────
  final Map<String, DeviceLiveData>     _liveCache     = {};
  final Map<String, String>             _clusterCache  = {}; // deviceId → JSON
  final Map<String, OtaProgressState>   _otaProgress   = {};
  final Map<String, PersistedSnapshot>  _snapshots     = {};

  final Set<int> _subscribedNodeIds = {};

  StreamSubscription<Map<String, dynamic>>? _deviceStateSub;

  // ── Public device list ────────────────────────────────────────────────────

  /// Raw commissioning records.  Most screens should use [deviceViews] or
  /// [viewFor] instead — those carry merged live state.
  List<MatterDevice> get devices => List.unmodifiable(_devices);

  /// All devices as merged [DeviceView] objects (commissioning record + live).
  List<DeviceView> get deviceViews =>
      _devices.map((d) => DeviceView(d, _liveCache[d.id])).toList();

  /// Returns a merged [DeviceView] for [id], or null if the device is unknown.
  DeviceView? viewFor(String id) {
    final idx = _indexById(id);
    if (idx < 0) return null;
    return DeviceView(_devices[idx], _liveCache[_devices[idx].id]);
  }

  // ── Constructor ───────────────────────────────────────────────────────────

  DeviceProvider(this._store, this._channel) {
    _load();
    _deviceStateSub = _channel.deviceStateUpdates.listen(_onDeviceStateEvent);
    Future.microtask(_startAllSubscriptions);
  }

  @override
  void dispose() {
    _deviceStateSub?.cancel();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  void _load() {
    _snapshots.addAll(_store.loadSnapshots());

    _devices = _store.loadDevices().map((d) {
      // Legacy fix: devices stored before device-type mapping may have
      // onOffLight as a stale commissioning fallback for thermostats.
      if (d.deviceType == DeviceType.onOffLight) {
        final snap = _snapshots[d.id];
        if (snap?.localTempCenti != null) {
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
        _liveCache[device.id] = DeviceLiveData(
          updatedAt:      DateTime.now(),
          isStale:        true, // cold-start seed — replaced when subscription fires
          isOn:           snap.isOn,
          levelRaw:       snap.levelRaw,
          localTempCenti: snap.localTempCenti,
          basicInfo:      snap.productName != null
              ? BasicInfoCache(productName: snap.productName)
              : BasicInfoCache.empty,
        );
      }
    }

    notifyListeners();
  }

  /// Persists both the commissioning records and the live-state snapshots.
  Future<void> _persist() async {
    await _store.saveDevices(_devices);
    await _store.saveSnapshots(_snapshots);
  }

  /// Captures the current live cache for [deviceId] into [_snapshots] and
  /// writes both stores to disk.  Called only at explicit checkpoints
  /// (user action, successful poll) — never from the subscription hot path.
  Future<void> _flushSnapshot(String deviceId) async {
    _snapshots[deviceId] = PersistedSnapshot(
      deviceId:       deviceId,
      isOn:           _liveCache[deviceId]?.isOn,
      levelRaw:       _liveCache[deviceId]?.levelRaw,
      localTempCenti: _liveCache[deviceId]?.localTempCenti,
      productName:    _liveCache[deviceId]?.productName,
    );
    await _persist();
  }

  // ── Live cache helpers ────────────────────────────────────────────────────

  /// Returns the raw live cache for [deviceId].
  /// Prefer [viewFor] when you also need commissioning fields.
  DeviceLiveData? liveDataFor(String deviceId) => _liveCache[deviceId];

  String?          clusterCacheFor(String deviceId) => _clusterCache[deviceId];
  OtaProgressState? otaProgressFor(String deviceId) => _otaProgress[deviceId];

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
  void _mergeLiveCache(
      String deviceId, DeviceLiveData Function(DeviceLiveData) transform) {
    _liveCache[deviceId] = transform(
      _liveCache[deviceId] ??
          DeviceLiveData(updatedAt: DateTime.now(), isStale: false),
    );
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
    int?    swVersionNum,
  }) {
    _mergeLiveCache(
        deviceId,
        (e) => e.withBasicInfo(serial, swVersion, productName,
            vendorName:        vendorName,
            vendorId:          vendorId,
            productId:         productId,
            hwVersion:         hwVersion,
            manufacturingDate: manufacturingDate,
            partNumber:        partNumber,
            productUrl:        productUrl,
            uniqueId:          uniqueId,
            swVersionNum:      swVersionNum));
    // Persist the product name into the snapshot so it survives cold restarts.
    if (productName != null && productName.isNotEmpty) {
      unawaited(_flushSnapshot(deviceId));
    }
  }

  void updateOtaSupport(String deviceId, bool supported, {int endpoint = 0}) {
    _mergeLiveCache(deviceId, (e) => e.withOtaSupported(supported, endpoint));
  }

  /// Searches for the OTA Requestor cluster (0x002A) across all endpoints.
  Future<void> detectAndUpdateOtaSupport(String deviceId) async {
    if (liveDataFor(deviceId)?.otaSupported != null) return;
    final device = findById(deviceId);
    if (device == null) return;

    const otaClusterId = 0x002A;
    int? foundEndpoint;

    final ep0 = await _channel.readServerClusterList(device.nodeId, endpoint: 0);
    if (ep0.contains(otaClusterId)) {
      foundEndpoint = 0;
    } else {
      for (final ep in await _channel.readPartsList(device.nodeId)) {
        final clusters =
            await _channel.readServerClusterList(device.nodeId, endpoint: ep);
        if (clusters.contains(otaClusterId)) {
          foundEndpoint = ep;
          break;
        }
      }
    }
    updateOtaSupport(deviceId, foundEndpoint != null,
        endpoint: foundEndpoint ?? 0);
  }

  // ── Subscription event handler ────────────────────────────────────────────

  void _onDeviceStateEvent(Map<String, dynamic> event) {
    final nodeId = event['nodeId'] as int?;
    final type   = event['type']   as String? ?? 'update';
    if (nodeId == null) return;

    final candidates = _devices.where((d) => d.nodeId == nodeId);
    if (candidates.isEmpty) return;
    final device = candidates.first;

    switch (type) {
      case 'otaProgress':
        _otaProgress[device.id] = OtaProgressState(
          phase:    event['phase']    as String? ?? 'error',
          progress: event['progress'] as int?,
          message:  event['message']  as String?,
        );
        notifyListeners();

      case 'error':
      case 'resubscribing':
        // Mark cache stale but keep values — UI shows last known state dimmed.
        final existing = _liveCache[device.id];
        if (existing != null && !existing.isStale) {
          _liveCache[device.id] = existing.markStale();
          notifyListeners();
        }

      case 'established':
      case 'update':
        // Merge event into live cache.
        final existing = _liveCache[device.id];
        _liveCache[device.id] = existing != null
            ? existing.merge(event)
            : DeviceLiveData.fromUpdate(event);

        // Infer device type from subscription attributes when the stored type
        // is unknown or is a stale commissioning fallback.
        final storedType = device.deviceType;
        if (storedType == DeviceType.unknown ||
            storedType == DeviceType.onOffLight) {
          final inferred = _inferTypeFromEvent(event);
          if (inferred != null) {
            final idx2 = _indexById(device.id);
            if (idx2 != -1) {
              _devices[idx2] =
                  _devices[idx2].copyWith(deviceType: inferred);
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
  }

  // ── Subscription management ───────────────────────────────────────────────

  Future<void> _startAllSubscriptions() async {
    for (final device in _devices) {
      await _startSubscription(device);
      if (device.deviceType == DeviceType.unknown) {
        _resolveUnknownDeviceType(device);
      }
    }
  }

  DeviceType? _inferTypeFromEvent(Map<String, dynamic> event) {
    if (event.containsKey('contactState'))  return DeviceType.contactSensor;
    if (event.containsKey('occupancy'))     return DeviceType.occupancySensor;
    if (event.containsKey('airQuality'))    return DeviceType.airQualitySensor;
    if (event.containsKey('humidityCenti') &&
        !event.containsKey('onOff'))        return DeviceType.humiditySensor;
    if (event.containsKey('tempMeasureCenti') &&
        !event.containsKey('onOff'))        return DeviceType.temperatureSensor;
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
    } catch (_) {}
  }

  Future<void> _startSubscription(MatterDevice device) async {
    if (_subscribedNodeIds.contains(device.nodeId)) return;
    _subscribedNodeIds.add(device.nodeId);
    final ok = await _channel.startSubscription(device.nodeId);
    if (!ok) _subscribedNodeIds.remove(device.nodeId);
  }

  Future<void> _stopSubscription(MatterDevice device) async {
    _subscribedNodeIds.remove(device.nodeId);
    await _channel.stopSubscription(device.nodeId);
  }

  // ── Commission ────────────────────────────────────────────────────────────

  Future<MatterDevice?> commissionDevice(
    String payload,
    String deviceName,
    String room, {
    String? wifiSsid,
    String? wifiPassword,
    String? threadDatasetHex,
  }) async {
    state = DeviceProviderState.loading;
    notifyListeners();

    final networkType = threadDatasetHex != null && threadDatasetHex.isNotEmpty
        ? NetworkType.thread
        : wifiSsid != null && wifiSsid.isNotEmpty
            ? NetworkType.wifi
            : NetworkType.ethernet;

    final result = await _channel.commissionDevice(
      payload,
      wifiSsid:         wifiSsid,
      wifiPassword:     wifiPassword,
      threadDatasetHex: threadDatasetHex,
    );
    return _handleCommissionResult(result, deviceName, room,
        networkType: networkType);
  }

  Future<MatterDevice?> commissionViaIp({
    required String ipAddress,
    required int    discriminator,
    required int    setupPinCode,
    required String deviceName,
    required String room,
    int port = 5540,
  }) async {
    state = DeviceProviderState.loading;
    notifyListeners();

    final result = await _channel.commissionViaIp(
      ipAddress:     ipAddress,
      port:          port,
      discriminator: discriminator,
      setupPinCode:  setupPinCode,
    );
    return _handleCommissionResult(result, deviceName, room,
        networkType: NetworkType.ethernet);
  }

  Future<MatterDevice?> _handleCommissionResult(
    CommissionResult result,
    String name,
    String room, {
    NetworkType networkType = NetworkType.unknown,
  }) async {
    if (!result.success) {
      state        = DeviceProviderState.error;
      errorMessage = result.error ?? 'Commissioning failed';
      notifyListeners();
      return null;
    }

    final deviceType = result.deviceTypeId != null
        ? DeviceType.fromMatterDeviceTypeId(result.deviceTypeId!)
        : DeviceType.onOffLight;

    final device = MatterDevice(
      id:             _uuid.v4(),
      name:           name,
      deviceType:     deviceType,
      nodeId:         result.nodeId!,
      room:           room,
      isOnline:       true,
      commissionedAt: DateTime.now(),
      networkType:    networkType,
    );

    _devices.add(device);
    await _persist();
    state = DeviceProviderState.idle;
    notifyListeners();

    // Poll once to seed live cache, then start subscription.
    unawaited(refreshDevice(device.id));
    unawaited(_startSubscription(device));

    return device;
  }

  // ── Control ───────────────────────────────────────────────────────────────

  Future<void> toggle(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    final device = _devices[idx];
    if (!device.deviceType.hasOnOff) return;

    // Use live cache as source of truth so toggle direction is always correct.
    final currentOn = _liveCache[deviceId]?.isOn ?? false;
    final newOn     = !currentOn;

    final ok = await _channel.toggleDevice(device.nodeId, on: newOn);
    if (ok) {
      _mergeLiveCache(deviceId, (e) => e.merge({'onOff': newOn}));
      await _flushSnapshot(deviceId);
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
    final newType   = typeIdRaw != null
        ? DeviceType.fromMatterDeviceTypeId(typeIdRaw)
        : device.deviceType;

    if (newType == DeviceType.thermostat) {
      final thermo = await _channel.readThermostat(device.nodeId);
      if (thermo != null) {
        _mergeLiveCache(deviceId, (e) => e.copyWith(
          updatedAt:         DateTime.now(),
          isStale:           false,
          isOn:              deviceState.isOn              ?? e.isOn,
          levelRaw:          deviceState.brightnessLevel   ?? e.levelRaw,
          localTempCenti:    thermo.localTempCenti         ?? e.localTempCenti,
          heatingSetptCenti: thermo.heatingSetptCenti      ?? e.heatingSetptCenti,
          coolingSetptCenti: thermo.coolingSetptCenti      ?? e.coolingSetptCenti,
          systemMode:        thermo.systemMode             ?? e.systemMode,
          controlSequence:   thermo.controlSequence        ?? e.controlSequence,
        ));
      }
    } else {
      _mergeLiveCache(deviceId, (e) => e.merge({
        if (deviceState.isOn            != null) 'onOff': deviceState.isOn,
        if (deviceState.brightnessLevel != null) 'level': deviceState.brightnessLevel,
      }));
    }

    // Update commissioning record with the resolved device type and online state.
    _devices[idx] = device.copyWith(
      isOnline:   true,
      deviceType: newType,
    );

    // Checkpoint: flush live state to snapshot so it survives a cold restart.
    await _flushSnapshot(deviceId);
    notifyListeners();
  }

  Future<void> refreshAll() async {
    for (final d in _devices) {
      await refreshDevice(d.id);
    }
  }

  // ── Share / rename / remove ───────────────────────────────────────────────

  Future<bool> shareWithGoogleHome(String deviceId) async {
    final device = findById(deviceId);
    if (device == null) return false;
    final ok = await _channel.shareDevice(device.nodeId);
    if (ok) {
      final idx = _indexById(deviceId);
      _devices[idx] = device.copyWith(sharedWithGoogleHome: true);
      await _persist();
      notifyListeners();
    }
    return ok;
  }

  Future<void> renameDevice(String deviceId, String newName) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    _devices[idx] = _devices[idx].copyWith(name: newName);
    await _persist();
    notifyListeners();
  }

  Future<void> setRoom(String deviceId, String room) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    _devices[idx] = _devices[idx].copyWith(room: room);
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

  List<String> get rooms {
    final set = <String>{};
    for (final d in _devices) set.add(d.room);
    return set.toList()..sort();
  }
}
