import 'dart:typed_data';

import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/thread_settings_service.dart';

/// Outcome of [ThreadSyncService.ensureInSync].
enum ThreadSyncStatus {
  /// Controller already runs the app's active Thread network — nothing to do.
  inSync,

  /// Controller already had a Thread network; the app adopted it as its active
  /// dataset so commissioned devices join the controller's mesh.
  adopted,

  /// Controller had no Thread network; the app pushed its active dataset.
  pushed,

  /// Controller had no Thread network and the app has none to push.
  nothingToDo,

  /// The controller could not be reached / read, or the push failed.
  unreachable,
}

class ThreadSyncResult {
  const ThreadSyncResult(this.status, {this.message});
  final ThreadSyncStatus status;
  final String?          message;
}

/// Keeps the app and the Flux controller on a single Thread network, with the
/// **controller as the source of truth**:
///
///  - controller has a Thread dataset → the app adopts it as its active dataset
///    (so every phone's commissioned devices join the controller's mesh);
///  - controller has none → the app pushes its own active dataset to seed it.
///
/// All operations use the existing CoAP endpoints, so this is purely
/// app-side logic.
class ThreadSyncService {
  ThreadSyncService(this.controller);

  final FluxCoapService controller;

  /// Reconciles the controller's Thread network with the app's active dataset.
  Future<ThreadSyncResult> ensureInSync({void Function(String)? log}) async {
    // getThreadDataset returns null only on a transport error; a reachable
    // controller with no network returns a non-null dataset with empty tlv.
    final ds = await controller.getThreadDataset();
    if (ds == null) {
      return const ThreadSyncResult(ThreadSyncStatus.unreachable,
          message: 'controller unreachable');
    }

    final controllerHex = _bytesToHex(ds.tlv);
    final active        = await ThreadSettingsService.loadActive();
    final appHex        = (active == null || active.isEmpty)
        ? ''
        : _normalize(active.hex);

    if (controllerHex.isNotEmpty) {
      // Controller owns a network.
      if (controllerHex == appHex) {
        log?.call('Controller Thread network already active');
        return const ThreadSyncResult(ThreadSyncStatus.inSync);
      }
      // Adopt the controller's network as the app's active dataset.
      await ThreadSettingsService.save(controllerHex);
      log?.call('Adopted controller Thread network '
          '(${ThreadTlvDecoder.networkName(controllerHex) ?? 'unnamed'})');
      return const ThreadSyncResult(ThreadSyncStatus.adopted);
    }

    // Controller has no Thread network — push the app's active dataset.
    if (appHex.isEmpty) {
      return const ThreadSyncResult(ThreadSyncStatus.nothingToDo,
          message: 'no Thread network on controller or app');
    }

    final ok = await controller.postThreadDataset(_hexToBytes(appHex));
    if (!ok) {
      return const ThreadSyncResult(ThreadSyncStatus.unreachable,
          message: 'failed to push Thread dataset');
    }
    log?.call('Pushed app Thread network to controller');
    return const ThreadSyncResult(ThreadSyncStatus.pushed);
  }

  static String _normalize(String hex) =>
      hex.replaceAll(RegExp(r'\s'), '').toLowerCase();

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s'), '');
    return Uint8List.fromList(List.generate(
        clean.length ~/ 2,
        (i) => int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16)));
  }
}
