# Platform-Channel Contract

> This document is the single source of truth for the Flutter ↔ native
> bridge.  Both the Android implementation (`bridge/` package) and any future
> iOS implementation (`ios/Runner/bridge/`) **must** satisfy this contract
> exactly.  The Dart consumer (`MatterChannel`) depends on it.

---

## Channels

| Name | Type | Direction |
|------|------|-----------|
| `com.fluxhome.app/matter` | `MethodChannel` | Dart → Native |
| `com.fluxhome.app/commission_events` | `EventChannel` | Native → Dart |
| `com.fluxhome.app/device_state` | `EventChannel` | Native → Dart |

---

## MethodChannel — `com.fluxhome.app/matter`

### Commissioning

#### `ping`
- **Args:** none
- **Returns:** `true`

#### `commissionDevice`
- **Args:** `payload: String, wifiSsid: String?, wifiPassword: String?, threadDatasetHex: String?, nodeId: Int|Long`
- **Returns:** `Map { nodeId: Int|Long, deviceTypeId: Int? }`
- **Errors:** `CHIP_SDK_UNAVAILABLE`, `CHIP_ERROR`

#### `commissionViaIp`
- **Args:** `ipAddress: String, port: Int, discriminator: Int, setupPinCode: Int, nodeId: Int|Long`
- **Returns:** `Map { nodeId: Int|Long, deviceTypeId: Int? }`

#### `commissionViaCode`
- **Args:** `setupCode: String, nodeId: Int|Long`
- **Returns:** `Map { nodeId: Int|Long, deviceTypeId: Int? }`

#### `parsePayload`
- **Args:** `payload: String`
- **Returns:** `Map { vendorId: Int, productId: Int, discriminator: Int, hasShortDiscriminator: Bool, setupPinCode: Int, discoveryCapabilities: List<String> }`
- **Errors:** `CHIP_SDK_UNAVAILABLE`, `PARSE_ERROR`

#### `provideCredentials`
- **Args:** `ssid: String?` (null = Thread or cancel), `password: String?`, `threadDatasetHex: String?`
- **Returns:** `null`

#### `removeDevice`
- **Args:** `nodeId: Int|Long`
- **Returns:** `true`

#### `shareDevice`
- **Args:** `nodeId: Int|Long, vendorId: Int, productId: Int`
- **Returns:** `Map { qrCodePayload: String, manualPairingCode: String }`

---

### Subscriptions

#### `startSubscription`
- **Args:** `nodeId: Int|Long`
- **Returns:** `true`
- **Side-effect:** begins emitting events on `com.fluxhome.app/device_state`

#### `stopSubscription`
- **Args:** `nodeId: Int|Long`
- **Returns:** `true`
- **Side-effect:** cancels SDK subscription; no further events for this node

---

### Device Control

#### `toggleDevice`
- **Args:** `nodeId: Int|Long, on: Bool`
- **Returns:** `true`

#### `setLevel`
- **Args:** `nodeId: Int|Long, level: Int` (0–254)
- **Returns:** `true`

#### `stepLevel`
- **Args:** `nodeId: Int|Long, stepUp: Bool`
- **Returns:** `true`

#### `readDeviceState`
- **Args:** `nodeId: Int|Long`
- **Returns:** `Map { isOnline: Bool, isOn: Bool?, brightness: Int? }` (brightness is actual CurrentLevel or null)

#### `setColorTemperature`
- **Args:** `nodeId: Int|Long, mireds: Int`
- **Returns:** `true`

#### `coveringUp` / `coveringDown` / `coveringStop`
- **Args:** `nodeId: Int|Long`
- **Returns:** `true`

#### `coveringGoToLift`
- **Args:** `nodeId: Int|Long, percent100ths: Int` (0–10 000)
- **Returns:** `true`

#### `setFanMode`
- **Args:** `nodeId: Int|Long, mode: Int` (0=Off … 6=Smart)
- **Returns:** `true`

#### `setFanPercent`
- **Args:** `nodeId: Int|Long, percent: Int` (0–100)
- **Returns:** `true`

