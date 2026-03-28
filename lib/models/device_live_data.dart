import 'thermostat_models.dart';

// Sentinel used by [DeviceLiveData.copyWith] to mean "keep the existing value"
// rather than "set to null".  Only applies to the flat live-measurement fields.
// Callers must not reference this directly.
const _keep = Object();

// ─────────────────────────────────────────────────────────────────────────────
// BasicInfoCache — read once per session, never touched by subscription events
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable cache of BasicInformation cluster (0x0028) fields.
/// Populated by a one-shot [MatterClusterPort.readBasicInfo] call; never
/// overwritten by subscription events.  The structural separation from
/// [DeviceLiveData]'s live-measurement fields makes that invariant impossible
/// to violate accidentally.
class BasicInfoCache {
  final String? productName;
  final String? vendorName;
  final String? vendorId;
  final String? productId;
  final String? hwVersion;
  final String? serialNumber;
  final String? softwareVersion;
  final int?    softwareVersionNum;  // uint32 from BasicInformation
  final String? manufacturingDate;
  final String? partNumber;
  final String? productUrl;
  final String? uniqueId;

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

  static const BasicInfoCache empty = BasicInfoCache();

  BasicInfoCache copyWith({
    String? productName,
    String? vendorName,
    String? vendorId,
    String? productId,
    String? hwVersion,
    String? serialNumber,
    String? softwareVersion,
    int?    softwareVersionNum,
    String? manufacturingDate,
    String? partNumber,
    String? productUrl,
    String? uniqueId,
  }) => BasicInfoCache(
    productName:       productName       ?? this.productName,
    vendorName:        vendorName        ?? this.vendorName,
    vendorId:          vendorId          ?? this.vendorId,
    productId:         productId         ?? this.productId,
    hwVersion:         hwVersion         ?? this.hwVersion,
    serialNumber:      serialNumber      ?? this.serialNumber,
    softwareVersion:   softwareVersion   ?? this.softwareVersion,
    softwareVersionNum:softwareVersionNum ?? this.softwareVersionNum,
    manufacturingDate: manufacturingDate  ?? this.manufacturingDate,
    partNumber:        partNumber         ?? this.partNumber,
    productUrl:        productUrl         ?? this.productUrl,
    uniqueId:          uniqueId           ?? this.uniqueId,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// OtaStatus — checked once after commissioning, never touched by subscriptions
// ─────────────────────────────────────────────────────────────────────────────

/// Whether the device supports OTA updates and, if so, on which endpoint.
/// Checked once via [DeviceProvider.detectAndUpdateOtaSupport]; never updated
/// by subscription events.
class OtaStatus {
  /// `null` = not yet checked; `true` / `false` = result of cluster walk.
  final bool? supported;
  final int?  endpoint;

  const OtaStatus({this.supported, this.endpoint});

  static const OtaStatus absent = OtaStatus();
}

// ─────────────────────────────────────────────────────────────────────────────
// DeviceLiveData — in-memory live state cache, never persisted
// ─────────────────────────────────────────────────────────────────────────────

/// In-memory-only live state cache for a commissioned device.
/// Populated by CHIP SDK subscriptions; never persisted.
///
/// Structured into two distinct zones:
/// * **Live-measurement fields** (flat, `_keep`-copyWith) — subscription events
///   may update these at any time via [merge].
/// * **Typed sub-objects** ([basicInfo], [ota]) — structurally excluded from
///   [merge]; only updated through dedicated methods ([withBasicInfo],
///   [withOtaSupported]).  The compiler enforces this — [merge] passes neither
///   argument to [copyWith], so they are always preserved.
class DeviceLiveData {
  final DateTime    updatedAt;
  final bool        isStale;

  // ── Live-measurement fields (subscription-writable) ────────────────────────
  final bool? isOn;
  final int?  levelRaw;        // 0–254

  final int? localTempCenti;      // °C × 100
  final int? heatingSetptCenti;
  final int? coolingSetptCenti;
  final int? systemMode;          // 0=Off 1=Auto 3=Cool 4=Heat …
  final int? controlSequence;     // ControlSequenceOfOperation

  final int? humidityCenti;       // 0.01 % RH
  final int? tempMeasureCenti;    // from Temperature Measurement (not Thermostat)

  final int? batPercentRaw;       // 0–200 (÷2 = %)
  final int? batChargeLevel;      // 0=OK 1=Warning 2=Critical

  final int?  occupancy;          // bitmap8; bit 0 = 1 → occupied
  final bool? contactState;       // true = contact (closed)

  /// AirQualityEnum: 0=Unknown 1=Good 2=Fair 3=Moderate 4=Poor 5=VeryPoor 6=ExtremelyPoor
  final int? airQuality;

  // ── Subscription-proof sub-objects ────────────────────────────────────────
  final BasicInfoCache basicInfo;
  final OtaStatus      ota;

  const DeviceLiveData({
    required this.updatedAt,
    required this.isStale,
    this.isOn,
    this.levelRaw,
    this.localTempCenti,
    this.heatingSetptCenti,
    this.coolingSetptCenti,
    this.systemMode,
    this.controlSequence,
    this.humidityCenti,
    this.tempMeasureCenti,
    this.batPercentRaw,
    this.batChargeLevel,
    this.occupancy,
    this.contactState,
    this.airQuality,
    this.basicInfo = BasicInfoCache.empty,
    this.ota       = OtaStatus.absent,
  });

  // ── BasicInfo getters (backward-compatible delegation) ────────────────────
  String? get productName       => basicInfo.productName;
  String? get vendorName        => basicInfo.vendorName;
  String? get vendorId          => basicInfo.vendorId;
  String? get productId         => basicInfo.productId;
  String? get hwVersion         => basicInfo.hwVersion;
  String? get serialNumber      => basicInfo.serialNumber;
  String? get softwareVersion   => basicInfo.softwareVersion;
  int?    get softwareVersionNum => basicInfo.softwareVersionNum;
  String? get manufacturingDate => basicInfo.manufacturingDate;
  String? get partNumber        => basicInfo.partNumber;
  String? get productUrl        => basicInfo.productUrl;
  String? get uniqueId          => basicInfo.uniqueId;

  // ── OTA getters (backward-compatible delegation) ──────────────────────────
  bool? get otaSupported => ota.supported;
  int?  get otaEndpoint  => ota.endpoint;

  // ── copyWith ───────────────────────────────────────────────────────────────
  //
  // Live-measurement fields use [_keep] so callers distinguish
  // "don't change this field" from "set this field to null".
  // Sub-objects use simple nullable params: null = keep existing.
  //
  DeviceLiveData copyWith({
    DateTime? updatedAt,
    bool?     isStale,
    Object?   isOn             = _keep,
    Object?   levelRaw         = _keep,
    Object?   localTempCenti   = _keep,
    Object?   heatingSetptCenti= _keep,
    Object?   coolingSetptCenti= _keep,
    Object?   systemMode       = _keep,
    Object?   controlSequence  = _keep,
    Object?   humidityCenti    = _keep,
    Object?   tempMeasureCenti = _keep,
    Object?   batPercentRaw    = _keep,
    Object?   batChargeLevel   = _keep,
    Object?   occupancy        = _keep,
    Object?   contactState     = _keep,
    Object?   airQuality       = _keep,
    BasicInfoCache? basicInfo,
    OtaStatus?      ota,
  }) {
    T? v<T>(Object? arg, T? existing) => identical(arg, _keep) ? existing : arg as T?;
    return DeviceLiveData(
      updatedAt:         updatedAt          ?? this.updatedAt,
      isStale:           isStale            ?? this.isStale,
      isOn:              v(isOn,              this.isOn),
      levelRaw:          v(levelRaw,          this.levelRaw),
      localTempCenti:    v(localTempCenti,    this.localTempCenti),
      heatingSetptCenti: v(heatingSetptCenti, this.heatingSetptCenti),
      coolingSetptCenti: v(coolingSetptCenti, this.coolingSetptCenti),
      systemMode:        v(systemMode,        this.systemMode),
      controlSequence:   v(controlSequence,   this.controlSequence),
      humidityCenti:     v(humidityCenti,     this.humidityCenti),
      tempMeasureCenti:  v(tempMeasureCenti,  this.tempMeasureCenti),
      batPercentRaw:     v(batPercentRaw,     this.batPercentRaw),
      batChargeLevel:    v(batChargeLevel,    this.batChargeLevel),
      occupancy:         v(occupancy,         this.occupancy),
      contactState:      v(contactState,      this.contactState),
      airQuality:        v(airQuality,        this.airQuality),
      basicInfo:         basicInfo            ?? this.basicInfo,
      ota:               ota                  ?? this.ota,
    );
  }

  // ── Targeted update helpers ────────────────────────────────────────────────

  DeviceLiveData markStale() => copyWith(isStale: true);

  /// Updates [basicInfo] fields individually, preserving any already-cached
  /// values for fields not supplied.  Never touches live-measurement fields.
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
    int?    swVersionNum,
  }) => copyWith(basicInfo: basicInfo.copyWith(
    serialNumber:      serial,
    softwareVersion:   swVersion,
    softwareVersionNum:swVersionNum ?? basicInfo.softwareVersionNum,
    productName:       product,
    vendorName:        vendorName        ?? basicInfo.vendorName,
    vendorId:          vendorId          ?? basicInfo.vendorId,
    productId:         productId         ?? basicInfo.productId,
    hwVersion:         hwVersion         ?? basicInfo.hwVersion,
    manufacturingDate: manufacturingDate  ?? basicInfo.manufacturingDate,
    partNumber:        partNumber         ?? basicInfo.partNumber,
    productUrl:        productUrl         ?? basicInfo.productUrl,
    uniqueId:          uniqueId           ?? basicInfo.uniqueId,
  ));

