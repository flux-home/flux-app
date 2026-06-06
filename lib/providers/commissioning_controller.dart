import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/cupertino.dart' show BuildContext;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/widgets.dart' show BuildContext;

import 'package:matter_home/models/commission_models.dart';
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
    MatterPort? localPort,
    this.controllerService,
  }) : _port = port,
       _provider = provider,
       _localPort = (localPort != null && !identical(localPort, port)) ? localPort : null;

  final MatterCommissionPort _port;
  final DeviceProvider _provider;

  /// Non-null in controller mode: local [MatterChannel] for phone-side BLE.
  final MatterPort? _localPort;

  /// Non-null in controller mode: HTTP client for [CommissionNotify] + Thread dataset.
  final FluxCoapService? controllerService;

  // Port to use for provideCredentials — set to _localPort during BLE handoff.
  MatterCommissionPort? _activeCredPort;

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

    // In hub mode FluxCoapService.parsePayload returns null (not supported over CoAP).
    // Fall back to the local MatterChannel which can always parse QR payloads.
    final p = await (_localPort?.parsePayload(raw) ?? _port.parsePayload(raw));

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

    MatterDevice? device;

    // Determine network type before starting so the provider can record it.
    NetworkType networkType = NetworkType.ethernet;
    CommissionResult commissionResult;

    _provider.beginCommissioning();

    if (cfg.method == CommissionMethod.ble && _localPort != null) {
      // ── Hub BLE handoff flow (Option B) ────────────────────────────────
      // 1. Phone BLE → device onto phone's fabric
      // 2. Phone opens commissioning window → new setup code
      // 3. Pi commissions device over IP using that code
      // 4. Phone removes device from its own fabric
      networkType = switch (cfg.netType) {
        0 => NetworkType.thread,
        1 => NetworkType.wifi,
        _ => NetworkType.ethernet,
      };
      _activeCredPort = _localPort; // CREDENTIALS_NEEDED goes to local port
      _eventSub = _localPort.commissionEvents.listen(_onEvent);
      commissionResult = await _runHubBleHandoff(cfg, sessionId);
      _activeCredPort = null;
    } else if (cfg.method == CommissionMethod.ip) {
      networkType = NetworkType.ethernet;
      if (controllerService != null) {
        // Hub mode — controller does the on-network commissioning.
        // Phone just hands the setup code to the controller via CommissionNotify.
        commissionResult = await _runHubNetworkCommission(sessionId);
      } else if (cfg.ipAddress.trim().isEmpty) {
        // Standalone — no IP: use DNS-SD on-network discovery.
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
    } else {
      switch (cfg.netType) {
        case 0: // Thread
          networkType = NetworkType.thread;
          commissionResult = await _port.commissionDevice(
            rawPayload!,
            threadDatasetHex: cfg.threadDatasetHex.isNotEmpty
                ? cfg.threadDatasetHex.replaceAll(RegExp(r'\s'), '')
                : threadDataset().replaceAll(RegExp(r'\s'), ''),
          );
        case 1: // Wi-Fi
          networkType = NetworkType.wifi;
          commissionResult = await _port.commissionDevice(
            rawPayload!,
            wifiSsid: cfg.wifiSsid,
            wifiPassword: cfg.wifiPassword,
          );
        default: // None / Ethernet
          networkType = NetworkType.ethernet;
          commissionResult = await _port.commissionDevice(rawPayload!);
      }
    }

    await _eventSub?.cancel();
    _eventSub = null;

    if (sessionId != _sessionId) return; // cancelled while commission ran

    if (commissionResult.success) {
      device = await _provider.registerCommissionedDevice(
        commissionResult,
        name,
        networkType,
        managedBy: controllerService != null
            ? ManagedBy.controller
            : ManagedBy.phone,
      );
      result = device;
      phase = CommissionPhase.done;
      await QrPayloadService.clear();
    } else {
      error = commissionResult.error ?? 'Commissioning failed';
      _provider.failCommissioning(error);
      phase = CommissionPhase.failed;
      _appendRaw(error!, level: LogLevel.error);
    }
    notifyListeners();
  }

  // ── Controller on-network commissioning ──────────────────────────────────────

  /// IP / on-network commissioning in hub mode.
  ///
  /// The phone already has the device's QR/manual setup code (from the scan
  /// screen).  The controller discovers and commissions the device over
  /// Thread/IP — no BLE needed.
  Future<CommissionResult> _runHubNetworkCommission(int sessionId) async {
    if (controllerService == null) {
      return CommissionResult.err('Controller service not available');
    }

    _appendRaw('▶ Sending setup code to controller for on-network commissioning…',
        level: LogLevel.step);

    // Switch commission event stream to WS so controller progress arrives.
    await _eventSub?.cancel();
    _eventSub = _port.commissionEvents.listen(_onEvent);

    final controllerNodeId = await controllerService!.sendCommissionNotify(
      phoneNodeId: 0,        // no prior phone commissioning step
      setupCode:   rawPayload!,
    );

    if (sessionId != _sessionId) return CommissionResult.err('Cancelled');

    if (controllerNodeId == null) {
      _appendRaw('✗ Controller commissioning failed', level: LogLevel.error);
      return CommissionResult.err('Controller commissioning failed');
    }

    _appendRaw('✓ Device commissioned by controller (node $controllerNodeId)',
        level: LogLevel.success);

    return CommissionResult.ok(nodeId: controllerNodeId);
  }

  // ── Controller BLE handoff flow ─────────────────────────────────────────────

  /// BLE commission via phone, then hand device to the Flux Controller.
  ///
  /// Steps:
  ///   1. Auto-fetch Thread dataset from controller (if available + Thread mode)
  ///   2. BLE-commission device onto phone's fabric  (via [_localPort])
  ///   3. Open enhanced commissioning window         (via [_localPort])
  ///   4. Send CommissionNotify with setup code      (via HTTP to controller)
  ///   5. Controller commissions over Thread/IP      (firmware handles it)
  ///   6. Device stays on phone's fabric too         (multi-fabric, intentional)
  Future<CommissionResult> _runHubBleHandoff(
    CommissionConfig cfg,
    int sessionId,
  ) async {
    final local = _localPort!;

    // ── Step 1: Auto-fetch Thread dataset from controller ─────────────────────
    var threadHex = cfg.threadDatasetHex.isNotEmpty
        ? cfg.threadDatasetHex.replaceAll(RegExp(r'\s'), '')
        : threadDataset().replaceAll(RegExp(r'\s'), '');

    if (threadHex.isEmpty && controllerService != null && cfg.netType == 0) {
      _appendRaw('▶ Fetching Thread dataset from controller…',
          level: LogLevel.step);
      final fetched = await controllerService!.getThreadDatasetHex();
      if (fetched != null && fetched.isNotEmpty) {
        threadHex = fetched;
        _appendRaw('✓ Thread dataset fetched (${fetched.length ~/ 2} bytes)',
            level: LogLevel.success);
      } else {
        _appendRaw('⚠ No Thread dataset on controller — continuing without',
            level: LogLevel.info);
      }
    }

    // ── Step 2: BLE commission onto phone's fabric ────────────────────────────
    _appendRaw('▶ Connecting to device via Bluetooth…', level: LogLevel.step);

    final CommissionResult localResult;
    switch (cfg.netType) {
      case 0: // Thread
        localResult = await local.commissionDevice(
          rawPayload!,
          threadDatasetHex: threadHex,
        );
      case 1: // Wi-Fi
        localResult = await local.commissionDevice(
          rawPayload!,
          wifiSsid: cfg.wifiSsid,
          wifiPassword: cfg.wifiPassword,
        );
      default:
        localResult = await local.commissionDevice(rawPayload!);
    }

    if (sessionId != _sessionId) return CommissionResult.err('Cancelled');

    if (!localResult.success) {
      return CommissionResult.err(
          localResult.error ?? 'BLE commissioning failed');
    }

    _appendRaw('✓ Device on network via BLE', level: LogLevel.success);

    // ── Step 3: Open enhanced commissioning window ────────────────────────────
    _appendRaw('▶ Opening commissioning window for controller…',
        level: LogLevel.step);

    final shareResult = await local.shareDevice(localResult.nodeId!);

    if (shareResult == null) {
      _appendRaw('✗ Failed to open commissioning window', level: LogLevel.error);
      return CommissionResult.err('Could not open commissioning window');
    }

    if (shareResult.ipv6Address.isNotEmpty) {
      _appendRaw('✓ Commissioning window open — device found at ${shareResult.ipv6Address}',
          level: LogLevel.success);
    } else {
      _appendRaw('✓ Commissioning window open (device IP not resolved — will use mDNS)',
          level: LogLevel.success);
    }

    // ── Step 4: Send CommissionNotify to controller ───────────────────────────
    _appendRaw('▶ Sending device to controller…', level: LogLevel.step);

    await _eventSub?.cancel();
    _eventSub = _port.commissionEvents.listen(_onEvent);
    _activeCredPort = null;

    if (controllerService == null) {
      _appendRaw('✗ No controller service — cannot send CommissionNotify',
          level: LogLevel.error);
      return CommissionResult.err('Controller service not available');
    }

    final controllerNodeId = await controllerService!.sendCommissionNotify(
      phoneNodeId: localResult.nodeId!,
      setupCode:   shareResult.qrCodePayload,
      ipv6Address: shareResult.ipv6Address,
    );

    // Device intentionally stays on phone's fabric too (multi-fabric).

    if (controllerNodeId == null) {
      _appendRaw('✗ Controller commissioning failed', level: LogLevel.error);
      return CommissionResult.err('Controller commissioning failed');
    }

    _appendRaw('✓ Device handed off to controller (node $controllerNodeId)',
        level: LogLevel.success);

    // Return the controller's assigned node_id so DeviceProvider registers
    // the device with the id the controller uses for all future commands.
    return CommissionResult.ok(
      nodeId:       controllerNodeId,
      deviceTypeId: localResult.deviceTypeId,
    );
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
    // In hub BLE flow, provideCredentials must go to the local port (phone's
    // CHIP SDK) not the hub - the hub isn't the one waiting for credentials.
    final credPort = _activeCredPort ?? _port;
    if (creds?.wifiSsid != null && creds!.wifiSsid!.isNotEmpty) {
      await credPort.provideCredentials(ssid: creds.wifiSsid, password: creds.wifiPassword);
    } else if (creds?.threadDatasetHex != null && creds!.threadDatasetHex!.isNotEmpty) {
      await credPort.provideCredentials(threadDatasetHex: creds.threadDatasetHex);
    } else {
      await credPort.provideCredentials();
    }
  }

  void _appendRaw(String msg, {LogLevel level = LogLevel.info}) {
    rawLog = [...rawLog, LogEntry(message: msg, level: level)];
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
    if (event.startsWith('🎉')) return 'COMPLETE';
    if (event.startsWith('✗')) return 'FAILED';
    return null;
  }
}
