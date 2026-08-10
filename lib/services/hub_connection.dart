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

/// One step of a connection attempt — the "where" in "where did it fail".
///
/// The FSM tries several things in order and any of them can be the thing that
/// broke; collapsing all of that into a single error string meant the UI could
/// only say "could not reach the controller", which is true of every failure and
/// useful for none.
enum ConnectStage {
  /// Deciding whether a LAN attempt is worth making at all.
  connectivity('Network check'),

  /// mDNS browse for the controller on the local network.
  discovery('LAN discovery'),

  /// DTLS + /info against the endpoint discovery returned.
  lanProbe('LAN probe'),

  /// Looking up the paired controller id / PSK for the remote path.
  pairing('Pairing lookup'),

  /// Handing the ICE offer to the rendezvous and awaiting the answer.
  rendezvous('Rendezvous'),

  /// Native ICE start + local candidate gathering (STUN/TURN).
  iceGather('ICE gather'),

  /// Applying the answer and waiting for the tunnel to come up.
  iceConnect('ICE connect'),

  /// DTLS + /info through the established tunnel.
  tunnelProbe('Tunnel probe');

  const ConnectStage(this.label);

  /// Short human label rendered on the Connection screen.
  final String label;
}

enum ConnectStepOutcome { ok, failed, skipped }

/// Outcome of one [ConnectStage] within a single attempt.
@immutable
class ConnectStep {
  const ConnectStep(this.stage, this.outcome, {this.detail, this.duration});

  final ConnectStage       stage;
  final ConnectStepOutcome outcome;

  /// What happened — an address on success, a reason on failure.
  final String?   detail;
  final Duration? duration;

  bool get isFailure => outcome == ConnectStepOutcome.failed;
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

  /// Coalesces the connect FSM. connect()/reconnect()/tryRemote() are called
  /// from boot, the connectivity watcher, pull-to-refresh, the add-controller
  /// flow and the settings screen — concurrently in practice. Without this two
  /// attempts race and the loser's FluxCoapService is disposed *under*
  /// DeviceProvider, killing its live observes and stranding requests.
  Future<bool>? _fsmInflight;

  /// Bumped on every service swap. Callbacks and probes capture it and drop
  /// their result if it no longer matches — a late reply from a replaced service
  /// must never write state for the current one.
  int _svcGen = 0;

  /// Live remote tunnel, retained so it can be stopped on swap/forget/dispose
  /// (otherwise every remote reconnect leaks a native session + TURN allocation)
  /// and monitored for post-connect failure.
  FluxIceSession? _ice;
  StreamSubscription<FluxIceState>? _iceStates;

  /// Consecutive failed probes, and when we last escalated to a full reconnect.
  /// Drives recovery backoff (#5): a heartbeat failure alone never re-ran
  /// discovery, so an IP change left the app offline until manual refresh.
  int _probeFailStreak = 0;
  DateTime? _lastRecoveryAt;

  bool _hasStoredPsk = false;
  bool _reachable    = false;
  bool _probing      = false;
  Timer? _heartbeatTimer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _connDebounce;
  bool?  _lastMobileOnly;

  FluxCoapService? get service => _service;
  bool get isConnected => _service != null;

  // ── Last-connection metrics (surfaced by the Connection screen) ────────────

  /// Wall time of the last completed connect attempt.
  Duration? lastConnectDuration;
  /// When the last connect attempt finished, and whether it succeeded.
  DateTime? lastConnectAt;
  bool?     lastConnectOk;
  /// How the last successful connect was established.
  ConnectionKind? lastConnectKind;
  /// Round-trip of the most recent heartbeat probe (GET /info).
  Duration? lastProbeRtt;
  DateTime? lastProbeAt;
  /// Reason the last attempt failed (null when it succeeded).
  String?   lastConnectError;
  /// Counters since app start.
  int connectAttempts = 0;
  int connectFailures = 0;

  // ── Last-attempt trace ─────────────────────────────────────────────────────

  /// Every stage of the most recent attempt, in the order it was tried. Replaced
  /// wholesale at the start of each attempt, so it always describes exactly one
  /// attempt rather than an accumulation of several.
  List<ConnectStep> get lastAttemptSteps => List.unmodifiable(_steps);
  final List<ConnectStep> _steps = [];

  /// The step that failed, if the last attempt failed at an identifiable stage.
  ConnectStep? get lastFailedStep {
    for (final s in _steps.reversed) {
      if (s.isFailure) return s;
    }
    return null;
  }

  Stopwatch? _stageSw;
  ConnectStage? _stage;

