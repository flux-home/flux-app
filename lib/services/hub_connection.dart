import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/flux_controller_discovery.dart';
import 'package:matter_home/services/flux_ice_channel.dart';
import 'package:matter_home/services/flux_rendezvous.dart';

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

  /// Default STUN server for srflx gathering on the remote path. Google's public
  /// STUN is the out-of-the-box default (ADR-0007) so remote access works with
  /// no configuration; a hub may still override it via RemoteConfig.stun.
  static const defaultStunHost = 'stun.l.google.com';
  static const defaultStunPort = 19302;

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

  /// LAN-first / remote-fallback connect (app ADR-0003). Tries mDNS discovery
  /// (+ manual-IP fallback) first; if the controller isn't found or isn't
  /// reachable, falls back to a remote ICE tunnel via the rendezvous. Remote is
  /// never used while LAN works (LAN is faster and needs no rendezvous/STUN).
  Future<bool> reconnect() async {
    _setStatusFlags(reachable: false, probing: true);
    final ep = await FluxControllerDiscovery.discover();
    if (ep != null) {
      _service?.dispose();
      _service = FluxCoapService(ep);
      _wire(_service);
      notifyListeners();
      await _probe();
      if (_reachable) {
        // Learn the hub's rendezvous URL while we can reach it on the LAN, so a
        // later off-LAN tryRemote() works without the user ever typing a URL.
        unawaited(_learnRendezvousUrl());
        return true;
      }
    }
    // LAN discovery and/or reachability failed → remote fallback.
    return tryRemote();
  }

  /// Cache the controller's own rendezvous URL (read over the LAN) against the
  /// paired controller id, so [tryRemote] can find it later. No-op if the hub
  /// doesn't advertise one or we can't resolve the controller id.
  Future<void> _learnRendezvousUrl() async {
    final svc = _service;
    if (svc == null) return;
    final url = await svc.getRendezvousUrl();
    if (url == null || url.isEmpty) return;
    final id = await ControllerSettings.firstControllerId()
        ?? svc.endpoint.dtlsIdentity;
    if (id != null) await ControllerSettings.saveRendezvousUrl(id, url);
  }

  /// Remote branch of the FSM: bring up the tunnel using the paired hub's
  /// cached PSK + rendezvous URL, gathering srflx via a public STUN server.
  /// Public so the UI can force the remote path (e.g. a "Connect remotely"
  /// action) without waiting for LAN discovery to fail — handy for testing
  /// off-LAN while still on the LAN, and the branch [reconnect] falls back to.
  Future<bool> tryRemote() async {
    final id = await ControllerSettings.firstControllerId();
    if (id == null) {
      _setStatusFlags(reachable: false, probing: false);
      return false;
    }
    final psk = await ControllerSettings.loadPsk(id);
    final url = await ControllerSettings.loadRendezvousUrl(id);
    if (psk == null || url == null) {
      _setStatusFlags(reachable: false, probing: false);
      return false;
    }
    final rzv = FluxRendezvous(baseUrl: url, psk: psk);
    return connectViaRemoteTunnel(
      controllerPsk: psk,
      signalOffer:   rzv.signalOffer,
      dtlsIdentity:  await ControllerSettings.loadDtlsId(id),
      // stunHost/stunPort default to Google's public STUN (see the defaults).
    );
  }

  /// Bring up a remote-access ICE tunnel and swap the active service to talk
  /// CoAP/DTLS through it (app ADR-0001/0003 — the remote branch of the
  /// LAN-first FSM). This is the integration seam the FSM calls once LAN
  /// discovery+reachability have both failed.
  ///
  /// [signalOffer] delivers the MAC-authenticated offer to the controller's
  /// `/remote/signal` (LAN) or the rendezvous (off-LAN) and returns the
  /// controller's answer SDP; keeping it a callback keeps the transport choice
  /// out of the connection FSM. [controllerPsk]/[dtlsIdentity] are reused for
  /// DTLS over the loopback tunnel (flux-interface ADR-0002 — no new secrets).
  Future<bool> connectViaRemoteTunnel({
    required Uint8List controllerPsk,
    required Future<String?> Function(String offerSdp) signalOffer,
    String? dtlsIdentity,
    String? stunHost = defaultStunHost,
    int stunPort = defaultStunPort,
  }) async {
    _setStatusFlags(reachable: false, probing: true);
    final session = await FluxIceChannel().start(stunHost: stunHost, stunPort: stunPort);
    if (session == null) {
      _setStatusFlags(reachable: false, probing: false);
      return false;
    }
    try {
      final answer = await signalOffer(session.offer);
      if (answer == null || answer.isEmpty || !await session.setAnswer(answer)) {
        await session.stop();
        _setStatusFlags(reachable: false, probing: false);
        return false;
      }
      await session.awaitConnected();
      final port = await session.localPort();
      setService(FluxCoapService(FluxControllerEndpoint(
        host: '127.0.0.1',
        port: port,
        psk: controllerPsk,
        dtlsIdentity: dtlsIdentity,
      )));
      return true;
    } on Object catch (e) {
      debugPrint('remote tunnel failed: $e');
      await session.stop();
      _setStatusFlags(reachable: false, probing: false);
      return false;
    }
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
