import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/device_live_data.dart';
import '../models/device_type.dart';
import '../models/matter_device.dart';
import '../services/device_store.dart';
import '../models/commission_models.dart';
import '../services/matter_channel.dart';

enum DeviceProviderState { idle, loading, error }

class DeviceProvider extends ChangeNotifier {
  final DeviceStore   _store;
  final MatterChannel _channel;
  final _uuid = const Uuid();

  DeviceProviderState state = DeviceProviderState.idle;
  String? errorMessage;
  List<MatterDevice> _devices = [];

  // ── Live cache (in-memory, not persisted) ──────────────────────────────────
  final Map<String, DeviceLiveData> _liveCache    = {};
  final Map<String, String>         _clusterCache = {}; // deviceId → clusters JSON

  /// Subscription node IDs that are currently active.
  final Set<int> _subscribedNodeIds = {};

  StreamSubscription<Map<String, dynamic>>? _deviceStateSub;

  List<MatterDevice> get devices => List.unmodifiable(_devices);

  DeviceProvider(this._store, this._channel) {
    _load();
    // Listen to live subscription updates from the Android CHIP layer.
    _deviceStateSub = _channel.deviceStateUpdates.listen(_onDeviceStateEvent);
    // Start subscriptions for all already-commissioned devices.
    Future.microtask(_startAllSubscriptions);
  }

  @override
  void dispose() {
    _deviceStateSub?.cancel();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  void _load() {
    _devices = _store.loadDevices().map((d) {
      if (d.deviceType == DeviceType.onOffLight && d.localTempCenti != null) {
        return d.copyWith(deviceType: DeviceType.thermostat);
      }
      return d;
    }).toList();
    notifyListeners();
  }

  Future<void> _persist() => _store.saveDevices(_devices);

  // ── Live cache accessors ───────────────────────────────────────────────────

  DeviceLiveData? liveDataFor(String deviceId) => _liveCache[deviceId];

  String? clusterCacheFor(String deviceId) => _clusterCache[deviceId];

  void cacheClusterJson(String deviceId, String json) {
    _clusterCache[deviceId] = json;
    // No notifyListeners needed — detail screen reads this directly.
  }

  void updateBasicInfo(String deviceId, String? productName, String? serial, String? swVersion,
      {String? vendorName, String? vendorId, String? productId,
       String? hwVersion, String? manufacturingDate, String? partNumber,
       String? productUrl, String? uniqueId}) {
    final existing = _liveCache[deviceId];
    if (existing != null) {
      _liveCache[deviceId] = existing.withBasicInfo(serial, swVersion, productName,
          vendorName: vendorName, vendorId: vendorId, productId: productId,
          hwVersion: hwVersion, manufacturingDate: manufacturingDate,
          partNumber: partNumber, productUrl: productUrl, uniqueId: uniqueId);
    } else {
      _liveCache[deviceId] = DeviceLiveData(
        updatedAt: DateTime.now(), isStale: false,
        productName: productName, vendorName: vendorName, vendorId: vendorId,
        productId: productId, hwVersion: hwVersion, serialNumber: serial,
        softwareVersion: swVersion, manufacturingDate: manufacturingDate,
        partNumber: partNumber, productUrl: productUrl, uniqueId: uniqueId,
      );
    }
    if (productName != null && productName.isNotEmpty) {
      final idx = _indexById(deviceId);
      if (idx != -1 && _devices[idx].productName != productName) {
        _devices[idx] = _devices[idx].copyWith(productName: productName);
        _persist();
      }
    }
    notifyListeners();
  }

  // ── Subscription event handler ─────────────────────────────────────────────

  void _onDeviceStateEvent(Map<String, dynamic> event) {
    final nodeId = event['nodeId'] as int?;
    final type   = event['type']   as String? ?? 'update';
    if (nodeId == null) return;

    final candidates = _devices.where((d) => d.nodeId == nodeId);
    if (candidates.isEmpty) return; // event for a device we no longer track
    final device = candidates.first;

    switch (type) {
      case 'error':
      case 'resubscribing':
        // Mark cache stale but don't discard it — UI keeps showing last value.
        final existing = _liveCache[device.id];
        if (existing != null && !existing.isStale) {
          _liveCache[device.id] = existing.markStale();
          notifyListeners();
        }

      case 'established':
      case 'update':
        final existing = _liveCache[device.id];
        _liveCache[device.id] = existing != null
            ? existing.merge(event)
            : DeviceLiveData.fromUpdate(event);

        // Mirror on/off + brightness + temp into the persisted MatterDevice
        // so the home screen tiles stay accurate.
        final idx = _indexById(device.id);
        if (idx != -1) {
          final isOn  = event['onOff']          as bool?;
          final level = event['level']           as int?;
          final temp  = event['localTempCenti']  as int?;
          final updated = _devices[idx].copyWith(
            isOnline:       true,
            isOn:           isOn   ?? _devices[idx].isOn,
            brightness:     level  != null ? level / 254.0 : null,
            localTempCenti: temp   ?? _devices[idx].localTempCenti,
          );
          if (updated != _devices[idx]) {
            _devices[idx] = updated;
            _persist();
          }
        }

        notifyListeners();
    }
  }

  // ── Subscription management ────────────────────────────────────────────────

  Future<void> _startAllSubscriptions() async {
    for (final device in _devices) {
      await _startSubscription(device);
      // If the device type was never resolved (commissioned before type mapping
      // existed), re-detect it now from the Descriptor cluster.
      if (device.deviceType == DeviceType.unknown) {
        _resolveUnknownDeviceType(device);
      }
    }
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

  // ── Commission ─────────────────────────────────────────────────────────────

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

    final result = await _channel.commissionDevice(
      payload,
      wifiSsid:         wifiSsid,
      wifiPassword:     wifiPassword,
      threadDatasetHex: threadDatasetHex,
    );
    return _handleCommissionResult(result, deviceName, room);
  }

  Future<MatterDevice?> commissionViaIp({
    required String ipAddress,
    required int discriminator,
    required int setupPinCode,
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
    return _handleCommissionResult(result, deviceName, room);
  }

  Future<MatterDevice?> _handleCommissionResult(
    CommissionResult result,
    String name,
    String room,
  ) async {
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
      isOn:           false,
      commissionedAt: DateTime.now(),
    );

    _devices.add(device);
    await _persist();
    state = DeviceProviderState.idle;
    notifyListeners();

    // Poll once immediately to seed the cache with the initial state.
    unawaited(refreshDevice(device.id));
    // Then subscribe for live updates.
    unawaited(_startSubscription(device));

    return device;
  }

  // ── Control ────────────────────────────────────────────────────────────────

  Future<void> toggle(String deviceId) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    final device = _devices[idx];
    if (!device.deviceType.hasOnOff) return;

    final newOn = !device.isOn;
    _devices[idx] = device.copyWith(isOn: newOn);
    notifyListeners();

    final ok = await _channel.toggleDevice(device.nodeId, on: newOn);
    if (!ok) {
      _devices[idx] = device;
      notifyListeners();
    } else {
      await _persist();
    }
  }