#### `writeHeatingSetpoint`
- **Args:** `nodeId: Int|Long, centidegrees: Int`
- **Returns:** `true`

#### `writeSystemMode`
- **Args:** `nodeId: Int|Long, mode: Int`
- **Returns:** `true`

---

### Device Information

#### `readBasicInfo`
- **Args:** `nodeId: Int|Long`
- **Returns:** `Map { productName, vendorName, vendorId, productId, hwVersion, softwareVersion: String, softwareVersionNum: Int, manufacturingDate, partNumber, productUrl, serialNumber, uniqueId: String }`

#### `readServerClusterList`
- **Args:** `nodeId: Int|Long, endpoint: Int`
- **Returns:** `List<Int>` (cluster IDs)

#### `readPartsList`
- **Args:** `nodeId: Int|Long`
- **Returns:** `List<Int>` (endpoint numbers)

#### `readDeviceType`
- **Args:** `nodeId: Int|Long`
- **Returns:** `Int` (primary application device-type ID, e.g. 0x0100)

#### `readThermostat`
- **Args:** `nodeId: Int|Long`
- **Returns:** `Map<String, Int>` — keys: `localTemp, heatingSetpoint, coolingSetpoint, systemMode, controlSequence, minHeatSetpt, maxHeatSetpt, minCoolSetpt, maxCoolSetpt, absMinHeatSetpt, absMaxHeatSetpt, absMinCoolSetpt, absMaxCoolSetpt`. Sentinel value for null/absent: `Int.MIN_VALUE` (-2147483648).

#### `readClusters`
- **Args:** `nodeId: Int|Long`
- **Returns:** JSON `String` — array of `{ endpoint, clusterId, deviceTypes?, attributes: [{id, value}] }`

#### `identify`
- **Args:** `nodeId: Int|Long, seconds: Int`
- **Returns:** `null`

#### `getFabricId`
- **Args:** none
- **Returns:** `String` — hex-formatted compressed fabric ID, e.g. `"0x0000000000000001"`

#### `getVendorId`
- **Args:** none
- **Returns:** `Int`

#### `discoverCommissionableNodes`
- **Args:** none
- **Returns:** `List<Map>` — each map: `{ discriminator: Long, ipAddress: String, port: Int, deviceType: Long, vendorId: Int, productId: Int, commissioningMode: String, deviceName: String, instanceName: String, pairingHint: Int, isIcd: Bool }`

---

### OTA

#### `downloadAndFlash`
- **Args:** `nodeId: Int|Long, otaUrl: String, targetVersion: String (Long as string), targetVersionString: String, dryRun: Bool, endpoint: Int`
- **Returns:** `true` (immediately; progress arrives on device_state channel)
- **Errors:** `OTA_DOWNLOAD_ERROR`

#### `cancelOta`
- **Args:** none
- **Returns:** `true`

---

### Network / Thread

#### `scanWifiNetworks`
- **Args:** none
- **Returns:** `List<Map { ssid: String, rssi: Int, isConnected: Bool }>`

#### `readAndroidThreadCredentials`
- **Args:** none
- **Returns:** `String?` — hex Thread dataset TLV, or null if unavailable. **Android-only.**

#### `discoverThreadNetworks`
- **Args:** none
- **Returns:** JSON `String` — array of border-router objects

#### `readThreadNetworkDiagnostics`
- **Args:** `nodeId: Int|Long`
- **Returns:** JSON `String` — Thread diagnostics object
- **Errors:** `CLUSTER_ABSENT` (Wi-Fi device)

#### `runNetworkDiagnostics`
- **Args:** none
- **Returns:** JSON `String` — full diagnostics report

---

## EventChannel — `com.fluxhome.app/commission_events`

Emits plain `String` lines during an active commissioning operation. Lines are
human-readable progress messages (emoji-prefixed). No schema — for logging and
display only.

---

## EventChannel — `com.fluxhome.app/device_state`

Emits `Map<String, dynamic>` payloads. Every map has:

| Key | Type | Always present |
|-----|------|---------------|
| `nodeId` | `Int` | ✓ |
| `type` | `String` | ✓ |

### `type = "established"`
Subscription handshake complete; initial data report follows.

