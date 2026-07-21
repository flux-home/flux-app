import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/cupertino.dart' show BuildContext;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/widgets.dart' show BuildContext;

import 'package:matter_home/models/commission_models.dart';
import 'package:matter_home/models/fabric_descriptor.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/services/qr_payload_service.dart';

// ── Public enums ──────────────────────────────────────────────────────────────

enum CommissionMethod { ble, ip }

enum CommissionPhase { idle, parsing, parsed, running, done, failed }

// ── Data classes ──────────────────────────────────────────────────────────────

class CommissionConfig {
  const CommissionConfig({
    required this.method,
    this.netType = 1,
    this.threadDatasetHex = '',
    this.wifiSsid = '',
    this.wifiPassword = '',
    this.ipAddress = '',
    this.discriminator = 3840,
    this.setupPinCode = 20202021,
  });
  final CommissionMethod method;
  final int netType; // 0 = Thread, 1 = Wi-Fi, 2 = None
  final String threadDatasetHex;
  final String wifiSsid;
  final String wifiPassword;
  final String ipAddress;
  final int discriminator;
  final int setupPinCode;

  CommissionConfig copyWith({
    CommissionMethod? method,
    int? netType,
    String? threadDatasetHex,
    String? wifiSsid,
    String? wifiPassword,
    String? ipAddress,
    int? discriminator,
    int? setupPinCode,
  }) => CommissionConfig(
    method: method ?? this.method,
    netType: netType ?? this.netType,
    threadDatasetHex: threadDatasetHex ?? this.threadDatasetHex,
    wifiSsid: wifiSsid ?? this.wifiSsid,
    wifiPassword: wifiPassword ?? this.wifiPassword,
    ipAddress: ipAddress ?? this.ipAddress,
    discriminator: discriminator ?? this.discriminator,
    setupPinCode: setupPinCode ?? this.setupPinCode,
  );
}

/// Credentials returned by the [CommissioningController.onNeedsCredentials]
/// callback.  Return null to cancel credential provision (BLE pre-collection
/// aborts commissioning; CREDENTIALS_NEEDED calls provideCredentials with
/// no args so the SDK fails gracefully).
class CommissionCredentials {
  const CommissionCredentials({this.wifiSsid, this.wifiPassword, this.threadDatasetHex});

  const CommissionCredentials.wifi(String ssid, String pass)
    : wifiSsid = ssid,
      wifiPassword = pass,
      threadDatasetHex = null;

  const CommissionCredentials.thread(String hex) : wifiSsid = null, wifiPassword = null, threadDatasetHex = hex;
  final String? wifiSsid;
  final String? wifiPassword;
  final String? threadDatasetHex;
}

// ── Log types (public - consumed by the progress widgets) ─────────────────────

enum LogLevel { step, info, success, error }

class LogEntry {
  const LogEntry({required this.message, required this.level});
  final String message;
  final LogLevel level;
}

class HumanEntry {
  const HumanEntry({required this.text, this.color});
  final String text;
  final Color? color;
}

// ── Stage constants (public - consumed by _buildProgressTrack) ────────────────

const List<String> kCommissionStages = [
  'ReadCommissioningInfo',
  'ArmFailSafe',
  'ConfigRegulatory',
  'ConfigureTCAcknowledgments',
  'ConfigureUTCTime',
  'ScanNetworks',
  'NeedsNetworkCreds',
  'RequestWiFiCredentials',
  'RequestThreadCredentials',
  'SendPAICertificateRequest',
  'SendDACCertificateRequest',
  'SendAttestationRequest',
  'AttestationVerification',
  'AttestationRevocationCheck',
  'SendOpCertSigningRequest',
  'ValidateCSR',
  'GenerateNOCChain',
  'SendTrustedRootCert',
  'SendNOC',
  'WiFiNetworkSetup',
  'WiFiNetworkEnable',
  'ThreadNetworkSetup',
  'ThreadNetworkEnable',
  'PrimaryOperationalNetworkFailed',
  'RemoveWiFiNetworkConfig',
  'RemoveThreadNetworkConfig',
  'EvictPreviousCaseSessions',
  'FindOperationalForStayActive',
  'ICDSendStayActive',
  'FindOperationalForCommissioningComplete',
  'SendComplete',
  'Cleanup',
];

