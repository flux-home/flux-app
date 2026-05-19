# Flux App — Architectural Review

**Focus:** long-term maintainability  
**Date:** 2026-04-27  
**Scope:** Dart layer (`lib/`) post-refactoring — 90 files, 17.3k lines

---

## Executive summary

The app has a clean separation between platform bridge (`MatterChannel`), state
management (`DeviceProvider`), and UI. The port-interface pattern
(`MatterClusterPort`, `MatterFabricPort`, etc.) is excellent — it makes the
native bridge fakeable and keeps screen dependencies narrow. The refactoring
reduced file sizes and eliminated the worst duplication. What follows are the
remaining structural risks that will compound over time if not addressed.

---

## ❶ `DeviceProvider` is still a God Object (833 lines, 7 concerns)

**What it does today:**
1. Device CRUD (add, rename, remove, persist)
2. Room management (create, assign, rename, delete)
3. Live-cache management (merge, flush, snapshot)
4. Subscription lifecycle (start, stop, fallback timers, established tracking)
5. Device control (toggle, brightness, covering, fan, color temp, thermostat)
6. OTA progress tracking
7. Commissioning lifecycle (beginCommissioning, registerCommissionedDevice)

The `AutomationEngine` extraction was a good first step, but the provider
still owns six unrelated domains behind one `notifyListeners()`. This
creates two problems:

- **Rebuild blast radius:** Every `notifyListeners()` call rebuilds every
  `Consumer<DeviceProvider>` in the tree — the home screen, every device
  card, the settings screen. A fan-speed change on device A triggers a
  rebuild of device B's thermostat card.
- **Testing surface area:** You cannot unit-test room management without
  also constructing a `DeviceStore`, a `MatterPort` fake, and wiring up
  a subscription stream.

**Recommendation:** Extract **domain-focused managers** that DeviceProvider
delegates to, similar to AutomationEngine:

| Manager | Owns | Lines saved |
|---|---|---|
| `SubscriptionManager` | `_subscribedNodeIds`, `_establishTimeouts`, `_establishedThisSession`, `_startSubscription`, `_stopSubscription`, `_startAllSubscriptions` | ~80 |
| `DeviceControlService` | `toggle`, `setBrightness`, `stepBrightness`, `coveringUp/Down/Stop`, `setFanMode`, `setFanPercent`, `setColorTemperature`, `_executeAction`, `_adjustSetpoint` | ~120 |
| `RoomManager` | `_rooms`, `createRoom`, `renameRoom`, `deleteRoom`, `assignRoom`, `_persistRooms` | ~60 |

DeviceProvider becomes a thin orchestrator that:
- Holds the canonical device list and live cache
- Delegates to managers
- Calls `notifyListeners()` at the right moments

Priority: **High.** Every new cluster you add (locks, EVSEs, etc.) will add
another control method to the provider. Without splitting now, you'll hit
1,500+ lines within a few months.

---

## ❷ `cluster_parser.dart` has a dual-pipeline problem (975 lines)

This file contains two parallel rendering systems:

1. **`_readingFromCluster()`** — converts `LiveCluster` objects (from a
   one-shot JSON read) into `ClusterReading`s. Uses cluster IDs (e.g.
   `0x0402` for temperature).
2. **`_kLiveRenderers`** — converts subscription-driven attribute keys
   (e.g. `'tempMeasureCenti'`) into `ClusterReading`s.

Both pipelines produce identical output types and duplicate threshold
constants (PM2.5: 12/35.4/55.4, CO₂: 800/1500/2500, etc.). When you add
a new sensor, you must update **both** pipelines or they drift.

Additionally, `cluster_parser.dart` imports `package:flutter/material.dart`
for `IconData` and `Color` — making it untestable without a Flutter test
harness. A service file should not depend on the UI framework.

**Recommendation:**
1. Create a `ClusterSpec` registry with one entry per attribute that both
   pipelines look up.
2. Split the file into:
   - `lib/services/cluster_parser.dart` — pure parsing (`parseClusters`,
     `extractReadings`, `extractSwitchGroups`) — no Flutter imports
   - `lib/services/cluster_renderer.dart` — `ClusterReading` construction
     using `Color` / `IconData` — okay to import `material.dart`
3. Move threshold constants to named values at the top of the renderer.

Priority: **Medium.** Doesn't block features but causes subtle bugs when
thresholds drift between the two pipelines.

---

## ❸ `DeviceView` model has UI-layer imports

