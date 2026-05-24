# iOS Port Plan (Updated 2026-05-24)

Flutter app currently targets Android only. This document captures all architectural
decisions and the full execution plan for adding iOS support.

> **Status**: Phase 1 partially done (`get_chip_sdk_ios.sh` + `Matter.xcframework`
> built). Pre-work NOT started. `flutter create --platforms ios .` NOT run yet.

---

## Decision log

| # | Topic | Decision | Rationale |
|---|---|---|---|
| 1 | Matter SDK | `connectedhomeip` open-source → build `Matter.xcframework` yourself on Mac | App's value is standalone, local, no-cloud control. Apple's `MatterSupport.framework` forces commissioning through the Home app and cedes fabric ownership. |
| 2 | BLE commissioning | No manual CoreBluetooth code — `MTRDeviceController` handles scan + GATT internally | Unlike Android where `BleConnectionManager.kt` owns the GATT and hands it to the CHIP SDK, the iOS SDK owns BLE end-to-end. |
| 3 | SDK distribution | Build once on Mac, store in Git LFS / S3, pull via `get_chip_sdk_ios.sh` | Mirrors the existing `get_chip_sdk.sh` pattern for `CHIPController.aar`. |
| 4 | Minimum iOS version | **16.0** | Hard floor set by `connectedhomeip`. Covers ~87% of active iOS devices. |
| 5 | Wi-Fi scanning | Current SSID only via `CNCopyCurrentNetworkInfo` + `wifi-info` entitlement; manual entry fallback | iOS has no public API for full network scan (`NEHotspotHelper` requires a restricted entitlement not granted to consumer apps). The common case — phone on home network, device joins same network — is auto-selected identically to Android. |
| 6 | Thread credential import | Manual dataset entry only for v1; `ThreadNetwork.framework` deferred to v2 | `ThreadNetwork.framework` requires an Apple entitlement review step. Datasets are persisted locally via `ThreadSettingsService` — a one-time paste is acceptable UX for v1. |
| 7 | iOS stub | Yes — Swift stub returning empty/hardcoded responses, same pattern as Android `chip-stub` | `Matter.xcframework` takes 2–4 hours to build. A stub lets any contributor build and run the iOS app immediately. |
| 8 | Fabric sharing | Separate fabrics accepted | Android and iOS each hold their own NOC/RCAC keypair. Exporting raw key material is a security liability. Users with both platforms can use the existing `shareDevice` multi-admin flow as a manual bridge. |
| 9 | Kotlin Multiplatform | Not applicable | The bridge is bottlenecked by platform CHIP SDK APIs (`ChipDeviceController` JVM on Android, `MTRDeviceController` ObjC on iOS), not by the Kotlin language. KMP cannot import `android.*` or `chip.devicecontroller.*` in `commonMain`. |
| 10 | OTA firmware updates | Deferred to v2 | `MTROTAProviderDelegate` on iOS is a straight port of `OTAProviderDelegate`, but OTA is a power-user feature. Deferring keeps v1 scope focused on commissioning and control. |
| 11 | App Store | Yes, from v1 | Play Store is already live. No App Review blockers identified — Bluetooth, local network, and camera usage are all standard permissions. |

---

## iOS v1 feature scope

