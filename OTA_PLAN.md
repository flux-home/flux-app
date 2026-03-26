# Flux — Firmware OTA Plan

> **Status:** Plan only — not yet implemented  
> **Date:** 2026-03-26

---

## How Matter OTA works

```
App (OTA Provider)                          Device (OTA Requestor)
        │                                           │
  startOTAProvider()                               │
        │                                           │
        │──── AnnounceOTAProvider ────────────────▶│
        │                                           │  (device initiates back)
        │◀─── QueryImage ─────────────────────────│
        │                                           │
  handleQueryImage()                               │
  → returns filePath + version                     │
        │                                           │
        │──── QueryImageResponse ────────────────▶│
        │           (UpdateAvailable)               │
        │                                           │  (BDX transfer)
        │◀─── BDX: TransferInit ──────────────────│
  handleBDXTransferSessionBegin()                  │
        │                                           │
        │◀─── BDX: BlockQuery ────────────────────│  (repeated)
  handleBDXQuery() → BDXData(bytes, isEOF)         │
        │──── BDX: Block ────────────────────────▶│
        │                                           │
  handleBDXTransferSessionEnd()                    │
        │                                           │
        │◀─── ApplyUpdateRequest ─────────────────│
  handleApplyUpdateRequest() → Proceed             │
        │──── ApplyUpdateResponse ───────────────▶│
        │                                           │
  handleNotifyUpdateApplied()                      │  (device reboots)
        │                                           │
  finishOTAProvider()                              │
```

The CHIP SDK handles BDX framing and CASE sessions. Our code only needs to:
1. Provide the firmware file path to `QueryImageResponse`
2. Return file chunks from `handleBDXQuery`

---

## What the CHIP SDK AAR already has

From decompiling `CHIPController.aar`:

```java
// ChipDeviceController
void startOTAProvider(OTAProviderDelegate delegate)
void finishOTAProvider()

// OTAProviderDelegate (interface we implement)
QueryImageResponse handleQueryImage(int vendorId, int productId, long softwareVersion,
    Integer hardwareVersion, String location, Boolean requestorCanConsent, byte[] metadataForProvider)
void handleOTAQueryFailure(int errorCode)
void handleBDXTransferSessionBegin(long transferSessionId, String fileDesignator, long length)
BDXData handleBDXQuery(long transferSessionId, int blockSize, long blockIndex,
    long bytesToSkip)   // → BDXData(byte[], isEOF)
void handleBDXTransferSessionEnd(long errorCode, long transferSessionId)
ApplyUpdateResponse handleApplyUpdateRequest(long nodeId, long newVersion)
default void handleNotifyUpdateApplied(long nodeId)

// OtaSoftwareUpdateRequestorCluster (on the device)
void announceOTAProvider(DefaultClusterCallback, Long providerNodeId, Integer vendorId,
    Integer announcementReason, Optional<byte[]> metadataForProvider, Integer endpoint)
void subscribeUpdateStateAttribute(IntegerAttributeCallback, minInterval, maxInterval)
void subscribeUpdateStateProgressAttribute(NullableIntegerAttributeCallback, min, max)
```

---

## What the DCL has (verified live)

Endpoint: `https://on.dcl.csa-iot.org/dcl`

| Query | Example (Eve Energy EU) |
|---|---|
| `GET /model/models/{vid}/{pid}` | Product info, name, commissioning hints |
| `GET /model/versions/{vid}/{pid}` | `softwareVersions: [6200, 6620, 6650, 9082]` |
| `GET /model/versions/{vid}/{pid}/{swVer}` | Full version entry (see below) |

Example version entry for Eve 9082 (`3.5.0`):
```json
{
  "softwareVersion": 9082,
  "softwareVersionString": "3.5.0",
  "softwareVersionValid": true,
  "otaUrl": "https://eve-updates.evehome.com/matter/eve_energy_eu-r3.5.0-....bin",
  "otaFileSize": "881923",
  "otaChecksum": "G+g+y5ksfMqzxwoq6uDblACdFkiGzB1cMJoypqSTSTA=",
  "otaChecksumType": 1,
  "minApplicableSoftwareVersion": 6200,
  "maxApplicableSoftwareVersion": 9081,
  "releaseNotesUrl": "https://..."
}
```

`otaChecksumType: 1` = SHA-256.  
A version is applicable to a device running `currentVer` when:  
`minApplicableSoftwareVersion ≤ currentVer ≤ maxApplicableSoftwareVersion`.

