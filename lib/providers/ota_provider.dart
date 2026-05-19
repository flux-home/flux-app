import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:matter_home/models/ota_progress.dart';
import 'package:matter_home/models/device_state_event.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/matter_port.dart';

class OtaProvider extends ChangeNotifier {
  OtaProvider(this._channel);

  final MatterPort _channel;
  DeviceProvider? _deviceProvider;

  final Map<String, OtaProgressState> _otaProgress = {};

  void update(DeviceProvider deviceProvider) {
    _deviceProvider = deviceProvider;
  }

  OtaProgressState? otaProgressFor(String deviceId) => _otaProgress[deviceId];

  void clearOtaProgress(String deviceId) {
    _otaProgress.remove(deviceId);
    notifyListeners();
  }

  void handleOtaEvent(String deviceId, OtaProgressEvent event) {
    _otaProgress[deviceId] = OtaProgressState(
      phase:    event.phase,
      progress: event.progress,
      message:  event.message,
    );
    notifyListeners();
  }

  Future<void> detectAndUpdateOtaSupport(String deviceId) async {
    final provider = _deviceProvider;
    if (provider == null) return;
    
    if (provider.liveDataFor(deviceId)?.otaSupported != null) return;
    final device = provider.findById(deviceId);
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
    
    provider.updateOtaSupport(deviceId, supported: foundEndpoint != null, endpoint: foundEndpoint ?? 0);
  }
}
