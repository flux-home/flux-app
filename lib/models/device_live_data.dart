import 'thermostat_models.dart';

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
  final String? softwareVersion;       // human-readable string, e.g. "1.2.0-s1"
  final int?    softwareVersionNum;    // uint32 from BasicInformation (for DCL comparison)
  final String? manufacturingDate;
  final String? partNumber;
  final String? productUrl;
  final String? uniqueId;

  // ── Optional-cluster flags (checked once after commissioning) ──────────────
  /// null = not yet checked, true = OTA Requestor cluster present on EP0
  final bool?   otaSupported;
  /// The endpoint on which the OTA Requestor cluster was found. Null when
  /// [otaSupported] is null or false.
  final int?    otaEndpoint;

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

  // ── Derived helpers ────────────────────────────────────────────────────────

  /// Convenience: build a [ThermostatState] if thermostat attributes are present.
  ThermostatState? get thermoState {
    if (localTempCenti == null && heatingSetptCenti == null) return null;
    return ThermostatState(
      localTempCenti:    _nullSentinel16(localTempCenti),
      heatingSetptCenti: _nullSentinel16(heatingSetptCenti),
      coolingSetptCenti: _nullSentinel16(coolingSetptCenti),
      systemMode:        systemMode == -1 ? null : systemMode,
      controlSequence:   controlSequence == -1 ? null : controlSequence,
    );
  }

  /// Battery percent 0–100 derived from raw (0–200) value.
  int? get batPercent =>
      batPercentRaw != null ? (batPercentRaw! ~/ 2) : null;

  /// Convenience: build a [BatteryInfo] if any battery attribute is present.
  BatteryInfo? get batteryInfo {
    if (batPercent == null && batChargeLevel == null) return null;
    return BatteryInfo(percent: batPercent, chargeLevel: batChargeLevel);
  }

  static int? _nullSentinel16(int? v) =>
      (v == null || v == -32768 || v == 0x8000) ? null : v;

  // ── Merge incoming subscription map ───────────────────────────────────────

  /// Returns a new [DeviceLiveData] with [update] values merged in.
  /// Fields not present in [update] retain their current values.
  DeviceLiveData merge(Map<String, dynamic> update) {
    T? pick<T>(String key, T? fallback) {
      if (update.containsKey(key)) return update[key] as T?;
      return fallback;
    }
    return DeviceLiveData(
      updatedAt:        DateTime.now(),
      isStale:          false,
      isOn:             pick('onOff',            isOn),
      levelRaw:         pick('level',            levelRaw),
      localTempCenti:   pick('localTempCenti',   localTempCenti),
      heatingSetptCenti:pick('heatingSetptCenti',heatingSetptCenti),
      coolingSetptCenti:pick('coolingSetptCenti',coolingSetptCenti),
      systemMode:       pick('systemMode',       systemMode),
      controlSequence:  pick('controlSequence',  controlSequence),
      humidityCenti:    pick('humidityCenti',    humidityCenti),
      tempMeasureCenti: pick('tempMeasureCenti', tempMeasureCenti),
      batPercentRaw:    pick('batPercentRaw',    batPercentRaw),
      batChargeLevel:   pick('batChargeLevel',   batChargeLevel),
      occupancy:        pick('occupancy',        occupancy),
      contactState:     pick('contactState',     contactState),
      airQuality:       pick('airQuality',       airQuality),
      // basic info passthrough
      productName: productName, vendorName: vendorName, vendorId: vendorId,
      productId: productId, hwVersion: hwVersion, serialNumber: serialNumber,
      softwareVersion: softwareVersion, softwareVersionNum: softwareVersionNum,
      manufacturingDate: manufacturingDate,
      partNumber: partNumber, productUrl: productUrl, uniqueId: uniqueId,
      otaSupported: otaSupported,
      otaEndpoint: otaEndpoint,
    );
  }

  DeviceLiveData markStale() => DeviceLiveData(
    updatedAt: updatedAt, isStale: true,
    isOn: isOn, levelRaw: levelRaw,
    localTempCenti: localTempCenti, heatingSetptCenti: heatingSetptCenti,
    coolingSetptCenti: coolingSetptCenti, systemMode: systemMode,
    controlSequence: controlSequence, humidityCenti: humidityCenti,
    tempMeasureCenti: tempMeasureCenti, batPercentRaw: batPercentRaw,
    batChargeLevel: batChargeLevel, occupancy: occupancy,
    contactState: contactState, airQuality: airQuality,
    productName: productName, vendorName: vendorName, vendorId: vendorId,
    productId: productId, hwVersion: hwVersion, serialNumber: serialNumber,
    softwareVersion: softwareVersion, softwareVersionNum: softwareVersionNum,
    manufacturingDate: manufacturingDate,
    partNumber: partNumber, productUrl: productUrl, uniqueId: uniqueId,
    otaSupported: otaSupported,
    otaEndpoint: otaEndpoint,
  );

  DeviceLiveData withBasicInfo(String? serial, String? swVersion, String? product,
      {String? vendorName, String? vendorId, String? productId,
       String? hwVersion, String? manufacturingDate, String? partNumber,
       String? productUrl, String? uniqueId, int? swVersionNum}) =>
    DeviceLiveData(
      updatedAt: updatedAt, isStale: isStale,
      isOn: isOn, levelRaw: levelRaw,
      localTempCenti: localTempCenti, heatingSetptCenti: heatingSetptCenti,
      coolingSetptCenti: coolingSetptCenti, systemMode: systemMode,
      controlSequence: controlSequence, humidityCenti: humidityCenti,
      tempMeasureCenti: tempMeasureCenti, batPercentRaw: batPercentRaw,
      batChargeLevel: batChargeLevel, occupancy: occupancy,
      contactState: contactState, airQuality: airQuality,
      serialNumber: serial, softwareVersion: swVersion,
      softwareVersionNum: swVersionNum ?? this.softwareVersionNum,
      productName: product,
      vendorName: vendorName ?? this.vendorName,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      hwVersion: hwVersion ?? this.hwVersion,
      manufacturingDate: manufacturingDate ?? this.manufacturingDate,
      partNumber: partNumber ?? this.partNumber,
      productUrl: productUrl ?? this.productUrl,
      uniqueId: uniqueId ?? this.uniqueId,
      otaSupported: otaSupported,
      otaEndpoint: otaEndpoint,
    );

  DeviceLiveData withOtaSupported(bool value, int endpoint) => DeviceLiveData(
    updatedAt: updatedAt, isStale: isStale,
    isOn: isOn, levelRaw: levelRaw,
    localTempCenti: localTempCenti, heatingSetptCenti: heatingSetptCenti,
    coolingSetptCenti: coolingSetptCenti, systemMode: systemMode,
    controlSequence: controlSequence, humidityCenti: humidityCenti,
    tempMeasureCenti: tempMeasureCenti, batPercentRaw: batPercentRaw,
    batChargeLevel: batChargeLevel, occupancy: occupancy,
    contactState: contactState, airQuality: airQuality,
    productName: productName, vendorName: vendorName, vendorId: vendorId,
    productId: productId, hwVersion: hwVersion, serialNumber: serialNumber,
    softwareVersion: softwareVersion, softwareVersionNum: softwareVersionNum,
    manufacturingDate: manufacturingDate,
    partNumber: partNumber, productUrl: productUrl, uniqueId: uniqueId,
    otaSupported: value,
    otaEndpoint: value ? endpoint : null,
  );

  factory DeviceLiveData.fromUpdate(Map<String, dynamic> update) {
    T? pick<T>(String key) =>
        update.containsKey(key) ? update[key] as T? : null;
    return DeviceLiveData(
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
    );
  }
}
