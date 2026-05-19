package com.fluxhome.app.chip.clusters

/**
 * Canonical subscription-event attribute key names.
 *
 * These are the string keys emitted by [SubscriptionManager.extractAttrs] on
 * the Kotlin side and consumed by [DeviceLiveData] on the Dart side.  A
 * matching mirror lives in `lib/services/subscription_keys.dart`.
 *
 * Rule: every rename here must be reflected in the Dart mirror and vice versa.
 * Adding a new attribute: add here, add to [SubscriptionManager.extractAttrs],
 * add to [SubscriptionManager.buildAttributePaths], then add to
 * `DeviceLiveData` (new accessor) and `_kLiveRenderers` in `cluster_parser.dart`.
 */
internal object SubscriptionKeys {
    // ── On/Off + Level ────────────────────────────────────────────────────────
    const val ON_OFF                    = "onOff"
    const val LEVEL                     = "level"

    // ── Thermostat ────────────────────────────────────────────────────────────
    const val LOCAL_TEMP_CENTI          = "localTempCenti"
    const val HEATING_SETPT_CENTI       = "heatingSetptCenti"
    const val COOLING_SETPT_CENTI       = "coolingSetptCenti"
    const val SYSTEM_MODE               = "systemMode"
    const val CONTROL_SEQUENCE          = "controlSequence"

    // ── Sensors ───────────────────────────────────────────────────────────────
    const val HUMIDITY_CENTI            = "humidityCenti"
    const val TEMP_MEASURE_CENTI        = "tempMeasureCenti"
    const val BAT_PERCENT_RAW           = "batPercentRaw"
    const val BAT_CHARGE_LEVEL          = "batChargeLevel"
    const val OCCUPANCY                 = "occupancy"
    const val CONTACT_STATE             = "contactState"
    const val AIR_QUALITY               = "airQuality"
    const val PM25                      = "pm25"
    const val CO2_PPM                   = "co2Ppm"
    const val CO_PPM                    = "coPpm"

    // ── Window Covering ───────────────────────────────────────────────────────
    const val LIFT_PERCENT_100THS       = "liftPercent100ths"

    // ── Fan ───────────────────────────────────────────────────────────────────
    const val FAN_MODE                  = "fanMode"
    const val FAN_PERCENT               = "fanPercent"

    // ── Color ─────────────────────────────────────────────────────────────────
    const val COLOR_TEMP_MIREDS         = "colorTempMireds"

    // ── Smoke/CO Alarm ────────────────────────────────────────────────────────
    const val SMOKE_STATE               = "smokeState"
    const val CO_STATE                  = "coState"

    // ── Door Lock (0x0101) ─────────────────────────────────────────────────
    // LockState: 0=NotFullyLocked  1=Locked  2=Unlocked  3=Unlatched  null=unknown
    // DoorState: 0=Open  1=Closed  2=Jammed  3=ForcedOpen  4=Error  5=Ajar  (DPS feature)
    const val LOCK_STATE                = "lockState"
    const val DOOR_STATE                = "doorState"

    // ── Switch ────────────────────────────────────────────────────────────────
    const val SWITCH_CURRENT_POSITION   = "switchCurrentPosition"
    const val SWITCH_CURRENT_ENDPOINT   = "switchCurrentEndpoint"
    const val SWITCH_LAST_POSITION      = "switchLastPosition"
    const val SWITCH_LAST_ENDPOINT      = "switchLastEndpoint"
    const val SWITCH_PRESS_TIME         = "switchPressTime"

    // ── Electrical Power Measurement (0x0090) ─────────────────────────────────
    const val ACTIVE_POWER              = "activePower"
    const val VOLTAGE                   = "voltage"
    const val ACTIVE_CURRENT            = "activeCurrent"

    // ── Electrical Energy Measurement (0x0091) ────────────────────────────────
    const val CUMULATIVE_ENERGY_WH           = "cumulativeEnergyWh"
    const val CUMULATIVE_ENERGY_EXPORTED_WH  = "cumulativeEnergyExportedWh"

    // ── Envelope keys (stripped before storing in DeviceLiveData.attrs) ──────
    const val NODE_ID                   = "nodeId"
    const val TYPE                      = "type"
}