---

## What the app already has

| Thing | Where | Gap |
|---|---|---|
| `vendorId`, `productId` | `DeviceLiveData`, read by `readBasicInfo` | ✓ have it |
| `softwareVersionString` | `DeviceLiveData.softwareVersion` (display only) | ✓ have it |
| **`softwareVersion` (uint32)** | **NOT read** | ⚠ need attribute 0x0009 |
| OTA Requestor cluster check | not checked | ⚠ need endpoint scan |
| DCL queries | none | ⚠ new service |
| Firmware download | none | ⚠ new |
| OTA Provider / BDX | none | ⚠ new |
| OTA status subscription | none | ⚠ new |
| OTA UI | none | ⚠ new |

---

## Implementation plan

### Phase 1 — Version data (prerequisite for everything else)

**1.1 Read numeric `softwareVersion` from device**

`BasicInformation` cluster attribute `0x0009` is `uint32` — distinct from `0x000A SoftwareVersionString`.  
Update `ClusterClient.readBasicInfo()` to also read attr `0x0009` and return it.  
Add `softwareVersionNum: Long?` to the `BasicInfo` data class.  
Store it in `DeviceLiveData` (`softwareVersionNum: Long?`) and persist in `MatterDevice`.

**1.2 Parse vendorId / productId as integers**

`readBasicInfo` currently returns VID/PID as hex strings (`"0x130A"`).  
Parse them to `Int` at read time so they can be passed directly to DCL queries.

---

### Phase 2 — DCL version check service

New file: `lib/services/dcl_service.dart`

```dart
class DclService {
  static const _base = 'https://on.dcl.csa-iot.org/dcl';

  /// Returns the latest applicable firmware version for this device,
  /// or null if none found or device is already up to date.
  static Future<DclFirmwareVersion?> checkForUpdate({
    required int vendorId,
    required int productId,
    required int currentSoftwareVersion,
  }) async { ... }
}

class DclFirmwareVersion {
  final int    softwareVersion;
  final String softwareVersionString;
  final String otaUrl;
  final int    otaFileSize;
  final String otaChecksum;       // base64 SHA-256
  final String? releaseNotesUrl;
}
```

Logic inside `checkForUpdate`:
1. `GET /model/versions/{vid}/{pid}` → list of `softwareVersions` integers
2. Sort descending, walk until `minApplicable ≤ currentVer ≤ maxApplicable`
3. Return the first applicable version that is `> currentSoftwareVersion`
4. Cache result per `(vid, pid, currentVer)` with a TTL (e.g. 24 h) to avoid hammering DCL

**Rate limiting**: DCL is public infrastructure. Cache aggressively. Don't query on every app launch.

---

### Phase 3 — Firmware download

New file: `android/.../chip/OtaDownloader.kt`

```kotlin
object OtaDownloader {
    // Downloads to app-private cache dir: otaCache/{vid}_{pid}_{swVer}.bin
    // Streams to disk, verifies SHA-256 checksum on completion.
    // Reports progress 0.0–1.0 via callback.
    suspend fun download(
        url: String,
        expectedSize: Long,
        expectedChecksum: String,  // base64 SHA-256
        onProgress: (Float) -> Unit,
    ): File
}
```

- Store in `context.cacheDir/ota/` so Android can reclaim space when needed
- Skip download if file already exists AND checksum matches (resume-safe re-use)
- On checksum mismatch: delete and re-download
- Expose progress via a `Flow<OtaDownloadState>` bridged to Flutter through the existing device-state `EventChannel` (add a new event type `"otaDownloadProgress"`)

---

### Phase 4 — Android OTA Provider

New file: `android/.../chip/OtaProvider.kt`

