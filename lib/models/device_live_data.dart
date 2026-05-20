import 'package:matter_home/models/persisted_snapshot.dart' show PersistedSnapshot;

import 'package:matter_home/models/thermostat_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BasicInfoCache — read once per session, structurally excluded from the
// subscription-attribute map.
// ─────────────────────────────────────────────────────────────────────────────

class BasicInfoCache {
  const BasicInfoCache({
    this.productName,
    this.vendorName,
    this.vendorId,
    this.productId,
    this.hwVersion,
    this.serialNumber,
    this.softwareVersion,
    this.softwareVersionNum,
    this.manufacturingDate,
    this.partNumber,
    this.productUrl,
    this.uniqueId,
  });
  final String? productName;
  final String? vendorName;
  final String? vendorId;
  final String? productId;
  final String? hwVersion;
  final String? serialNumber;
  final String? softwareVersion;
  final int? softwareVersionNum;
  final String? manufacturingDate;
  final String? partNumber;
  final String? productUrl;
  final String? uniqueId;

  static const BasicInfoCache empty = BasicInfoCache();

  BasicInfoCache copyWith({
    String? productName,
    String? vendorName,
    String? vendorId,
    String? productId,
    String? hwVersion,
    String? serialNumber,
    String? softwareVersion,
    int? softwareVersionNum,
    String? manufacturingDate,
    String? partNumber,
    String? productUrl,
    String? uniqueId,
  }) => BasicInfoCache(
    productName: productName ?? this.productName,
    vendorName: vendorName ?? this.vendorName,
    vendorId: vendorId ?? this.vendorId,
    productId: productId ?? this.productId,
    hwVersion: hwVersion ?? this.hwVersion,
    serialNumber: serialNumber ?? this.serialNumber,
    softwareVersion: softwareVersion ?? this.softwareVersion,
    softwareVersionNum: softwareVersionNum ?? this.softwareVersionNum,
    manufacturingDate: manufacturingDate ?? this.manufacturingDate,
    partNumber: partNumber ?? this.partNumber,
    productUrl: productUrl ?? this.productUrl,
    uniqueId: uniqueId ?? this.uniqueId,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// OtaStatus
// ─────────────────────────────────────────────────────────────────────────────

class OtaStatus {
  const OtaStatus({this.supported, this.endpoint});
  final bool? supported;
  final int? endpoint;
  static const OtaStatus absent = OtaStatus();
}

// ─────────────────────────────────────────────────────────────────────────────
// DeviceLiveData
// ─────────────────────────────────────────────────────────────────────────────

/// In-memory live state for one commissioned device.
///
/// All subscription-driven measurements are stored in [attrs] — a plain
/// `Map<String, dynamic>` whose keys are exactly the event keys emitted by
/// the Android subscription layer (e.g. `'onOff'`, `'level'`,
/// `'humidityCenti'`, `'co2Ppm'`, …).
///
/// Adding a new cluster attribute requires **zero changes here**: Android
/// emits the new key, [merge] spreads it into [attrs], [PersistedSnapshot]
/// stores it automatically, and the renderer registry in `cluster_parser.dart`
/// displays it.
///
/// [basicInfo] and [ota] are structurally separate — they are never touched
/// by [merge].
class DeviceLiveData {
  DeviceLiveData({
    required this.updatedAt,
    required this.isStale,
    Map<String, dynamic>? attrs,
    this.basicInfo = BasicInfoCache.empty,
    this.ota = OtaStatus.absent,
  }) : attrs = attrs ?? const {};

  // ── Factories ─────────────────────────────────────────────────────────────

  factory DeviceLiveData.fromUpdate(Map<String, dynamic> update) =>
      DeviceLiveData(updatedAt: DateTime.now(), isStale: false).merge(update);
  final DateTime updatedAt;
  final bool isStale;

  /// All subscription-driven measurement values.  Callers that need a specific
  /// attribute should use the typed accessors below rather than reading [attrs]
  /// directly — those accessors are the stable API surface.
  final Map<String, dynamic> attrs;

  final BasicInfoCache basicInfo;
  final OtaStatus ota;

  // ── Typed accessors (stable API for dedicated cards & DeviceView) ─────────

  bool? get isOn => attrs['onOff'] as bool?;
  int? get levelRaw => attrs['level'] as int?;

  int? get localTempCenti => attrs['localTempCenti'] as int?;
  int? get heatingSetptCenti => attrs['heatingSetptCenti'] as int?;
  int? get coolingSetptCenti => attrs['coolingSetptCenti'] as int?;
  int? get systemMode => attrs['systemMode'] as int?;
  int? get controlSequence => attrs['controlSequence'] as int?;
  int? get minHeatSetptCenti => attrs['minHeatSetptCenti'] as int?;
  int? get maxHeatSetptCenti => attrs['maxHeatSetptCenti'] as int?;
  int? get minCoolSetptCenti => attrs['minCoolSetptCenti'] as int?;
  int? get maxCoolSetptCenti => attrs['maxCoolSetptCenti'] as int?;
  int? get absMinHeatSetptCenti => attrs['absMinHeatSetptCenti'] as int?;
  int? get absMaxHeatSetptCenti => attrs['absMaxHeatSetptCenti'] as int?;
  int? get absMinCoolSetptCenti => attrs['absMinCoolSetptCenti'] as int?;
  int? get absMaxCoolSetptCenti => attrs['absMaxCoolSetptCenti'] as int?;

  int? get humidityCenti => attrs['humidityCenti'] as int?;
  int? get tempMeasureCenti => attrs['tempMeasureCenti'] as int?;
  int? get batPercentRaw => attrs['batPercentRaw'] as int?;
  int? get batChargeLevel => attrs['batChargeLevel'] as int?;
  int? get occupancy => attrs['occupancy'] as int?;
  bool? get contactState => attrs['contactState'] as bool?;
  int? get airQuality => attrs['airQuality'] as int?;
  int? get liftPercent100ths => attrs['liftPercent100ths'] as int?;
  int? get fanMode => attrs['fanMode'] as int?;
  int? get fanPercent => attrs['fanPercent'] as int?;
  int? get colorTempMireds => attrs['colorTempMireds'] as int?;
  int? get smokeState => attrs['smokeState'] as int?;
  int? get coState => attrs['coState'] as int?;
  int? get switchCurrentPosition => attrs['switchCurrentPosition'] as int?;
  int? get switchCurrentEndpoint => attrs['switchCurrentEndpoint'] as int?;
  int? get switchLastPosition     => attrs['switchLastPosition'] as int?;
  int? get switchLastEndpoint     => attrs['switchLastEndpoint'] as int?;

  int? get lockState              => attrs['lockState']              as int?;

  // Electrical Power Measurement (0x0090) — all values are nullable int64
  // transmitted as Dart int (64-bit).  Units: mW, mV, mA.
  int? get activePower    => attrs['activePower']    as int?;  // milliwatts
  int? get voltage        => attrs['voltage']        as int?;  // millivolts
  int? get activeCurrent  => attrs['activeCurrent']  as int?;  // milliamps

  // Electrical Energy Measurement (0x0091) — raw milliwatt-hours from device.
  // Wh getters are computed for backward-compat (gate checks, chart section).
  int? get cumulativeEnergyMwh         => attrs['cumulativeEnergyMwh']         as int?;
  int? get cumulativeEnergyExportedMwh => attrs['cumulativeEnergyExportedMwh'] as int?;
  int? get cumulativeEnergyWh          => cumulativeEnergyMwh         != null ? cumulativeEnergyMwh!         ~/ 1000 : null;
  int? get cumulativeEnergyExportedWh  => cumulativeEnergyExportedMwh != null ? cumulativeEnergyExportedMwh! ~/ 1000 : null;

  // ── BasicInfo delegation (unchanged public API) ───────────────────────────

  String? get productName => basicInfo.productName;
  String? get vendorName => basicInfo.vendorName;
  String? get vendorId => basicInfo.vendorId;
  String? get productId => basicInfo.productId;
  String? get hwVersion => basicInfo.hwVersion;
  String? get serialNumber => basicInfo.serialNumber;
  String? get softwareVersion => basicInfo.softwareVersion;
  int? get softwareVersionNum => basicInfo.softwareVersionNum;
  String? get manufacturingDate => basicInfo.manufacturingDate;
  String? get partNumber => basicInfo.partNumber;
  String? get productUrl => basicInfo.productUrl;
  String? get uniqueId => basicInfo.uniqueId;

  // ── OTA delegation ────────────────────────────────────────────────────────

  bool? get otaSupported => ota.supported;
  int? get otaEndpoint => ota.endpoint;

  // ── Core operations ───────────────────────────────────────────────────────

  /// Returns a new instance with all keys in [update] merged in.
  /// Sets [isStale] → false.  Does not touch [basicInfo] or [ota].
  DeviceLiveData merge(Map<String, dynamic> update) => DeviceLiveData(
    updatedAt: DateTime.now(),
    isStale: false,
    attrs: {...attrs, ...update},
    basicInfo: basicInfo,
    ota: ota,
  );

  DeviceLiveData markStale() =>
      DeviceLiveData(updatedAt: updatedAt, isStale: true, attrs: attrs, basicInfo: basicInfo, ota: ota);

  // ── Targeted helpers for non-subscription sub-objects ─────────────────────

  DeviceLiveData withBasicInfo(
    String? serial,
    String? swVersion,
    String? product, {
    String? vendorName,
    String? vendorId,
    String? productId,
    String? hwVersion,
    String? manufacturingDate,
    String? partNumber,
    String? productUrl,
    String? uniqueId,
    int? swVersionNum,
  }) => DeviceLiveData(
    updatedAt: updatedAt,
    isStale: isStale,
    attrs: attrs,
    basicInfo: basicInfo.copyWith(
      serialNumber: serial,
      softwareVersion: swVersion,
      softwareVersionNum: swVersionNum ?? basicInfo.softwareVersionNum,
      productName: product,
      vendorName: vendorName ?? basicInfo.vendorName,
      vendorId: vendorId ?? basicInfo.vendorId,
      productId: productId ?? basicInfo.productId,
      hwVersion: hwVersion ?? basicInfo.hwVersion,
      manufacturingDate: manufacturingDate ?? basicInfo.manufacturingDate,
      partNumber: partNumber ?? basicInfo.partNumber,
      productUrl: productUrl ?? basicInfo.productUrl,
      uniqueId: uniqueId ?? basicInfo.uniqueId,
    ),
    ota: ota,
  );

  DeviceLiveData withOtaSupported({required bool value, required int endpoint}) => DeviceLiveData(
    updatedAt: updatedAt,
    isStale: isStale,
    attrs: attrs,
    basicInfo: basicInfo,
    ota: OtaStatus(supported: value, endpoint: value ? endpoint : null),
  );

  // ── Derived helpers ───────────────────────────────────────────────────────

  int? get batPercent => batPercentRaw != null ? (batPercentRaw! ~/ 2) : null;

  BatteryInfo? get batteryInfo {
    if (batPercent == null && batChargeLevel == null) return null;
    return BatteryInfo(percent: batPercent, chargeLevel: batChargeLevel);
  }

  ThermostatState? get thermoState {
    if (localTempCenti == null && heatingSetptCenti == null) return null;
    return ThermostatState(
      localTempCenti: _noSentinel(localTempCenti),
      heatingSetptCenti: _noSentinel(heatingSetptCenti),
      coolingSetptCenti: _noSentinel(coolingSetptCenti),
      systemMode: systemMode == -1 ? null : systemMode,
      controlSequence: controlSequence == -1 ? null : controlSequence,
      minHeatSetptCenti: _noSentinel(minHeatSetptCenti),
      maxHeatSetptCenti: _noSentinel(maxHeatSetptCenti),
      minCoolSetptCenti: _noSentinel(minCoolSetptCenti),
      maxCoolSetptCenti: _noSentinel(maxCoolSetptCenti),
      absMinHeatSetptCenti: _noSentinel(absMinHeatSetptCenti),
      absMaxHeatSetptCenti: _noSentinel(absMaxHeatSetptCenti),
      absMinCoolSetptCenti: _noSentinel(absMinCoolSetptCenti),
      absMaxCoolSetptCenti: _noSentinel(absMaxCoolSetptCenti),
    );
  }

  static int? _noSentinel(int? v) => (v == null || v == -32768) ? null : v;
}