const Map<String, String> kCommissionStageHuman = {
  'ReadCommissioningInfo': 'READ DEVICE INFO',
  'ArmFailSafe': 'SET TIMEOUT',
  'ConfigRegulatory': 'SET REGIONAL SETTINGS',
  'ConfigureTCAcknowledgments': 'TERMS AND CONDITIONS',
  'ConfigureUTCTime': 'SYNC TIME/CLOCK',
  'ScanNetworks': 'SCAN NETWORKS',
  'NeedsNetworkCreds': 'NEED CREDENTIALS',
  'RequestWiFiCredentials': 'REQUEST WIFI CREDS',
  'RequestThreadCredentials': 'REQUEST THREAD CREDS',
  'SendPAICertificateRequest': 'REQUEST PAI CERTIFICATE',
  'SendDACCertificateRequest': 'REQUEST DAC CERTIFICATE',
  'SendAttestationRequest': 'SEND VERIFICATION',
  'AttestationVerification': 'DEVICE VERIFICATION',
  'AttestationRevocationCheck': 'DCL SECURITY CHECK',
  'SendOpCertSigningRequest': 'KEY REQUEST',
  'ValidateCSR': 'ID CHECK',
  'GenerateNOCChain': 'ASSIGN NETWORK ID',
  'SendTrustedRootCert': 'ALLOW ACCESS',
  'SendNOC': 'INSTALL ID',
  'WiFiNetworkSetup': 'WIFI NETWORK SETUP',
  'WiFiNetworkEnable': 'ENABLE WIFI',
  'ThreadNetworkSetup': 'THREAD NETWORK SETUP',
  'ThreadNetworkEnable': 'ENABLE THREAD',
  'PrimaryOperationalNetworkFailed': 'NETWORK FAILED',
  'RemoveWiFiNetworkConfig': 'REMOVE WIFI CONFIG',
  'RemoveThreadNetworkConfig': 'REMOVE THREAD CONFIG',
  'EvictPreviousCaseSessions': 'CLEAR CONNECTION',
  'FindOperationalForStayActive': 'LOOKING FOR DEVICE ON NETWORK',
  'ICDSendStayActive': 'WAKING',
  'FindOperationalForCommissioningComplete': 'CHECK ID',
  'SendComplete': 'FINALIZING',
  'Cleanup': 'DONE',
};

// ── CommissioningController ────────────────────────────────────────────────────

/// Owns all commissioning flow logic: payload parsing, BLE permission checks,
/// event-stream subscription, the CREDENTIALS_NEEDED handshake, human-readable
/// log mapping, device name generation, and QR payload persistence.
///
/// The widget keeps only UI-only state (mode toggle, form controllers) and
/// injects two callbacks so the controller never touches [BuildContext]:
///   - [requestBlePermissions] - shows OS dialogs, returns true if granted
///   - [onNeedsCredentials]    - shows credential sheet, returns creds or null
class CommissioningController extends ChangeNotifier {
  CommissioningController({
    required MatterCommissionPort port,
    required DeviceProvider provider,
    required this.requestBlePermissions,
    required this.onNeedsCredentials,
    this.threadDataset = _returnEmpty,
    this.controllerService,
  }) : _port = port,
       _provider = provider;

  final MatterCommissionPort _port;
  final DeviceProvider _provider;

  /// The connected Flux hub's CoAP client.  Commissioning requires it: the
  /// device is handed off to the controller (`POST /commission`), which
  /// commissions it onto its own fabric.  Null when no hub is connected — in
  /// which case [start] fails fast (there is no standalone commissioning).
  final FluxCoapService? controllerService;