```dart
// device_view.dart
import 'package:matter_home/ui/screens/cluster_inspector_screen.dart';
import 'package:matter_home/ui/screens/device_settings_screen.dart';
import 'package:matter_home/ui/screens/thread_diag_screen.dart';
```

These are `show` imports used only in doc comments. They create a dependency
from the **model layer → UI layer**, which:
- Prevents the model from being used in a non-Flutter context (CLI tools, tests)
- Creates import cycles if any screen ever imports `device_view.dart`
  indirectly via a model

**Recommendation:** Remove the `show` imports and replace the doc-comment
references with plain strings (`/// See [ClusterInspectorScreen]` →
`/// See the cluster inspector screen`). Models should never import from
`ui/`.

Priority: **Low** (harmless today, but establishes a bad precedent).

---

## ❹ Screens reach through Provider to call platform ports directly

17 call sites do `context.read<MatterClusterPort>()` or
`context.read<MatterFabricPort>()` directly from screen code to perform
reads/writes (`readBasicInfo`, `writeSystemMode`, `readClusters`,
`identify`, etc.).

This means:
- Business logic (which endpoint to read, what to do with the result) lives
  in widget `State` objects
- The same "load basic info" orchestration in `device_detail_screen.dart`
  can't be reused by another screen
- You can't test the orchestration without widget tests

The architecture doc says *"No logic in screens — business logic belongs in
DeviceProvider."* These call sites violate that rule.

**Recommendation:** Move each platform call into a DeviceProvider method
(or into one of the new domain managers). For example:

```dart
// Before (in screen):
final info = await context.read<MatterClusterPort>().readBasicInfo(view.nodeId);
provider.updateBasicInfo(deviceId, info.productName, info.serialNumber, ...);

// After (in provider):
Future<void> loadBasicInfo(String deviceId) async { ... }
```

The screen just calls `provider.loadBasicInfo(deviceId)`.

Priority: **Medium.** Not urgent but compounds with every new cluster.

---

## ❺ Static service singletons (`ThreadSettingsService`, `QrPayloadService`)

Both services use `static` methods backed by `SharedPreferences.getInstance()`:

```dart
class ThreadSettingsService {
  static Future<String> load() async { ... }
  static Future<void> setActive(String hex) async { ... }
}
```

This pattern:
- Is impossible to fake in tests (no way to inject a mock `SharedPreferences`)
- Creates hidden global state — any screen can call `ThreadSettingsService.load()`
  without declaring the dependency
- Scatters persistence calls across 15+ call sites in screens, controllers,
  and the commission flow

**Recommendation:** Convert to instance-based services registered via Provider:

```dart
// In main.dart
Provider<ThreadSettingsService>(create: (_) => ThreadSettingsService(prefs)),
```

Screens access it via `context.read<ThreadSettingsService>()`. Commission
controller and DeviceProvider take it as a constructor parameter.

Priority: **Medium.** Not blocking but prevents meaningful unit testing.

---

## ❻ `network_diagnostics_engine.dart` still imports Flutter

```dart
import 'package:flutter/material.dart';
```

The file was designed as "pure computation, no Flutter widgets" but needs
`BuildContext` for `diagStatusColor()` and `Icons` for `diagStatusIcon()`.
This makes it impossible to unit-test without a Flutter test harness.

