import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/services/thread_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller stub: [controllerTlv] null → unreachable, empty → no network,
/// bytes → has a Thread network.  Records pushes.
class _FakeThreadController extends FluxCoapService {
  _FakeThreadController()
      : super(const FluxControllerEndpoint(host: '127.0.0.1', port: 5683));

  List<int>? controllerTlv;
  bool postOk = true;

  int postCalls = 0;
  Uint8List? pushed;

  @override
  Future<$proto.ThreadDataset?> getThreadDataset() async =>
      controllerTlv == null ? null : ($proto.ThreadDataset()..tlv = controllerTlv!);

  @override
  Future<bool> postThreadDataset(Uint8List tlv) async {
    postCalls++;
    pushed = tlv;
    return postOk;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('controller has a network, app has none → adopts it', () async {
    final ctrl = _FakeThreadController()..controllerTlv = [0xaa, 0xbb, 0xcc];
    final result = await ThreadSyncService(ctrl).ensureInSync();

    expect(result.status, ThreadSyncStatus.adopted);
    expect(ctrl.postCalls, 0); // never push when controller already has one
    // Controller's network is now the app's active dataset.
    expect(await ThreadSettingsService.load(), 'aabbcc');
  });

  test('controller network already matches app → inSync, no push', () async {
    await ThreadSettingsService.save('AABBCC');
    final ctrl = _FakeThreadController()..controllerTlv = [0xaa, 0xbb, 0xcc];
    final result = await ThreadSyncService(ctrl).ensureInSync();

    expect(result.status, ThreadSyncStatus.inSync);
    expect(ctrl.postCalls, 0);
  });

  test('controller has no network, app has one → pushes it', () async {
    await ThreadSettingsService.save('AABBCC');
    final ctrl = _FakeThreadController()..controllerTlv = const [];
    final result = await ThreadSyncService(ctrl).ensureInSync();

    expect(result.status, ThreadSyncStatus.pushed);
    expect(ctrl.postCalls, 1);
    expect(ctrl.pushed, Uint8List.fromList([0xaa, 0xbb, 0xcc]));
  });

  test('neither side has a network → nothingToDo', () async {
    final ctrl = _FakeThreadController()..controllerTlv = const [];
    final result = await ThreadSyncService(ctrl).ensureInSync();

    expect(result.status, ThreadSyncStatus.nothingToDo);
    expect(ctrl.postCalls, 0);
  });

  test('controller unreachable → unreachable, no push', () async {
    await ThreadSettingsService.save('AABBCC');
    final ctrl = _FakeThreadController()..controllerTlv = null;
    final result = await ThreadSyncService(ctrl).ensureInSync();

    expect(result.status, ThreadSyncStatus.unreachable);
    expect(ctrl.postCalls, 0);
  });

  test('push failure → unreachable', () async {
    await ThreadSettingsService.save('AABBCC');
    final ctrl = _FakeThreadController()
      ..controllerTlv = const []
      ..postOk = false;
    final result = await ThreadSyncService(ctrl).ensureInSync();

    expect(result.status, ThreadSyncStatus.unreachable);
    expect(ctrl.postCalls, 1);
  });
}
