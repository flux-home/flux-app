import 'dart:async';

import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/services/matter_port.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionManager
//
// Owns the subscription lifecycle for every commissioned device:
//   • starting / stopping subscriptions on the CHIP SDK
//   • arming a fallback-read timer when the SDK stalls before `established`
//   • resolving unknown device types via a one-shot cluster read
//
// All decisions that change persistent state are delegated back via callbacks
// so this class stays free of ChangeNotifier / DeviceStore concerns.
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionManager {
  SubscriptionManager({
    required MatterPort channel,
    required Future<void> Function(String deviceId) onFallbackRefresh,
    required void Function(String deviceId, DeviceType newType) onTypeResolved,
    required bool Function() isDisposed,
  })  : _channel           = channel,
        _onFallbackRefresh = onFallbackRefresh,
        _onTypeResolved    = onTypeResolved,
        _isDisposed        = isDisposed;

  final MatterPort _channel;
  final Future<void> Function(String deviceId) _onFallbackRefresh;
  final void Function(String deviceId, DeviceType newType) _onTypeResolved;
  final bool Function() _isDisposed;

  final Set<int>            _subscribedNodeIds      = {};
  final Map<String, Timer?> _establishTimeouts      = {};
  final Set<String>         _establishedThisSession = {};

  static const _kEstablishTimeout = Duration(seconds: 15);

  // ── Public API ─────────────────────────────────────────────────────────────

  bool hasEstablishedThisSession(String deviceId) =>
      _establishedThisSession.contains(deviceId);

  bool markEstablished(String deviceId) =>
      _establishedThisSession.add(deviceId); // returns true on first call

  void cancelEstablishTimeout(String deviceId) {
    _establishTimeouts[deviceId]?.cancel();
    _establishTimeouts[deviceId] = null;
  }

  Future<void> startAll(List<MatterDevice> devices) async {
    await Future.wait([for (final d in devices) _startSubscription(d)]);
    for (final d in devices) {
      if (d.deviceType == DeviceType.unknown) {
        unawaited(_resolveUnknownType(d));
      }
    }
  }

  Future<void> start(MatterDevice device) => _startSubscription(device);

  Future<void> stop(MatterDevice device) async {
    _subscribedNodeIds.remove(device.nodeId);
    await _channel.stopSubscription(device.nodeId);
  }

  void dispose() {
    for (final t in _establishTimeouts.values) t?.cancel();
    _establishTimeouts.clear();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _startSubscription(MatterDevice device) async {
    if (_subscribedNodeIds.contains(device.nodeId)) return;
    _subscribedNodeIds.add(device.nodeId);
    final ok = await _channel.startSubscription(device.nodeId);
    if (!ok) { _subscribedNodeIds.remove(device.nodeId); return; }

    _establishTimeouts[device.id]?.cancel();
    _establishTimeouts[device.id] = Timer(_kEstablishTimeout, () {
      if (!_isDisposed()) unawaited(_onFallbackRefresh(device.id));
    });
  }

  Future<void> _resolveUnknownType(MatterDevice device) async {
    try {
      final typeId = await _channel.readDeviceTypeId(device.nodeId);
      if (typeId == null) return;
      final resolved = DeviceType.fromMatterDeviceTypeId(typeId);
      if (resolved == DeviceType.unknown) return;
      _onTypeResolved(device.id, resolved);
    } on Exception catch (_) {}
  }
}


