import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../models/commission_models.dart';
import '../models/matter_device.dart';
import '../providers/device_provider.dart';
import '../services/matter_port.dart';
import '../services/qr_payload_service.dart';

// ── Public enums ──────────────────────────────────────────────────────────────

enum CommissionMethod { ble, ip }

enum CommissionPhase { idle, parsing, parsed, running, done, failed }

// ── Data classes ──────────────────────────────────────────────────────────────

class CommissionConfig {
  final CommissionMethod method;
  final int    netType;           // 0 = Thread, 1 = Wi-Fi, 2 = None
  final String threadDatasetHex;
  final String wifiSsid;
  final String wifiPassword;
  final String ipAddress;
  final int    discriminator;
  final int    setupPinCode;

  const CommissionConfig({
    required this.method,
    this.netType          = 1,
    this.threadDatasetHex = '',
    this.wifiSsid         = '',
    this.wifiPassword     = '',
    this.ipAddress        = '',
    this.discriminator    = 3840,
    this.setupPinCode     = 20202021,
  });

  CommissionConfig copyWith({
    CommissionMethod? method,
    int?    netType,
    String? threadDatasetHex,
    String? wifiSsid,
    String? wifiPassword,
    String? ipAddress,
    int?    discriminator,
    int?    setupPinCode,
  }) => CommissionConfig(
    method:           method           ?? this.method,
    netType:          netType          ?? this.netType,
    threadDatasetHex: threadDatasetHex ?? this.threadDatasetHex,
    wifiSsid:         wifiSsid         ?? this.wifiSsid,
    wifiPassword:     wifiPassword     ?? this.wifiPassword,
    ipAddress:        ipAddress        ?? this.ipAddress,
    discriminator:    discriminator    ?? this.discriminator,
    setupPinCode:     setupPinCode     ?? this.setupPinCode,
  );
}

/// Credentials returned by the [CommissioningController.onNeedsCredentials]
/// callback.  Return null to cancel credential provision (BLE pre-collection
/// aborts commissioning; CREDENTIALS_NEEDED calls [provideCredentials] with
/// no args so the SDK fails gracefully).
class CommissionCredentials {
  final String? wifiSsid;
  final String? wifiPassword;
  final String? threadDatasetHex;

  const CommissionCredentials({
    this.wifiSsid,
    this.wifiPassword,
    this.threadDatasetHex,
  });

  const CommissionCredentials.wifi(String ssid, String pass)
      : wifiSsid         = ssid,
        wifiPassword     = pass,
        threadDatasetHex = null;

  const CommissionCredentials.thread(String hex)
      : wifiSsid         = null,
        wifiPassword     = null,
        threadDatasetHex = hex;
}

// ── Log types (public — consumed by the progress widgets) ─────────────────────

enum LogLevel { step, info, success, error }

class LogEntry {
  final String   message;
  final LogLevel level;
  const LogEntry({required this.message, required this.level});
}

class HumanEntry {
  final String text;
  final Color? color;
  const HumanEntry({required this.text, this.color});
}

