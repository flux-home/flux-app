# Flux

A Flutter app for commissioning and controlling real Matter devices on Android.
Uses the connectedhomeip (CHIP) SDK directly — no Google Home SDK required.

## What it does

- Commission Thread and Wi-Fi Matter devices via BLE (QR code or manual pairing code) or IP
- Control On/Off, dimming, and thermostat (arc dial, mode selector, live temperature)
- Live sensor readings from all clusters (temperature, humidity, battery, air quality, etc.)
- OTA firmware updates via Matter BDX protocol with DCL version lookup
- Cluster Inspector: wildcard-reads all attributes/commands/feature-maps from all endpoints
- Thread network browser: discovers border routers via mDNS, imports credentials from Android
- Persists commissioned devices across restarts (no cloud dependency)

---

## Architecture overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  Flutter (Dart)                                                      │
│                                                                      │
│  main.dart  →  router.dart (go_router)                              │
│                                                                      │
│  providers/                  services/                              │
│    DeviceProvider              MatterChannel  ← single MethodChannel │
│    (ChangeNotifier,            DclService     ← DCL REST API        │
│     persists to JSON)          DeviceStore    ← SharedPreferences   │
│                                                                      │
│  models/          ui/screens/              ui/widgets/              │
│    MatterDevice     HomeScreen               DotMatrixPainter       │
│    DeviceLiveData   DeviceDetailScreen  ─┐   DeviceCard             │
│    BasicInfo          ├ cluster_readings  │  InfoRow / SectionLabel  │
│    OtaProgress        ├ device_cards      │                          │
│    …                  └ thermostat_card   │                          │
│                     SettingsScreen  ──────┤                          │
│                       ├ MatterSettingsScreen                         │
│                       └ ThreadSettingsScreen                         │
│                     CommissionScreen                                 │
│                     DeviceSettingsScreen (OTA, rename, remove)       │
│                     ClusterInspectorScreen                           │
└────────────────────────┬────────────────────────────────────────────┘
                         │  MethodChannel  +  EventChannel
┌────────────────────────▼────────────────────────────────────────────┐
│  Android (Kotlin)                                                    │
│                                                                      │
│  MainActivity.kt  →  MatterBridge.kt  ← routes all method calls     │
│                                                                      │
│  chip/                                                               │
│    ChipClient.kt              ← SDK singleton, CASE sessions         │
│    MatterCommissioner.kt      ← BLE + Thread/Wi-Fi + IP flows        │
│    BleConnectionManager.kt    ← BLE scan, GATT, MTU negotiation      │
│    OtaManager.kt              ← BDX provider delegate                │
│    SetupPayloadHelper.kt      ← QR + manual pairing code parser      │
│    ThreadBorderRouterScanner  ← mDNS _meshcop._udp discovery         │
│    AndroidThreadCredentialReader ← Play Services credential store    │
│    NetworkDiagnosticsRunner   ← IPv6 / VPN / Wi-Fi diagnostics       │
│                                                                      │
│    clusters/  (one file per cluster domain)                          │
│      ClusterClient.kt    ← public facade, all calls go through here  │
│      ClusterUtils.kt     ← readAttributes / writeAttribute / invoke  │
│      OnOffCluster.kt                                                 │
│      LevelControlCluster.kt                                          │
│      IdentifyCluster.kt                                              │
│      DescriptorCluster.kt                                            │
│      BasicInfoCluster.kt                                             │
│      ThermostatCluster.kt                                            │
│      SensorCluster.kt        ← battery + humidity                   │
│      OtaCluster.kt           ← AnnounceOTAProvider + DefaultOTA     │
│      ThreadDiagCluster.kt    ← Thread network diagnostics + parsers  │
│      SubscriptionManager.kt  ← wildcard attribute subscriptions      │
│      ClusterInspector.kt     ← full wildcard read → JSON             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key design decisions

