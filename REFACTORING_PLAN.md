# Flux App — Refactoring Plan

> **Goal:** Improve architecture and eliminate duplication, making the codebase
> more navigable, testable, and maintainable — without changing user-visible
> behaviour.

---

## Summary of findings

| Metric | Value |
|---|---|
| Total Dart lines | ~18,200 |
| Files over 500 lines | 7 |
| Largest file | `commission_screen.dart` — **2,111 lines** |
| Second largest | `device_settings_screen.dart` — **1,858 lines** |
| Private widget classes (`class _`) | **114** — most are trapped in mega-files |
| `showModalBottomSheet` call sites | **10** — each builds its own sheet chrome |
| Duplicated `_parseHexId` | **3 copies** (2 in `device_settings_screen.dart`, 1 top-level) |
| Hardcoded colour literals (`Color(0xFF…)`, `Colors.green.shade400`) | **~30+** across 10 files |
| Bottom-sheet "handle bar" boilerplate | **~7 copies** |
| `part` / `part of` usage | device_detail/ — 10 files stitched into one compilation unit |

---

## Phase 1 — Extract shared utilities (zero-risk, pure additions)

### 1.1  `lib/utils/hex_utils.dart` — deduplicate `_parseHexId`

**Problem:** `_parseHexId(String?) → int?` is defined **three times** in
`device_settings_screen.dart` (once as a static method in `_OtaSectionState`,
once as a top-level function, and used from `_DeviceSettingsScreenState`).

**Action:**
- Create `lib/utils/hex_utils.dart` with a single public `int? parseHexId(String? raw)`.
- Replace all three definitions with imports.

**Files touched:** `device_settings_screen.dart`, new `hex_utils.dart`.

---

### 1.2  `lib/ui/theme.dart` — centralise semantic colours

**Problem:** `Color(0xFF34A853)` (success green) appears **13 times** across 7
files. `Color(0xFFE53935)` (error red) appears 3 times. `Colors.green.shade400`,
`Colors.orange.shade400`, `Colors.red.shade400` are scattered through
`cluster_parser.dart`, `device_settings_screen.dart`, `thread_diag_screen.dart`,
and `network_check_screen.dart` for identical semantic meanings (ok / warning /
error).

**Action:**
- Add to `theme.dart`:
  ```dart
  const kSuccessGreen  = Color(0xFF34A853);
  const kErrorRed      = Color(0xFFE53935);
  const kWarningOrange = Color(0xFFF9AB00);
  Color statusOk(BuildContext ctx)      => kSuccessGreen;
  Color statusWarning(BuildContext ctx)  => kWarningOrange;
  Color statusError(BuildContext ctx)    => Theme.of(ctx).colorScheme.error;
  ```
- Replace all inline literals with the named constants.
- Replace the `_statusColor()`/`qualityColor()` helpers in
  `network_check_screen.dart` and `cluster_parser.dart` to use these shared
  constants.

**Files touched:** `theme.dart`, every file that uses the hardcoded hex colours.

---

### 1.3  `lib/ui/widgets/bottom_sheet_scaffold.dart` — handle-bar + safe-area boilerplate

**Problem:** Every `showModalBottomSheet` builder manually constructs a
`SafeArea` → `Padding` → `Column` with a centred `Container(width: 40, height: 4)`
handle bar and bottom inset padding. This identical pattern appears ~7 times.

**Action:**
- Create a reusable `BottomSheetScaffold` widget:
  ```dart
  class BottomSheetScaffold extends StatelessWidget {
    const BottomSheetScaffold({required this.title, required this.child, …});
    final String? title;
    final Widget child;
    …
  }
  ```
- Migrate each sheet builder to wrap content in `BottomSheetScaffold`.

**Files touched:** `device_settings_screen.dart` (4 sheets), `commission_screen.dart`
(3 sheets), new widget file.

---

## Phase 2 — Break up mega-files (extract private classes into standalone files)

### 2.1  `commission_screen.dart` (2,111 → ~600 lines)

