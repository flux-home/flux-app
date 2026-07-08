import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:matter_home/services/controller_settings.dart';
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
  HubConnection(FluxCoapService? initial) : _service = initial {
    unawaited(refreshConfiguredState());
  }

  FluxCoapService? _service;
  bool _hasStoredPsk = false;

  FluxCoapService? get service => _service;
  bool get isConnected => _service != null;

  /// True when a hub has been configured (a PSK is stored), even if the
  /// controller is currently unreachable. Lets the UI distinguish "no hub set
  /// up yet" from "hub set up but offline" — the latter should not be told to
  /// pair a new hub.
  bool get hasConfiguredHub => isConnected || _hasStoredPsk;

  /// Re-reads whether any controller PSK is stored and notifies listeners if it
  /// changed. Call after the add-controller flow saves a PSK.
  Future<void> refreshConfiguredState() async {
    final has = await ControllerSettings.hasAnyPsk();
    if (has != _hasStoredPsk) {
      _hasStoredPsk = has;
      notifyListeners();
    }
  }

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