  final Future<bool> Function() requestBlePermissions;
  /// Called when the device needs credentials during commissioning.
  /// [isThread] is true when the device is a Thread device, false for WiFi.
  final Future<CommissionCredentials?> Function(bool isThread) onNeedsCredentials;
  final String Function() threadDataset;

  // ── Public state ──────────────────────────────────────────────────────────

  CommissionPhase phase = CommissionPhase.idle;
  ParsedPayload? parsed;
  String? parseError;
  bool parsing = false;
  String? rawPayload;
  List<LogEntry> rawLog = const [];
  List<HumanEntry> humanLog = const [];
  int stageIdx = -1;
  MatterDevice? result;
  String? error;

  // ── Private ───────────────────────────────────────────────────────────────

  StreamSubscription<String>? _eventSub;

  /// Monotonically-increasing session counter.  When reset() or a new start()
  /// is called, any in-flight start() from a previous session detects the
  /// mismatch and discards its result.
  int _sessionId = 0;

  static String _returnEmpty() => '';

  // ── setPayload ────────────────────────────────────────────────────────────

  /// Parses [raw] and updates [parsed] / [parseError] / [phase].
  /// After this returns the caller should read those fields and decide whether
  /// to call [start].  Auto-starting from inside the controller is intentionally
  /// not supported - the widget has the authoritative thread-selected state
  /// needed to pick the correct network type.
  Future<void> setPayload(String raw) async {
    rawPayload = raw;
    parsed = null;
    parseError = null;
    parsing = true;
    phase = CommissionPhase.parsing;
    notifyListeners();

    final p = await _port.parsePayload(raw);

    if (p == null) {
      parsing = false;
      parseError = 'Could not parse payload';
      phase = CommissionPhase.idle;
      notifyListeners();
      return;
    }

    parsing = false;
    parsed = p;
    phase = CommissionPhase.parsed;
    notifyListeners();

    debugPrint(
      '🔍 parsed payload: caps=${p.discoveryCapabilities} '
      'prefersBle=${p.prefersBle} hasOnNetwork=${p.hasOnNetwork} '
      'capabilitiesUnknown=${p.capabilitiesUnknown} '
      '→ method=${suggestMethod(p)} netType=${suggestNetType(p, threadDataset: threadDataset())}',
    );

    await QrPayloadService.save(raw);
  }

  // ── start ─────────────────────────────────────────────────────────────────