This file contains the main screen **plus 11 private widget classes** that are
fully self-contained and never access `_CommissionScreenState` private fields:

| Class | Lines | Target file |
|---|---|---|
| `_PayloadEntry` + `_PayloadEntryState` | ~190 | `lib/ui/screens/commission/payload_entry.dart` |
| `_ManualCodeFormatter` | ~25 | same file as `_PayloadEntry` |
| `_NetworkSection` + state | ~170 | `lib/ui/screens/commission/network_section.dart` |
| `_ThreadDatasetHeader` + state | ~100 | `lib/ui/screens/commission/thread_dataset_header.dart` |
| `_ThreadDatasetPromptSheet` + state | ~120 | `lib/ui/screens/commission/thread_dataset_prompt_sheet.dart` |
| `_DatasetPickerSheet` | ~60 | `lib/ui/screens/commission/dataset_picker_sheet.dart` |
| `_ScanOverlayPainter` | ~35 | `lib/ui/widgets/scan_overlay_painter.dart` |
| `_WifiCredentialPanel` + state | ~150 | `lib/ui/screens/commission/wifi_credential_panel.dart` |
| `_ConnectionTile` | ~45 | `lib/ui/screens/commission/connection_tile.dart` |
| `_GlyphLogLine` | ~80 | `lib/ui/screens/commission/glyph_log_line.dart` |
| `_WifiSignalIcon` | ~15 | inline in `network_section.dart` |