| Feature | Status |
|---|---|
| Commission via BLE (QR code + manual pairing code) | ✅ v1 |
| Commission via IP | ✅ v1 |
| Commission via on-network DNS-SD (`commissionViaCode`) | ✅ v1 |
| Deferred credentials flow (`provideCredentials`) | ✅ v1 |
| OnOff, Level, Color, Fan, Covering, Thermostat, Sensor clusters | ✅ v1 |
| Door Lock (lock/unlock) | ✅ v1 |
| Identify command | ✅ v1 |
| Live subscriptions / real-time attribute updates | ✅ v1 |
| Thread commissioning (manual dataset entry) | ✅ v1 |
| Thread border router discovery (mDNS) | ✅ v1 |
| Wi-Fi commissioning (current SSID auto-selected, manual fallback) | ✅ v1 |
| QR code scanning (`flutter_zxing` supports iOS) | ✅ v1 |
| Share device / multi-admin (open commissioning window) | ✅ v1 |
| Remove device | ✅ v1 |
| Basic info, Cluster Inspector | ✅ v1 |
| Network diagnostics | ✅ v1 |
| Discover commissionable nodes (DNS-SD) | ✅ v1 |
| OTA firmware updates | ❌ v2 |
| Thread credential import from OS (`ThreadNetwork.framework`) | ❌ v2 |
| Water heater management cluster | ❌ v2 (Android-only for now) |

---

## Key API shape differences: Android vs iOS CHIP SDK

Understanding these upfront prevents the Swift bridge from being a naive line-by-line
translation attempt.

| Concern | Android (`ChipDeviceController`) | iOS (`MTRDeviceController`) |
|---|---|---|
| Commissioning entry point | `controller.pairDeviceThroughBLE(gatt, connId, nodeId, pin, params)` | `controller.setupCommissioningSession(with: payload, newNodeID: nodeID)` |
| BLE ownership | App owns `BluetoothGatt`, hands it to CHIP SDK | SDK owns BLE entirely — app never touches CoreBluetooth |
| Progress callbacks | `setCompletionListener(GenericChipDeviceListener)` | `MTRDeviceControllerDelegate` protocol |
| Network credentials during commissioning | Passed upfront or via `updateCommissioningNetworkCredentials()` | `MTRDeviceControllerDelegate.controller(_:requestCommissioningParametersFor:)` callback |
| Subscriptions | Manual: `startSubscription(nodeId)` / `stopSubscription(nodeId)` | Automatic: `MTRDevice.addDelegate(_:queue:)` / `removeDelegate(_:)` |
| Cluster commands | `InvokeElement` + `TlvWriter` via `ChipDeviceController` | Typed cluster classes: `MTRBaseClusterOnOff().toggle(with: params, completion:)` |
| CASE session | `getConnectedDevicePointer(nodeId, callback)` | `MTRDevice` handles CASE internally |
| Storage | `PreferencesKeyValueStoreManager` (Android SharedPreferences) | Path provided to `MTRDeviceControllerStorageDelegate` (or auto Keychain) |

The **subscription difference** is the most structurally significant: `startSubscription` /
`stopSubscription` on the Swift side map to `addDelegate` / `removeDelegate` on `MTRDevice`,
not to explicit subscribe calls. The Dart API and `MatterPort` interface are unchanged.

---

## Pre-work: fix 3 Dart abstraction leakages

These are the only places where Android leaks through the `MatterPort` boundary.
Fix before any iOS work begins.

> **Current state (2026-05-24)**: ALL THREE still need fixing.

### 1. Method name rename

**Files**: `matter_port.dart` (line 111), `matter_channel.dart` (line 341),
`commission_screen.dart` (line 1484), `thread_settings_screen.dart` (line 162)

```dart
// Before
Future<String?> readAndroidThreadCredentials();

// After
Future<String?> readSystemThreadCredentials();
```

Also rename the platform channel method string in `matter_channel.dart`:
```dart
// Before
_invoke<String?>('readAndroidThreadCredentials', null);

// After
_invoke<String?>('readSystemThreadCredentials', null);
```

And update the Android-side handler in `MainActivity.kt` to accept both names
(or rename there too and update the Kotlin side):
```kotlin
// In MatterBridge route map, rename:
"readAndroidThreadCredentials" -> ...
// to:
"readSystemThreadCredentials" -> ...
```

### 2. UI label + icon — `commission_screen.dart`