// ── Stage constants (public — consumed by _buildProgressTrack) ────────────────

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
  'ReadCommissioningInfo':                   'READ DEVICE INFO',
  'ArmFailSafe':                             'SET TIMEOUT',
  'ConfigRegulatory':                        'SET REGIONAL SETTINGS',
  'ConfigureTCAcknowledgments':              'TERMS AND CONDITIONS',
  'ConfigureUTCTime':                        'SYNC TIME/CLOCK',
  'ScanNetworks':                            'SCAN NETWORKS',
  'NeedsNetworkCreds':                       'NEED CREDENTIALS',
  'RequestWiFiCredentials':                  'REQUEST WIFI CREDS',
  'RequestThreadCredentials':                'REQUEST THREAD CREDS',
  'SendPAICertificateRequest':               'REQUEST PAI CERTIFICATE',
  'SendDACCertificateRequest':               'REQUEST DAC CERTIFICATE',
  'SendAttestationRequest':                  'SEND VERIFICATION',
  'AttestationVerification':                 'DEVICE VERIFICATION',
  'AttestationRevocationCheck':              'DCL SECURITY CHECK',
  'SendOpCertSigningRequest':                'KEY REQUEST',
  'ValidateCSR':                             'ID CHECK',
  'GenerateNOCChain':                        'ASSIGN NETWORK ID',
  'SendTrustedRootCert':                     'ALLOW ACCESS',
  'SendNOC':                                 'INSTALL ID',
  'WiFiNetworkSetup':                        'WIFI NETWORK SETUP',
  'WiFiNetworkEnable':                       'ENABLE WIFI',
  'ThreadNetworkSetup':                      'THREAD NETWORK SETUP',
  'ThreadNetworkEnable':                     'ENABLE THREAD',
  'PrimaryOperationalNetworkFailed':         'NETWORK FAILED',
  'RemoveWiFiNetworkConfig':                 'REMOVE WIFI CONFIG',
  'RemoveThreadNetworkConfig':               'REMOVE THREAD CONFIG',
  'EvictPreviousCaseSessions':               'CLEAR CONNECTION',
  'FindOperationalForStayActive':            'ICD STAY AWAKE',
  'ICDSendStayActive':                       'WAKING',
  'FindOperationalForCommissioningComplete': 'CHECK ID',
  'SendComplete':                            'FINALIZING',
  'Cleanup':                                 'DONE',
};

// ── CommissioningController ────────────────────────────────────────────────────

/// Owns all commissioning flow logic: payload parsing, BLE permission checks,
/// event-stream subscription, the CREDENTIALS_NEEDED handshake, human-readable
/// log mapping, device name generation, and QR payload persistence.
///
/// The widget keeps only UI-only state (mode toggle, form controllers) and
/// injects two callbacks so the controller never touches [BuildContext]:
///   - [requestBlePermissions] — shows OS dialogs, returns true if granted
///   - [onNeedsCredentials]    — shows credential sheet, returns creds or null
class CommissioningController extends ChangeNotifier {
  final MatterCommissionPort _port;
  final DeviceProvider       _provider;

  final Future<bool> Function()                    requestBlePermissions;
  final Future<CommissionCredentials?> Function()  onNeedsCredentials;
  final String Function()                          threadDataset;

  // ── Public state ──────────────────────────────────────────────────────────

  CommissionPhase  phase      = CommissionPhase.idle;
  ParsedPayload?   parsed;
  String?          parseError;
  bool             parsing    = false;
  String?          rawPayload;
  List<LogEntry>   rawLog     = const [];
  List<HumanEntry> humanLog   = const [];
  int              stageIdx   = -1;
  MatterDevice?    result;
  String?          error;

  // ── Private ───────────────────────────────────────────────────────────────

  StreamSubscription<String>? _eventSub;

  /// Monotonically-increasing session counter.  When reset() or a new start()
  /// is called, any in-flight start() from a previous session detects the
  /// mismatch and discards its result.
  int _sessionId = 0;

  CommissioningController({
    required MatterCommissionPort port,
    required DeviceProvider       provider,
    required this.requestBlePermissions,
    required this.onNeedsCredentials,
    this.threadDataset = _returnEmpty,
  })  : _port     = port,
        _provider = provider;

  static String _returnEmpty() => '';

  // ── setPayload ────────────────────────────────────────────────────────────

