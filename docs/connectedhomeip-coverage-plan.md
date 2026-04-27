# Plan: Native Reimplementations of connectedhomeip SDK Features

## How this was found

`MatterBridge.openCommissioningWindow` contains this comment:

> *"Build an OnboardingPayload and use the SDK's own generators for both codes.
> This guarantees the manual code uses the correct Verhoeff check digit and
> the QR code uses the correct base-38 encoding — **no custom implementations needed**."*

That comment points directly at two files that should no longer exist.

---

## Finding 1 — `MatterQrCode.kt` is dead code duplicating the CHIP SDK

**File:** `android/app/src/main/kotlin/com/fluxhome/app/chip/MatterQrCode.kt`

### What it does

Manually implements the full Matter QR code encoding pipeline from
Matter Core Spec §5.1.4.1:

- Bit-packs `version / VID / PID / CustomFlow / DiscoveryCapabilities /
  discriminator / passcode / padding` into an 88-bit (11-byte) buffer
- Base38-encodes the buffer (custom alphabet, 3-byte chunks → 5 chars)
- Prepends `"MT:"`

This is ~70 lines of custom bit-manipulation and encoding.

### What the CHIP SDK already provides

```kotlin
// From matter.onboardingpayload — already in the .aar
val qrCode = "MT:" + QRCodeOnboardingPayloadGenerator(payload).payloadBase38Representation()
```

### Is `MatterQrCode` actually called anywhere?

**No.** A grep across the entire Android source confirms the object is defined
but never imported or called. `MatterBridge.openCommissioningWindow` already
uses `QRCodeOnboardingPayloadGenerator` directly.

### Action

Delete `MatterQrCode.kt`.

---

## Finding 2 — `MatterManualCode.kt` is dead code duplicating the CHIP SDK

**File:** `android/app/src/main/kotlin/com/fluxhome/app/chip/MatterManualCode.kt`

### What it does

Manually implements the 11-digit Matter manual pairing code (Matter Core Spec §5.1.4),
including a full Verhoeff check-digit implementation with three lookup tables
(`D`, `P`, `INV`). The file's own comment says:

> *"Same tables and iteration order as the CHIP SDK:
> `src/setup_payload/ManualSetupPayloadGenerator.cpp`"*

This is ~80 lines of crypto-style table-driven arithmetic.

### What the CHIP SDK already provides

```kotlin
// From matter.onboardingpayload — already in the .aar
val manualCode = ManualOnboardingPayloadGenerator(payload).payloadDecimalStringRepresentation()
```

### Is `MatterManualCode` actually called anywhere?

**No.** Same situation as `MatterQrCode` — never imported or invoked.
`MatterBridge.openCommissioningWindow` already uses
`ManualOnboardingPayloadGenerator` directly.

### Action

Delete `MatterManualCode.kt`.

---

## Finding 3 — `chip-stub` is missing stubs for the generators it now needs

**File:** `android/chip-stub/src/main/kotlin/matter/onboardingpayload/OnboardingPayload.kt`

### The gap

`MatterBridge.kt` imports three classes that are absent from the stub module:

| Imported symbol | Present in chip-stub? |
|---|---|
| `matter.onboardingpayload.ManualOnboardingPayloadGenerator` | ❌ |
| `matter.onboardingpayload.QRCodeOnboardingPayloadGenerator` | ❌ |
| `matter.onboardingpayload.CommissioningFlow` | ❌ |

The stub currently only contains `OnboardingPayload`, `OnboardingPayloadParser`,
and `DiscoveryCapability`.

Building with the stub instead of the real `.aar` will fail with
`Unresolved reference` errors at the `MatterBridge.kt` imports.

### Action

Add stub classes for the three missing symbols:

```kotlin
// in matter/onboardingpayload/OnboardingPayload.kt

enum class CommissioningFlow(val value: Int) {
    STANDARD(0), USER_ACTION_REQUIRED(1), CUSTOM(2)
}

class QRCodeOnboardingPayloadGenerator(private val payload: OnboardingPayload) {
    fun payloadBase38Representation(): String = throw ChipSdkStubException()
}

class ManualOnboardingPayloadGenerator(private val payload: OnboardingPayload) {
    fun payloadDecimalStringRepresentation(): String = throw ChipSdkStubException()
}
```

The stub constructor of `OnboardingPayload` also needs to match the positional
form used in `MatterBridge.kt`:
`OnboardingPayload(version, vendorId, productId, commissioningFlow, discoveryCapabilities, discriminator, hasShortDiscriminator, setupPinCode)`.

---

## Finding 4 (bug) — `MatterBridge.readThermostat` silently truncates 8 fields

**File:** `android/app/src/main/kotlin/com/fluxhome/app/MatterBridge.kt`
**Line:** ~850

### The gap

`ThermostatCluster.readThermostat` reads and returns **13 fields**:

