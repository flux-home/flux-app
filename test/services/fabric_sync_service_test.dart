import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/services/fabric_sync_service.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'package:shared_preferences/shared_preferences.dart';

import '../support/matter_fakes.dart' show FakeMatterPort;

/// Local CHIP fabric stub — the app side, master of the fabric id.
class _FakeLocalFabric extends FakeMatterPort {
  _FakeLocalFabric(this.exported, {this.fabricIdHex, this.csr, this.importOk = true});
  final FabricExportData? exported;
  final String? fabricIdHex;

  /// CSR returned by [generateOperationalCsr]; null = adoption unavailable.
  final Uint8List? csr;
  final bool importOk;

  int importCalls = 0;
  FabricImportData? imported;

  @override
  Future<FabricExportData?> exportFabricForController() async => exported;
  @override
  Future<String?> getFabricId() async => fabricIdHex;
  @override
  // FabricSyncService compares the RAW fabric id; tests drive it via fabricIdHex.
  Future<String?> getRawFabricId() async => fabricIdHex;
  @override
  Future<Uint8List?> generateOperationalCsr() async => csr;
  @override
  Future<bool> importControllerFabric(FabricImportData creds) async {
    importCalls++;
    imported = creds;
    return importOk;
  }
}

FabricExportData _creds(int fabricId, {Uint8List? rcac}) => FabricExportData(
      rootCaTlv: Uint8List(0),
      nocTlv: Uint8List(0),
      opPrivKey: Uint8List(0),
      ipk: Uint8List(0),
      fabricId: fabricId,
      rcacPrivKey: rcac,
    );

/// Controller stub — returns a scripted sequence of [getInfo] fabric ids and
/// records provisioning attempts.
class _FakeController extends FluxCoapService {
  _FakeController({required this.infoFabricIds})
      : super(const FluxControllerEndpoint(host: '127.0.0.1', port: 5683));

  /// Fabric ids returned by successive [getInfo] calls. `null` → unreachable.
  final List<int?> infoFabricIds;

  int getInfoCalls = 0;
  // Tracks that the app NEVER seeds (controller-owns-fabric model).
  int provisionCalls = 0;

  @override
  Future<$proto.ControllerInfo?> getInfo() async {
    final v = infoFabricIds[getInfoCalls.clamp(0, infoFabricIds.length - 1)];
    getInfoCalls++;
    if (v == null) return null;
    return $proto.ControllerInfo()..fabricId = Int64(v);
  }

  @override
  Future<$proto.FabricProvisionResult?> provisionFabric({
    required int fabricId,
    required int nodeId,
    required Uint8List rootCaTlv,
    required Uint8List nocTlv,
    required Uint8List opPrivKey,
    required Uint8List ipk,
    Uint8List? icacTlv,
    Uint8List? rcacPrivKey,
    int vendorId = 0,
  }) async {
    provisionCalls++;
    return $proto.FabricProvisionResult()..success = true;
  }

  /// Enrollment behaviour for adoption tests.
  bool enrollOk = true;
  int  enrollCalls = 0;
  Uint8List? enrolledCsr;

