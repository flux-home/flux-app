# iOS Port Plan

Flutter app currently targets Android only. This document captures all architectural
decisions and the full execution plan for adding iOS support.

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
| OnOff, Level, Color, Fan, Covering, Thermostat, Sensor clusters | ✅ v1 |
| Live subscriptions / real-time attribute updates | ✅ v1 |
| Thread commissioning (manual dataset entry) | ✅ v1 |
| Thread border router discovery (mDNS) | ✅ v1 |
| Wi-Fi commissioning (current SSID auto-selected, manual fallback) | ✅ v1 |
| QR code scanning (`flutter_zxing` supports iOS) | ✅ v1 |
| Share device / multi-admin (open commissioning window) | ✅ v1 |
| Remove device | ✅ v1 |
| Basic info, Cluster Inspector | ✅ v1 |
| Network diagnostics | ✅ v1 |
| OTA firmware updates | ❌ v2 |
| Thread credential import from OS (`ThreadNetwork.framework`) | ❌ v2 |

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

**1. Method name** — `matter_port.dart`, `matter_channel.dart`, `commission_screen.dart`:
```dart
// Before
Future<String?> readAndroidThreadCredentials();

// After
Future<String?> readSystemThreadCredentials();
```

**2. UI label + icon** — `commission_screen.dart`:
```dart
// Before
leading: Icon(Icons.android, color: cs.primary),
title: const Text('Load from Android'),

// After
leading: Icon(Icons.system_security_update, color: cs.primary),
title: const Text('Import from OS'),
```

**3. Stale comments** — `matter_port.dart`, `matter_channel.dart`:
```dart
// Before
/// Typed events emitted by the Android CHIP SDK subscription layer.
/// Emits plain-text progress lines from the Android commissioning flow.

// After
/// Typed events emitted by the platform CHIP SDK subscription layer.
/// Emits plain-text progress lines from the platform commissioning flow.
```

---

## Phase 1 — Flutter iOS target setup

**Effort: ~half a day**

```bash
flutter create --platforms ios .
```

### `ios/Runner/Info.plist` entries

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
</array>
```

### `ios/Runner/Runner.entitlements`

```xml
<!-- Read current Wi-Fi SSID via CNCopyCurrentNetworkInfo -->
<key>com.apple.developer.networking.wifi-info</key>
<true/>
```

### `get_chip_sdk_ios.sh`

Mirror `get_chip_sdk.sh`. Downloads or builds `Matter.xcframework` and places it
at `ios/Frameworks/Matter.xcframework`. CI pulls from an artifact store (Git LFS / S3).
Build steps when building from source:

```bash
git clone --recurse-submodules https://github.com/project-chip/connectedhomeip
cd connectedhomeip
./scripts/build/build_examples.py \
  --target darwin-x64-darwin-framework-tool \
  build
# Output: out/darwin-x64-darwin-framework-tool/Matter.xcframework
```

---

## Phase 2 — iOS stub

**Effort: ~1 day**

Mirrors `android/chip-stub`. Registered at app startup when `Matter.xcframework` is
absent (controlled by a build flag or a runtime check). Every MethodChannel method
returns an empty or hardcoded response, allowing full UI development without the SDK.

```
ios/
  ChipStub/
    StubBridge.swift    ← handles all MethodChannel + EventChannel calls
```

`StubBridge.swift` registers the same three channels as the real bridge:

```swift
// com.fluxhome.app/matter      → MethodChannel
// com.fluxhome.app/commission_events → EventChannel  
// com.fluxhome.app/device_state      → EventChannel
```

Every method call returns a sensible empty value (`false`, `[]`, `nil`, `{}`).
`commissionDevice` emits a few fake progress strings on `commission_events` then
returns `{nodeId: 1, deviceTypeId: 256}`.

---

## Phase 3 — iOS native bridge in Swift

**Effort: ~2–3 weeks**

Same structural split as the Kotlin side. The channel names, method names, and
JSON payload shapes are **identical** to Android — only the implementation changes.

```
ios/Runner/
  chip/
    ChipClient.swift                ← MTRDeviceController singleton, CASE sessions,
                                       fabric initialisation, attestation delegate
    MatterCommissioner.swift        ← commissioning orchestration + progress events
    ThreadBorderRouterScanner.swift ← NWBrowser scanning _meshcop._udp.local
    NetworkInfoReader.swift         ← CNCopyCurrentNetworkInfo (current SSID only)

  bridge/
    BridgeCore.swift                ← DispatchQueue, EventChannel sinks, requireChip guard
    MatterBridge.swift              ← coordinator, routes all MethodChannel calls
    CommissioningBridge.swift       ← commissionDevice, commissionViaIp, parsePayload,
                                       removeDevice, shareDevice (openCommissioningWindow)
    SubscriptionBridge.swift        ← MTRDevice addDelegate/removeDelegate →
                                       deviceStateUpdates EventChannel
    NetworkBridge.swift             ← scanWifiNetworks (SSID only) + discoverThreadNetworks
    OnOffBridge.swift               ← MTRBaseClusterOnOff
    CoveringBridge.swift            ← MTRBaseClusterWindowCovering
    FanBridge.swift                 ← MTRBaseClusterFanControl
    ColorBridge.swift               ← MTRBaseClusterColorControl
    ThermostatBridge.swift          ← MTRBaseClusterThermostat
    SensorBridge.swift              ← temperature, humidity, battery, air quality clusters
    DeviceInfoBridge.swift          ← MTRBaseClusterBasicInformation, Descriptor cluster
    DiagnosticsBridge.swift         ← readThreadNetworkDiagnostics, runNetworkDiagnostics
    OtaBridge.swift                 ← stub only (returns false); real impl in v2
```

### What is NOT needed on iOS

- Any `CBCentralManager` / CoreBluetooth code — `MTRDeviceController` owns BLE
- Any NFC code
- Any Dart changes beyond the pre-work leakage fixes
- Any changes to providers, models, router, or UI screens

---

## Phase 4 — Build pipeline

**Effort: ~half a day**

- Add iOS lane to CI (GitHub Actions / Fastlane)
- Cache `Matter.xcframework` in CI artifact store, keyed by connectedhomeip commit SHA
- Add App Store upload script alongside `upload_to_play.py`

---

## v2 backlog

| Item | Notes |
|---|---|
| OTA firmware updates | Implement `MTROTAProviderDelegate` — direct port of `OtaManager.kt` |
| Thread credential import from OS | Implement `THClient.retrievePreferredCredentials()` via `ThreadNetwork.framework`; request `networkextension` entitlement from Apple; rename call site from `readSystemThreadCredentials` to use new platform implementation |
