import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/matter_port.dart';

/// Read-only classification of the controller's fabric relative to the app.
enum FabricState {
  /// App already holds an operational identity on the controller's fabric.
  inSync,

  /// Controller owns a fabric the app is not yet on — the app should enroll
  /// (adopt) to join it.
  needsAdopt,

  /// Controller has no fabric yet (fabricId == 0).  The controller is the CA
  /// and self-generates its fabric on first boot, so this is a transient
  /// "still starting up" state — the app must NOT push a fabric.
  controllerNotReady,

  /// CHIP SDK not ready or controller unreachable — answer unknown.
  unknown,
}

/// Outcome of [FabricSyncService.ensureInSync].
enum FabricSyncStatus {
  /// App already held an operational identity on the controller's fabric.
  inSync,

  /// App joined the controller's fabric by enrolling (controller-issued NOC)
  /// and importing that identity.
  adopted,

  /// The app could not join (native adoption unavailable, or enrollment
  /// failed) — controller left untouched.
  adoptRequired,

  /// The local CHIP SDK is not ready (can't read the app fabric / make a CSR).
  notReady,

  /// Controller has no fabric yet (still initializing as the CA).
  controllerNotReady,

  /// The controller could not be reached / read.
  unreachable,

  /// Enrollment or import failed.
  failed,
}

@immutable
class FabricSyncResult {
  const FabricSyncResult(this.status, {this.message});

  final FabricSyncStatus status;
  final String?          message;

  /// True when the app and controller are guaranteed to share a fabric.
  bool get ok =>
      status == FabricSyncStatus.inSync || status == FabricSyncStatus.adopted;
}

/// Joins the app to the Flux controller's Matter fabric.
///
/// The **controller owns the fabric**: it self-generates its root CA + fabric
/// on first boot and acts as the Certificate Authority.  The app never seeds a
/// fabric — it always *enrolls* (sends a CSR, the controller signs it) and
/// imports the issued operational identity.  This is what makes multiple phones
/// safe: every phone joins the one controller-owned fabric instead of running
/// its own.  See docs/multi-phone-fabric.md.
class FabricSyncService {
  FabricSyncService({required this.localFabric, required this.controller});

  /// Local CHIP SDK — holds the app's operational identity.
  final MatterFabricPort localFabric;

  /// CoAP client for the controller being synced.
  final FluxCoapService controller;

  /// Read-only classification of the controller's fabric vs. the app's, with no
  /// side effects — safe to call on screen load / connect.  Callers should
  /// treat [FabricState.unknown] as "don't alarm the user".
  Future<FabricState> readState() async {
    final appNorm = await _appFabricId();

    final info = await controller.getInfo();
    if (info == null) return FabricState.unknown;

    if (info.fabricId.toInt() == 0) return FabricState.controllerNotReady;
    final ctrlNorm = _normalizeHex(info.fabricId.toHexString());
    debugPrint('FabricSync.readState: app=0x${appNorm ?? "?"} '
        'controller=0x${ctrlNorm ?? "?"} '
        '→ ${appNorm != null && appNorm == ctrlNorm ? "inSync" : "needsAdopt"}');
    if (appNorm == null) return FabricState.needsAdopt; // app has no identity yet
    return ctrlNorm == appNorm ? FabricState.inSync : FabricState.needsAdopt;
  }

  /// The app's operational **raw** fabric id (normalised hex).  The controller
  /// reports this same raw value in `/info.fabric_id`, so membership is a
  /// raw-vs-raw comparison.  (NOT the compressed id from [getFabricId] — the
  /// controller's `/info` exposes the raw fabric id it generated at first boot.)
  /// Returns null when the CHIP SDK is not ready.
  Future<String?> _appFabricId() async {
    final hex = await localFabric.getRawFabricId();
    return hex == null ? null : _normalizeHex(hex);
  }