**Recommendation:** Move `diagStatusColor()` and `diagStatusIcon()` to
`diag_widgets.dart` (where they're consumed). The engine file should
return `DiagStatus` enums and let the widget layer map those to colours
and icons.

Priority: **Low** (two functions to move).

---

## ❼ No test coverage for business logic

The test directory contains a single smoke test (theme + channel type check +
empty parser). There are zero tests for:
- `AutomationEngine` (rule matching, switch debounce, contact transitions)
- `DeviceProvider` (toggle optimistic update + rollback, subscription
  lifecycle, snapshot persistence)
- `NetworkDiagnosticsEngine` (border router checks, diagnostic sections)
- `ClusterParser` (reading extraction, switch group building)

These are all pure or near-pure logic with well-defined inputs and outputs.
The `AutomationEngine` extraction was specifically motivated by testability,
but no tests were added.

**Recommendation:** Start with the highest-value targets:

| Target | Why | Effort |
|---|---|---|
| `AutomationEngine` | Complex matching logic, debounce timing, preset generation | Small — pure class, no mocks needed |
| `NetworkDiagnosticsEngine` | 300 lines of branching diagnostic logic | Small — pure functions |
| `ClusterParser.liveReadings` | Threshold logic shared across 12+ sensors | Small — pure function |
| `DeviceProvider.toggle` | Optimistic update + rollback on failure | Medium — needs `DeviceStore` + `MatterPort` fakes |

Priority: **High.** Without tests, the refactoring itself can't be
validated and future changes are risky.

---

## ❽ Inconsistent optimistic caching strategy

The architecture doc says:
> *"Subscription is source of truth. Never use optimistic caching for
> on/off/sensor state."*

But `DeviceProvider.toggle()` does optimistic updates:

```dart
_mergeLiveCache(deviceId, (e) => e.merge({'onOff': newOn}));  // optimistic
final ok = await _channel.toggleDevice(device.nodeId, on: newOn);
if (!ok) {
  _mergeLiveCache(deviceId, (e) => e.merge({'onOff': currentOn}));  // rollback
}
```

And `setBrightness`, `coveringGoToLift`, `setFanMode`, `setFanPercent`,
`setColorTemperature` all do optimistic updates **without** rollback:

```dart
_mergeLiveCache(deviceId, (e) => e.merge({'fanMode': mode}));
await _channel.setFanMode(_devices[idx].nodeId, mode);
// No rollback on failure
```

This creates two problems:
1. Inconsistency: toggle rolls back, everything else doesn't
2. The architecture doc contradicts the implementation

**Recommendation:** Pick one strategy and apply it uniformly:
- **Option A:** Optimistic with rollback (current `toggle()` pattern) for all
  control methods — best UX, more code
- **Option B:** Wait for subscription confirmation — simpler but UI feels
  sluggish on high-latency Thread links

Either way, update the architecture doc to match reality.

Priority: **Medium.** Silent failures (fan set to wrong mode, covering
position wrong) will confuse users.

---

## ❾ `BottomSheetScaffold` was created but never adopted

The `BottomSheetScaffold` widget was created in Phase 1 but none of the
extracted bottom sheets (`ShareBottomSheet`, `RoomPickerSheet`,
`ConnectionDetailSheet`, `AddConnectionSheet`, `WifiCredentialPanel`, etc.)
actually use it. Each still builds its own handle-bar + safe-area + keyboard
padding manually.

**Recommendation:** Migrate the 7+ sheet builders to use
`BottomSheetScaffold` in a follow-up pass.

Priority: **Low** (cosmetic consistency).

---

## ❿ Semantic colour constants created but not adopted

`kColorSuccess`, `kColorFailed`, `kColorWarning` were added to `theme.dart`
but the 30+ inline `Color(0xFF34A853)` and `Colors.green.shade400` call
sites were not updated to use them.

**Recommendation:** Do a search-and-replace pass:
- `Color(0xFF34A853)` → `kColorSuccess` (13 sites)
- `Color(0xFFE53935)` → `kColorFailed` (3 sites)
- `Color(0xFFF9AB00)` → `kColorWarning` (where applicable)

Priority: **Low** (cosmetic, but prevents future drift).

---

## Summary — prioritised action list

| # | Issue | Impact | Effort | Priority |
|---|---|---|---|---|
| 7 | Add tests for AutomationEngine + diagnostics engine | Validates refactoring, gates future changes | S | **High** |
| 1 | Split DeviceProvider into domain managers | Reduces rebuild blast radius, improves testability | M | **High** |
| 4 | Move platform port calls out of screens | Enforces architecture boundary | M | **Medium** |
| 5 | Convert static services to injectable instances | Enables testing | S | **Medium** |
| 2 | Unify cluster parser rendering pipelines | Single source of truth for thresholds | M | **Medium** |
| 8 | Standardise optimistic caching strategy | Prevents silent control failures | S | **Medium** |
| 6 | Remove Flutter import from diagnostics engine | Pure testability | XS | **Low** |
| 3 | Remove UI imports from DeviceView | Layer hygiene | XS | **Low** |
| 9 | Adopt BottomSheetScaffold in extracted sheets | Reduces boilerplate | S | **Low** |
| 10 | Replace inline colour literals with theme constants | Consistency | XS | **Low** |

The app is in good shape structurally. The port interfaces, the
subscription-driven live cache, and the `DeviceView` merge pattern are
all solid foundations. The biggest risk to long-term maintainability is
the DeviceProvider's remaining breadth and the absence of tests — those
two items alone account for most of the maintenance tax going forward.