```dart
// Before (around line 1566–1571)
leading: Icon(Icons.android, color: cs.primary),
title: const Text('Load from Android'),

// After — platform-aware
leading: Icon(
  defaultTargetPlatform == TargetPlatform.iOS
      ? Icons.apple
      : Icons.system_security_update,
  color: cs.primary,
),
title: const Text('Import from OS'),
```

> Add `import 'package:flutter/foundation.dart';` if not already present.
> On iOS this method will return `null` in v1 (Thread credential import deferred),
> so also wrap the ListTile with a platform check to hide it on iOS entirely.

### 3. Stale comments — `matter_port.dart` (line 19), `matter_channel.dart` (line 17, 51)

```dart
// Before
/// Typed events emitted by the Android CHIP SDK subscription layer.
/// Emits plain-text progress lines from the Android commissioning flow.
/// Flutter ↔ Android MethodChannel bridge.

// After
/// Typed events emitted by the platform CHIP SDK subscription layer.
/// Emits plain-text progress lines from the platform commissioning flow.
/// Flutter ↔ platform MethodChannel bridge.
```

---

## Phase 1 — Flutter iOS target setup

**Effort: ~half a day**

### 1a. Create the iOS target (NOT YET DONE)

```bash
cd /Users/stimpson/workspace/fluxhome
flutter create --platforms ios .
```

### 1b. `ios/Runner/Info.plist` entries

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Flux uses Bluetooth to commission new Matter devices.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Flux scans the local network to discover Thread border routers.</string>

<key>NSCameraUsageDescription</key>
<string>Flux uses the camera to scan Matter QR codes.</string>

<!-- Required for NWBrowser / Bonjour App Store review -->
<key>NSBonjourServices</key>
<array>
  <string>_meshcop._udp</string>
  <string>_matterc._udp</string>
</array>
```

### 1c. `ios/Runner/Runner.entitlements`

```xml
<!-- Read current Wi-Fi SSID via CNCopyCurrentNetworkInfo -->
<key>com.apple.developer.networking.wifi-info</key>
<true/>
```

### 1d. Link `Matter.xcframework` (ALREADY BUILT)

The xcframework already exists at `ios/Frameworks/Matter.xcframework` (built via
`get_chip_sdk_ios.sh`). After `flutter create`, add it to the Xcode project:

- In `ios/Runner.xcodeproj`, add the framework to **Frameworks, Libraries, and Embedded Content** → Embed & Sign.
- Or use a `Podfile` post_install hook / manual xcconfig.

### 1e. Set deployment target

In `ios/Runner.xcodeproj/project.pbxproj`, set `IPHONEOS_DEPLOYMENT_TARGET = 16.0`.

---

## Phase 2 — iOS stub

**Effort: ~1 day**

Mirrors `android/chip-stub`. Registered at app startup when `Matter.xcframework` is
absent (controlled by a Swift compiler flag, e.g. `CHIP_STUB`). Every MethodChannel
method returns an empty or hardcoded response, allowing full UI development without the SDK.

```
ios/Runner/
  stub/
    StubBridge.swift    ← handles all MethodChannel + EventChannel calls
