/// Canonical subscription-event attribute key names.
///
/// These are the string keys emitted by SubscriptionManager.extractAttrs on
/// the Kotlin side and consumed by [DeviceLiveData] on the Dart side.  A
/// matching mirror lives in
/// `android/.../chip/clusters/SubscriptionKeys.kt`.
///
/// Rule: every rename here must be reflected in the Kotlin mirror.
/// Adding a new attribute: add here, then add to SubscriptionKeys.kt,
/// SubscriptionManager.extractAttrs, SubscriptionManager.buildAttributePaths,
/// DeviceLiveData (new accessor), and _kLiveRenderers in cluster_parser.dart.
abstract final class SubscriptionKeys {
  // ── On/Off + Level ──────────────────────────────────────────────────────────
  static const String onOff                 = 'onOff';
  static const String level                 = 'level';

  // ── Thermostat ──────────────────────────────────────────────────────────────
  static const String localTempCenti        = 'localTempCenti';
  static const String heatingSetptCenti     = 'heatingSetptCenti';
  static const String coolingSetptCenti     = 'coolingSetptCenti';
  static const String systemMode            = 'systemMode';
  static const String controlSequence       = 'controlSequence';

  // ── Sensors ─────────────────────────────────────────────────────────────────
  static const String humidityCenti         = 'humidityCenti';
  static const String tempMeasureCenti      = 'tempMeasureCenti';
  static const String batPercentRaw         = 'batPercentRaw';
  static const String batChargeLevel        = 'batChargeLevel';
  static const String occupancy             = 'occupancy';
  static const String contactState          = 'contactState';
  static const String airQuality            = 'airQuality';
  static const String pm25                  = 'pm25';
  static const String co2Ppm                = 'co2Ppm';
  static const String coPpm                 = 'coPpm';

  // ── Window Covering ─────────────────────────────────────────────────────────
  static const String liftPercent100ths     = 'liftPercent100ths';

  // ── Fan ─────────────────────────────────────────────────────────────────────
  static const String fanMode               = 'fanMode';
  static const String fanPercent            = 'fanPercent';

  // ── Color ────────────────────────────────────────────────────────────────────
  static const String colorTempMireds       = 'colorTempMireds';

  // ── Smoke/CO Alarm ──────────────────────────────────────────────────────────
  static const String smokeState            = 'smokeState';
  static const String coState               = 'coState';

  // ── Door Lock (0x0101) ───────────────────────────────────────────────────
  // LockState: 0=NotFullyLocked 1=Locked 2=Unlocked 3=Unlatched (null = moving)
  // DoorState: 0=Open 1=Closed 2=Jammed 3=ForcedOpen 4=Error 5=Ajar (DPS feature)
  static const String lockState             = 'lockState';
  static const String doorState             = 'doorState';

  // ── Switch ──────────────────────────────────────────────────────────────────
  static const String switchCurrentPosition = 'switchCurrentPosition';
  static const String switchCurrentEndpoint = 'switchCurrentEndpoint';
  static const String switchLastPosition    = 'switchLastPosition';
  static const String switchLastEndpoint    = 'switchLastEndpoint';
  static const String switchPressTime       = 'switchPressTime';

  // ── Electrical Power Measurement (0x0090) ───────────────────────────────────
  static const String activePower           = 'activePower';
  static const String voltage               = 'voltage';
  static const String activeCurrent         = 'activeCurrent';

  // ── Electrical Energy Measurement (0x0091) ──────────────────────────────────
  static const String cumulativeEnergyWh         = 'cumulativeEnergyWh';
  static const String cumulativeEnergyExportedWh  = 'cumulativeEnergyExportedWh';
}
