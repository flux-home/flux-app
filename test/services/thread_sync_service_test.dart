import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/services/thread_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller stub: [controllerTlv] null → unreachable, empty → no network,
/// bytes → has a Thread network.
///
/// Note there is deliberately no push hook to fake: the app can no longer send
/// a dataset to the controller at all (FluxCoapService has no postThreadDataset),
/// so "the app never pushes" is guaranteed by construction, not by assertion.
class _FakeThreadController extends FluxCoapService {
  _FakeThreadController()
      : super(const FluxControllerEndpoint(host: '127.0.0.1', port: 5683));

  List<int>? controllerTlv;

  @override
  Future<$proto.ThreadDataset?> getThreadDataset() async =>
      controllerTlv == null ? null : ($proto.ThreadDataset()..tlv = controllerTlv!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('controller has a network, app has none → adopts it', () async {
    final ctrl = _FakeThreadController()..controllerTlv = [0xaa, 0xbb, 0xcc];
    final result = await ThreadSyncService(ctrl).ensureInSync();

    expect(result.status, ThreadSyncStatus.adopted);
    // Controller's network is now the app's active dataset.
    expect(await ThreadSettingsService.load(), 'aabbcc');
  });

  test('controller network differs from app → adopts controller (it wins)', () async {
    await ThreadSettingsService.save('DEADBEEF');
    final ctrl = _FakeThreadController()..controllerTlv = [0xaa, 0xbb, 0xcc];
    final result = await ThreadSyncService(ctrl).ensureInSync();

    expect(result.status, ThreadSyncStatus.adopted);
    // The app's own dataset is overwritten — the controller is source of truth.
    expect(await ThreadSettingsService.load(), 'aabbcc');
  });

  test('controller network already matches app → inSync', () async {
    await ThreadSettingsService.save('AABBCC');
    final ctrl = _FakeThreadController()..controllerTlv = [0xaa, 0xbb, 0xcc];
    final result = await ThreadSyncService(ctrl).ensureInSync();

    expect(result.status, ThreadSyncStatus.inSync);
  });

  test('controller has no network → nothingToDo, app dataset left alone', () async {
    await ThreadSettingsService.save('AABBCC');
    final ctrl = _FakeThreadController()..controllerTlv = const [];
    final result = await ThreadSyncService(ctrl).ensureInSync();

    // Previously this pushed the app's dataset to seed the controller; the app
    // must never do that now.
    expect(result.status, ThreadSyncStatus.nothingToDo);
    expect(await ThreadSettingsService.load(), 'AABBCC');
  });

  test('controller unreachable → unreachable', () async {
    await ThreadSettingsService.save('AABBCC');
    final ctrl = _FakeThreadController()..controllerTlv = null;
    final result = await ThreadSyncService(ctrl).ensureInSync();

    expect(result.status, ThreadSyncStatus.unreachable);
  });
}
