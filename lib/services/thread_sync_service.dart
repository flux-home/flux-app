import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/thread_settings_service.dart';

/// Outcome of [ThreadSyncService.ensureInSync].
enum ThreadSyncStatus {
  /// Controller already runs the app's active Thread network — nothing to do.
  inSync,

  /// The app adopted the controller's Thread network as its active dataset so
  /// commissioned devices join the controller's mesh.
  adopted,

  /// The controller runs no Thread network — nothing for the app to adopt.
  nothingToDo,

  /// The controller could not be reached / read.
  unreachable,
}

class ThreadSyncResult {
  const ThreadSyncResult(this.status, {this.message});
  final ThreadSyncStatus status;
  final String?          message;
}

/// Adopts the Flux controller's Thread network so the app and the controller
/// are always on a single mesh, with the **controller as the sole source of
/// truth**.
///
/// This is deliberately one-way: the app only ever *reads* the controller's
/// network and mirrors it locally.  It never pushes a phone-held dataset to the
/// controller — the controller owns its mesh (it is the border router), and a
/// phone seeding it would let a stale local dataset override live hardware.
/// Devices are joined to an existing foreign network through the controller's
/// own Thread credential-sharing flow (`POST /thread/join`) instead.
class ThreadSyncService {
  ThreadSyncService(this.controller);

  final FluxCoapService controller;

  /// Mirrors the controller's Thread network into the app's active dataset.
  Future<ThreadSyncResult> ensureInSync({void Function(String)? log}) async {
    // getThreadDataset returns null only on a transport error; a reachable
    // controller with no network returns a non-null dataset with empty tlv.
    final ds = await controller.getThreadDataset();
    if (ds == null) {
      return const ThreadSyncResult(ThreadSyncStatus.unreachable,
          message: 'controller unreachable');
    }

    final controllerHex = _bytesToHex(ds.tlv);
    if (controllerHex.isEmpty) {
      return const ThreadSyncResult(ThreadSyncStatus.nothingToDo,
          message: 'controller runs no Thread network');
    }

    final active = await ThreadSettingsService.loadActive();
    final appHex = (active == null || active.isEmpty) ? '' : _normalize(active.hex);
    if (controllerHex == appHex) {
      log?.call('Controller Thread network already active');
      return const ThreadSyncResult(ThreadSyncStatus.inSync);
    }

    await ThreadSettingsService.save(controllerHex);
    log?.call('Adopted controller Thread network '
        '(${ThreadTlvDecoder.networkName(controllerHex) ?? 'unnamed'})');
    return const ThreadSyncResult(ThreadSyncStatus.adopted);
  }

  static String _normalize(String hex) =>
      hex.replaceAll(RegExp(r'\s'), '').toLowerCase();

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