**Action:**
- Create `lib/ui/screens/commission/` directory.
- Move each class to its own file, changing from private (`_`) to library-private
  or public as needed (prefix with an underscore convention comment if they
  shouldn't be imported outside the commission feature).
- The main `CommissionScreen` stays in `commission_screen.dart` but drops from
  ~2,100 to ~600 lines (just the StatefulWidget + state + builder methods).

---

### 2.2  `device_settings_screen.dart` (1,858 → ~300 lines)

Same story — **12 private classes** are packed in:

| Class | Lines | Target file |
|---|---|---|
| `_RoomTile` | ~30 | `lib/ui/screens/device_settings/room_tile.dart` |
| `_RoomPickerSheet` + state | ~100 | `lib/ui/screens/device_settings/room_picker_sheet.dart` |
| `_OtaSection` + state | ~250 | `lib/ui/screens/device_settings/ota_section.dart` |
| `_ShareBottomSheet` + state | ~260 | `lib/ui/screens/device_settings/share_bottom_sheet.dart` |
| `DeviceInfoScreen` | ~100 | `lib/ui/screens/device_settings/device_info_screen.dart` |
| `_BatteryCard` | ~45 | `lib/ui/screens/device_settings/battery_card.dart` |
| `_AutomationsSummaryTile` | ~30 | `lib/ui/screens/device_settings/automations_summary_tile.dart` |
| `_ConnectionsScreen` | ~60 | `lib/ui/screens/device_settings/connections_screen.dart` |
| `_ConnectionCard` | ~70 | `lib/ui/screens/device_settings/connection_card.dart` |
| `_GesturePill` | ~20 | same file as `connection_card.dart` |
| `_ConnectionDetailSheet` + state | ~170 | `lib/ui/screens/device_settings/connection_detail_sheet.dart` |
| `_AddConnectionSheet` | ~70 | `lib/ui/screens/device_settings/add_connection_sheet.dart` |
| `_GestureActionRow` | ~45 | same file as `connection_detail_sheet.dart` |
| `_DeviceChips` | ~20 | `lib/ui/widgets/device_chips.dart` |

**Action:** Same pattern as 2.1. Create `lib/ui/screens/device_settings/` and
extract. The main `DeviceSettingsScreen` drops to ~300 lines.

---

### 2.3  `network_check_screen.dart` (1,207 → ~500 + ~300 + ~200)

| Extraction | Target |
|---|---|
| All `_brChecks` / `_buildNonBrSections` / `_worstStatus` diagnostic logic | `lib/services/network_diagnostics_engine.dart` — pure functions, fully testable |
| `_BorderRouterDetailScreen` | `lib/ui/screens/network_check/border_router_detail_screen.dart` |
| `_DiagCard`, `_CheckRow`, `_SummaryBanner`, `_BulletList` | `lib/ui/screens/network_check/diag_widgets.dart` |

The diagnostic logic currently mixes UI models (`_Status`, `_CheckResult`) with
pure computation. Separating the engine from the widgets makes the checks
**unit-testable** without Flutter.

---

### 2.4  `thread_settings_screen.dart` (967 → ~300 + subfiles)

| Class | Target |
|---|---|
| `_ActiveNetworkDetailScreen` | `lib/ui/screens/settings/thread/active_network_detail_screen.dart` |
| `_ThreadNetworkScreen` | `lib/ui/screens/settings/thread/thread_network_screen.dart` |
| `_BorderRouterDetailScreen` | `lib/ui/screens/settings/thread/border_router_detail_screen.dart` |
| `_ThreadDatasetDetailScreen` | `lib/ui/screens/settings/thread/thread_dataset_detail_screen.dart` |
| `_NoCredentialsHint` | `lib/ui/screens/settings/thread/no_credentials_hint.dart` |

---

## Phase 3 — Eliminate `part` / `part of` in device detail

### 3.1  Convert device-detail cards from `part` to regular imports

**Problem:** `device_detail_screen.dart` uses `part` directives to stitch
10 files into one compilation unit. This means:
- All 10 card files share the same private namespace — any `_` symbol leaks
  across boundaries.
- IDE navigation is confusing (clicking a symbol sometimes jumps to the
  "wrong" part file).
- You cannot write focused unit tests for a single card without pulling in
  the entire screen.

**Action:**
- Remove all `part` / `part of` directives.
- Make each card widget **public** (drop the underscore):
  `_OnOffCard` → `OnOffCard`, `_BrightnessCard` → `BrightnessCard`, etc.
- Add `import` statements in `device_detail_screen.dart`.
- Move each card file into `lib/ui/screens/device_detail/` (already there
  physically; just change the linkage).

**Files touched:** `device_detail_screen.dart` + all 10 card files.

---

## Phase 4 — Thin the DeviceProvider (1,016 lines → ~600 + ~250)

### 4.1  Extract automation / rule engine into `lib/services/automation_engine.dart`

**Problem:** `DeviceProvider` is a ~1,016-line god object. About 40% of its
code is the in-app automation engine: `_handleSwitchPress`, `_handleContactChange`,
`_executeAction`, `_adjustSetpoint`, `connectDevice`, `disconnectTarget`,
`connectionsFor`, `nextFreeSlot`, `_supportsAction`, plus rule CRUD. This
logic is business-rule-heavy and independently testable, but it's entangled
with the provider's `notifyListeners` / persistence calls.

**Action:**
- Create `AutomationEngine` class that owns `_rules`, exposes pure methods for
  matching/executing, and takes a callback (`Future<void> Function(String, AutomationAction)`)
  for the actual device-control calls.
- `DeviceProvider` delegates to `AutomationEngine` and handles persistence +
  `notifyListeners`.
- Net result: `DeviceProvider` drops to ~600 lines; `AutomationEngine` is
  ~250 lines and fully unit-testable without `ChangeNotifier`.

---

### 4.2  Extract subscription management into a mixin or helper

The `_startSubscription`, `_stopSubscription`, `_startAllSubscriptions`,
`_onDeviceStateEvent`, and `_applyStateUpdate` block (~150 lines) could live
in a focused `SubscriptionManager` helper that takes a `MatterPort` and a
callback for state merging. This is lower priority than 4.1 but would further
slim `DeviceProvider`.

---

## Phase 5 — Deduplicate cluster rendering logic

### 5.1  Unify static (`extractReadings`) and live (`liveReadings`) renderers

**Problem:** `cluster_parser.dart` contains **two parallel rendering pipelines**:

1. `_readingFromCluster()` — static, operates on `LiveCluster` objects from a
   one-shot cluster JSON read. Uses cluster IDs (e.g. `0x0402` for temperature).
2. `_kLiveRenderers` — subscription-driven, operates on `DeviceView.live.attrs`
   string keys (e.g. `'tempMeasureCenti'`).

Both produce `ClusterReading` objects with identical fields. The PM2.5 quality
thresholds, CO₂ thresholds, humidity quality bands, etc. are **duplicated
between the two pipelines** and can drift.

**Action:**
- Define a shared `ClusterSpec` registry:
  ```dart
  class ClusterSpec {
    final String attrKey;        // subscription key
    final int    clusterId;      // Matter cluster ID
    final int    attrId;         // attribute ID within cluster
    final ClusterReading? Function(dynamic value) render;
  }
  ```
- Both `extractReadings` and `liveReadings` look up the same `ClusterSpec`
  table. The rendering logic lives in **one place**.
- Threshold constants (`pm25Good = 12.0`, `co2Elevated = 800`, …) become
  named constants at the top of the file.

**Lines saved:** ~200 (duplicate render functions + duplicate threshold logic).

---

## Phase 6 — Minor deduplication & cleanup

### 6.1  Thread dataset prompt sheet consolidation

`commission_screen.dart` and `thread_settings_screen.dart` both contain Thread
dataset picker/prompt sheets with near-identical structure (list saved datasets,
"Load from Android" row, "Empty dataset" option). After Phase 2 extraction,
evaluate whether `ThreadDatasetPromptSheet` and the settings-screen "Add
credentials" sheet can share a single widget (parameterised by title and
whether "Empty dataset" is shown).