  DeviceLiveData withOtaSupported(bool value, int endpoint) => copyWith(
    ota: OtaStatus(
      supported: value,
      endpoint:  value ? endpoint : null,
    ),
  );

  // ── Merge incoming subscription map ───────────────────────────────────────

  /// Returns a new [DeviceLiveData] with subscription [update] values merged in.
  ///
  /// Keys absent from [update] retain their current values.  [basicInfo] and
  /// [ota] are structurally excluded — they are never passed to [copyWith] here,
  /// so the compiler guarantees they cannot be touched.
  DeviceLiveData merge(Map<String, dynamic> update) {
    Object? pick(String key) =>
        update.containsKey(key) ? update[key] : _keep;
    return copyWith(
      updatedAt:         DateTime.now(),
      isStale:           false,
      isOn:              pick('onOff'),
      levelRaw:          pick('level'),
      localTempCenti:    pick('localTempCenti'),
      heatingSetptCenti: pick('heatingSetptCenti'),
      coolingSetptCenti: pick('coolingSetptCenti'),
      systemMode:        pick('systemMode'),
      controlSequence:   pick('controlSequence'),
      humidityCenti:     pick('humidityCenti'),
      tempMeasureCenti:  pick('tempMeasureCenti'),
      batPercentRaw:     pick('batPercentRaw'),
      batChargeLevel:    pick('batChargeLevel'),
      occupancy:         pick('occupancy'),
      contactState:      pick('contactState'),
      airQuality:        pick('airQuality'),
      // basicInfo and ota deliberately omitted → preserved unchanged
    );
  }