| Decision | Reason |
|---|---|
| `ClusterClient` is a thin facade | `MatterBridge` has stable call sites; cluster implementations can be replaced/added without touching the bridge |
| `ClusterUtils.readAttributes / readAttributeOrThrow / writeAttribute / invoke` | Eliminates the `suspendCancellableCoroutine` + `ReportCallback` boilerplate repeated across every cluster |
| `DeviceLiveData.copyWith` with `_keep` sentinel | Updating any single field (e.g. `isStale`) doesn't require listing all 30 fields by hand |
| `DeviceProvider._mergeLiveCache` | All live-cache mutations go through one helper; ensures `notifyListeners()` is always called |
| `MatterChannel._invoke<T>` | 28 `try { invokeMethod } on PlatformException` blocks → one generic helper |
| `paintDotMatrix` free function | `DotMatrixPainter` and `_DialPainter` both render dot-matrix text from one shared implementation |
| Subscription is source of truth for on/off | No optimistic caching — avoids UI bouncing; `toggle()` does update live cache *after* command success to handle stale subscriptions |
| `autoResubscribe = true` + 30 s backoff restart | SDK exponential backoff can grow to minutes after a power cycle; a forced restart after 30 s recovers in ~2 s |
| `setSkipAttestationCertificateValidation(true)` | Commercial devices have PAA certs not in the SDK test store |
| `continueCommissioning` posted to main thread | Direct call from attestation callback causes JNI reentrant deadlock |
| `chip-stub` module | Allows compilation without the real AAR; operations return `CHIP_SDK_UNAVAILABLE` at runtime |
| `CHANGE_WIFI_MULTICAST_STATE` permission | Required by the CHIP mDNS resolver; without it the app crashes during operational discovery |

---

## Dart file layout

```
lib/
  main.dart                         App entry, Provider setup
  router.dart                       go_router — top-level routes only

  models/
    matter_device.dart              Persisted device (nodeId, deviceType, networkType, …)
    device_live_data.dart           In-memory subscription cache (copyWith + _keep sentinel)
    basic_info.dart                 BasicInformation cluster result model
    device_type.dart                DeviceType enum + Matter device-type ID mapping
    ota_progress.dart               OTA phase/progress state model
    commission_models.dart          ParsedPayload, CommissionResult, DiscoveryCapability
    thermostat_models.dart          ThermostatState, BatteryInfo, BatteryLevel
    thread_models.dart              ThreadBorderRouter, ThreadNetworkDiagnostics
    network_diagnostics.dart        NetworkDiagnosticsReport
    wifi_network.dart               WifiNetwork

  providers/
    device_provider.dart            Single ChangeNotifier for all device state
                                    – subscription event handler
                                    – live-cache mutations (_mergeLiveCache)
                                    – commission / control / OTA methods
                                    – detectAndUpdateOtaSupport()

  services/
    matter_channel.dart             Flutter ↔ Android bridge (_invoke<T> helper)
    dcl_service.dart                CSA DCL REST API (version list + OTA URL)
    device_store.dart               SharedPreferences JSON persistence
    matter_vendors.dart             VID → vendor name lookup table
    qr_payload_service.dart         Persist last scanned QR payload
    thread_settings_service.dart    Persist Thread operational dataset hex

  ui/
    theme.dart                      Material theme

    widgets/
      dot_matrix_painter.dart       DotMatrixPainter + paintDotMatrix() free fn
      device_card.dart              Home-screen device tile
      info_row.dart                 Label/value row for device info
      section_label.dart            Section header widget

    screens/
      home_screen.dart              Device grid grouped by room
      commission_screen.dart        QR scan + manual code + BLE/IP flow + log

      device_detail_screen.dart     Device detail scaffold (part host)
      device_detail/
        cluster_readings.dart       _Reading model, _extractReadings(),
                                    _readingFromCluster() 300-line switch,
                                    _parseClusters(), live cluster models
        device_cards.dart           _OnOffCard, _BrightnessCard,
                                    _ReadingsSection, _ReadingCard
        thermostat_card.dart        _ThermostatCard, _ThermostatDial,
                                    _DialPainter, _ModeSelector,
                                    _SensorPill, _BatteryPill

      device_settings_screen.dart   OTA update section, identify, rename, remove,
                                    network type label, device info sub-screen

      settings_screen.dart          Top-level settings navigation
      settings/
        matter_settings_screen.dart Fabric ID, vendor ID, clear-all devices
        thread_settings_screen.dart Thread networks, credentials, dataset editor,
                                    border router detail, _ThreadDecoder

      cluster_inspector_screen.dart Wildcard cluster/attribute/command browser
      thread_diag_screen.dart       Thread Network Diagnostics cluster viewer
      network_check_screen.dart     IPv6 / Thread / Wi-Fi diagnostics UI
      qr_payload_detail_screen.dart Parsed QR payload detail view
      qr_scanner_screen.dart        Camera QR scanner (mobile_scanner)
```