### 6.2  `_ScanOverlayPainter` consolidation

Both `commission_screen.dart` and `qr_scanner_screen.dart` paint identical
scrim-with-cutout overlays. Extract into `lib/ui/widgets/scan_overlay_painter.dart`.

### 6.3  `_BorderRouterDetailScreen` — name collision

Both `network_check_screen.dart` and `thread_settings_screen.dart` define a
private `_BorderRouterDetailScreen` with different layouts but overlapping
purpose. Consider:
- Rename for clarity: `NetworkCheckBorderRouterScreen` vs.
  `ThreadSettingsBorderRouterScreen`.
- Or unify into one public screen parameterised by what sections to show.

### 6.4  Date formatting

`DeviceInfoScreen._formatDate()` is a one-off manual formatter. Replace with a
shared `String formatDateTime(DateTime dt)` in `lib/utils/date_utils.dart`.

### 6.5  WiFi scan + network picker

`_NetworkSection` (commission screen) and `_WifiCredentialPanel` (same file)
both scan WiFi networks and build a dropdown. After extraction in Phase 2,
evaluate sharing a single `WifiNetworkPicker` widget.

---

## Proposed file tree after refactoring

```
lib/
├── main.dart
├── router.dart
├── models/              (unchanged)
├── providers/
│   ├── device_provider.dart          (slimmed ~600 lines)
│   └── commissioning_controller.dart (unchanged)
├── services/
│   ├── automation_engine.dart        (NEW — ~250 lines)
│   ├── network_diagnostics_engine.dart (NEW — ~300 lines, pure functions)
│   ├── cluster_parser.dart           (slimmed, unified renderers)
│   ├── device_store.dart
│   ├── matter_port.dart
│   ├── matter_channel.dart
│   ├── matter_vendors.dart
│   ├── dcl_service.dart
│   ├── thread_settings_service.dart
│   ├── qr_payload_service.dart
│   └── wifi_scan_service.dart
├── utils/
│   ├── hex_utils.dart                (NEW)
│   └── date_utils.dart               (NEW)
└── ui/
    ├── theme.dart                    (extended with semantic colours)
    ├── widgets/
    │   ├── bottom_sheet_scaffold.dart (NEW)
    │   ├── device_card.dart
    │   ├── device_chips.dart          (NEW — extracted)
    │   ├── dot_matrix_painter.dart
    │   ├── info_row.dart
    │   ├── scan_overlay_painter.dart  (NEW — extracted)
    │   └── section_label.dart
    └── screens/
        ├── home_screen.dart
        ├── commission_screen.dart     (slimmed ~600 lines)
        ├── commission/
        │   ├── payload_entry.dart
        │   ├── network_section.dart
        │   ├── thread_dataset_header.dart
        │   ├── thread_dataset_prompt_sheet.dart
        │   ├── dataset_picker_sheet.dart
        │   ├── wifi_credential_panel.dart
        │   ├── connection_tile.dart
        │   └── glyph_log_line.dart
        ├── device_detail_screen.dart  (no more `part` directives)
        ├── device_detail/
        │   ├── on_off_card.dart       (public OnOffCard)
        │   ├── brightness_card.dart
        │   ├── color_temperature_card.dart
        │   ├── connecting_banner.dart
        │   ├── fan_control_card.dart
        │   ├── readings_section.dart
        │   ├── smoke_alarm_card.dart
        │   ├── switch_card.dart
        │   ├── thermostat_card.dart
        │   └── window_covering_card.dart
        ├── device_settings_screen.dart (slimmed ~300 lines)
        ├── device_settings/
        │   ├── room_tile.dart
        │   ├── room_picker_sheet.dart
        │   ├── ota_section.dart
        │   ├── share_bottom_sheet.dart
        │   ├── device_info_screen.dart
        │   ├── battery_card.dart
        │   ├── automations_summary_tile.dart
        │   ├── connections_screen.dart
        │   ├── connection_card.dart
        │   ├── connection_detail_sheet.dart
        │   └── add_connection_sheet.dart
        ├── network_check_screen.dart  (slimmed ~500 lines)
        ├── network_check/
        │   ├── border_router_detail_screen.dart
        │   └── diag_widgets.dart
        ├── settings/
        │   ├── thread_settings_screen.dart (slimmed ~300 lines)
        │   ├── thread/
        │   │   ├── active_network_detail_screen.dart
        │   │   ├── thread_network_screen.dart
        │   │   ├── border_router_detail_screen.dart
        │   │   ├── thread_dataset_detail_screen.dart
        │   │   └── no_credentials_hint.dart
        │   ├── matter_settings_screen.dart
        │   └── app_info_screen.dart
        ├── cluster_inspector_screen.dart
        ├── thread_diag_screen.dart
        ├── qr_scanner_screen.dart
        ├── qr_payload_detail_screen.dart
        ├── settings_screen.dart
        └── commission_area/
            └── room_picker_screen.dart
```