### `type = "resubscribing"`
| Key | Type |
|-----|------|
| `nextMs` | `Int` — milliseconds until next retry |

### `type = "error"`
| Key | Type |
|-----|------|
| `message` | `String` |

### `type = "otaProgress"`
| Key | Type | Notes |
|-----|------|-------|
| `phase` | `String` | `download \| querying \| installing \| applying \| complete \| dryrun \| error` |
| `progress` | `Int?` | 0–100; omitted for non-progress phases |
| `message` | `String?` | Error description; omitted otherwise |

### `type = "update"`
All subscription attribute keys from `SubscriptionKeys.kt` / `subscription_keys.dart`
may be present. Consumers must handle any subset. Key definitions:

| Key | Type | Unit / Notes |
|-----|------|-----|
| `onOff` | `Bool` | |
| `level` | `Int` | 0–254 |
| `localTempCenti` | `Int` | centidegrees °C; 0x8000 sentinel already stripped |
| `heatingSetptCenti` | `Int` | centidegrees °C |
| `coolingSetptCenti` | `Int` | centidegrees °C |
| `systemMode` | `Int` | 0=Off 1=Auto 3=Cool 4=Heat |
| `controlSequence` | `Int` | |
| `humidityCenti` | `Int` | 0.01 %RH |
| `tempMeasureCenti` | `Int` | centidegrees °C |
| `batPercentRaw` | `Int` | 0–200 (÷2 for %) |
| `batChargeLevel` | `Int` | 0=OK 1=Warning 2=Critical |
| `occupancy` | `Int` | bit 0 = occupied |
| `contactState` | `Bool` | true = closed |
| `airQuality` | `Int` | 1=Good … 6=ExtremePoor |
| `pm25` | `Int` | µg/m³ × 10 |
| `co2Ppm` | `Int` | ppm (direct) |
| `coPpm` | `Int` | ppm × 10 |
| `liftPercent100ths` | `Int` | 0=open 10 000=closed |
| `fanMode` | `Int` | 0=Off … 6=Smart |
| `fanPercent` | `Int` | 0–100 |
| `colorTempMireds` | `Int` | mireds |
| `smokeState` | `Int` | 0=Normal 1=Warning 2=Critical |
| `coState` | `Int` | 0=Normal 1=Warning 2=Critical |
| `switchCurrentPosition` | `Int` | 0 = released |
| `switchCurrentEndpoint` | `Int` | endpoint the press came from |
| `switchLastPosition` | `Int` | last non-zero press position |
| `switchLastEndpoint` | `Int` | endpoint of last non-zero press |
| `switchPressTime` | `Int` | `System.currentTimeMillis()` of press |
| `activePower` | `Int` (Long) | mW |
| `voltage` | `Int` (Long) | mV |
| `activeCurrent` | `Int` (Long) | mA |
| `cumulativeEnergyWh` | `Int` (Long) | Wh (converted from mWh on Kotlin side) |

---

## iOS Porting Notes

| Android concept | iOS equivalent |
|---|---|
| `ChipDeviceController` | `MTRDeviceController` |
| `AndroidChipPlatform` | Framework-managed; no explicit init |
| `BleConnectionManager` | `MTRDevice` / `MTRCommissioningParameters` |
| `SetupPayloadHelper` | `MTRSetupPayload(onboardingPayload:)` |
| `MatterForegroundService` | `BGAppRefreshTask` + `MTRDevice` auto-resubscribe |
| `WifiManager.MulticastLock` | Not needed (iOS handles mDNS natively) |
| `NsdManager` | `NetService` / `NWBrowser` |
| `AndroidThreadCredentialReader` | `MTRSetupPayload` thread dataset APIs |
| `SubscriptionManager.subscribeDeviceState` | `MTRDevice.addObserver(_:queue:)` |
| `shutdownSubscriptions(fabricIndex, nodeId)` | `MTRDevice` dealloc / `removeObserver` |
| `OTAProviderDelegate` | `MTROTAProviderDelegate` |

All method names, argument names, return shapes, and event payloads in this
document must be matched identically in both implementations.
