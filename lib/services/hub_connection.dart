import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
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

/// How the app is currently reaching the controller.
enum ConnectionKind {
  /// Not currently connected.
  none,

  /// Direct connection on the local network (mDNS/LAN).
  local,

  /// Off-LAN via the remote ICE tunnel (rendezvous + STUN/TURN).
  remote,
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
    _startConnectivityWatch();
  }

  static const _heartbeat = Duration(seconds: 15);

  /// Default STUN server for srflx gathering on the remote path (ADR-0007) —
  /// metered.ca, the same provider as the default TURN relay, so the whole ICE
  /// stack rides one vendor with an SLA (no public-STUN dependency). A hub may
  /// still override it via RemoteConfig.stun.
  static const defaultStunHost = 'stun.relay.metered.ca';
  static const defaultStunPort = 80;

  /// Standard STUN port, used when a user-configured STUN server gives a host
  /// but no explicit port (the Google default above uses a non-standard port).
  static const _stunStandardPort = 3478;

  /// Default rendezvous mailbox (ADR-0006). Non-secret and shared by all users,
  /// so it's a plain baked constant (public builds included); the controller
  /// carries the same default. A hub's RemoteConfig.rendezvous_url learned on
  /// the LAN, or the Remote-access settings override, still takes precedence.
  static const defaultRendezvousUrl = 'https://flux.fluxbox.workers.dev';

  /// Built-in default TURN relay, injected at build time via --dart-define and
  /// EMPTY in public builds. A private/personal build can bake in a relay
  /// (`--dart-define=FLUX_TURN_HOST=… FLUX_TURN_USER=… FLUX_TURN_PASS=…`) so it
  /// works out of the box; public builds ship no credentials and users
  /// configure their own relay in Remote-access settings (which always wins).
  /// Public so the settings screen can display the effective defaults.
  static const defaultTurnHost = String.fromEnvironment('FLUX_TURN_HOST');
  static const defaultTurnUser = String.fromEnvironment('FLUX_TURN_USER');
  static const defaultTurnPass = String.fromEnvironment('FLUX_TURN_PASS');

  FluxCoapService? _service;
  bool _hasStoredPsk = false;
  bool _reachable    = false;
  bool _probing      = false;
  Timer? _heartbeatTimer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _connDebounce;
  bool?  _lastMobileOnly;

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

  /// Which transport the active connection uses. The remote ICE tunnel always
  /// presents a 127.0.0.1 loopback endpoint (app ADR-0001), so a loopback host
  /// means remote; any other reachable host is a direct LAN connection. Only
  /// meaningful while [isOnline].
  ConnectionKind get connectionKind {
    if (!_reachable) return ConnectionKind.none;
    return _service?.endpoint.host == '127.0.0.1'
        ? ConnectionKind.remote
        : ConnectionKind.local;
  }

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

  /// Connectivity-aware entry to the connect FSM (app ADR-0003). On a
  /// cellular-only network the home LAN is unreachable, so skip mDNS discovery
  /// (which otherwise blocks up to ~20s) and go straight to the remote tunnel.
  /// Wi-Fi/ethernet/VPN are ambiguous (could be a foreign network), so there we
  /// still try LAN-first via [reconnect].
  Future<bool> connect() async {
    if (await _isMobileOnly()) {
      _log('cellular-only network → skipping LAN discovery, going remote');
      return tryRemote();
    }
    return reconnect();
  }

  /// True when the only active transport is cellular. Wi-Fi/ethernet/VPN count
  /// as "LAN-capable" even if foreign — the LAN probe is what disambiguates
  /// those. Unknown/empty → false (fall back to LAN-first, the safe default).
  bool _classifyMobileOnly(List<ConnectivityResult> types) {
    final hasLan = types.any((t) =>
        t == ConnectivityResult.wifi ||
        t == ConnectivityResult.ethernet ||
        t == ConnectivityResult.vpn);
    return types.contains(ConnectivityResult.mobile) && !hasLan;
  }

  Future<bool> _isMobileOnly() async {
    try {
      return _classifyMobileOnly(await Connectivity().checkConnectivity());
    } on Object catch (e) {
      _log('connectivity check failed: $e');
      return false;
    }
  }

  /// Re-run the FSM when the network class flips between cellular-only and
  /// LAN-capable (leave home Wi-Fi → remote; return → LAN). Debounced, and only
  /// fires on a meaningful class change so Wi-Fi→Wi-Fi hops don't churn.
  void _startConnectivityWatch() {
    _connSub = Connectivity().onConnectivityChanged.listen((types) {
      final mobileOnly = _classifyMobileOnly(types);
      if (mobileOnly == _lastMobileOnly) return;
      _lastMobileOnly = mobileOnly;
      _connDebounce?.cancel();
      _connDebounce = Timer(const Duration(seconds: 2), () {
        if (!hasConfiguredHub) return;
        _log('network class changed (mobileOnly=$mobileOnly) → reconnecting');
        unawaited(connect());
      });
    });
  }

  /// LAN-first / remote-fallback connect (app ADR-0003). Tries mDNS discovery on
  /// the LAN first (faster, and needs no rendezvous/STUN/TURN); a successful LAN
  /// connect also (re)learns the hub's rendezvous URL so the off-LAN path is
  /// ready later. If the controller can't be reached on the LAN, falls back to
  /// the remote ICE tunnel (rendezvous + STUN, TURN for CGNAT).
  Future<bool> reconnect() async {
    _setStatusFlags(reachable: false, probing: true);
    // LAN first.
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
    if (psk == null) {
      _setStatusFlags(reachable: false, probing: false);
      return false;
    }
    // Rendezvous: a URL learned from the hub / set as an override wins; else the
    // built-in default (the controller falls back to the same one).
    final url = await ControllerSettings.loadRendezvousUrl(id) ?? defaultRendezvousUrl;
    final rzv = FluxRendezvous(baseUrl: url, psk: psk, onLog: _log);
    final (stunHost, stunPort) = _resolveStun(await ControllerSettings.loadStunServer(id));

    // TURN: a user-configured relay wins; otherwise the build-time default,
    // which is empty in public builds → STUN-only (fails on CGNAT, expected
    // until the user sets up their own relay). ADR-0004.
    final (turnServer, mUser, mPass) = await ControllerSettings.loadTurn(id);
    String? turnHost; var turnPort = 0; String? turnUser; String? turnPass;
    if (turnServer != null) {
      (turnHost, turnPort) = _resolveHostPort(turnServer, _stunStandardPort);
      turnUser = mUser;
      turnPass = mPass;
    } else if (defaultTurnHost.isNotEmpty) {
      (turnHost, turnPort) = _resolveHostPort(defaultTurnHost, _stunStandardPort);
      turnUser = defaultTurnUser.isEmpty ? null : defaultTurnUser;
      turnPass = defaultTurnPass.isEmpty ? null : defaultTurnPass;
      _log('default TURN: $turnHost:$turnPort (built-in)');
    }

    return connectViaRemoteTunnel(
      controllerPsk: psk,
      signalOffer:   rzv.signalOffer,
      dtlsIdentity:  await ControllerSettings.loadDtlsId(id),
      stunHost:      stunHost,
      stunPort:      stunPort,
      turnHost:      turnHost,
      turnPort:      turnPort,
      turnUser:      turnUser,
      turnPass:      turnPass,
    );
  }


  /// Resolve a stored STUN setting ("host" or "host:port") to (host, port),
  /// falling back to the built-in Google default when unset. A host without an
  /// explicit port uses the standard STUN port 3478.
  static (String, int) _resolveStun(String? server) =>
      (server == null || server.trim().isEmpty)
          ? (defaultStunHost, defaultStunPort)
          : _resolveHostPort(server, _stunStandardPort);

  /// Parse "host", "host:port", or "stun:/turn:host:port" → (host, port),
  /// falling back to [defaultPort] when no explicit port is given.
  static (String, int) _resolveHostPort(String server, int defaultPort) {
    var host = server.trim();
    for (final scheme in const ['stun:', 'turn:', 'turns:', 'stuns:']) {
      if (host.startsWith(scheme)) { host = host.substring(scheme.length); break; }
    }
    var port = defaultPort;
    final colon = host.lastIndexOf(':');
    if (colon > 0 && colon < host.length - 1) {
      final p = int.tryParse(host.substring(colon + 1));
      if (p != null && p > 0 && p <= 65535) {
        port = p;
        host = host.substring(0, colon);
      }
    }
    return (host, port);
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
    String? turnHost,
    int turnPort = 0,
    String? turnUser,
    String? turnPass,
  }) async {
    _diag.clear();
    _log('start: stun=$stunHost:$stunPort'
        '${turnHost != null ? ' turn=$turnHost:$turnPort' : ' (no TURN)'}');
    _setStatusFlags(reachable: false, probing: true);
    final session = await FluxIceChannel().start(
      stunHost: stunHost, stunPort: stunPort,
      turnHost: turnHost, turnPort: turnPort,
      turnUser: turnUser, turnPass: turnPass,
    );
    if (session == null) {
      _log('FAIL: native ICE start returned null');
      _setStatusFlags(reachable: false, probing: false);
      return false;
    }
    _log('offer gathered: ${_candSummary(session.offer)}');
    final stateSub = session.states.listen((s) => _log('ICE state: ${s.name}'));
    try {
      _log('signaling offer via rendezvous…');
      final answer = await signalOffer(session.offer);
      if (answer == null || answer.isEmpty) {
        _log('FAIL: no answer from rendezvous (unreachable? MAC rejected? no hub?)');
        await session.stop();
        _setStatusFlags(reachable: false, probing: false);
        return false;
      }
      _log('answer received: ${_candSummary(answer)}');
      if (!await session.setAnswer(answer)) {
        _log('FAIL: setAnswer rejected the SDP');
        await session.stop();
        _setStatusFlags(reachable: false, probing: false);
        return false;
      }
      await session.awaitConnected();
      final port = await session.localPort();
      _log('CONNECTED: ICE up, loopback CoAP port=$port');
      setService(FluxCoapService(FluxControllerEndpoint(
        host: '127.0.0.1',
        port: port,
        psk: controllerPsk,
        dtlsIdentity: dtlsIdentity,
      )));
      return true;
    } on Object catch (e) {
      _log('FAIL: $e');
      await session.stop();
      _setStatusFlags(reachable: false, probing: false);
      return false;
    } finally {
      await stateSub.cancel();
    }
  }

  /// Human-readable trace of the last remote-tunnel attempt — shown on-screen
  /// (so the phone can be debugged with Wi-Fi off, no adb) and mirrored to
  /// logcat via debugPrint for the persistent-buffer dump afterwards.
  final List<String> _diag = [];
  String get lastRemoteDiagnostics => _diag.join('\n');

  void _log(String line) {
    _diag.add(line);
    debugPrint('flux-remote: $line');
  }

  /// Count candidate types in an SDP — srflx>0 means STUN produced a public
  /// (server-reflexive) candidate, the key signal when testing off-LAN.
  static String _candSummary(String sdp) {
    int n(String t) => RegExp('typ $t').allMatches(sdp).length;
    return 'host=${n('host')} srflx=${n('srflx')} relay=${n('relay')}';
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
    _connDebounce?.cancel();
    unawaited(_connSub?.cancel());
    _service?.dispose();
    super.dispose();
  }
}