---

## Execution order & risk assessment

| Phase | Risk | Effort | Impact |
|---|---|---|---|
| **1 — Shared utilities** | 🟢 Very low (additive, no logic change) | Small | Eliminates ~30 scattered duplicates |
| **2 — Extract from mega-files** | 🟢 Low (mechanical moves, no logic change) | Medium | Largest readability win — 4 files drop by 60–80% |
| **3 — Remove `part`/`part of`** | 🟢 Low (rename + import swap) | Small | Proper encapsulation for 10 card widgets |
| **4 — Thin DeviceProvider** | 🟡 Medium (logic extraction) | Medium | Makes automation rules unit-testable |
| **5 — Unify cluster renderers** | 🟡 Medium (rendering pipeline change) | Medium | Single source of truth for thresholds + readings |
| **6 — Minor dedup** | 🟢 Low | Small | Polish |

**Recommended order:** 1 → 3 → 2 → 6 → 4 → 5

Phase 3 (remove `part`) is a prerequisite for cleanly extracting Phase 2
sub-files, because the `part` files currently share a private namespace that
must be untangled first. Phase 1 creates the shared utilities that Phase 2
extracted files will import. Phase 4 and 5 are higher-risk and can be done
incrementally after the structural work is complete.

---

## What this plan does NOT change

- **No feature changes** — all refactoring is internal.
- **No new dependencies** — everything uses existing packages.
- **No model changes** — `models/` directory is untouched.
- **No platform channel changes** — `matter_port.dart` and `matter_channel.dart`
  are well-structured and stay as-is.
- **No router changes** — route definitions stay the same.
- **No theme visual changes** — only naming of existing colours.