  /// Parses [raw] and optionally starts commissioning immediately.
  /// After this returns the caller should read [parsed], [parseError], and
  /// [phase] to decide what to show.
  Future<void> setPayload(String raw, {bool autoStart = false}) async {
    rawPayload = raw;
    parsed     = null;
    parseError = null;
    parsing    = true;
    phase      = CommissionPhase.parsing;
    notifyListeners();

    final p = await _port.parsePayload(raw);

    if (p == null) {
      parsing    = false;
      parseError = 'Could not parse payload';
      phase      = CommissionPhase.idle;
      notifyListeners();
      return;
    }

    parsing = false;
    parsed  = p;
    phase   = CommissionPhase.parsed;
    notifyListeners();

    debugPrint('🔍 parsed payload: caps=${p.discoveryCapabilities} '
        'prefersBle=${p.prefersBle} hasOnNetwork=${p.hasOnNetwork} '
        'capabilitiesUnknown=${p.capabilitiesUnknown} '
        '→ method=${suggestMethod(p)} netType=${suggestNetType(p, threadDataset: threadDataset())}');

    await QrPayloadService.save(raw);

    if (autoStart) {
      await start(CommissionConfig(
        method:  suggestMethod(p),
        netType: suggestNetType(p, threadDataset: threadDataset()),
      ));
    }
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

    final int sessionId = ++_sessionId;

    rawLog   = const [];
    humanLog = const [];
    stageIdx = -1;
    result   = null;
    error    = null;
    phase    = CommissionPhase.running;
    notifyListeners();

    final name = _generateName(_provider.devices.map((d) => d.name).toList());
    _appendRaw('Commissioning "$name"…', level: LogLevel.step);

    _eventSub = _port.commissionEvents.listen(_onEvent);

    // Pre-collect Wi-Fi credentials for BLE+WiFi when the form was left empty.
    CommissionConfig cfg = config;
    if (config.method == CommissionMethod.ble &&
        config.netType == 1 &&
        config.wifiSsid.isEmpty &&
        threadDataset().trim().isEmpty) {
      final creds = await onNeedsCredentials();
      if (sessionId != _sessionId) return; // cancelled while awaiting
      if (creds == null) {
        await _eventSub?.cancel();
        _eventSub = null;
        rawLog    = const [];
        humanLog  = const [];
        phase     = CommissionPhase.idle;
        notifyListeners();
        return;
      }
      cfg = config.copyWith(
        wifiSsid:         creds.wifiSsid         ?? '',
        wifiPassword:     creds.wifiPassword      ?? '',
        threadDatasetHex: creds.threadDatasetHex  ?? '',
      );
    }

    MatterDevice? device;

    if (cfg.method == CommissionMethod.ip) {
      device = await _provider.commissionViaIp(
        ipAddress:    cfg.ipAddress,
        discriminator: cfg.discriminator > 0
            ? cfg.discriminator
            : (parsed!.discriminator > 0 ? parsed!.discriminator : 3840),
        setupPinCode: cfg.setupPinCode,
        deviceName:   name,
        room:         'Unassigned',
      );
    } else {
      switch (cfg.netType) {
        case 0: // Thread
          device = await _provider.commissionDevice(
            rawPayload!, name, 'Unassigned',
            threadDatasetHex: cfg.threadDatasetHex.isNotEmpty
                ? cfg.threadDatasetHex.replaceAll(RegExp(r'\s'), '')
                : threadDataset().replaceAll(RegExp(r'\s'), ''),
          );
        case 1: // Wi-Fi
          device = await _provider.commissionDevice(
            rawPayload!, name, 'Unassigned',
            wifiSsid:     cfg.wifiSsid,
            wifiPassword: cfg.wifiPassword,
          );
        default: // None / Ethernet
          device = await _provider.commissionDevice(rawPayload!, name, 'Unassigned');
      }
    }

    await _eventSub?.cancel();
    _eventSub = null;

    if (sessionId != _sessionId) return; // cancelled while commissionDevice ran

    if (device != null) {
      result = device;
      phase  = CommissionPhase.done;
      await QrPayloadService.clear();
    } else {
      error = _provider.errorMessage ?? 'Commissioning failed';
      phase = CommissionPhase.failed;
      _appendRaw(error!, level: LogLevel.error);
    }
    notifyListeners();
  }

  // ── reset ─────────────────────────────────────────────────────────────────