  /// Mark the start of [stage]. The previous open stage, if any, is closed as
  /// ok — stages are sequential, so reaching the next one means this one passed.
  void _beginStage(ConnectStage stage, {String? detail}) {
    _endStage(ConnectStepOutcome.ok);
    _stage = stage;
    _stageSw = Stopwatch()..start();
    if (detail != null) _log('${stage.label}: $detail');
  }

  void _endStage(ConnectStepOutcome outcome, {String? detail}) {
    final stage = _stage;
    if (stage == null) return;
    _steps.add(ConnectStep(stage, outcome,
        detail: detail, duration: _stageSw?.elapsed));
    if (outcome == ConnectStepOutcome.failed) {
      _log('${stage.label} FAILED: ${detail ?? "no detail"}');
    }
    _stage = null;
    _stageSw = null;
  }

  /// Record a stage that was deliberately not attempted (e.g. LAN skipped on a
  /// cellular-only network), so the trace shows the path taken, not just the
  /// stages that ran.
  void _skipStage(ConnectStage stage, String why) {
    _steps.add(ConnectStep(stage, ConnectStepOutcome.skipped, detail: why));
  }
  /// Consecutive failed heartbeats right now (0 when healthy).
  int get probeFailStreak => _probeFailStreak;

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

  /// Forgets the connected controller: tears down the live service, stops the
  /// heartbeat and re-reads configured state so [status] drops to [noHub] once
  /// the stored keys are gone. Unlike [connect] it does NOT re-run discovery,
  /// so a just-removed hub is not immediately re-found over mDNS. Call AFTER
  /// clearing the controller's keys (ControllerSettings.clearController /
  /// clearAllControllers).
  Future<void> forget() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _stopIce(why: 'controller removed');
    _service?.onReachability = null;
    _svcGen++;
    _service?.dispose();
    _service   = null;
    _reachable = false;
    _probing   = false;
    _hasStoredPsk = await ControllerSettings.hasAnyPsk();
    notifyListeners();
  }

  /// Directly installs a freshly-created service (e.g. after background
  /// discovery that completed post-boot) and notifies listeners.
  void setService(FluxCoapService svc) {
    _install(svc);
    notifyListeners();
    unawaited(_probe());
  }

  /// Swaps in [svc], detaching and disposing whatever it replaces and bumping
  /// the generation so stale callbacks/probes are ignored.
  void _install(FluxCoapService svc) {
    final old = _service;
    old?.onReachability = null;   // detach BEFORE dispose (late timeouts fire)
    old?.dispose();
    _svcGen++;
    _service = svc;
    _wire(svc);
    _probeFailStreak = 0;
    _lastRecoveryAt  = null;
    // forget() cancels the heartbeat and the re-add path (add-controller flow →
    // reconnect → here) never restarted it, leaving a dead hub reported online.
    if (_heartbeatTimer == null) startHealthMonitoring();
  }

  /// Tear down the remote tunnel, if any. Safe to call when there isn't one.
  Future<void> _stopIce({required String why}) async {
    final ice = _ice;
    final sub = _iceStates;
    _ice = null;
    _iceStates = null;
    if (sub != null) await sub.cancel();
    if (ice != null) {
      _log('stopping ICE session ($why)');
      try {
        await ice.stop();
      } on Object catch (e) {
        _log('ICE stop failed: $e');
      }
    }
  }

  /// Connectivity-aware entry to the connect FSM (app ADR-0003). On a
  /// cellular-only network the home LAN is unreachable, so skip mDNS discovery
  /// (which otherwise blocks up to ~20s) and go straight to the remote tunnel.
  /// Wi-Fi/ethernet/VPN are ambiguous (could be a foreign network), so there we
  /// still try LAN-first via [reconnect].
  Future<bool> connect() => _runFsm('connect', () async {
        _beginStage(ConnectStage.connectivity);
        final mobileOnly = await _isMobileOnly();
        _endStage(ConnectStepOutcome.ok,
            detail: mobileOnly ? 'cellular only' : 'LAN-capable');
        if (mobileOnly) {
          _log('cellular-only network → skipping LAN discovery, going remote');
          _skipStage(ConnectStage.discovery, 'cellular only');
          _skipStage(ConnectStage.lanProbe, 'cellular only');
          return _tryRemoteInner();
        }
        return _reconnectInner();
      });

  /// Runs one FSM attempt at a time. A caller arriving while an attempt is in
  /// flight joins it instead of starting a competing one. Also the single place
  /// exceptions are contained: previously a throw (MissingPluginException from
  /// the ICE bridge, a keystore error, an Error from discovery) escaped through
  /// `unawaited(connect())` and left `_probing == true` forever — the UI stuck
  /// on "Connecting…" with no retry until the app was killed.
  Future<bool> _runFsm(String tag, Future<bool> Function() body) {
    final inflight = _fsmInflight;
    if (inflight != null) {
      _log('$tag: joined the in-flight attempt');
      return inflight;
    }
    final sw = Stopwatch()..start();
    connectAttempts++;
    // One attempt, one trace: reset here rather than inside the remote branch,
    // which is why the LAN stages never used to show up in the diagnostics.
    _steps.clear();
    _diag.clear();
    _stage = null;
    _stageSw = null;
    final f = () async {
      try {
        final ok = await body();
        _endStage(ok ? ConnectStepOutcome.ok : ConnectStepOutcome.failed);
        if (!ok) {
          connectFailures++;
          final failed = lastFailedStep;
          lastConnectError ??= failed == null
              ? 'could not reach the controller'
              : '${failed.stage.label}: ${failed.detail ?? "failed"}';
        } else {
          lastConnectError = null;
          lastConnectKind = connectionKind;
        }
        return ok;
      } on Object catch (e) {
        connectFailures++;
        _endStage(ConnectStepOutcome.failed, detail: e.toString());
        final failed = lastFailedStep;
        lastConnectError = failed == null
            ? e.toString()
            : '${failed.stage.label}: ${failed.detail}';
        _log('$tag failed: $e');
        _setStatusFlags(reachable: false, probing: false);
        return false;
      } finally {
        lastConnectDuration = sw.elapsed;
        lastConnectAt = DateTime.now();
      }
    }();
    _fsmInflight = f;
    unawaited(f.then((ok) => lastConnectOk = ok).whenComplete(() {
      if (identical(_fsmInflight, f)) _fsmInflight = null;
    }));
    return f;
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
      // A transport came back after being fully down (Wi-Fi toggled, out of
      // range and back). _classifyMobileOnly maps both [none] and [wifi] to
      // false, so the class does NOT change and this used to be ignored — on a
      // device without cellular, toggling Wi-Fi never re-ran discovery.
      final hadNothing = _lastTypesEmpty;
      final hasSomething = types.isNotEmpty &&
          !(types.length == 1 && types.first == ConnectivityResult.none);
      _lastTypesEmpty = !hasSomething;

      final classChanged = _lastMobileOnly != null && mobileOnly != _lastMobileOnly;
      // First event after boot only seeds the baseline: main() already runs a
      // connect(), and treating the seed as a change fired a second, competing
      // attempt while the first was still inside the 20s mDNS discovery.
      final seeding = _lastMobileOnly == null;
      _lastMobileOnly = mobileOnly;
      if (seeding) return;
      if (!classChanged && !(hadNothing && hasSomething)) return;

      _connDebounce?.cancel();
      _connDebounce = Timer(const Duration(seconds: 2), () {
        if (!hasConfiguredHub) return;
        _log('connectivity changed (mobileOnly=$mobileOnly '
            'regained=${hadNothing && hasSomething}) → reconnecting');
        unawaited(connect());
      });
    });
  }

  /// Whether the last connectivity event reported no usable transport.
  bool _lastTypesEmpty = false;

  /// LAN-first / remote-fallback connect (app ADR-0003). Tries mDNS discovery on
  /// the LAN first (faster, and needs no rendezvous/STUN/TURN); a successful LAN
  /// connect also (re)learns the hub's rendezvous URL so the off-LAN path is
  /// ready later. If the controller can't be reached on the LAN, falls back to
  /// the remote ICE tunnel (rendezvous + STUN, TURN for CGNAT).
  Future<bool> reconnect() => _runFsm('reconnect', _reconnectInner);

  Future<bool> _reconnectInner() async {
    _setStatusFlags(reachable: false, probing: true);
    // LAN first.
    _beginStage(ConnectStage.discovery);
    final ep = await FluxControllerDiscovery.discover();
    if (ep == null) {
      _endStage(ConnectStepOutcome.failed,
          detail: 'no controller advertised on this network (mDNS)');
      _skipStage(ConnectStage.lanProbe, 'nothing discovered');
    }
    if (ep != null) {
      _endStage(ConnectStepOutcome.ok, detail: '${ep.host}:${ep.port}');
      await _stopIce(why: 'LAN connect supersedes the tunnel');
      _install(FluxCoapService(ep));
      notifyListeners();
      _beginStage(ConnectStage.lanProbe, detail: '${ep.host}:${ep.port}');
      await _probe();
      _endStage(
          _reachable ? ConnectStepOutcome.ok : ConnectStepOutcome.failed,
          detail: _reachable
              ? '${ep.host}:${ep.port} answered'
              : (_service?.lastTransportError ?? 'no answer from ${ep.host}'));
      if (_reachable) {
        // Learn the hub's rendezvous URL while we can reach it on the LAN, so a
        // later off-LAN tryRemote() works without the user ever typing a URL.
        unawaited(_learnRendezvousUrl());
        return true;
      }
    }
    // LAN discovery and/or reachability failed → remote fallback.
    // Call the inner impl: going through the guard would return our own
    // in-flight future and deadlock.
    return _tryRemoteInner();
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
  Future<bool> tryRemote() => _runFsm('tryRemote', _tryRemoteInner);

  Future<bool> _tryRemoteInner() async {
    _beginStage(ConnectStage.pairing);
    final id = await ControllerSettings.firstControllerId();
    if (id == null) {
      _endStage(ConnectStepOutcome.failed,
          detail: 'no paired controller stored on this phone');
      _setStatusFlags(reachable: false, probing: false);
      return false;
    }
    final psk = await ControllerSettings.loadPsk(id);
    if (psk == null) {
      _endStage(ConnectStepOutcome.failed,
          detail: 'no pairing key stored for $id — re-pair the controller');
      _setStatusFlags(reachable: false, probing: false);
      return false;
    }
    _endStage(ConnectStepOutcome.ok, detail: id);
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
    _log('start: stun=$stunHost:$stunPort'
        '${turnHost != null ? ' turn=$turnHost:$turnPort' : ' (no TURN)'}');
    _setStatusFlags(reachable: false, probing: true);
    _beginStage(ConnectStage.iceGather,
        detail: 'stun=$stunHost:$stunPort'
            '${turnHost != null ? ' turn=$turnHost:$turnPort' : ' (no TURN)'}');
    final session = await FluxIceChannel().start(
      stunHost: stunHost, stunPort: stunPort,
      turnHost: turnHost, turnPort: turnPort,
      turnUser: turnUser, turnPass: turnPass,
    );
    if (session == null) {
      _endStage(ConnectStepOutcome.failed,
          detail: 'native ICE start returned null');
      _setStatusFlags(reachable: false, probing: false);
      return false;
    }
    _log('offer gathered: ${_candSummary(session.offer)}');
    final cands = _candSummary(session.offer);
    // No srflx means STUN never produced a public candidate, so an off-LAN peer
    // has nothing routable to connect to — worth saying out loud rather than
    // letting it surface later as a generic "tunnel did not come up".
    _endStage(ConnectStepOutcome.ok,
        detail: cands.contains('srflx=0') && !cands.contains('relay=0')
            ? '$cands (no public candidate — STUN blocked?)'
            : cands);
    final stateSub = session.states.listen((s) => _log('ICE state: ${s.name}'));
    try {
      _log('signaling offer via rendezvous…');
      _beginStage(ConnectStage.rendezvous);
      final answer = await signalOffer(session.offer);
      if (answer == null || answer.isEmpty) {
        _endStage(ConnectStepOutcome.failed,
            detail: 'no answer — rendezvous unreachable, key rejected, '
                'or the controller is not connected to it');
        await session.stop();
        _setStatusFlags(reachable: false, probing: false);
        return false;
      }
      _log('answer received: ${_candSummary(answer)}');
      _endStage(ConnectStepOutcome.ok,
          detail: 'answer ${_candSummary(answer)}');
      _beginStage(ConnectStage.iceConnect);
      if (!await session.setAnswer(answer)) {
        _endStage(ConnectStepOutcome.failed,
            detail: 'the controller\'s answer SDP was rejected');
        await session.stop();
        _setStatusFlags(reachable: false, probing: false);
        return false;
      }
      await session.awaitConnected();
      final port = await session.localPort();
      // localPort() returns 0 when the native handle is bad. Reporting CONNECTED
      // on port 0 produced a "connected" hub that could never answer.
      if (port <= 0) {
        _endStage(ConnectStepOutcome.failed,
            detail: 'tunnel reported connected but has no local port '
                '(bad native handle)');
        await stateSub.cancel();
        await session.stop();
        _setStatusFlags(reachable: false, probing: false);
        return false;
      }
      _endStage(ConnectStepOutcome.ok, detail: 'loopback port $port');
      _log('CONNECTED: ICE up, loopback CoAP port=$port');
      // Retain the session so it can be stopped later (it used to leak a native
      // session + TURN allocation per attempt) and keep watching its state, so
      // a tunnel that dies later is noticed instead of us writing into a dead
      // socket until the heartbeat happens to fail.
      await stateSub.cancel();
      await _stopIce(why: 'superseded by a new tunnel');
      _ice = session;
      _iceStates = session.states.listen((st) {
        _log('ICE state: ${st.name}');
        if (st == FluxIceState.failed || st == FluxIceState.closed) {
          if (!identical(_ice, session)) return; // already superseded
          _log('tunnel died → marking offline and re-running the FSM');
          _setStatusFlags(reachable: false, probing: false);
          unawaited(_stopIce(why: 'tunnel ${st.name}'));
          unawaited(connect());
        }
      });
      // Verify the tunnel actually carries CoAP before reporting success. This
      // used to be a fire-and-forget setService(), so a tunnel that came up but
      // could not answer was reported as connected and only unmasked later by a
      // failing heartbeat — and the attempt had no failure to point at.
      _install(FluxCoapService(FluxControllerEndpoint(
        host: '127.0.0.1',
        port: port,
        psk: controllerPsk,
        dtlsIdentity: dtlsIdentity,
      )));
      notifyListeners();
      _beginStage(ConnectStage.tunnelProbe, detail: '127.0.0.1:$port');
      await _probe();
      _endStage(
          _reachable ? ConnectStepOutcome.ok : ConnectStepOutcome.failed,
          detail: _reachable
              ? 'controller answered through the tunnel'
              : (_service?.lastTransportError ??
                  'tunnel is up but the controller did not answer'));
      return _reachable;
    } on Object catch (e) {
      _endStage(ConnectStepOutcome.failed, detail: e.toString());
      _log('FAIL: $e');
      await stateSub.cancel();
      await session.stop();
      _setStatusFlags(reachable: false, probing: false);
      return false;
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
    _heartbeatTimer = Timer.periodic(_heartbeat, (_) {
      // A probe can outlive the 15s period (15s DTLS timeout + one retry), so
      // ticks used to pile up: each toggled _probing, flapping the status chip
      // and thrashing the DTLS session. Skip a tick while one is still running.
      if (_probeInflight) return;
      unawaited(_probe());
    });
    unawaited(_probe());
  }

  /// Pause the heartbeat (call when the app is backgrounded).
  void pauseHealthMonitoring() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  bool _probeInflight = false;

  void _wire(FluxCoapService? svc) {
    final gen = _svcGen;
    svc?.onReachability = (ok) {
      // Ignore a reply from a service we've already replaced: a request issued
      // on the old service can time out 15-30s later and would otherwise mark a
      // perfectly healthy new connection "offline".
      if (gen != _svcGen) return;
      _setStatusFlags(reachable: ok, probing: false);
    };
  }

  Future<void> _probe() async {
    final svc = _service;
    if (svc == null) {
      _setStatusFlags(reachable: false, probing: false);
      return;
    }
    final gen = _svcGen;
    _probeInflight = true;
    _setStatusFlags(reachable: _reachable, probing: true);
    final sw = Stopwatch()..start();
    final info = await svc.getInfo().whenComplete(() => _probeInflight = false);
    if (gen != _svcGen) return;       // service swapped under us — result is stale
    lastProbeAt  = DateTime.now();
    lastProbeRtt = info != null ? sw.elapsed : null;
    _setStatusFlags(reachable: info != null, probing: false);

    // ── #5: escalate a failing heartbeat to a real reconnect ────────────────
    // The heartbeat used to only repaint flags, so it re-probed a stale endpoint
    // forever: after a DHCP change the app stayed offline on the same Wi-Fi
    // until the user pulled to refresh. Escalating re-runs mDNS discovery.
    if (info != null) {
      _probeFailStreak = 0;
      return;
    }
    _probeFailStreak++;
    if (_probeFailStreak < 2 || !hasConfiguredHub) return;
    // Backoff so a powered-off hub isn't hammered: 30s, 60s, 120s… capped 5min.
    final backoff = Duration(
        seconds: (30 * (1 << (_probeFailStreak - 2).clamp(0, 4))).clamp(30, 300));
    final last = _lastRecoveryAt;
    if (last != null && DateTime.now().difference(last) < backoff) return;
    _lastRecoveryAt = DateTime.now();
    _log('heartbeat failed x$_probeFailStreak → re-running discovery');
    unawaited(connect()); // coalesced by _runFsm
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
    unawaited(_stopIce(why: 'HubConnection disposed'));
    _service?.onReachability = null;
    _service?.dispose();
    super.dispose();
  }
}