  Future<void> setBrightness(String deviceId, double value) async {
    final idx = _indexById(deviceId);
    if (idx == -1) return;
    _devices[idx] = _devices[idx].copyWith(brightness: value);
    notifyListeners();
    final level = (value * 254).round().clamp(0, 254);
    await _channel.setLevel(_devices[idx].nodeId, level);
    await _persist();
  }

  // ── Refresh (on-demand one-shot read) ──────────────────────────────────────

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

    int? localTempCenti = device.localTempCenti;
    if (newType == DeviceType.thermostat) {
      final thermo = await _channel.readThermostat(device.nodeId);
      if (thermo != null) {
        localTempCenti = thermo.localTempCenti ?? localTempCenti;
        // Seed live cache with thermostat data for immediate display.
        final existing = _liveCache[device.id];
        _liveCache[device.id] = DeviceLiveData(
          updatedAt:        DateTime.now(),
          isStale:          false,
          isOn:             deviceState.isOn  ?? existing?.isOn,
          levelRaw:         deviceState.brightnessLevel ?? existing?.levelRaw,
          localTempCenti:   thermo.localTempCenti    ?? existing?.localTempCenti,
          heatingSetptCenti:thermo.heatingSetptCenti ?? existing?.heatingSetptCenti,
          coolingSetptCenti:thermo.coolingSetptCenti ?? existing?.coolingSetptCenti,
          systemMode:       thermo.systemMode        ?? existing?.systemMode,
          controlSequence:  thermo.controlSequence   ?? existing?.controlSequence,
          humidityCenti:    existing?.humidityCenti,
          tempMeasureCenti: existing?.tempMeasureCenti,
          batPercentRaw:    existing?.batPercentRaw,
          batChargeLevel:   existing?.batChargeLevel,
          serialNumber:     existing?.serialNumber,
          softwareVersion:  existing?.softwareVersion,
        );
      }
    } else {
      // Seed basic on/off state into live cache.
      final existing = _liveCache[device.id];
      _liveCache[device.id] = (existing ?? DeviceLiveData(
        updatedAt: DateTime.now(), isStale: false)).merge({
        'onOff': deviceState.isOn,
        'level': deviceState.brightnessLevel,
      });
    }

    _devices[idx] = device.copyWith(
      isOnline:       true,
      isOn:           deviceState.isOn ?? device.isOn,
      brightness:     deviceState.brightnessLevel != null
          ? deviceState.brightnessLevel! / 254.0
          : device.brightness,
      deviceType:     newType,
      localTempCenti: localTempCenti,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    for (final d in _devices) {
      await refreshDevice(d.id);
    }
  }

  // ── Share / rename / remove ────────────────────────────────────────────────

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
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> clearAllDevices() async {
    for (final d in _devices) { await _stopSubscription(d); }
    _devices.clear();
    _liveCache.clear();
    _clusterCache.clear();
    await _persist();
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  MatterDevice? findById(String id) => _indexById(id) >= 0
      ? _devices[_indexById(id)]
      : null;

  int _indexById(String id) => _devices.indexWhere((d) => d.id == id);

  List<String> get rooms {
    final set = <String>{};
    for (final d in _devices) set.add(d.room);
    return set.toList()..sort();
  }
}