  /// Creates a fresh [DeviceLiveData] seeded only from a subscription update map.
  factory DeviceLiveData.fromUpdate(Map<String, dynamic> update) =>
      DeviceLiveData(updatedAt: DateTime.now(), isStale: false).merge(update);

  // ── Derived helpers ────────────────────────────────────────────────────────

  ThermostatState? get thermoState {
    if (localTempCenti == null && heatingSetptCenti == null) return null;
    return ThermostatState(
      localTempCenti:    _noSentinel(localTempCenti),
      heatingSetptCenti: _noSentinel(heatingSetptCenti),
      coolingSetptCenti: _noSentinel(coolingSetptCenti),
      systemMode:        systemMode == -1 ? null : systemMode,
      controlSequence:   controlSequence == -1 ? null : controlSequence,
    );
  }

  int? get batPercent =>
      batPercentRaw != null ? (batPercentRaw! ~/ 2) : null;

  BatteryInfo? get batteryInfo {
    if (batPercent == null && batChargeLevel == null) return null;
    return BatteryInfo(percent: batPercent, chargeLevel: batChargeLevel);
  }

  /// Converts Matter's signed-16-bit null sentinel (0x8000 = −32768) to Dart null.
  static int? _noSentinel(int? v) =>
      (v == null || v == -32768) ? null : v;
}
