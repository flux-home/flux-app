import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/flux_controller_discovery.dart';

/// App-wide reachability of the Flux controller.
enum ControllerStatus {
  /// No hub has been paired yet.
  noHub,

  /// A hub is configured and a connection attempt is in progress.
  connecting,

  /// The controller answered recently — interactions will work.
  online,

  /// A hub is configured but currently unreachable.
  offline,
}

/// Mutable handle on the Flux Controller connection.
///
/// Injected as a [ChangeNotifierProvider] so any widget or provider can
/// watch for connection changes without restarting the app.
///
/// The initial service is set in [main] after startup discovery.
/// [reconnect] can be called later (e.g. from the settings screen) to
/// re-run discovery and swap in a new [FluxCoapService].
///
/// [status] is the single source of truth for "can the app talk to the hub
/// right now" — driven by a lightweight heartbeat plus the pass/fail outcome
/// of every real request (see [FluxCoapService.onReachability]).
class HubConnection extends ChangeNotifier {
  HubConnection(FluxCoapService? initial) : _service = initial {
    _wire(_service);
    unawaited(refreshConfiguredState());
    startHealthMonitoring();
  }

  static const _heartbeat = Duration(seconds: 15);

  FluxCoapService? _service;
  bool _hasStoredPsk = false;
  bool _reachable    = false;
  bool _probing      = false;
  Timer? _heartbeatTimer;

  FluxCoapService? get service => _service;
  bool get isConnected => _service != null;

  /// True when a hub has been configured (a PSK is stored), even if the
  /// controller is currently unreachable. Lets the UI distinguish "no hub set
  /// up yet" from "hub set up but offline" — the latter should not be told to
  /// pair a new hub.
  bool get hasConfiguredHub => isConnected || _hasStoredPsk;

  /// App-wide controller reachability. Watch this to reflect/gate anything that
  /// depends on the hub.
  ControllerStatus get status {
    if (!hasConfiguredHub) return ControllerStatus.noHub;
    if (_reachable)        return ControllerStatus.online;
    if (_probing)          return ControllerStatus.connecting;
    return ControllerStatus.offline;
  }

  bool get isOnline => status == ControllerStatus.online;

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
    _wire(svc);
    notifyListeners();
    unawaited(_probe());
  }

  /// Re-runs mDNS discovery (+ manual-IP fallback) and, on success, replaces
  /// the active service and notifies listeners.
  Future<bool> reconnect() async {
    _setStatusFlags(reachable: false, probing: true);
    final ep = await FluxControllerDiscovery.discover();
    if (ep == null) {
      _setStatusFlags(reachable: false, probing: false);
      return false;
    }
    _service?.dispose();
    _service = FluxCoapService(ep);
    _wire(_service);
    notifyListeners();
    await _probe();
    return _reachable;
  }

  // ── Health monitoring ──────────────────────────────────────────────────────

  /// Start (or restart) the idle heartbeat. Call on app-resume.
  void startHealthMonitoring() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeat, (_) => unawaited(_probe()));
    unawaited(_probe());
  }

  /// Pause the heartbeat (call when the app is backgrounded).
  void pauseHealthMonitoring() => _heartbeatTimer?.cancel();

  void _wire(FluxCoapService? svc) => svc?.onReachability =
      (ok) => _setStatusFlags(reachable: ok, probing: false);

  Future<void> _probe() async {
    final svc = _service;
    if (svc == null) {
      _setStatusFlags(reachable: false, probing: false);
      return;
    }
    _setStatusFlags(reachable: _reachable, probing: true);
    final info = await svc.getInfo(); // onReachability also fires from _send
    _setStatusFlags(reachable: info != null, probing: false);
  }

  void _setStatusFlags({required bool reachable, required bool probing}) {
    if (reachable == _reachable && probing == _probing) return;
    _reachable = reachable;
    _probing   = probing;
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _service?.dispose();
    super.dispose();
  }
}
