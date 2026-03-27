import 'thermostat_models.dart';

// Sentinel used by [DeviceLiveData.copyWith] to mean "keep the existing value"
// rather than "set to null".  Callers must not reference this directly.
const _keep = Object();

/// In-memory-only live state cache for a commissioned device.
/// Populated by CHIP SDK subscriptions; never persisted.
class DeviceLiveData {
  final DateTime    updatedAt;
  final bool        isStale;

  // ── On/Off + Level ─────────────────────────────────────────────────────────
  final bool? isOn;
  final int?  levelRaw;        // 0–254

  // ── Thermostat cluster ─────────────────────────────────────────────────────
  final int? localTempCenti;      // °C × 100; null sentinel −32768
  final int? heatingSetptCenti;
  final int? coolingSetptCenti;
  final int? systemMode;          // 0=Off 1=Auto 3=Cool 4=Heat …
  final int? controlSequence;     // ControlSequenceOfOperation

  // ── Measurement clusters ───────────────────────────────────────────────────
  final int? humidityCenti;       // 0.01 % RH; null sentinel 0xFFFF
  final int? tempMeasureCenti;    // from Temperature Measurement (not Thermostat)

  // ── Power Source / battery ─────────────────────────────────────────────────
  final int? batPercentRaw;       // 0–200 (divide by 2 for %)
  final int? batChargeLevel;      // 0=OK 1=Warning 2=Critical

  // ── Binary sensors ─────────────────────────────────────────────────────────
  final int?  occupancy;          // bitmap8; bit 0 = 1 → occupied
  final bool? contactState;       // true = contact (closed)

  // ── Air quality ────────────────────────────────────────────────────────────
  /// AirQualityEnum: 0=Unknown 1=Good 2=Fair 3=Moderate 4=Poor 5=VeryPoor 6=ExtremelyPoor
  final int? airQuality;

  // ── Basic info (read once, not subscribed) ─────────────────────────────────
  final String? productName;
  final String? vendorName;
  final String? vendorId;
  final String? productId;
  final String? hwVersion;
  final String? serialNumber;
  final String? softwareVersion;    // human-readable string, e.g. "1.2.0-s1"
  final int?    softwareVersionNum; // uint32 from BasicInformation (for DCL comparison)
  final String? manufacturingDate;
  final String? partNumber;
  final String? productUrl;
  final String? uniqueId;

  // ── Optional-cluster flags (checked once after commissioning) ──────────────
  final bool?   otaSupported; // null = not yet checked
  final int?    otaEndpoint;  // endpoint where OTA Requestor was found

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
    this.otaSupported,
    this.otaEndpoint,
  });

  // ── copyWith ───────────────────────────────────────────────────────────────
  //
  // Nullable fields use [_keep] as a default so callers can distinguish
  // "don't change this field" from "set this field to null".
  //
  //   data.copyWith(isOn: true)      // sets isOn = true, everything else kept
  //   data.copyWith(isOn: null)      // sets isOn = null
  //   data.copyWith()                // returns identical copy
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
    Object?   productName      = _keep,
    Object?   vendorName       = _keep,
    Object?   vendorId         = _keep,
    Object?   productId        = _keep,
    Object?   hwVersion        = _keep,
    Object?   serialNumber     = _keep,
    Object?   softwareVersion  = _keep,
    Object?   softwareVersionNum = _keep,
    Object?   manufacturingDate = _keep,
    Object?   partNumber       = _keep,
    Object?   productUrl       = _keep,
    Object?   uniqueId         = _keep,
    Object?   otaSupported     = _keep,
    Object?   otaEndpoint      = _keep,
  }) {
    // Helper: return existing value if caller passed _keep, otherwise cast.
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
      productName:       v(productName,       this.productName),
      vendorName:        v(vendorName,        this.vendorName),
      vendorId:          v(vendorId,          this.vendorId),
      productId:         v(productId,         this.productId),
      hwVersion:         v(hwVersion,         this.hwVersion),
      serialNumber:      v(serialNumber,      this.serialNumber),
      softwareVersion:   v(softwareVersion,   this.softwareVersion),
      softwareVersionNum:v(softwareVersionNum,this.softwareVersionNum),
      manufacturingDate: v(manufacturingDate, this.manufacturingDate),
      partNumber:        v(partNumber,        this.partNumber),
      productUrl:        v(productUrl,        this.productUrl),
      uniqueId:          v(uniqueId,          this.uniqueId),
      otaSupported:      v(otaSupported,      this.otaSupported),
      otaEndpoint:       v(otaEndpoint,       this.otaEndpoint),
    );
  }

  // ── Targeted update helpers (all delegate to copyWith) ────────────────────

  DeviceLiveData markStale() => copyWith(isStale: true);

  DeviceLiveData withOtaSupported(bool value, int endpoint) => copyWith(
    otaSupported: value,
    otaEndpoint:  value ? endpoint : null,
  );

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
  }) =>
      copyWith(
        serialNumber:      serial,
        softwareVersion:   swVersion,
        softwareVersionNum:swVersionNum ?? this.softwareVersionNum,
        productName:       product,
        vendorName:        vendorName       ?? this.vendorName,
        vendorId:          vendorId         ?? this.vendorId,
        productId:         productId        ?? this.productId,
        hwVersion:         hwVersion        ?? this.hwVersion,
        manufacturingDate: manufacturingDate ?? this.manufacturingDate,
        partNumber:        partNumber       ?? this.partNumber,
        productUrl:        productUrl       ?? this.productUrl,
        uniqueId:          uniqueId         ?? this.uniqueId,
      );

  // ── Merge incoming subscription map ───────────────────────────────────────

  /// Returns a new [DeviceLiveData] with subscription [update] values merged in.
  /// Keys absent from [update] retain their current values; basic-info fields
  /// (productName, vendorId, etc.) are always preserved.
  DeviceLiveData merge(Map<String, dynamic> update) {
    // Returns _keep when the key is absent so copyWith leaves the field alone.
    Object? pick(String key) =>
        update.containsKey(key) ? update[key] : _keep;
    return copyWith(
      updatedAt:        DateTime.now(),
      isStale:          false,
      isOn:             pick('onOff'),
      levelRaw:         pick('level'),
      localTempCenti:   pick('localTempCenti'),
      heatingSetptCenti:pick('heatingSetptCenti'),
      coolingSetptCenti:pick('coolingSetptCenti'),
      systemMode:       pick('systemMode'),
      controlSequence:  pick('controlSequence'),
      humidityCenti:    pick('humidityCenti'),
      tempMeasureCenti: pick('tempMeasureCenti'),
      batPercentRaw:    pick('batPercentRaw'),
      batChargeLevel:   pick('batChargeLevel'),
      occupancy:        pick('occupancy'),
      contactState:     pick('contactState'),
      airQuality:       pick('airQuality'),
      // Basic-info fields are never overwritten by subscription events.
    );
  }

  /// Creates a fresh [DeviceLiveData] seeded only from a subscription update map.
  factory DeviceLiveData.fromUpdate(Map<String, dynamic> update) =>
      DeviceLiveData(updatedAt: DateTime.now(), isStale: false)
          .merge(update);

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