```
localTemp, heatingSetpoint, coolingSetpoint, systemMode, controlSequence,
minHeatSetpt, maxHeatSetpt, minCoolSetpt, maxCoolSetpt,
absMinHeatSetpt, absMaxHeatSetpt, absMinCoolSetpt, absMaxCoolSetpt
```

But `MatterBridge.readThermostat` only forwards **5 of them** back to Dart:

```kotlin
result.success(mapOf(
    "localTemp"       to ...,
    "heatingSetpoint" to ...,
    "coolingSetpoint" to ...,
    "systemMode"      to ...,
    "controlSequence" to ...,
    // ← 8 setpoint-limit fields silently dropped here
))
```

The Dart side (`MatterChannel.dart`) already reads all 13 fields via `get(...)`,
but the absent keys always decode as `null`. As a result, `ThermostatState`
always has `minHeatSetptCenti = null`, `maxHeatSetptCenti = null`, etc., and
the thermostat dial falls back to hard-coded 5 °C / 35 °C limits instead of
using the device's own reported range.

### Fix

Pass all 13 keys through the bridge:

```kotlin
result.success(mapOf(
    "localTemp"       to (data["localTemp"]       ?: Int.MIN_VALUE),
    "heatingSetpoint" to (data["heatingSetpoint"] ?: Int.MIN_VALUE),
    "coolingSetpoint" to (data["coolingSetpoint"] ?: Int.MIN_VALUE),
    "systemMode"      to (data["systemMode"]      ?: -1),
    "controlSequence" to (data["controlSequence"] ?: -1),
    "minHeatSetpt"    to (data["minHeatSetpt"]    ?: Int.MIN_VALUE),
    "maxHeatSetpt"    to (data["maxHeatSetpt"]    ?: Int.MIN_VALUE),
    "minCoolSetpt"    to (data["minCoolSetpt"]    ?: Int.MIN_VALUE),
    "maxCoolSetpt"    to (data["maxCoolSetpt"]    ?: Int.MIN_VALUE),
    "absMinHeatSetpt" to (data["absMinHeatSetpt"] ?: Int.MIN_VALUE),
    "absMaxHeatSetpt" to (data["absMaxHeatSetpt"] ?: Int.MIN_VALUE),
    "absMinCoolSetpt" to (data["absMinCoolSetpt"] ?: Int.MIN_VALUE),
    "absMaxCoolSetpt" to (data["absMaxCoolSetpt"] ?: Int.MIN_VALUE),
))
```

---

## Finding 5 (bug) — `SubscriptionManager` is missing subscription paths for 6 actuator attributes

**File:** `android/app/src/main/kotlin/com/fluxhome/app/chip/clusters/SubscriptionManager.kt`

### The gap

`extractAttrs()` knows how to decode updates for these clusters:

| Cluster | Attribute | Key emitted |
|---|---|---|
| WindowCovering (0x0102) | CurrentPositionLiftPercent100ths | `liftPercent100ths` |
| FanControl (0x0202) | FanMode | `fanMode` |
| FanControl (0x0202) | PercentCurrent | `fanPercent` |
| ColorControl (0x0300) | ColorTemperatureMireds | `colorTempMireds` |
| SmokeCoAlarm (0x005C) | SmokeState | `smokeState` |
| SmokeCoAlarm (0x005C) | COState | `coState` |

But `buildPaths()` never subscribes to any of these attribute paths.
The report callback will never deliver these fields — so window covers,
fans, color-temp lights, and smoke detectors never receive live subscription
updates. Their UI only refreshes when the user navigates to the device
detail screen and a one-shot cluster read happens.

### Fix

Add the six missing paths to `buildPaths()`:

```kotlin
// Window covering position
wep(WindowCovering.ID,  WindowCovering.Attribute.CurrentPositionLiftPercent100ths.id),
// Fan
wep(FanControl.ID,      FanControl.Attribute.FanMode.id),
wep(FanControl.ID,      FanControl.Attribute.PercentCurrent.id),
// Color temperature
wep(ColorControl.ID,    ColorControl.Attribute.ColorTemperatureMireds.id),
// Smoke / CO alarm
wep(SmokeCoAlarm.ID,    SmokeCoAlarm.Attribute.SmokeState.id),
wep(SmokeCoAlarm.ID,    SmokeCoAlarm.Attribute.COState.id),
```

The required `ClusterIDMapping` imports for these are already present in the
`SubscriptionManager.kt` import block.

---

## Execution order

| Priority | Finding | Files touched | Risk |
|---|---|---|---|
| 1 — Delete | `MatterQrCode.kt` | 1 file deleted | Zero (dead code) |
| 2 — Delete | `MatterManualCode.kt` | 1 file deleted | Zero (dead code) |
| 3 — Add stubs | `chip-stub` missing generators | 1 file edited | Low (compile-time only) |
| 4 — Fix bug | Bridge truncates thermostat | `MatterBridge.kt` | Low (additive change) |
| 5 — Fix bug | Missing subscription paths | `SubscriptionManager.kt` | Low (additive paths) |

Findings 1 and 2 are pure deletions with no callers to update — safest changes
in the codebase. Do them first.