```

`StubBridge.swift` registers the same three channels as the real bridge:

```swift
// com.fluxhome.app/matter            → MethodChannel
// com.fluxhome.app/commission_events  → EventChannel
// com.fluxhome.app/device_state       → EventChannel
```

Every method call returns a sensible empty value (`false`, `[]`, `nil`, `{}`).
`commissionDevice` emits a few fake progress strings on `commission_events` then
returns `{nodeId: 1, deviceTypeId: 256}`.

---

## Phase 3 — iOS native bridge in Swift

**Effort: ~2–3 weeks**

Same structural split as the Kotlin side. The channel names, method names, and
JSON payload shapes are **identical** to Android — only the implementation changes.

### Complete method channel contract (37 methods)

These are ALL the method names that the Dart `MatterChannel` invokes. The iOS
bridge must handle every one:

| Method name | Dart return | Bridge file |
|---|---|---|
| `startSubscription` | `bool` | SubscriptionBridge |
| `stopSubscription` | `void` | SubscriptionBridge |
| `parsePayload` | `Map?` | CommissioningBridge |
| `commissionDevice` | `Map` | CommissioningBridge |
| `commissionViaIp` | `Map` | CommissioningBridge |
| `commissionViaCode` | `Map` | CommissioningBridge |
| `provideCredentials` | `void` | CommissioningBridge |
| `scanWifiNetworks` | `List<Map>` | NetworkBridge |
| `shareDevice` | `Map?` | CommissioningBridge |
| `removeDevice` | `bool` | CommissioningBridge |
| `toggleDevice` | `bool` | OnOffBridge |
| `setLevel` | `bool` | OnOffBridge |
| `stepLevel` | `bool` | OnOffBridge |
| `coveringUp` | `bool` | CoveringBridge |
| `coveringDown` | `bool` | CoveringBridge |
| `coveringStop` | `bool` | CoveringBridge |
| `coveringGoToLift` | `bool` | CoveringBridge |
| `setFanMode` | `bool` | FanBridge |
| `setFanPercent` | `bool` | FanBridge |
| `setColorTemperature` | `bool` | ColorBridge |
| `readBasicInfo` | `Map?` | DeviceInfoBridge |
| `readServerClusterList` | `List<int>` | DeviceInfoBridge |
| `readPartsList` | `List<int>` | DeviceInfoBridge |
| `readThermostat` | `Map?` | ThermostatBridge |
| `writeHeatingSetpoint` | `bool` | ThermostatBridge |
| `writeSystemMode` | `bool` | ThermostatBridge |
| `readClusters` | `String?` | DeviceInfoBridge |
| `readDeviceType` | `int?` | DeviceInfoBridge |
| `readDeviceState` | `Map` | DeviceInfoBridge |
| `identify` | `void` | DeviceInfoBridge |
| `lockDoor` | `bool` | DoorLockBridge |
| `unlockDoor` | `bool` | DoorLockBridge |
| `discoverThreadNetworks` | `String (JSON)` | NetworkBridge |
| `readThreadNetworkDiagnostics` | `String? (JSON)` | DiagnosticsBridge |
| `readSystemThreadCredentials` | `String?` | NetworkBridge |
| `runNetworkDiagnostics` | `String? (JSON)` | DiagnosticsBridge |
| `downloadAndFlash` | `bool` | OtaBridge (stub) |
| `cancelOta` | `bool` | OtaBridge (stub) |
| `getFabricId` | `String?` | DeviceInfoBridge |
| `getVendorId` | `int?` | DeviceInfoBridge |
| `discoverCommissionableNodes` | `List<Map>` | DeviceInfoBridge |

### File structure

```
ios/Runner/
  chip/
    ChipClient.swift                ← MTRDeviceController singleton, CASE sessions,
                                       fabric initialisation, attestation delegate
    MatterCommissioner.swift        ← commissioning orchestration + progress events
                                       (BLE, IP, on-network/code, deferred credentials)
    ThreadBorderRouterScanner.swift ← NWBrowser scanning _meshcop._udp.local
    NetworkInfoReader.swift         ← CNCopyCurrentNetworkInfo (current SSID only)

  bridge/
    BridgeCore.swift                ← DispatchQueue, EventChannel sinks, requireChip guard
    MatterBridge.swift              ← coordinator, routes all MethodChannel calls to sub-bridges
    CommissioningBridge.swift       ← commissionDevice, commissionViaIp, commissionViaCode,
                                       provideCredentials, parsePayload,
                                       removeDevice, shareDevice (openCommissioningWindow)
    SubscriptionBridge.swift        ← MTRDevice addDelegate/removeDelegate →
                                       deviceStateUpdates EventChannel
    NetworkBridge.swift             ← scanWifiNetworks (SSID only), discoverThreadNetworks,
                                       readSystemThreadCredentials (returns nil on iOS v1)
    OnOffBridge.swift               ← MTRBaseClusterOnOff (toggle, setLevel, stepLevel)
    CoveringBridge.swift            ← MTRBaseClusterWindowCovering
    FanBridge.swift                 ← MTRBaseClusterFanControl (mode + percent)
    ColorBridge.swift               ← MTRBaseClusterColorControl (color temperature)
    ThermostatBridge.swift          ← MTRBaseClusterThermostat (read, writeSetpoint, writeMode)
    SensorBridge.swift              ← temperature, humidity, battery, air quality clusters
    DeviceInfoBridge.swift          ← MTRBaseClusterBasicInformation, Descriptor cluster,
                                       identify, readDeviceState, readClusters,
                                       getFabricId, getVendorId, discoverCommissionableNodes
    DiagnosticsBridge.swift         ← readThreadNetworkDiagnostics, runNetworkDiagnostics
    DoorLockBridge.swift            ← MTRBaseClusterDoorLock (lock, unlock)
    OtaBridge.swift                 ← stub only (returns false); real impl in v2