  /// Lower-cases, strips a `0x` prefix and leading zeros so fabric ids from
  /// different sources compare equal regardless of formatting.  Returns null
  /// for non-hex input.
  static String? _normalizeHex(String hex) {
    var s = hex.trim().toLowerCase();
    if (s.startsWith('0x')) s = s.substring(2);
    s = s.replaceFirst(RegExp(r'^0+'), '');
    if (s.isEmpty) return '0';
    return RegExp(r'^[0-9a-f]+$').hasMatch(s) ? s : null;
  }

  /// Ensures the app holds an operational identity on the controller's fabric.
  ///
  /// The controller owns the fabric, so the app never seeds:
  ///  - already on the controller's fabric → [FabricSyncStatus.inSync]
  ///  - controller has a fabric we're not on → join it by enrolling →
  ///    [FabricSyncStatus.adopted] (or [FabricSyncStatus.adoptRequired] if the
  ///    platform can't enroll yet)
  ///  - controller has no fabric yet → [FabricSyncStatus.controllerNotReady]
  ///
  /// [log] receives human-readable progress lines (optional).
  Future<FabricSyncResult> ensureInSync({void Function(String)? log}) async {
    final info = await controller.getInfo();
    if (info == null) {
      return const FabricSyncResult(FabricSyncStatus.unreachable,
          message: 'controller unreachable');
    }
    if (info.fabricId.toInt() == 0) {
      return const FabricSyncResult(FabricSyncStatus.controllerNotReady,
          message: 'controller is still starting up');
    }

    final appNorm = await _appFabricId();
    if (appNorm != null &&
        _normalizeHex(info.fabricId.toHexString()) == appNorm) {
      log?.call('Already on the controller\'s fabric (0x$appNorm)');
      return const FabricSyncResult(FabricSyncStatus.inSync);
    }

    // Not on the controller's fabric (or the app has no identity yet) → join
    // it: enroll (the controller signs our CSR) and import the issued identity.
    return _adopt(log: log);
  }

  /// Joins the controller's fabric: generate a CSR, have the controller (the
  /// CA) sign it via `/fabric/enroll`, then import the issued identity into the
  /// local CHIP controller.
  ///
  /// Falls back to [FabricSyncStatus.adoptRequired] when the platform can't
  /// produce a CSR yet (native enrollment not implemented).
  Future<FabricSyncResult> _adopt({void Function(String)? log}) async {
    final csr = await localFabric.generateOperationalCsr();
    if (csr == null) {
      log?.call('Controller owns a different fabric — adoption unavailable '
          'on this device');
      return const FabricSyncResult(FabricSyncStatus.adoptRequired,
          message: 'hub already set up with a different identity');
    }

    log?.call('Enrolling on the controller\'s fabric…');
    final enroll = await controller.enrollFabric(csr: csr);
    if (enroll == null || !enroll.success) {
      return FabricSyncResult(FabricSyncStatus.failed,
          message: enroll?.error.isNotEmpty == true
              ? enroll!.error
              : 'controller did not issue an identity');
    }

    final icac = enroll.icacDer;
    final ok = await localFabric.importControllerFabric(FabricImportData(
      rootCaTlv: Uint8List.fromList(enroll.rootCaDer),
      icacTlv:   icac.isEmpty ? null : Uint8List.fromList(icac),
      nocTlv:    Uint8List.fromList(enroll.nocDer),
      ipk:       Uint8List.fromList(enroll.ipk),
      fabricId:  enroll.fabricId.toInt(),
      nodeId:    enroll.nodeId.toInt(),
    ));
    if (!ok) {
      return const FabricSyncResult(FabricSyncStatus.failed,
          message: 'failed to import the controller-issued identity');
    }

    final hostname = controller.endpoint.dtlsIdentity ?? controller.endpoint.host;
    await ControllerSettings.saveProvisionedFlag(hostname);
    log?.call('Joined the controller\'s fabric (node 0x${enroll.nodeId.toInt().toRadixString(16)})');
    return const FabricSyncResult(FabricSyncStatus.adopted);
  }
}
