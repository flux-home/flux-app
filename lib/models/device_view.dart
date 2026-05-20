import 'package:flutter/foundation.dart';
import 'package:matter_home/models/device_live_data.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/ui/screens/cluster_inspector_screen.dart' show ClusterInspectorScreen;
import 'package:matter_home/ui/screens/device_settings_screen.dart' show DeviceSettingsScreen;
import 'package:matter_home/ui/screens/thread_diag_screen.dart' show ThreadDiagScreen;

/// Read-only merged view of a commissioned device's state.
///
/// Combines the stable commissioning record ([MatterDevice]) with the
/// in-memory live subscription cache ([DeviceLiveData]).  Priority rule:
/// live data always wins over any persisted fallback.
///
/// Screens consume [DeviceView] exclusively; they never hold both a
/// [MatterDevice] and a [DeviceLiveData] and implement their own merge.
@immutable
class DeviceView {

  const DeviceView(MatterDevice device, DeviceLiveData? live)
      : _device = device,
        _live   = live;
  final MatterDevice    _device;
  final DeviceLiveData? _live;

  // ── Commissioning identity (stable, never updated by subscriptions) ────────

  String      get id                   => _device.id;
  String      get name                 => _device.name;
  DeviceType  get deviceType           => _device.deviceType;
  int         get nodeId               => _device.nodeId;
  DateTime    get commissionedAt       => _device.commissionedAt;
  NetworkType get networkType          => _device.networkType;
  bool        get sharedWithGoogleHome => _device.sharedWithGoogleHome;

  /// The underlying commissioning record.
  /// Pass this to screens that need a stable identity handle for navigation
  /// (e.g. [ClusterInspectorScreen], [ThreadDiagScreen], [DeviceSettingsScreen]).
  MatterDevice get device => _device;

  // ── Connectivity ───────────────────────────────────────────────────────────

  /// True when the device was last known to be reachable (persisted).
  /// Use this to gate whether to show device-specific UI.
  bool get isOnline => _device.isOnline;

  /// True when the live subscription data exists but is stale
  /// (connection lost / resubscribing).  Use this to disable controls.
  bool get isStale => _live?.isStale ?? false;

  // ── Live state (live cache wins; snapshot seed is the cold-start value) ────

  bool   get isOn       => _live?.isOn ?? false;
  int?   get lockState  => _live?.lockState;
  double get brightness => _live?.levelRaw != null
      ? _live!.levelRaw! / 254.0
      : 1.0;
  int?   get localTempCenti => _live?.localTempCenti;

  // ── BasicInfo ──────────────────────────────────────────────────────────────

  /// Product name from the BasicInformation cluster, or null if not yet loaded.
  String? get displayProductName =>
      _live?.productName?.isNotEmpty ?? false ? _live!.productName : null;

  String? get vendorName         => _live?.vendorName;
  String? get vendorId           => _live?.vendorId;
  String? get productId          => _live?.productId;
  String? get hwVersion          => _live?.hwVersion;
  String? get serialNumber       => _live?.serialNumber;
  String? get softwareVersion    => _live?.softwareVersion;
  int?    get softwareVersionNum => _live?.softwareVersionNum;
  String? get manufacturingDate  => _live?.manufacturingDate;
  String? get partNumber         => _live?.partNumber;
  String? get productUrl         => _live?.productUrl;
  String? get uniqueId           => _live?.uniqueId;

  // ── OTA ───────────────────────────────────────────────────────────────────

  bool? get otaSupported => _live?.otaSupported;
  int?  get otaEndpoint  => _live?.otaEndpoint;

  // ── Sensors / thermostat ──────────────────────────────────────────────────

  ThermostatState? get thermoState    => _live?.thermoState;
  int?             get humidityCenti  => _live?.humidityCenti;
  BatteryInfo?     get batteryInfo    => _live?.batteryInfo;
  bool?            get contactState   => _live?.contactState;

  // ── New controllable clusters ─────────────────────────────────────────────
  int? get liftPercent100ths => _live?.liftPercent100ths;
  int? get fanMode           => _live?.fanMode;
  int? get fanPercent        => _live?.fanPercent;
  int? get colorTempMireds   => _live?.colorTempMireds;
  int? get smokeState        => _live?.smokeState;
  int? get coState           => _live?.coState;
  int? get switchCurrentPosition => _live?.switchCurrentPosition;
  int? get switchCurrentEndpoint => _live?.switchCurrentEndpoint;
  int? get switchLastPosition     => _live?.switchLastPosition;
  int? get switchLastEndpoint     => _live?.switchLastEndpoint;

  // ── Escape hatch ──────────────────────────────────────────────────────────

  /// Direct access to the raw live cache for edge cases.
  /// Prefer the typed getters above whenever possible.
  DeviceLiveData? get live => _live;
}