  /// Runs the full commissioning flow for the currently parsed payload.
  ///
  /// Returns normally once commissioning has either succeeded ([phase] == done)
  /// or failed ([phase] == failed).  After the call the widget should navigate
  /// on success or display the failure footer.
  Future<void> start(CommissionConfig config) async {
    if (rawPayload == null || parsed == null) return;

    // Commission-then-handoff requires a hub: the device is commissioned onto a
    // throwaway phone fabric, then handed to the controller.  Without a hub
    // there is nothing to hand off to, so fail fast (no standalone path).
    if (controllerService == null) {
      error = 'No Flux controller connected — connect a controller before adding devices';
      phase = CommissionPhase.failed;
      notifyListeners();
      return;
    }

    if (config.method == CommissionMethod.ble) {
      if (!await requestBlePermissions()) return;
    }

    final sessionId = ++_sessionId;

    rawLog = const [];
    humanLog = const [];
    stageIdx = -1;
    result = null;
    error = null;
    phase = CommissionPhase.running;
    notifyListeners();

    final name = _generateName(_provider.devices.map((d) => d.name).toList());
    _appendRaw('Commissioning "$name"...', level: LogLevel.step);

    _eventSub = _port.commissionEvents.listen(_onEvent);

    // Pre-collect Wi-Fi credentials for BLE+WiFi when SSID is not filled in.
    // Only fires when the user has explicitly selected WiFi (netType 1) - for
    // unknown/auto-detect (netType 2) we let onReadCommissioningInfo decide.
    var cfg = config;
    if (config.method == CommissionMethod.ble &&
        config.netType == 1 &&
        config.wifiSsid.isEmpty) {
      final creds = await onNeedsCredentials(false); // false = WiFi
      if (sessionId != _sessionId) return; // cancelled while awaiting
      if (creds == null) {
        await _eventSub?.cancel();
        _eventSub = null;
        rawLog = const [];
        humanLog = const [];
        phase = CommissionPhase.idle;
        notifyListeners();
        return;
      }
      cfg = config.copyWith(
        wifiSsid: creds.wifiSsid ?? '',
        wifiPassword: creds.wifiPassword ?? '',
        threadDatasetHex: creds.threadDatasetHex ?? '',
      );
    }

    NetworkType networkType = NetworkType.ethernet;
    CommissionResult commissionResult;

    _provider.beginCommissioning();

    if (cfg.method == CommissionMethod.ble) {
      // ── BLE commissioning (phone always commissions) ──────────────────────
      networkType = switch (cfg.netType) {
        0 => NetworkType.thread,
        1 => NetworkType.wifi,
        _ => NetworkType.ethernet,
      };

      // Resolve which Thread network to commission onto.  Precedence:
      //   1. an explicit dataset chosen for THIS commission (expert mode),
      //   2. the HUB's Thread network — the hub owns it, so devices must join
      //      its mesh to be reachable by the controller and every phone,
      //   3. the app's locally-configured active dataset (standalone fallback).
      var threadHex = cfg.threadDatasetHex.replaceAll(RegExp(r'\s'), '');

      if (threadHex.isEmpty && controllerService != null && cfg.netType == 0) {
        _appendRaw('▶ Using the controller\'s Thread network…', level: LogLevel.step);
        final fetched = await controllerService!.getThreadDatasetHex();
        if (fetched != null && fetched.isNotEmpty) {
          threadHex = fetched;
          _appendRaw('✓ Controller Thread network (${fetched.length ~/ 2} bytes)',
              level: LogLevel.success);
        } else {
          _appendRaw('⚠ Controller has no Thread network — using app dataset if set',
              level: LogLevel.info);
        }
      }

      // Fallback: the app's own active dataset (e.g. standalone / hub has none).
      if (threadHex.isEmpty && cfg.netType == 0) {
        threadHex = threadDataset().replaceAll(RegExp(r'\s'), '');
      }

      _appendRaw('▶ Connecting to device via Bluetooth…', level: LogLevel.step);
      commissionResult = switch (cfg.netType) {
        0 => await _port.commissionDevice(rawPayload!, threadDatasetHex: threadHex),
        1 => await _port.commissionDevice(rawPayload!,
                wifiSsid: cfg.wifiSsid, wifiPassword: cfg.wifiPassword),
        _ => await _port.commissionDevice(rawPayload!),
      };
    } else {
      // ── IP / on-network commissioning ─────────────────────────────────────
      networkType = NetworkType.ethernet;
      if (cfg.ipAddress.trim().isEmpty) {
        _appendRaw('🔍 No IP address — using DNS-SD on-network discovery…',
            level: LogLevel.info);
        commissionResult = await _port.commissionViaCode(setupCode: rawPayload!);
      } else {
        commissionResult = await _port.commissionViaIp(
          ipAddress: cfg.ipAddress,
          discriminator: cfg.discriminator > 0
              ? cfg.discriminator
              : (parsed!.discriminator > 0 ? parsed!.discriminator : 3840),
          setupPinCode: cfg.setupPinCode,
        );
      }
    }

    await _eventSub?.cancel();
    _eventSub = null;

    if (sessionId != _sessionId) return; // cancelled while commission ran

    if (!commissionResult.success) {
      error = commissionResult.error ?? 'Commissioning failed';
      _provider.failCommissioning(error);
      phase = CommissionPhase.failed;
      _appendRaw(error!, level: LogLevel.error);
      notifyListeners();
      return;
    }

    final nodeId = commissionResult.nodeId!;
    final svc    = controllerService!;
    var managedBy = ManagedBy.phone;

    // ── Commission-then-handoff (standard Matter multi-admin) ─────────────────
    // Phone Pass-1 is done; stop projecting its remaining stages onto the human
    // track and switch to handoff milestones.
    stageIdx = kCommissionStages.length;
    // 1. Open an ECM window on the device (still on our throwaway fabric).
    _appendRaw('▶ Opening commissioning window…', level: LogLevel.step);
    final window = await _port.openCommissioningWindow(nodeId);
    if (sessionId != _sessionId) return; // cancelled while awaiting
    if (window == null || window.passcode == 0 || window.discriminator == 0) {
      _failHandoff('Could not open a commissioning window on the device');
      return;
    }
    _appendRaw('✓ Window open (disc=${window.discriminator})', level: LogLevel.success);

    // 2. Hand the device to the controller — it commissions onto its OWN fabric
    //    with its own CA and registers + subscribes it itself.
    _appendRaw('▶ Handing the device to the controller…', level: LogLevel.step);
    _appendHuman('CONTROLLER COMMISSIONING');
    // Pass nodeId 0 so the controller assigns the device's node ID on its own
    // fabric. The controller owns id assignment there, and this avoids feeding
    // the phone-fabric node ID through the wire (the proto field is uint64; a
    // node ID with bit 31 set must not be sign-extended). Our post-handoff
    // fabric gate uses the phone's own CASE session, not this id.
    // device_address/port come from the phone's own mDNS scan of the open window
    // (window.ipv6Address). The controller PASEs this directly because its own
    // DNS-SD discovery can't identify the device over the OTBR proxy.
    final handoff = await svc.commission(
      passcode:      window.passcode,
      discriminator: window.discriminator,
      nodeId:        0,
      name:          name,
      deviceType:    commissionResult.deviceTypeId ?? 0,
      deviceAddress: window.ipv6Address,
      devicePort:    window.port,
    );
    if (sessionId != _sessionId) return;
    if (handoff == null || !handoff.success) {
      // Controller could not commission — NEVER remove our fabric; the device
      // stays recoverable on the phone's throwaway fabric.
      final why = (handoff?.error.isNotEmpty ?? false)
          ? handoff!.error
          : 'the controller could not commission the device';
      _failHandoff('Handoff failed — $why');
      return;
    }

    final controllerFabricHex =
        handoff.fabricId.toHexString().toUpperCase().padLeft(16, '0');
    _appendRaw('✓ Controller commissioned the device (fabric 0x$controllerFabricHex)',
        level: LogLevel.success);
    _appendHuman('CONTROLLER COMMISSIONED');
    managedBy = ManagedBy.controller;

    // 3. Safety gate + 4. RemoveFabric.  The controller's fabric MUST be present
    //    on the device before we remove our own; on any doubt we keep our fabric
    //    (the device stays recoverable, never orphaned).
    _appendRaw('▶ Verifying the controller fabric on the device…', level: LogLevel.step);
    _appendHuman('VERIFYING');
    final fabrics = await _port.readFabrics(nodeId) ?? const <FabricDescriptor>[];
    if (sessionId != _sessionId) return;

    bool isControllerFabric(String id) =>
        id.replaceFirst(RegExp('^0x', caseSensitive: false), '')
          .toUpperCase()
          .padLeft(16, '0') == controllerFabricHex;

    if (!fabrics.any((f) => isControllerFabric(f.fabricId))) {
      _appendRaw(
          '⚠ Controller fabric not yet visible on the device — leaving this phone\'s '
          'fabric in place (the device stays recoverable)',
          level: LogLevel.info);
    } else {
      final mine = fabrics.where((f) => !isControllerFabric(f.fabricId)).toList();
      if (mine.length == 1) {
        _appendRaw('▶ Removing this phone\'s temporary fabric…', level: LogLevel.step);
        final removed = await _port.removeFabric(nodeId, mine.single.fabricIndex);
        if (sessionId != _sessionId) return;
        _appendRaw(
            removed
                ? '✓ Device is now on the controller fabric only'
                : '⚠ Could not remove this phone\'s fabric — the controller still controls the device',
            level: removed ? LogLevel.success : LogLevel.info);
      } else {
        _appendRaw(
            '⚠ Could not uniquely identify this phone\'s fabric '
            '(${mine.length} candidates) — leaving it in place',
            level: LogLevel.info);
      }
    }

    final device = await _provider.registerCommissionedDevice(
      commissionResult,
      name,
      networkType,
      managedBy: managedBy,
    );
    result = device;
    phase = CommissionPhase.done;
    _appendHuman('COMPLETE', color: const Color(0xFF34A853));
    await QrPayloadService.clear();
    notifyListeners();
  }

