import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  /// Standard STUN port, used when a user-configured STUN server gives a host
  /// but no explicit port (the Google default above uses a non-standard port).
  static const _stunStandardPort = 3478;

  /// Default TURN provider (metered.ca). Credentials are ephemeral, so they're
  /// fetched fresh at connect time from this API rather than hard-coded. Used
  /// only when no TURN relay is configured manually in settings.
  /// NOTE: test key — for production, issue TURN creds from a backend instead
  /// of shipping an API key in the app.
  static const _meteredTurnApi =
      'https://fluxcontrol.metered.live/api/v1/turn/credentials'
      '?apiKey=9da12fdc3b0bf3b0e1539b6ab18969f79963';

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

  /// Remote-first / LAN-fallback connect (app ADR-0003). The off-LAN ICE tunnel
  /// (via the rendezvous, srflx over STUN) is the default path; if it can't be
  /// brought up — no rendezvous URL learned yet (first run), or the
  /// rendezvous/STUN is unreachable — falls back to mDNS discovery on the LAN.
  /// A successful LAN connect also (re)learns the rendezvous URL for next time,
  /// so the remote path is ready on subsequent connects.
  Future<bool> reconnect() async {
    _setStatusFlags(reachable: false, probing: true);
    // Off-LAN tunnel first.
    if (await tryRemote()) return true;

    // Fall back to the LAN.
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
    _setStatusFlags(reachable: false, probing: false);
    return false;
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
    final rzv = FluxRendezvous(baseUrl: url, psk: psk, onLog: _log);
    final (stunHost, stunPort) = _resolveStun(await ControllerSettings.loadStunServer(id));

    // TURN: a manually-configured relay wins; otherwise fall back to the
    // built-in metered.ca default (fresh ephemeral creds fetched per connect).
    final (turnServer, mUser, mPass) = await ControllerSettings.loadTurn(id);
    String? turnHost; var turnPort = 0; String? turnUser; String? turnPass;
    if (turnServer != null) {
      (turnHost, turnPort) = _resolveHostPort(turnServer, _stunStandardPort);
      turnUser = mUser;
      turnPass = mPass;
    } else {
      (turnHost, turnPort, turnUser, turnPass) = await _fetchDefaultTurn();
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

  /// Fetch fresh TURN credentials from the default provider (metered.ca).
  /// Returns (host, port, user, pass); host is null on any failure (falls back
  /// to STUN-only). Picks the first plain-UDP `turn:` entry.
  Future<(String?, int, String?, String?)> _fetchDefaultTurn() async {
    try {
      final r = await http.get(Uri.parse(_meteredTurnApi))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) {
        _log('default TURN fetch: HTTP ${r.statusCode}');
        return (null, 0, null, null);
      }
      final list = jsonDecode(r.body) as List<dynamic>;
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final urls = (m['urls'] as String?) ?? '';
        if (urls.startsWith('turn:') && !urls.contains('transport=tcp')) {
          final (h, p) = _resolveHostPort(urls, _stunStandardPort);
          _log('default TURN: $h:$p (metered.ca)');
          return (h, p, m['username'] as String?, m['credential'] as String?);
        }
      }
      _log('default TURN: no usable turn: entry in response');
    } on Object catch (e) {
      _log('default TURN fetch failed: $e');
    }
    return (null, 0, null, null);
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
    _service?.dispose();
    super.dispose();
  }
}