---

## Android / Kotlin file layout

```
chip/
  ChipClient.kt                   SDK singleton, CASE session cache, fabric
  MatterCommissioner.kt           BLE commissioning flow, IP commissioning
  BleConnectionManager.kt         BLE scan (service-data filter), GATT, MTU
  OtaManager.kt                   OTAProviderDelegate — BDX file serving,
                                   dry-run support, graceful cancel
  SetupPayloadHelper.kt           Parses "MT:…" QR payloads + 11-digit manual codes
  ThreadBorderRouterScanner.kt    mDNS _meshcop._udp border router discovery
  AndroidThreadCredentialReader   Play Services Thread credential store
  NetworkDiagnosticsRunner.kt     IPv6 addresses, Wi-Fi band, VPN, border router reachability
  GenericChipDeviceListener.kt    CHIP SDK commissioning callbacks

  clusters/
    ClusterClient.kt              Public facade — one line per operation
    ClusterUtils.kt               Shared helpers:
                                    readAttributes<T>()       — returns fallback on error
                                    readAttributeOrThrow<T>() — throws on error (offline detection)
                                    writeAttribute()          — device-pointer + nodeId overloads
                                    invoke()                  — device-pointer + nodeId overloads
                                    jsonEscape()
    OnOffCluster.kt               setOnOff, readOnOff
    LevelControlCluster.kt        moveToLevel
    IdentifyCluster.kt            sendIdentify
    DescriptorCluster.kt          readDeviceTypes, readServerClusterList, readPartsList
    BasicInfoCluster.kt           BasicInfo data class, readBasicInfo
    ThermostatCluster.kt          readThermostat, writeHeatingSetpoint, writeSystemMode
    SensorCluster.kt              readBattery, readHumidity
    OtaCluster.kt                 announceOtaProvider, writeDefaultOtaProviders
    ThreadDiagCluster.kt          readThreadNetworkDiagnostics, TLV parsers,
                                   neighbor/route table JSON builder
    SubscriptionManager.kt        subscribeDeviceState — wildcard attribute subscriptions,
                                   attribute extraction, path list
    ClusterInspector.kt           readAllClusters — full wildcard read → JSON

MatterBridge.kt                   Routes MethodChannel calls → cluster objects;
                                   owns subscription lifecycle, OTA flow,
                                   Wi-Fi scan, network diagnostics dispatch
MainActivity.kt                   FlutterActivity, MethodChannel + EventChannel setup
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter | 3.x (stable) |
| Java | 17 |
| Android SDK | API 36 (compile), API 27 (min) |
| NDK | 28.2.13676358 |

The real CHIP SDK AAR (`CHIPController.aar`, ~31 MB) must be placed at:

```
android/app/libs/CHIPController.aar
```

Build it from [connectedhomeip](https://github.com/project-chip/connectedhomeip)
or copy from an existing CHIPTool build:

```
out/android-arm64-chip-tool/lib/src/controller/java/CHIPController.aar
```

Without the AAR the app compiles against `chip-stub` and all Matter calls return
`CHIP_SDK_UNAVAILABLE` at runtime.

---

## Build

```bash
export JAVA_HOME=/home/tado/workspace/jdk-17
export PATH=$JAVA_HOME/bin:$PATH
cd /home/tado/workspace/flux/app

flutter pub get
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Install on WiFi-connected device
adb -s 192.168.1.123:5555 install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## Known limitations / production TODOs

- Attestation validation is disabled (`setSkipAttestationCertificateValidation(true)`)
- Vendor ID is the CSA test VID `0xFFF4` — not valid for production
- No DAC revocation checking
- `openCommissioningWindow` (multi-admin sharing) is a stub