  @override
  Future<$proto.FabricEnrollResponse?> enrollFabric({
    required Uint8List csr,
    int nodeId = 0,
  }) async {
    enrollCalls++;
    enrolledCsr = csr;
    if (!enrollOk) {
      return $proto.FabricEnrollResponse()
        ..success = false
        ..error = 'enroll denied';
    }
    return $proto.FabricEnrollResponse()
      ..success = true
      ..rootCaDer = [1, 2, 3]
      ..nocDer = [4, 5, 6]
      ..ipk = [7, 8, 9]
      ..fabricId = Int64(0xABCD)
      ..nodeId = Int64(0x10);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  FabricSyncService svc(MatterFabricPort local, FluxCoapService ctrl) =>
      FabricSyncService(localFabric: local, controller: ctrl);

  // App side: [appHex] is the compressed id the controller reports for the
  // fabric the app is already on. The app never seeds, so there's no payload id.
  _FakeLocalFabric local(String appHex, {Uint8List? csr}) =>
      _FakeLocalFabric(_creds(0x7777), fabricIdHex: appHex, csr: csr);

  test('already on the controller fabric → inSync, no enroll', () async {
    final ctrl = _FakeController(infoFabricIds: [0xABCD]);
    final result = await svc(local('0xABCD'), ctrl).ensureInSync();

    expect(result.status, FabricSyncStatus.inSync);
    expect(result.ok, isTrue);
    expect(ctrl.enrollCalls, 0);
  });

  test('controller has no fabric yet → controllerNotReady, never seeds', () async {
    // Controller self-generates its CA; 0 means "still starting up". The app
    // must NOT push a fabric.
    final ctrl = _FakeController(infoFabricIds: [0]);
    final result = await svc(local('0xABCD'), ctrl).ensureInSync();

    expect(result.status, FabricSyncStatus.controllerNotReady);
    expect(result.ok, isFalse);
    expect(ctrl.provisionCalls, 0);
    expect(ctrl.enrollCalls, 0);
  });

  test('not on the controller fabric, no native CSR → adoptRequired', () async {
    final ctrl = _FakeController(infoFabricIds: [0xABCD]);
    final result = await svc(local('0xDEAD'), ctrl).ensureInSync(); // app on a different fabric, no csr

    expect(result.status, FabricSyncStatus.adoptRequired);
    expect(result.ok, isFalse);
    expect(ctrl.enrollCalls, 0);
  });

  test('not on the controller fabric, enrollment available → enrolls + imports → adopted', () async {
    final ctrl = _FakeController(infoFabricIds: [0xABCD]);
    final fab = _FakeLocalFabric(_creds(0x7777),
        fabricIdHex: '0xDEAD', csr: Uint8List.fromList([0xC5, 0x12]));
    final result = await svc(fab, ctrl).ensureInSync();

    expect(result.status, FabricSyncStatus.adopted);
    expect(result.ok, isTrue);
    expect(ctrl.provisionCalls, 0); // app never pushes a fabric
    expect(ctrl.enrollCalls, 1);
    expect(ctrl.enrolledCsr, Uint8List.fromList([0xC5, 0x12]));
    // imported the controller-issued identity (node 0x10, fabric 0xABCD).
    expect(fab.importCalls, 1);
    expect(fab.imported!.nodeId, 0x10);
    expect(fab.imported!.fabricId, 0xABCD);
  });

  test('app has no identity yet → enrolls to join the controller fabric', () async {
    final ctrl = _FakeController(infoFabricIds: [0xABCD]);
    // fabricIdHex null = app has no operational identity at all.
    final fab = _FakeLocalFabric(_creds(0x7777),
        fabricIdHex: null, csr: Uint8List.fromList([0xC5]));
    final result = await svc(fab, ctrl).ensureInSync();

    expect(result.status, FabricSyncStatus.adopted);
    expect(ctrl.enrollCalls, 1);
    expect(fab.importCalls, 1);
  });

  test('enrollment rejected → failed, no import', () async {
    final ctrl = _FakeController(infoFabricIds: [0xABCD])..enrollOk = false;
    final fab = _FakeLocalFabric(_creds(0x7777),
        fabricIdHex: '0xDEAD', csr: Uint8List.fromList([0xC5]));
    final result = await svc(fab, ctrl).ensureInSync();

    expect(result.status, FabricSyncStatus.failed);
    expect(ctrl.enrollCalls, 1);
    expect(fab.importCalls, 0);
  });

  test('import fails → failed', () async {
    final ctrl = _FakeController(infoFabricIds: [0xABCD]);
    final fab = _FakeLocalFabric(_creds(0x7777),
        fabricIdHex: '0xDEAD', csr: Uint8List.fromList([0xC5]), importOk: false);
    final result = await svc(fab, ctrl).ensureInSync();

    expect(result.status, FabricSyncStatus.failed);
    expect(fab.importCalls, 1);
  });

  test('controller unreachable → unreachable', () async {
    final ctrl = _FakeController(infoFabricIds: [null]);
    final result = await svc(local('0xABCD'), ctrl).ensureInSync();

    expect(result.status, FabricSyncStatus.unreachable);
    expect(ctrl.provisionCalls, 0);
  });

  group('readState (read-only classification)', () {
    test('matching ids → inSync, never provisions', () async {
      final ctrl = _FakeController(infoFabricIds: [0x1234]);
      final local = _FakeLocalFabric(_creds(0x1234), fabricIdHex: '0x1234');
      expect(await svc(local, ctrl).readState(), FabricState.inSync);
      expect(ctrl.provisionCalls, 0);
    });

    test('controller on a different fabric → needsAdopt', () async {
      final ctrl = _FakeController(infoFabricIds: [0xDEAD]);
      final local = _FakeLocalFabric(_creds(0xBEEF), fabricIdHex: 'BEEF');
      expect(await svc(local, ctrl).readState(), FabricState.needsAdopt);
      expect(ctrl.provisionCalls, 0);
    });

    test('app has no identity but controller has a fabric → needsAdopt', () async {
      final ctrl = _FakeController(infoFabricIds: [0xABCD]);
      final local = _FakeLocalFabric(_creds(0xBEEF), fabricIdHex: null);
      expect(await svc(local, ctrl).readState(), FabricState.needsAdopt);
    });

    test('formatting differences (0x, case, leading zeros) still match', () async {
      final ctrl = _FakeController(infoFabricIds: [0x00ABCD]);
      final local = _FakeLocalFabric(_creds(0xABCD), fabricIdHex: '0X0000ABCD');
      expect(await svc(local, ctrl).readState(), FabricState.inSync);
    });

    test('controller has no fabric (0) → controllerNotReady', () async {
      final ctrl = _FakeController(infoFabricIds: [0]);
      final local = _FakeLocalFabric(_creds(0xBEEF), fabricIdHex: 'BEEF');
      expect(await svc(local, ctrl).readState(), FabricState.controllerNotReady);
    });

    test('controller unreachable → unknown (do not alarm)', () async {
      final ctrl = _FakeController(infoFabricIds: [null]);
      final local = _FakeLocalFabric(_creds(0x1234), fabricIdHex: '1234');
      expect(await svc(local, ctrl).readState(), FabricState.unknown);
    });
  });
}