  /// Fails the current commission with [msg].  Used for handoff failures where
  /// the device remains on the phone's throwaway fabric (never orphaned).
  void _failHandoff(String msg) {
    error = msg;
    _provider.failCommissioning(msg);
    phase = CommissionPhase.failed;
    _appendRaw(msg, level: LogLevel.error);
    _appendHuman('FAILED', color: const Color(0xFFE53935));
    notifyListeners();
  }


  /// Cancels any in-flight commissioning and returns to [CommissionPhase.idle].
  void reset() {
    _sessionId++; // invalidate in-flight start()
    _eventSub?.cancel();
    _eventSub = null;
    _provider.failCommissioning(null);
    phase = CommissionPhase.idle;
    parsed = null;
    rawPayload = null;
    parseError = null;
    parsing = false;
    rawLog = const [];
    humanLog = const [];
    stageIdx = -1;
    result = null;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  // ── Static helpers ────────────────────────────────────────────────────────

  static CommissionMethod suggestMethod(ParsedPayload p) =>
      (p.prefersBle || p.capabilitiesUnknown) ? CommissionMethod.ble : CommissionMethod.ip;

  /// Returns the suggested network type for [p].
  ///
  /// [threadDataset] - the current dataset hex (used when non-empty).
  /// [threadSelected] - true if the user has explicitly selected a Thread
  ///   dataset (even the "Empty dataset" option); overrides the empty-string
  ///   check so an empty dataset still defaults to Thread.
  static int suggestNetType(ParsedPayload p, {String threadDataset = '', bool threadSelected = false}) {
    if (p.hasOnNetwork) return 2;
    if (p.discoveryCapabilities.contains(DiscoveryCapability.wifiPaf)) return 1;
    if (threadSelected || threadDataset.trim().isNotEmpty) return 0;
    // Unknown BLE device with no credentials configured: default to None (2)
    // so the app doesn't assume WiFi. The actual type is learned from
    // onReadCommissioningInfo after BLE connects.
    return 2;
  }

  // ── Name generation ───────────────────────────────────────────────────────

  String _generateName(List<String> existing) {
    final base = parsed?.suggestedName ?? 'Matter Device';
    if (!existing.contains(base)) return base;
    for (var i = 2; i <= 99; i++) {
      final candidate = '$base $i';
      if (!existing.contains(candidate)) return candidate;
    }
    return '$base ${DateTime.now().millisecondsSinceEpoch}';
  }

  // ── Event processing ──────────────────────────────────────────────────────

  void _onEvent(String event) {
    var lvl = LogLevel.info;
    if (event.startsWith('✓') || event.startsWith('🎉')) lvl = LogLevel.success;
    if (event.startsWith('✗')) lvl = LogLevel.error;
    if (event.startsWith('▶')) lvl = LogLevel.step;

    const stagePrefix = '▶ Stage: ';
    if (event.startsWith(stagePrefix)) {
      final stageName = event.substring(stagePrefix.length).trim();
      final idx = kCommissionStages.indexOf(stageName);
      if (idx >= 0) stageIdx = idx;
    }

    if (event.contains('CREDENTIALS_NEEDED:THREAD')) {
      scheduleMicrotask(() => _handleCredentialsNeeded(true));
    } else if (event.contains('CREDENTIALS_NEEDED')) {
      // CREDENTIALS_NEEDED:WIFI or legacy plain CREDENTIALS_NEEDED
      scheduleMicrotask(() => _handleCredentialsNeeded(false));
    }

    final human = _eventToHumanText(event);
    if (human != null) {
      Color? humanColor;
      if (human == 'COMPLETE') humanColor = const Color(0xFF34A853);
      if (human == 'FAILED') humanColor = const Color(0xFFE53935);
      humanLog = [...humanLog, HumanEntry(text: human, color: humanColor ?? _humanColorFor(lvl))];
    }

    _appendRaw(event, level: lvl);
  }

  Future<void> _handleCredentialsNeeded(bool isThread) async {
    final creds = await onNeedsCredentials(isThread);
    if (creds?.wifiSsid != null && creds!.wifiSsid!.isNotEmpty) {
      await _port.provideCredentials(ssid: creds.wifiSsid, password: creds.wifiPassword);
    } else if (creds?.threadDatasetHex != null && creds!.threadDatasetHex!.isNotEmpty) {
      await _port.provideCredentials(threadDatasetHex: creds.threadDatasetHex);
    } else {
      await _port.provideCredentials();
    }
  }

  void _appendRaw(String msg, {LogLevel level = LogLevel.info}) {
    rawLog = [...rawLog, LogEntry(message: msg, level: level)];
    notifyListeners();
  }

  /// Appends a milestone to the human-readable progress track.
  ///
  /// The controller handoff runs AFTER the phone's Pass-1 commissioning (whose
  /// milestones arrive via [commissionEvents]). Without this the human track
  /// would freeze at the phone's completion — and read as fully "done" — while
  /// the hub is still commissioning the device onto its own fabric.
  void _appendHuman(String text, {Color? color}) {
    humanLog = [...humanLog, HumanEntry(text: text, color: color)];
    notifyListeners();
  }

  static Color? _humanColorFor(LogLevel lvl) => switch (lvl) {
    LogLevel.success => const Color(0xFF34A853),
    _ => null,
  };

  // ── Human text mapping ────────────────────────────────────────────────────

  static String? _eventToHumanText(String event) {
    const stagePrefix = '▶ Stage: ';
    if (event.startsWith(stagePrefix)) {
      final name = event.substring(stagePrefix.length).trim();
      return kCommissionStageHuman[name] ?? name.toUpperCase();
    }
    if (event.contains('BLE scanning')) return 'BLUETOOTH SCANNING';
    if (event.contains('Found device')) return 'DEVICE FOUND';
    if (event.contains('GATT connecting')) return 'BLE CONNECTING';
    if (event.contains('BLE connected')) return 'BLE CONNECTED';
    if (event.contains('Closing previous BLE')) return 'RECONNECTING';
    if (event.contains('Starting CHIP commissioning')) return 'STARTING COMMISSIONING';
    if (event.contains('Commissioning via IP')) return 'IP CONNECTING';
    if (event.contains('Device:') && event.contains('VID=')) return 'DEVICE IDENTIFIED';
    if (event.contains('ICD device detected')) return 'ICD REGISTERING';
    if (event.contains('Using Thread')) return 'THREAD DATASET';
    if (event.contains('Using Wi-Fi')) return 'WIFI CREDENTIALS';
    // The phone's Pass-1 completion is NOT the end of the flow — the controller
    // handoff follows. Label it as a handoff step, not "COMPLETE" (which is
    // reserved for phase == done, after the hub has commissioned the device).
    if (event.startsWith('🎉')) return 'HANDING TO CONTROLLER';
    if (event.startsWith('✗')) return 'FAILED';
    return null;
  }
}