  /// Cancels any in-flight commissioning and returns to [CommissionPhase.idle].
  void reset() {
    _sessionId++; // invalidate in-flight start()
    _eventSub?.cancel();
    _eventSub  = null;
    phase      = CommissionPhase.idle;
    parsed     = null;
    rawPayload = null;
    parseError = null;
    parsing    = false;
    rawLog     = const [];
    humanLog   = const [];
    stageIdx   = -1;
    result     = null;
    error      = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  // ── Static helpers ────────────────────────────────────────────────────────

  static CommissionMethod suggestMethod(ParsedPayload p) =>
      (p.prefersBle || p.capabilitiesUnknown)
          ? CommissionMethod.ble
          : CommissionMethod.ip;

  /// Returns the suggested network type for [p].
  ///
  /// [threadDataset] — the current dataset hex (used when non-empty).
  /// [threadSelected] — true if the user has explicitly selected a Thread
  ///   dataset (even the "Empty dataset" option); overrides the empty-string
  ///   check so an empty dataset still defaults to Thread.
  static int suggestNetType(
    ParsedPayload p, {
    String threadDataset = '',
    bool   threadSelected = false,
  }) {
    if (p.hasOnNetwork) return 2;
    if (p.discoveryCapabilities.contains(DiscoveryCapability.wifiPaf)) return 1;
    if (threadSelected || threadDataset.trim().isNotEmpty) return 0;
    return 1;
  }

  // ── Name generation ───────────────────────────────────────────────────────

  String _generateName(List<String> existing) {
    final base = parsed?.suggestedName ?? 'Matter Device';
    if (!existing.contains(base)) return base;
    for (int i = 2; i <= 99; i++) {
      final candidate = '$base $i';
      if (!existing.contains(candidate)) return candidate;
    }
    return '$base ${DateTime.now().millisecondsSinceEpoch}';
  }

  // ── Event processing ──────────────────────────────────────────────────────

  void _onEvent(String event) {
    LogLevel lvl = LogLevel.info;
    if (event.startsWith('✓') || event.startsWith('🎉')) lvl = LogLevel.success;
    if (event.startsWith('✗'))                            lvl = LogLevel.error;
    if (event.startsWith('▶'))                            lvl = LogLevel.step;

    const stagePrefix = '▶ Stage: ';
    if (event.startsWith(stagePrefix)) {
      final stageName = event.substring(stagePrefix.length).trim();
      final idx       = kCommissionStages.indexOf(stageName);
      if (idx >= 0) stageIdx = idx;
    }

    if (event.contains('CREDENTIALS_NEEDED')) {
      scheduleMicrotask(_handleCredentialsNeeded);
    }

    final human = _eventToHumanText(event);
    if (human != null) {
      Color? humanColor;
      if (human == 'COMPLETE') humanColor = const Color(0xFF34A853);
      if (human == 'FAILED')   humanColor = const Color(0xFFE53935);
      humanLog = [...humanLog, HumanEntry(text: human, color: humanColor ?? _humanColorFor(lvl))];
    }

    _appendRaw(event, level: lvl);
  }

  Future<void> _handleCredentialsNeeded() async {
    final creds = await onNeedsCredentials();
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

  static Color? _humanColorFor(LogLevel lvl) => switch (lvl) {
    LogLevel.success => const Color(0xFF34A853),
    _                => null,
  };

  // ── Human text mapping ────────────────────────────────────────────────────

  static String? _eventToHumanText(String event) {
    const stagePrefix = '▶ Stage: ';
    if (event.startsWith(stagePrefix)) {
      final name = event.substring(stagePrefix.length).trim();
      return kCommissionStageHuman[name] ?? name.toUpperCase();
    }
    if (event.contains('BLE scanning'))                return 'BLUETOOTH SCANNING';
    if (event.contains('Found device'))                return 'DEVICE FOUND';
    if (event.contains('GATT connecting'))             return 'BLE CONNECTING';
    if (event.contains('BLE connected'))               return 'BLE CONNECTED';
    if (event.contains('Closing previous BLE'))        return 'RECONNECTING';
    if (event.contains('Starting CHIP commissioning')) return 'STARTING COMMISSIONING';
    if (event.contains('Commissioning via IP'))        return 'IP CONNECTING';
    if (event.contains('Device:') && event.contains('VID=')) return 'DEVICE IDENTIFIED';
    if (event.contains('ICD device detected'))         return 'ICD REGISTERING';
    if (event.contains('Using Thread'))                return 'THREAD DATASET';
    if (event.contains('Using Wi-Fi'))                 return 'WIFI CREDENTIALS';
    if (event.startsWith('🎉'))                        return 'COMPLETE';
    if (event.startsWith('✗'))                         return 'FAILED';
    return null;
  }
}
