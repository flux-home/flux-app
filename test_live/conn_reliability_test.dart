// Live reliability harness — talks to the REAL controller.
//
// Deliberately outside test/ so `flutter test` (the unit suite) never picks it
// up. Reads the controller host/PSK from ~/.config/flux/config.toml, the same
// file flux-ctl uses, so no secret is committed here.
//
// Run: flutter test test_live/conn_reliability_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/services/flux_coap_service.dart';

late String _host;
late int _port;
late String _identity;
late Uint8List _psk;

void _loadConfig() {
  final f = File('${Platform.environment['HOME']}/.config/flux/config.toml');
  final txt = f.readAsStringSync();
  String? grab(String key) =>
      RegExp('$key\\s*=\\s*"?([^"\n]+)"?').firstMatch(txt)?.group(1)?.trim();
  _host = grab('host')!;
  _port = int.parse(grab('port') ?? '5684');
  _identity = grab('identity')!;
  final hex = RegExp(r'[0-9a-fA-F]{32}').firstMatch(txt)!.group(0)!;
  _psk = Uint8List.fromList(List.generate(
      16, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
}

FluxCoapService _svc({String? host, int? port}) =>
    FluxCoapService(FluxControllerEndpoint(
        host: host ?? _host,
        port: port ?? _port,
        psk: _psk,
        dtlsIdentity: _identity));

String _stats(List<int> ms) {
  if (ms.isEmpty) return 'n/a';
  final s = [...ms]..sort();
  int p(double q) => s[(s.length * q).clamp(0, s.length - 1).toInt()];
  return 'med=${p(.5)} p95=${p(.95)} max=${s.last}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadConfig);

  test('T1 smoke: GET /info over DTLS via the app transport', () async {
    final svc = _svc();
    final sw = Stopwatch()..start();
    final info = await svc.getInfo();
    print('  T1 GET /info in ${sw.elapsedMilliseconds}ms -> '
        '${info == null ? "NULL" : "fw=${info.firmwareVersion} up=${info.uptimeSeconds}s"}');
    expect(info, isNotNull, reason: 'controller must answer over DTLS');
    svc.dispose();
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('T2 sustained: 30 sequential GETs on one service (session reuse)',
      () async {
    final svc = _svc();
    await svc.getInfo(); // establish
    final lat = <int>[];
    var fail = 0;
    for (var i = 0; i < 30; i++) {
      final sw = Stopwatch()..start();
      final r = await svc.getInfo();
      if (r == null) {
        fail++;
      } else {
        lat.add(sw.elapsedMilliseconds);
      }
    }
    print('  T2 ok=${lat.length}/30 fail=$fail ms: ${_stats(lat)}');
    expect(fail, 0, reason: 'sustained session must not drop requests');
    svc.dispose();
  }, timeout: const Timeout(Duration(seconds: 180)));

  test('T3 unreachable host: request must fail fast, not pin the caller',
      () async {
    // 192.0.2.1 is TEST-NET-1 — guaranteed unroutable.
    final svc = _svc(host: '192.0.2.1');
    final sw = Stopwatch()..start();
    var hung = false;
    final info =
        await svc.getInfo().timeout(const Duration(seconds: 75), onTimeout: () {
      hung = true;
      return null;
    });
    print('  T3 unreachable: ${hung ? "HUNG >75s" : "returned ${info == null ? "null" : "data"}"}'
        ' after ${sw.elapsedMilliseconds}ms');
    // App DTLS timeout is 15s; with one connection-error retry ~30s is the
    // worst legitimate case. Beyond that the caller is effectively pinned.
    expect(sw.elapsedMilliseconds, lessThan(40000),
        reason: 'unreachable controller must fail fast');
    svc.dispose();
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('T4 dispose mid-flight: in-flight request must complete, not hang',
      () async {
    // Must target an UNREACHABLE host: against the real controller a GET
    // completes in ~3ms, so the request is already done before dispose() and
    // the race is never exercised (an earlier version of this test passed
    // vacuously for exactly that reason). A blackhole keeps it genuinely
    // in flight for ~10s, which is the window a service swap hits in practice.
    final svc = _svc(host: '192.0.2.1');
    final inflight = svc.getInfo(); // fire, then yank the service underneath it
    await Future<void>.delayed(const Duration(milliseconds: 300));
    svc.dispose();
    final sw = Stopwatch()..start();
    var hung = false;
    final r =
        await inflight.timeout(const Duration(seconds: 40), onTimeout: () {
      hung = true;
      return null;
    });
    print('  T4 in-flight after dispose: '
        '${hung ? "HUNG (never completed)" : "returned ${r == null ? "null" : "data"}"}'
        ' after ${sw.elapsedMilliseconds}ms');
    expect(hung, isFalse,
        reason: 'dispose() must complete pending requests, not orphan them');
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('T5 concurrent connects: N fresh services handshaking at once', () async {
    // Models the real post-reboot / post-outage storm: every client (phones,
    // flux-ctl, this app) re-handshakes simultaneously.
    for (final n in [2, 4, 8]) {
      final svcs = List.generate(n, (_) => _svc());
      final sw = Stopwatch()..start();
      final results = await Future.wait(svcs.map((s) async {
        final t = Stopwatch()..start();
        final r = await s.getInfo();
        return (ok: r != null, ms: t.elapsedMilliseconds);
      }));
      final ok = results.where((r) => r.ok).length;
      final lat = results.map((r) => r.ms).toList();
      print('  T5 n=$n ok=$ok/$n wall=${sw.elapsedMilliseconds}ms '
          'per-conn ms: ${_stats(lat)}');
      for (final s in svcs) {
        s.dispose();
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }, timeout: const Timeout(Duration(seconds: 300)));

  // Reboots the controller by toggling DTR/RTS on its UART bridge (opening
  // /dev/ttyACM0 resets an ESP32-P4). The serial logger owns the port, so it is
  // stopped and restarted around the toggle.
  test('T6 controller reboot: does the SAME service instance recover?',
      () async {
    const fw = '/home/tado/workspace/flux/flux-controller/firmware';
    final svc = _svc();
    expect(await svc.getInfo(), isNotNull, reason: 'must be up before reboot');

    await Process.run('python3', ['serial_logger.py', 'stop'],
        workingDirectory: fw);
    await Process.run('python3', [
      '-c',
      'import serial,time;s=serial.Serial("/dev/ttyACM0");'
          's.setDTR(False);s.setRTS(True);time.sleep(0.2);'
          's.setRTS(False);s.close()',
    ], workingDirectory: fw);
    await Process.run(
        'python3', ['serial_logger.py', 'start', '/dev/ttyACM0'],
        workingDirectory: fw);
    print('  T6 reboot triggered');

    // Confirm it actually went away, then measure recovery on the SAME service.
    var sawDown = false;
    final sw = Stopwatch()..start();
    int? recoveredMs;
    while (sw.elapsed < const Duration(seconds: 120)) {
      final r = await svc.getInfo();
      if (r == null) {
        sawDown = true;
      } else if (sawDown) {
        recoveredMs = sw.elapsedMilliseconds;
        print('  T6 recovered after ${recoveredMs}ms (uptime=${r.uptimeSeconds}s)');
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    print('  T6 sawDown=$sawDown recovered=${recoveredMs != null}');
    expect(sawDown, isTrue, reason: 'reboot should have interrupted the session');
    expect(recoveredMs, isNotNull,
        reason: 'the service must re-establish DTLS after the hub returns');
    svc.dispose();
  }, timeout: const Timeout(Duration(seconds: 240)));
}