```

### Event channels (2 streams)

| Channel name | Event shape | Source |
|---|---|---|
| `com.fluxhome.app/commission_events` | `String` (progress line) | `MatterCommissioner` → `CommissioningBridge` |
| `com.fluxhome.app/device_state` | `Map` with keys: `nodeId`, `type`, + attrs | `SubscriptionBridge` (from `MTRDevice` delegate callbacks) |

The `device_state` event `type` values: `established`, `resubscribing`, `error`,
`otaProgress`, or `update` (attribute payload). Must match Android exactly.

### What is NOT needed on iOS

- Any `CBCentralManager` / CoreBluetooth code — `MTRDeviceController` owns BLE
- Any NFC code
- Any Dart changes beyond the pre-work leakage fixes
- Any changes to providers, models, router, or UI screens
- WaterHeater bridge (not in `MatterPort` interface; Android-only for now)

---

## Phase 4 — Build pipeline

**Effort: ~half a day**

- Add iOS lane to CI (GitHub Actions / Fastlane)
- Cache `Matter.xcframework` in CI artifact store, keyed by connectedhomeip commit SHA
- Add App Store upload script alongside `upload_to_play.py`

---

## Execution order for agents

Each phase is a self-contained unit of work. Execute sequentially.

### Agent task 0: Pre-work (Dart-only, no iOS knowledge needed)

1. Rename `readAndroidThreadCredentials` → `readSystemThreadCredentials` in:
   - `lib/services/matter_port.dart` (interface declaration)
   - `lib/services/matter_channel.dart` (method + channel string)
   - `lib/ui/screens/commission_screen.dart` (call site)
   - `lib/ui/screens/settings/thread_settings_screen.dart` (call site)
   - Android handler: `grep -rn "readAndroidThreadCredentials" android/` and rename

2. Update UI in `commission_screen.dart`:
   - Replace `Icons.android` → platform-aware icon (or `Icons.system_security_update`)
   - Replace `'Load from Android'` → `'Import from OS'`
   - Hide the tile entirely on iOS (it returns nil in v1)

3. Fix stale comments:
   - `matter_port.dart` line 19: "Android CHIP SDK" → "platform CHIP SDK"
   - `matter_port.dart` line 33: "Android commissioning" → "platform commissioning"
   - `matter_channel.dart` line 17: "Flutter ↔ Android" → "Flutter ↔ platform"
   - `matter_channel.dart` line 51: "Android commissioning" → "platform commissioning"

4. **Verify**: `flutter analyze` passes, Android build still works.

### Agent task 1: Flutter iOS target scaffold

1. Run `flutter create --platforms ios .`
2. Set deployment target to 16.0
3. Add Info.plist permission strings
4. Add Runner.entitlements with wifi-info
5. Link `Matter.xcframework` from `ios/Frameworks/`
6. Add `_matterc._udp` to NSBonjourServices
7. **Verify**: `flutter build ios --no-codesign` succeeds (empty app)

### Agent task 2: iOS stub bridge

1. Create `ios/Runner/stub/StubBridge.swift`
2. Register all 3 channels, return sensible defaults for every method
3. Add `CHIP_STUB` Swift compiler flag in debug config
4. Wire stub registration in `AppDelegate.swift`
5. **Verify**: app launches in iOS Simulator, can navigate all screens without crash

### Agent task 3: iOS native bridge — core infrastructure

1. Create `ChipClient.swift` — MTRDeviceController init, fabric, storage, attestation
2. Create `BridgeCore.swift` — dispatch queue, EventChannel sinks, FlutterMethodChannel setup
3. Create `MatterBridge.swift` — route switch statement for all 39 method names
4. **Verify**: compiles with Matter.xcframework linked

### Agent task 4: iOS native bridge — commissioning

1. Create `MatterCommissioner.swift` — BLE, IP, on-network, deferred creds
2. Create `CommissioningBridge.swift` — 7 methods: commissionDevice, commissionViaIp,
   commissionViaCode, provideCredentials, parsePayload, removeDevice, shareDevice
3. **Verify**: can commission a real device from iOS

### Agent task 5: iOS native bridge — subscriptions

1. Create `SubscriptionBridge.swift` — MTRDevice delegate → EventChannel events
2. Map `addDelegate`/`removeDelegate` to `startSubscription`/`stopSubscription`
3. Emit events matching Android's map shape (`nodeId`, `type`, attr keys)
4. **Verify**: live attribute updates flow to Dart

### Agent task 6: iOS native bridge — cluster commands

1. Create `OnOffBridge.swift` (toggle, setLevel, stepLevel)
2. Create `CoveringBridge.swift` (up, down, stop, goToLift)
3. Create `FanBridge.swift` (mode, percent)
4. Create `ColorBridge.swift` (color temperature)
5. Create `ThermostatBridge.swift` (read, writeSetpoint, writeMode)
6. Create `SensorBridge.swift` (temp, humidity, battery, air quality)
7. Create `DoorLockBridge.swift` (lock, unlock)
8. **Verify**: control commands work on real devices

### Agent task 7: iOS native bridge — device info & network

1. Create `DeviceInfoBridge.swift` (readBasicInfo, readClusters, readDeviceState,
   readDeviceType, readServerClusterList, readPartsList, identify,
   getFabricId, getVendorId, discoverCommissionableNodes)
2. Create `NetworkBridge.swift` (scanWifiNetworks, discoverThreadNetworks,
   readSystemThreadCredentials → returns nil)
3. Create `DiagnosticsBridge.swift` (readThreadNetworkDiagnostics, runNetworkDiagnostics)
4. Create `ThreadBorderRouterScanner.swift` (NWBrowser _meshcop._udp)
5. Create `NetworkInfoReader.swift` (CNCopyCurrentNetworkInfo)
6. Create `OtaBridge.swift` (downloadAndFlash → false, cancelOta → false)
7. **Verify**: device info screens, Thread BR discovery, diagnostics all work

### Agent task 8: Build pipeline & release

1. Add iOS CI lane (GitHub Actions)
2. Add Fastlane config for TestFlight / App Store
3. Test full commissioning + control flow on physical device
4. Submit to App Store

---

## v2 backlog

| Item | Notes |
|---|---|
| OTA firmware updates | Implement `MTROTAProviderDelegate` — direct port of `OtaManager.kt` |
| Thread credential import from OS | Implement `THClient.retrievePreferredCredentials()` via `ThreadNetwork.framework`; request `networkextension` entitlement from Apple; iOS `readSystemThreadCredentials` returns real data |
| Water heater management | Add to `MatterPort` interface first, then implement iOS bridge |