```kotlin
class OtaProvider(
    private val firmwareFile: File,
    private val targetSoftwareVersion: Long,
    private val targetSoftwareVersionString: String,
    private val onStatusUpdate: (OtaProviderStatus) -> Unit,
) : OTAProviderDelegate {

    override fun handleQueryImage(...): QueryImageResponse {
        return QueryImageResponse(
            softwareVersion       = targetSoftwareVersion,
            softwareVersionString = targetSoftwareVersionString,
            filePath              = firmwareFile.absolutePath,
            userConsentNeeded     = false,
        )
    }

    override fun handleBDXTransferSessionBegin(sessionId, fileDesignator, length) {
        onStatusUpdate(OtaProviderStatus.Transferring(0f))
    }

    override fun handleBDXQuery(sessionId, blockSize, blockIndex, bytesToSkip): BDXData {
        // Read blockSize bytes starting at blockIndex * blockSize from the file
        // Report progress
    }

    override fun handleBDXTransferSessionEnd(errorCode, sessionId) { ... }

    override fun handleApplyUpdateRequest(nodeId, newVersion): ApplyUpdateResponse {
        return ApplyUpdateResponse(ApplyUpdateActionEnum.Proceed, 0L)
    }

    override fun handleNotifyUpdateApplied(nodeId) {
        onStatusUpdate(OtaProviderStatus.Applied)
    }
}

sealed class OtaProviderStatus {
    data class Transferring(val progress: Float) : OtaProviderStatus()
    object Applied : OtaProviderStatus()
    data class Failed(val error: String) : OtaProviderStatus()
}
```

**Important:** `startOTAProvider` registers our node as an OTA Provider on the fabric. The device must be able to establish a CASE session back to the phone's node ID. This requires the phone to have a stable IPv6 address reachable from the device — the same condition the Network Check screen already verifies.

---

### Phase 5 — OTA orchestration in MatterBridge

New method `startOtaUpdate(nodeId, firmwareFile, targetVersion)` in `MatterBridge`:

```kotlin
fun startOtaUpdate(nodeId: Long, firmwareFile: File, newVersion: DclFirmwareVersion,
                   result: MethodChannel.Result) {
    scope.launch {
        val provider = OtaProvider(firmwareFile, newVersion.softwareVersion, ...) { status ->
            emitDeviceState(mapOf(
                "nodeId" to nodeId.toInt(),
                "type"   to "otaStatus",
                "status" to status.name,
                "progress" to (status as? OtaProviderStatus.Transferring)?.progress,
            ))
        }

        // 1. Register as OTA Provider on this fabric
        ChipClient.getController().startOTAProvider(provider)

        // 2. Get a CASE session to the device
        val devicePtr = ClusterClient.getDevicePointer(context, nodeId)

        // 3. Tell the device to check for updates from us
        val requestor = OtaSoftwareUpdateRequestorCluster(devicePtr, endpoint = 0)
        requestor.announceOTAProvider(
            callback          = ...,
            providerNodeId    = ChipClient.getController().compressedFabricId, // our node ID
            vendorId          = ourVendorId,
            announcementReason = 1, // UpdateAvailable
            metadataForProvider = Optional.empty(),
            endpoint          = 0,
        )

        // 4. Subscribe to UpdateState + UpdateStateProgress on the device
        requestor.subscribeUpdateStateAttribute(...)
        requestor.subscribeUpdateStateProgressAttribute(...)

        // 5. Wait for completion / timeout
        // finishOTAProvider() is called in handleNotifyUpdateApplied or on error
    }
}
```

**Timeout**: OTA can take minutes for large firmware. Set a generous timeout (e.g. 10 min) and surface partial progress.

---

### Phase 6 — Flutter side

**6.1 DeviceProvider changes**

```dart
// New method
Future<OtaUpdateInfo?> checkForUpdate(String deviceId) async { ... }
Future<void> startOtaUpdate(String deviceId, OtaUpdateInfo info) async { ... }

// New state in DeviceLiveData
final OtaStatus? otaStatus;   // null | downloading | transferring(%) | applying | done | failed
```

Handle new `"otaStatus"` events from the device state stream in `_onDeviceStateEvent`.

**6.2 New model: `lib/models/ota_update_info.dart`**

```dart
class OtaUpdateInfo {
  final int    newSoftwareVersion;
  final String newVersionString;
  final String otaUrl;
  final int    fileSizeBytes;
  final String? releaseNotesUrl;
}

enum OtaStatusPhase { checking, downloading, transferring, applying, done, failed }

class OtaStatus {
  final OtaStatusPhase phase;
  final double? progress;  // 0.0–1.0 during downloading + transferring
  final String? error;
}
```

**6.3 Device settings screen — "Firmware" section**

Add below the existing Tools section in `DeviceSettingsScreen`:

```
┌──────────────────────────────────────┐
│ Firmware                             │
│ ─────────────────────────────────    │
│ Current   3.2.1 (build 6620)         │
│ Latest    3.5.0 (build 9082)  [NEW]  │
│                                      │
│  [ Update to 3.5.0 ]                 │
│  Release notes ↗                     │
└──────────────────────────────────────┘
```

