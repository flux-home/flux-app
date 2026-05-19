import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/providers/device_provider.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController(this._channel);

  final MatterPort _channel;
  DeviceProvider? _deviceProvider;

  final Set<int> _subscribedNodeIds = {};
  final Map<String, Timer?> _establishTimeouts = {};
  final Set<String> _establishedThisSession = {};
  
  static const _kEstablishTimeout = Duration(seconds: 15);

  void update(DeviceProvider deviceProvider) {
    _deviceProvider = deviceProvider;
  }

  void startAll(List<MatterDevice> devices) {
    for (final device in devices) {
      unawaited(start(device));
    }
  }

  Future<void> start(MatterDevice device) async {
    if (_subscribedNodeIds.contains(device.nodeId)) return;
    _subscribedNodeIds.add(device.nodeId);
    
    final ok = await _channel.startSubscription(device.nodeId);
    if (!ok) {
      _subscribedNodeIds.remove(device.nodeId);
      return;
    }

    _establishTimeouts[device.id]?.cancel();
    _establishTimeouts[device.id] = Timer(_kEstablishTimeout, () {
      _deviceProvider?.refreshDevice(device.id);
    });
  }

  Future<void> stop(MatterDevice device) async {
    _subscribedNodeIds.remove(device.nodeId);
    await _channel.stopSubscription(device.nodeId);
  }

  void handleEstablished(String deviceId) {
    _establishTimeouts[deviceId]?.cancel();
    _establishTimeouts[deviceId] = null;
    _establishedThisSession.add(deviceId);
  }

  bool isEstablishedThisSession(String deviceId) => _establishedThisSession.contains(deviceId);

  void dispose() {
    for (final t in _establishTimeouts.values) {
      t?.cancel();
    }
    _establishTimeouts.clear();
  }
}
