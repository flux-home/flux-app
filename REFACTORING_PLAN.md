# Flux App — Refactoring Plan

> **Generated:** 2026-03-26  
> **Codebase:** 9,619 LOC across 26 Dart files  
> **Goal:** Deduplicate, harden fragile spots, improve maintainability

---

## Table of Contents

1. [Dead / Unused Code](#1-dead--unused-code)
2. [Duplicated Widgets](#2-duplicated-widgets)
3. [Duplicated Logic](#3-duplicated-logic)
4. [Fragile / Brittle Spots](#4-fragile--brittle-spots)
5. [Monster Files](#5-monster-files)
6. [Architecture Improvements](#6-architecture-improvements)
7. [Prioritised Action Items](#7-prioritised-action-items)

---

## 1. Dead / Unused Code

| What | Where | Notes |
|---|---|---|
| **`OnlineBadge` widget** | `ui/widgets/online_badge.dart` (32 LOC) | Never imported or used anywhere. Delete the file. |
| **`matter_cluster.dart` entire file** | `models/matter_cluster.dart` (116 LOC) | `ClusterAttribute`, `MatterCluster`, and `mockClustersForNode()` are **never imported** by any other file. The cluster inspector uses its own `_ClusterData`/`_AttrData` models. Delete. |
| **`_HeroCard` + `_ToggleSwitch`** | `device_detail_screen.dart` lines 650–730 | Defined but never instantiated. The `_kCardShape` constant on line 650 is also orphaned (device_card.dart has its own copy). Delete both widgets + the constant. |
| **`_EmptyState`** | `home_screen.dart` line 106 | Returns `SizedBox.shrink()` — a no-op placeholder. Inline as `const SizedBox.shrink()` or add real empty-state UI. |
| **`fromJsonString()` / `toJsonString()`** | `matter_device.dart` lines 105–108 | Never called from anywhere. Delete. |
| **`simulationMode` / `setSimulationMode` / `_kSimMode`** | `device_store.dart` lines 11, 55–57 | Legacy simulation mode toggle, never read or written outside the store itself. Delete. |
| **`fabricId` / `setFabricId`** | `device_store.dart` lines 51–53 | `setFabricId` is never called. `fabricId` getter is never read (settings screen calls `MatterChannel().getFabricId()` directly instead). Delete. |
| **`readHumidity()` / `readBattery()`** | `matter_channel.dart` | These one-shot read methods are never called — humidity and battery data now come through subscriptions. Delete. |
| **`_dialGlyphs` + `_dialCharCols`** | `device_detail_screen.dart` lines 983–991 | Duplicate of `dotMatrixGlyphs` / `dotMatrixCharCols` in `dot_matrix_painter.dart`. The dial painter's `_dotMatrix()` method should import and reuse the shared painter's glyph table. |

**Estimated removal: ~400 LOC**

---

## 2. Duplicated Widgets

### 2.1 Section Headers / Labels (×5 copies!)

There are **five independent private implementations** of essentially the same "section label" widget:

| File | Class | Style |
|---|---|---|
| `commission_screen.dart` | `_SectionLabel` | `labelLarge`, primary colour, bold, `letterSpacing: 0.4` |
| `device_settings_screen.dart` | `_SectionLabel` | `labelSmall`, `.toUpperCase()`, `letterSpacing: 1.1` |
| `network_check_screen.dart` | `_SectionLabel` | `labelSmall`, `.toUpperCase()`, `letterSpacing: 1.1` |
| `thread_diag_screen.dart` | `_SectionLabel` | `labelSmall`, `.toUpperCase()`, `letterSpacing: 1.1` |
| `settings_screen.dart` | `_SectionHeader` | `labelSmall`, `.toUpperCase()`, `letterSpacing: 1.1` |

**Action:** Extract a single `SectionLabel` widget into `ui/widgets/section_label.dart` with an optional `style` parameter (compact uppercase vs prominent). Replace all five copies.

### 2.2 Key-Value Info Rows (×4 copies)

| File | Class | Label width |
|---|---|---|
| `device_detail_screen.dart` | `_InfoLine` | 90px |
| `device_settings_screen.dart` | `_InfoRow` | 130px |
| `network_check_screen.dart` | `_InfoRow` | 130px |
| `thread_diag_screen.dart` | `_Row` | 140px |
| `settings_screen.dart` | `_FieldRow` | 140px |
| `qr_payload_detail_screen.dart` | `_FieldRow` | 120px |

All do the exact same thing: label on the left, monospace value on the right, with a fixed-width label column.

**Action:** Extract `InfoRow` into `ui/widgets/info_row.dart` with a configurable `labelWidth` parameter (default 130). Replace all six copies.

### 2.3 Card Shape Constant (×2)

`_kCardShape` is defined identically in both `device_card.dart` and `device_detail_screen.dart` (white border, 20–22px radius).

**Action:** Move to a shared location (e.g. `ui/theme.dart` or a `ui/widgets/constants.dart`). The `_HeroCard` in detail screen is unused (see §1) so after deleting that, only `device_card.dart` needs it — but it's still better as a shared constant.

### 2.4 Dot-Matrix Glyph Table (×2)

`device_detail_screen.dart` has its own copy of the 5×7 glyph table (`_dialGlyphs` at line 983) while `dot_matrix_painter.dart` has the canonical version (`dotMatrixGlyphs`). The dial painter's private `_dotMatrix()` method should reuse the shared table.

**Action:** Refactor `_DialPainter._dotMatrix()` to use `dotMatrixGlyphs` and `dotMatrixCharCols` from `dot_matrix_painter.dart`. Delete the duplicate.

---

## 3. Duplicated Logic

### 3.1 `DeviceLiveData` copy-all-fields boilerplate

`merge()`, `markStale()`, and `withBasicInfo()` all manually enumerate every field. Adding a new sensor attribute means editing **four places** (constructor + these three methods + `fromUpdate`).

**Action:** Consider using `copyWith()` pattern with named parameters (like `MatterDevice` does), or use code generation (`freezed` / `json_serializable`). At minimum, refactor these three methods to share a private `_copyWith()` helper.

### 3.2 `SharedPreferences.getInstance()` called per-operation

`QrPayloadService` and `ThreadSettingsService` call `SharedPreferences.getInstance()` on **every** `load()`/`save()`/`clear()` call. Meanwhile `DeviceStore` correctly gets a singleton at startup.

**Action:** Either pass the `SharedPreferences` instance through (like `DeviceStore` does), or use a top-level lazy singleton. This removes repeated async overhead and makes the code more consistent.

### 3.3 Device lookup by ID repeated everywhere

The pattern `_devices.indexWhere((d) => d.id == deviceId)` appears **13 times** in `DeviceProvider`. Several call sites also do `_devices.firstWhere(…, orElse: …)`.

**Action:** Extract a private `_indexById(String id)` helper that returns the index (or -1). Consider also using a `Map<String, MatterDevice>` as a secondary index for O(1) lookups.

### 3.4 Cluster JSON parsing duplicated

`device_detail_screen.dart` has `_parseClusters()` (lines 553–585) and `cluster_inspector_screen.dart` has nearly identical parsing logic in `_load()` (lines 168–205). Both decode the same JSON shape, group by endpoint, and parse device types from Descriptor.

**Action:** Extract a shared `ParsedClusterData` model and a `parseClustersJson(String)` utility in `services/` or `models/`. Both screens can import it.

---

## 4. Fragile / Brittle Spots

### 4.1 🔴 `_onDeviceStateEvent` — `firstWhere` throws `StateError`

```dart
final device = _devices.firstWhere(
  (d) => d.nodeId == nodeId,
  orElse: () => throw StateError('not found'));
```

If the Android native layer sends an event for a device that has just been removed, this **crashes the app**. The `StateError` is not caught.

**Fix:** Use `firstWhereOrNull` (from `collection` package) or the `try/catch` pattern, and silently ignore events for unknown nodes.

### 4.2 🔴 `matter_channel.dart` is a 933-line god file

This file mixes **12+ unrelated data classes** (`BatteryInfo`, `ParsedPayload`, `CommissionResult`, `DeviceStateResult`, `ThermostatState`, `ThreadBorderRouter`, `PhoneIpv6Check`, `StateBitmapInfo`, `WifiBandInfo`, `VpnInfo`, `BorderRouterDiagnostic`, `NetworkDiagnosticsReport`, `ThreadNeighborInfo`, `ThreadRouteInfo`, `ThreadNetworkDiagnostics`) with the `MatterChannel` platform bridge.

**Risk:** Any change to one data model risks breaking others. Hard to find classes. Hard to test in isolation.

**Fix:** Split into:
- `services/matter_channel.dart` — only the `MatterChannel` class
- `models/commission_models.dart` — `ParsedPayload`, `CommissionResult`, `DeviceStateResult`  
- `models/thermostat_state.dart` — `ThermostatState`, `BatteryInfo`
- `models/thread_models.dart` — `ThreadBorderRouter`, `ThreadNeighborInfo`, `ThreadRouteInfo`, `ThreadNetworkDiagnostics`
- `models/network_diagnostics.dart` — `PhoneIpv6Check`, `WifiBandInfo`, `VpnInfo`, `StateBitmapInfo`, `BorderRouterDiagnostic`, `NetworkDiagnosticsReport`

### 4.3 🟡 `device_detail_screen.dart` — 1,235-line monolith

This is the largest file in the project. It mixes:
- Screen state management
- Cluster JSON parsing + reading logic
- 14 distinct widget classes (`_HeroCard`, `_ToggleSwitch`, `_BrightnessCard`, `_ReadingsSection`, `_ReadingCard`, `_ThermostatCard`, `_ThermostatDial`, `_DialPainter`, `_InfoLine`, `_SensorPill`, `_BatteryPill`, `_ModeSelector`, `_Quality` enum, cluster reading extraction)

**Fix:** Split into:
- `device_detail_screen.dart` — just the screen + state
- `ui/widgets/thermostat_card.dart` — dial + thermostat card
- `ui/widgets/reading_card.dart` — `_ReadingCard` + `_ReadingsSection`
- `ui/widgets/brightness_card.dart` — `_BrightnessCard`
- `services/cluster_parser.dart` — `_parseClusters()`, `_extractReadings()`, reading models

### 4.4 🟡 `settings_screen.dart` — 1,290 lines, 8 classes in one file

Contains `SettingsScreen`, `MatterSettingsScreen`, `ThreadSettingsScreen`, `_ThreadCredentialsScreen`, `_ThreadNetworkScreen`, `_BorderRouterDetailScreen`, `_ThreadDatasetDetailScreen`, `_ThreadDecoder`, plus helper widgets. This is a navigation tree 4 levels deep in a single file.

**Fix:** Split into separate files per screen:
- `settings_screen.dart` — main settings list
- `matter_settings_screen.dart` — fabric / clear-all
- `thread_settings_screen.dart` — network scan + list
- `thread_dataset_detail_screen.dart` — hex editor + decoder

### 4.5 🟡 `network_check_screen.dart` — 1,226 lines

Contains the screen, all diagnostic logic, check-building functions, and UI widgets. The check-building functions (`_brChecks`, `_buildNonBrSections`) are pure business logic mixed in with the UI.

**Fix:** Extract check-building logic into `services/network_check_service.dart`. Keep only UI in the screen file.

### 4.6 🟡 Provider listener leak potential

In `_DeviceDetailScreenState.dispose()`:
```dart
try { _provider.removeListener(_onProviderUpdate); } catch (_) {}
```
The `try/catch` suggests this has failed before. The root cause is that `_provider` uses `context.read()` which can fail after dispose. 

**Fix:** Cache the provider reference in `initState` instead of reading it from context in `dispose`.

### 4.7 🟡 `DeviceProvider` does I/O in constructor

`DeviceProvider` calls `_load()` synchronously and `_startAllSubscriptions()` via `Future.microtask` in its constructor. This means commissioning can race with the initial load. The `_load()` call is synchronous only because `SharedPreferences` was pre-loaded, but this is an implicit contract.

**Fix:** Use an explicit `init()` async method or a `FutureProvider` wrapper to make the initialization lifecycle clear.

### 4.8 🟡 Magic string keys throughout

Subscription event keys (`'onOff'`, `'level'`, `'localTempCenti'`, etc.) are **raw strings** passed between Kotlin and Dart. A typo breaks the pipeline silently.

**Fix:** Define an `EventKeys` class with `static const` fields. Reference these everywhere instead of string literals.

### 4.9 🟡 No error boundary / reporting

Platform exceptions from `MatterChannel` are caught and silently `debugPrint`ed. In production, commissioning failures or cluster read errors give the user no feedback.

**Fix:** Add structured error propagation — return `Result<T, E>` types or throw typed exceptions that the UI can display meaningfully.

---

## 5. Monster Files

| File | LOC | Recommendation |
|---|---|---|
| `settings_screen.dart` | 1,290 | Split into 4 files (see §4.4) |
| `device_detail_screen.dart` | 1,235 | Split into 4 files (see §4.3) |
| `network_check_screen.dart` | 1,226 | Extract logic into service (see §4.5) |
| `matter_channel.dart` | 933 | Extract data classes (see §4.2) |
| `commission_screen.dart` | 877 | OK for now; could extract `_PayloadEntry` / `_NetworkSection` |
| `cluster_inspector_screen.dart` | 639 | OK for now; could extract name maps |
| `thread_diag_screen.dart` | 622 | OK, self-contained |

---

## 6. Architecture Improvements

### 6.1 `MatterChannel` instantiated ad-hoc

`MatterChannel()` is constructed inline in multiple places:
- `main.dart` creates one and provides it via `Provider`
- `CommissionScreen._commission()` creates **new** instances: `MatterChannel().commissionEvents` / `MatterChannel().parsePayload(...)`
- `MatterSettingsScreen.initState` creates a new one: `MatterChannel().getFabricId()`

Since `MatterChannel` has no state (it wraps static `MethodChannel`/`EventChannel`), this works by accident. But it bypasses the DI system and makes future testing/mocking impossible.

**Fix:** Always use `context.read<MatterChannel>()`. The Provider is already set up in `main.dart`.

### 6.2 Mixed navigation patterns

The app uses `go_router` for top-level routes but `Navigator.push(MaterialPageRoute(...))` for sub-screens (device settings, cluster inspector, thread diagnostics, etc.). This means:
- Deep links don't work for sub-screens
- Back-button behavior is inconsistent
- No transition consistency

**Fix:** Either register all screens in `go_router` routes, or at minimum be consistent. The sub-screens pushed via `Navigator.push` could be registered as nested GoRouter routes under `/device/:id/settings`, `/device/:id/clusters`, etc.

### 6.3 No widget tests possible

All business logic (cluster parsing, reading extraction, thread TLV decoding, network check logic) is embedded as private functions inside widget files. None of it is testable without rendering the widget.

**Fix:** Extract pure logic into standalone service/utility files with public APIs.

---

## 7. Prioritised Action Items

### P0 — Fix Bugs / Crashes

| # | Task | Impact | Effort |
|---|---|---|---|
| 1 | Fix `firstWhere` crash in `_onDeviceStateEvent` | App crash on device removal race | 5 min |

### P1 — Remove Dead Code (~400 LOC)

| # | Task | Impact | Effort |
|---|---|---|---|
| 2 | Delete `online_badge.dart` | Unused file | 1 min |
| 3 | Delete `matter_cluster.dart` | Unused file (116 LOC) | 1 min |
| 4 | Delete `_HeroCard`, `_ToggleSwitch`, duplicate `_kCardShape` from `device_detail_screen.dart` | Dead code | 5 min |
| 5 | Delete `fromJsonString`/`toJsonString` from `MatterDevice` | Dead code | 1 min |
| 6 | Delete `simulationMode`/`setSimulationMode` from `DeviceStore` | Dead code | 1 min |
| 7 | Delete `fabricId`/`setFabricId` from `DeviceStore` | Dead code | 1 min |
| 8 | Delete `readHumidity()`/`readBattery()` from `MatterChannel` | Dead code | 2 min |
| 9 | Delete duplicate `_dialGlyphs`/`_dialCharCols`, import from `dot_matrix_painter.dart` | Dedup | 10 min |

### P2 — Extract Shared Widgets (~6 widgets)

| # | Task | Files affected | Effort |
|---|---|---|---|
| 10 | Create `ui/widgets/section_label.dart` | 5 screens | 30 min |
| 11 | Create `ui/widgets/info_row.dart` | 6 screens | 30 min |
| 12 | Move `_kCardShape` to `ui/theme.dart` | 1 file (after P1) | 5 min |

### P3 — Split Monster Files

| # | Task | New files | Effort |
|---|---|---|---|
| 13 | Split `matter_channel.dart` data classes into `models/` | 4 new files | 1 hr |
| 14 | Split `device_detail_screen.dart` into screen + widgets + service | 4 new files | 1.5 hr |
| 15 | Split `settings_screen.dart` into per-screen files | 4 new files | 1 hr |
| 16 | Extract check logic from `network_check_screen.dart` | 1 new file | 45 min |

### P4 — Reduce Fragility

| # | Task | Effort |
|---|---|---|
| 17 | Cache provider ref in `initState` instead of `context.read` in `dispose` | 10 min |
| 18 | Always use `context.read<MatterChannel>()`, never `MatterChannel()` | 15 min |
| 19 | Extract cluster JSON parsing into shared service | 30 min |
| 20 | Add `DeviceLiveData.copyWith()` to eliminate field enumeration | 45 min |
| 21 | Extract `_indexById()` helper in `DeviceProvider` | 15 min |
| 22 | Consolidate `SharedPreferences` access in services | 20 min |

### P5 — Nice-to-haves

| # | Task | Effort |
|---|---|---|
| 23 | Define event key constants for subscription data | 20 min |
| 24 | Register sub-screens in go_router | 1 hr |
| 25 | Replace `_EmptyState` with real empty-state UI | 30 min |
| 26 | Add structured error types for `MatterChannel` calls | 1 hr |

---

## Summary

| Category | Issues | Est. LOC saved |
|---|---|---|
| Dead code removal | 9 items | ~400 |
| Widget dedup | 3 widget families (11 copies → 3) | ~200 |
| Logic dedup | 4 items | ~150 |
| Fragile spots | 9 items | — (resilience gain) |
| File splits | 4 monster files → ~16 focused files | — (readability gain) |
| **Total estimated effort** | | **~10 hours** |
