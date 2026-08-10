import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// ICE session state, mirroring the native `flux_ice_state_t` ordinals.
enum FluxIceState { newborn, gathering, checking, connected, failed, closed }

FluxIceState _stateFromInt(int v) => switch (v) {
      1 => FluxIceState.gathering,
      2 => FluxIceState.checking,
      3 => FluxIceState.connected,
      4 => FluxIceState.failed,
      5 => FluxIceState.closed,
      _ => FluxIceState.newborn,
    };

/// Flutter ↔ platform bridge for the flux-ice remote-access tunnel.
///
/// Mirrors `MatterChannel`: a low-frequency control surface over the shared C
/// (app ADR-0001). The packet data plane never crosses into Dart — the native
/// side owns the external + loopback sockets, and the app's CoAP/DTLS client
/// simply connects to `coaps://127.0.0.1:<loopbackPort>`.
class FluxIceChannel {
  static const _method = MethodChannel('com.fluxhome.app/flux_ice');
  static const _events = EventChannel('com.fluxhome.app/flux_ice_events');

  /// Open a CONTROLLING session and gather. Blocks natively (~3 s) then returns
  /// a [FluxIceSession] carrying the local offer SDP — POST it (MAC'd) to the
  /// controller's `/remote/signal`, then feed the answer to
  /// [FluxIceSession.setAnswer]. Returns null on failure.
  Future<FluxIceSession?> start({
    String? stunHost,
    int stunPort = 0,
    String? turnHost,
    int turnPort = 0,
    String? turnUser,
    String? turnPass,
  }) async {
    try {
      final res = await _method.invokeMethod<Map<dynamic, dynamic>>('start', {
        'stunHost': stunHost,
        'stunPort': stunPort,
        'turnHost': turnHost,
        'turnPort': turnPort,
        'turnUser': turnUser,
        'turnPass': turnPass,
      });
      if (res == null) return null;
      final handle = (res['handle'] as num).toInt();
      final offer = res['offer'] as String? ?? '';
      if (handle == 0 || offer.isEmpty) return null;
      return FluxIceSession._(handle, offer);
    } on PlatformException catch (e) {
      debugPrint('flux_ice start error: ${e.message}');
      return null;
    }
  }

  static Future<int> _setAnswer(int handle, String answer) async =>
      await _method.invokeMethod<int>('setAnswer', {'handle': handle, 'answer': answer}) ?? -1;

  static Future<int> _localPort(int handle) async =>
      await _method.invokeMethod<int>('localPort', {'handle': handle}) ?? 0;

  static Future<void> _stop(int handle) async =>
      _method.invokeMethod<void>('stop', {'handle': handle});

  /// State stream for [handle]: the native side polls ICE state and emits on
  /// change. The handle is passed as the EventChannel's listen argument.
  static Stream<FluxIceState> _states(int handle) =>
      _events.receiveBroadcastStream(handle).map((e) => _stateFromInt(e as int));
}

/// A live CONTROLLING ICE session. Obtain via [FluxIceChannel.start].
class FluxIceSession {
  FluxIceSession._(this._handle, this.offer);

  final int _handle;

  /// The local offer SDP gathered at start; send to `/remote/signal`.
  final String offer;

  /// ICE state changes (dedup'd by the native poller).
  Stream<FluxIceState> get states => FluxIceChannel._states(_handle);

  /// Feed the controller's answer SDP. Returns true on success; connectivity
  /// then proceeds asynchronously (watch [states] for [FluxIceState.connected]).
  Future<bool> setAnswer(String answerSdp) async =>
      (await FluxIceChannel._setAnswer(_handle, answerSdp)) == 0;

  /// Loopback UDP port for the app's CoAP client. Usable once [states] reaches
  /// [FluxIceState.connected].
  Future<int> localPort() => FluxIceChannel._localPort(_handle);

  /// Convenience: complete when CONNECTED, throw on FAILED/CLOSED or [timeout].
  ///
  /// The thrown message is user-facing — it lands verbatim on the Connection
  /// screen's ICE-connect stage. A bare `.timeout(d)` was worse than useless
  /// there: Dart's default TimeoutException message is the literal string
  /// "Future not completed", which told the reader nothing about ICE. Report the
  /// last state actually observed instead, because "no state at all" (the native
  /// state stream never delivered) and "stuck in checking" (connectivity checks
  /// are failing) have completely different causes.
  Future<void> awaitConnected({Duration timeout = const Duration(seconds: 20)}) async {
    FluxIceState? last;
    final done = Completer<FluxIceState>();
    final sub = states.listen(
      (st) {
        last = st;
        if (!done.isCompleted &&
            (st == FluxIceState.connected ||
             st == FluxIceState.failed ||
             st == FluxIceState.closed)) {
          done.complete(st);
        }
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
      onDone: () {
        if (!done.isCompleted) {
          done.completeError(StateError(
              'the ICE state stream closed before connecting '
              '(last state: ${last?.name ?? "none"})'));
        }
      },
    );
    try {
      final s = await done.future.timeout(timeout, onTimeout: () {
        throw StateError(
            'ICE did not connect within ${timeout.inSeconds} s '
            '(last state: ${last?.name ?? "none seen — no candidate pair "
                "succeeded, or the native state stream is silent"})');
      });
      if (s != FluxIceState.connected) {
        throw StateError('ICE reported ${s.name} before connecting');
      }
    } finally {
      await sub.cancel();
    }
  }

  /// Tear down the native session.
  Future<void> stop() => FluxIceChannel._stop(_handle);
}
