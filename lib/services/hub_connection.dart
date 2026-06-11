import 'package:flutter/foundation.dart';

import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/flux_controller_discovery.dart';

/// Mutable handle on the Flux Controller connection.
///
/// Injected as a [ChangeNotifierProvider] so any widget or provider can
/// watch for connection changes without restarting the app.
///
/// The initial service is set in [main] after startup discovery.
/// [reconnect] can be called later (e.g. from the settings screen) to
/// re-run discovery and swap in a new [FluxCoapService].
class HubConnection extends ChangeNotifier {
  HubConnection(FluxCoapService? initial) : _service = initial;

  FluxCoapService? _service;

  FluxCoapService? get service => _service;
  bool get isConnected => _service != null;

  /// Directly installs a freshly-created service (e.g. after background
  /// discovery that completed post-boot) and notifies listeners.
  void setService(FluxCoapService svc) {
    _service?.dispose();
    _service = svc;
    notifyListeners();
  }

  /// Re-runs mDNS discovery (+ manual-IP fallback) and, on success, replaces
  /// the active service and notifies listeners.
  Future<bool> reconnect() async {
    final ep = await FluxControllerDiscovery.discover();
    if (ep == null) return false;

    _service?.dispose();
    _service = FluxCoapService(ep);
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }
}
