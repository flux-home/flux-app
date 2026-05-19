# Architectural follow-ups

Open improvement items that are not actively blocking development. None of
these are required for the app to build, ship, or be understood.

These survived an audit in May 2026 that deleted ~3,500 LOC of half-finished
extraction work (see `git log --grep="refactor:"`). The items here are the
remaining valid suggestions from the earlier `ARCHITECTURE_REVIEW.md` and
`REFACTORING_PLAN.md`, which were both deleted because they described a
target state that we are explicitly not pursuing.

---

## 1. `cluster_parser.dart` has two parallel rendering pipelines

`lib/services/cluster_parser.dart` (~975 LOC) contains:

- `_readingFromCluster()` — renders one-shot JSON-read cluster data via
  cluster IDs (e.g. `0x0402` for temperature).
- `_kLiveRenderers` — renders subscription-driven attributes via string
  keys (e.g. `'tempMeasureCenti'`).

Both produce `ClusterReading`s and both hard-code identical thresholds
(PM2.5 12/35.4/55.4, CO₂ 800/1500/2500, …). When a new sensor is added,
both pipelines must be updated or they drift.

The file also imports `package:flutter/material.dart` for `IconData` /
`Color`, so it can't be unit-tested without a Flutter test harness.

**Suggested shape.** A `ClusterSpec` registry — one entry per attribute
giving icon, colour rule, thresholds, label, unit — that both pipelines
look up. Split into a pure-Dart `cluster_parser.dart` (no Flutter import)
and a thin `cluster_renderer.dart` that constructs `ClusterReading`s.

## 2. Static persistence singletons

`ThreadSettingsService` and `QrPayloadService` expose `static` methods
backed by `SharedPreferences.getInstance()`. Persistence calls are
scattered across 15+ sites in screens, controllers, and the commission
flow. There's no way to inject a mock for testing.

**Suggested shape.** Instance-based, constructed in `main.dart` from an
opened `SharedPreferences`, registered in `MultiProvider`, accessed via
`context.read<…>()`. Tests use `SharedPreferences.setMockInitialValues()`.

## 3. Mega screen files

| File | LOC | Note |
|---|---|---|
| `lib/ui/screens/commission_screen.dart` | 2,111 | 13 private widget classes |
| `lib/ui/screens/device_settings_screen.dart` | 1,858 | 11 private widget classes |
| `lib/ui/screens/network_check_screen.dart` | 1,207 |  9 private widget classes |
| `lib/ui/screens/cluster_inspector_screen.dart` |   900 |  7 private widget classes |

For grep-and-AI navigation, "what does `_DatasetPickerSheet` do?" returning
2,111 unrelated lines is friction.

**Suggested shape.** Use the same `part`/`part of` pattern already used by
`device_detail_screen.dart` (10 sibling files stitched into one compilation
unit). This preserves `_`-prefixed-type privacy and access to the host
`State`'s private fields, so the migration is mechanical rather than
requiring data-flow redesign. A prior attempt to extract these as fully
standalone classes left ~2,600 LOC of unused parallel copies and was
reverted (see `git log` for the deletions).

## 4. Inconsistent optimistic-update strategy in `DeviceProvider`

`toggle()` does an optimistic update with rollback on failure.
`setBrightness`, `coveringGoToLift`, `setFanMode`, `setFanPercent`,
`setColorTemperature` do optimistic updates **without** rollback —
silent failures can leave the UI showing the wrong value.

`ARCHITECTURE.md` says "Subscription is source of truth. Never use
optimistic caching for on/off/sensor state" — which contradicts the
implementation.

**Suggested shape.** Pick one strategy (optimistic-with-rollback for
all, or wait-for-subscription for all) and apply it uniformly. Update
`ARCHITECTURE.md` to match.

## 5. Three writers for device type in `DeviceProvider`

`_inferTypeFromEvent`, `_resolveUnknownDeviceType`, and `_applyStateUpdate`
all mutate `device.deviceType` under different non-symmetric conditions.
No single authority owns the field. (Friction #4 in `ARCHITECTURE.md`.)

**Suggested shape.** A single `resolveDeviceType(MatterDevice, DeviceLiveData)
→ DeviceType` function, called from one place after the live cache merge.

## 6. Test coverage

Tests currently exist only for the smoke path. After this audit the only
test left in the repo is `test/widget_test.dart`. The pure-logic targets
worth covering at the boundary:

- `DeviceProvider.toggle` — optimistic update + rollback.
- `DeviceProvider` rule matching (formerly in the now-deleted
  `AutomationEngine` — git history has a working tested implementation).
- `cluster_parser.parseClusters` / `extractSwitchGroups`.
- Once #1 lands: the `ClusterSpec` registry can be tested headlessly.

Local-substitutable dependencies (`DeviceStore` over `SharedPreferences`)
make this tractable without mocking the platform channel.

---

## In-flight feature work

See `lib/_wip/README.md` for shelved Matter cluster cards (door lock,
water heater, energy) and the matching Kotlin bridges under
`android/app/src/main/kotlin/com/fluxhome/app/{bridge,chip/clusters}/`.