- "Check" happens automatically when screen opens (uses cached result for 24 h)
- Button disabled while another OTA is in progress
- Tapping "Update" → confirms, starts download + OTA

**6.4 OTA progress screen**

Full-screen overlay (or bottom sheet) while update is in progress:

```
Updating Eve Energy
─────────────────────────────────────

  ████████████░░░░░░░  62%

  Downloading firmware…   (or "Transferring to device…" / "Applying…")

  Do not power off the device

  [ Cancel ]   ← only available during download phase
```

**6.5 Home screen device card badge**

When `checkForUpdate` returns a result, show a small amber `↑` badge on the device card so users notice without going into settings.

---

## Edge cases & failure modes

| Scenario | Handling |
|---|---|
| Device doesn't have OTA Requestor cluster (0x002A) | Check cluster list before offering update; hide the section |
| DCL has no entry for this VID/PID | Hide firmware section silently; log for debugging |
| No applicable version (`currentVer` outside `min/max` range) | Show "Up to date" |
| Phone loses IP connectivity mid-transfer | BDX session will time out; device retries from last block if session can be re-established |
| Checksum mismatch on download | Delete file, show error, allow retry |
| Device reboots and changes nodeId | Not possible in Matter (nodeId is fabric-bound); reconnect via existing subscription |
| User kills app during BDX transfer | Device retries on next `AnnounceOTAProvider`; firmware is not applied until `ApplyUpdateRequest` succeeds |
| Two devices updating simultaneously | One `OTAProviderDelegate` can handle multiple concurrent sessions via `transferSessionId`; implement but gate UI to one at a time |
| `otaUrl` is empty in DCL | Manufacturer hasn't published an OTA URL; show "Check manufacturer's app" |

---

## Files to create / modify

### New files
| File | Purpose |
|---|---|
| `lib/services/dcl_service.dart` | DCL HTTP queries + caching |
| `lib/models/ota_update_info.dart` | `OtaUpdateInfo`, `OtaStatus`, `OtaStatusPhase` |
| `android/.../chip/OtaDownloader.kt` | Firmware download + SHA-256 verification |
| `android/.../chip/OtaProvider.kt` | `OTAProviderDelegate` implementation |
| `lib/ui/screens/ota_progress_screen.dart` | Full-screen OTA progress UI |

### Modified files
| File | Change |
|---|---|
| `ClusterClient.kt` | Read attr `0x0009` (uint32 softwareVersion) in `readBasicInfo` |
| `MatterBridge.kt` | Add `startOtaUpdate`, emit `otaStatus` events |
| `MainActivity.kt` | Route `startOtaUpdate` method call |
| `matter_channel.dart` | `startOtaUpdate()`, handle `otaStatus` events |
| `models/device_live_data.dart` | Add `softwareVersionNum: Long?`, `otaStatus: OtaStatus?` |
| `models/matter_device.dart` | Persist `softwareVersionNum` |
| `providers/device_provider.dart` | `checkForUpdate()`, `startOtaUpdate()`, handle otaStatus events |
| `ui/screens/device_settings_screen.dart` | Firmware section with version + update button |
| `ui/widgets/device_card.dart` | Update available badge |

---

## Open questions before implementing

1. **Our vendor ID for `announceOTAProvider`**: The call requires the phone's VID on the fabric. `ChipClient.getController().compressedFabricId` gives the fabric ID but not the admin VID. Need to confirm the correct value to pass — likely the VID from `ControllerParams` (currently hardcoded as `0xFFF1` test VID).

2. **OTA Provider endpoint**: `startOTAProvider` registers on what endpoint? The spec says OTA Provider cluster sits on endpoint 0 of the provider node. Confirm the CHIP SDK default.

3. **Concurrent OTA sessions**: `OTAProviderDelegate.handleBDXQuery` receives a `transferSessionId` — confirm the SDK can handle multiple concurrent sessions or whether it serialises them.

4. **App backgrounding during transfer**: Android may kill the process. Consider a `ForegroundService` for the duration of the OTA transfer so Android keeps the process alive and the BDX session stays open.

5. **DCL rate limits**: No published rate limit found. Cache per `(vid, pid, currentVer)` in `SharedPreferences` with a 24-hour TTL to be conservative.
