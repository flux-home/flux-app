---
name: flux-architecture
description: Reference for the Flux app architecture, file layout, naming conventions and coding patterns. Use when adding new features, new clusters, new screens, or refactoring. Also use when asked "where does X live?" or "how should I implement Y?".
---

# Flux Architecture

Project root: `/home/tado/workspace/flux/app`

Full architecture is documented in `README.md`. This skill provides the
actionable rules an AI agent needs to stay consistent when making changes.

---

## Guiding principles

1. **One concern per file.** Screens that grow beyond ~300 lines should be split
   using Dart `part`/`part of` (preserves `_`-type privacy) or into a sub-folder.
2. **No logic in screens.** Business logic (OTA detection, device refresh,
   commissioning) belongs in `DeviceProvider`. Screens call provider methods.
3. **`MatterChannel` is a dumb bridge.** It translates Dart calls to
   `MethodChannel` and back. No state, no logic beyond decoding the raw result.
4. **`ClusterClient` is a pure facade.** Every public method is one line
   delegating to a domain object in `chip/clusters/`. `MatterBridge` only calls
   `ClusterClient`, never the domain objects directly.
5. **Subscription is source of truth.** Never use optimistic caching for
   on/off/sensor state. Update `_liveCache` only after a successful command
   (post-acknowledge), never before sending it.

---

## Adding a new Matter cluster (Kotlin side)

1. Create `android/app/src/main/kotlin/com/example/matter_home/chip/clusters/XyzCluster.kt`
2. Use `internal object XyzCluster` with `private const val TAG = "XyzCluster"`
3. Import order: `android.*` → `chip.*` / `matter.*` → `com.example.*` → `kotlin.*`
4. **Reads** — use `readAttributes<T>(context, nodeId, path/paths, fallback, TAG) { state -> ... }`
   - Returns fallback on any error, never throws
   - Use `readAttributeOrThrow<T>(...)` only when the caller needs to distinguish
     offline (throws) from "attribute = default value"
5. **Writes** — use `writeAttribute(context, nodeId, req, TAG)` or `writeAttribute(context, nodeId, req, TAG) { status -> /* validate */ }`
6. **Invocations** — use `invoke(context, nodeId, element)`
   - Both helpers are in `ClusterUtils.kt`; no manual `getConnectedDevicePointer` needed
7. Add a one-line delegation method to `ClusterClient.kt`
8. Add a method to `MatterBridge.kt` that calls `ClusterClient.xyz(...)`
9. Add the method call to `MainActivity.kt`'s `when (call.method)` block
10. Add a Dart wrapper to `MatterChannel` using `_invoke<T>(method, fallback, ...)`

### ClusterUtils helpers quick reference

```kotlin
// Read — returns fallback on error
readAttributes(context, nodeId, path, fallback, TAG) { state -> ... }
readAttributes(context, nodeId, listOf(p1, p2), fallback, TAG) { state -> ... }

// Read — throws on error (use for online/offline detection)
readAttributeOrThrow(context, nodeId, path, TAG) { state -> ... }

// Write — resumes on onDone; validateResponse may throw to reject IM status
writeAttribute(context, nodeId, req, TAG)
writeAttribute(context, nodeId, req, TAG) { status -> if (!ok) throw Exception(...) }

// Invoke a command
invoke(context, nodeId, InvokeElement.newInstance(...))
```

---

## Adding a new feature to `DeviceProvider`

File: `lib/providers/device_provider.dart`

- Live-cache mutations: always use `_mergeLiveCache(deviceId, (e) => e.copyWith(...))` — it handles the null-check and calls `notifyListeners()`
- To persist a device field: call `_devices[idx] = device.copyWith(...)` then `await _persist()`
- Subscription-event handling: add a case to `_onDeviceStateEvent`'s `switch (type)` block

---

## Adding a new field to `DeviceLiveData`

File: `lib/models/device_live_data.dart`

1. Add `final T? fieldName;` to the class
2. Add `this.fieldName,` to the constructor
3. Add `Object? fieldName = _keep,` to `copyWith` signature
4. Add `fieldName: v(fieldName, this.fieldName),` to the `copyWith` body
5. If it comes from subscriptions: add extraction in `SubscriptionManager.extractAttrs` (Kotlin) and add `pick('key')` in `DeviceLiveData.merge` (Dart)

The `_keep` sentinel means `copyWith()` with no args returns an identical copy; passing `fieldName: null` explicitly sets it to null.

---

## Adding a new screen

### Top-level screen (reachable from any screen / deep link)
1. Create `lib/ui/screens/my_screen.dart`
2. Add a `GoRoute` entry in `lib/router.dart`
3. Navigate with `context.push('/my-route')`

### Sub-screen (only reachable from one parent)
1. Create `lib/ui/screens/parent_area/my_screen.dart` (use a sub-folder matching the parent)
2. Push with `Navigator.push(context, MaterialPageRoute(builder: (_) => MyScreen(...)))`
3. Do **not** add to `router.dart`

### Splitting a large screen file
Use Dart `part`/`part of` to split while keeping `_`-prefixed types private:
```dart
// my_screen.dart (host)
part 'my_screen/widgets.dart';
part 'my_screen/models.dart';

// my_screen/widgets.dart
part of '../my_screen.dart';
// ... private widget classes here
```

---

## `MatterChannel._invoke` quick reference

```dart
// Simple bool
Future<bool> doThing(int nodeId) =>
    _invoke('doThing', false, args: {'nodeId': nodeId});

// With decode
Future<List<int>> readList(int nodeId) =>
    _invoke<List<int>>('readList', [], args: {'nodeId': nodeId},
        decode: (raw) => (raw as List?)?.map((e) => e as int).toList() ?? []);

// Nullable result
Future<String?> readString(int nodeId) =>
    _invoke<String?>('readString', null, args: {'nodeId': nodeId});

// Complex decode
Future<MyModel?> readModel(int nodeId) =>
    _invoke<MyModel?>('readModel', null, args: {'nodeId': nodeId},
        decode: (raw) {
          if (raw == null) return null;
          final map = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
          return MyModel.fromMap(map);
        });
```

Commission flows (`commissionDevice`, `commissionViaIp`) do **not** use `_invoke`
because they return `CommissionResult.err(...)` on failure, not a simple fallback.

---

## Dot-matrix display

Use `DotMatrixPainter` for `CustomPaint` widgets, or `paintDotMatrix()` for
drawing inside a `CustomPainter.paint()` method.

```dart
// Widget form
SizedBox(
  height: 56,
  child: CustomPaint(
    painter: DotMatrixPainter(
      text: '42%',
      litColor: Colors.white,
      dimColor: Colors.white12,
    ),
  ),
)

// Inside CustomPainter.paint()
paintDotMatrix(canvas, centre,
  '21.5',
  maxWidth: size.width * 0.8,
  maxHeight: size.height * 0.4,
  color: Colors.white,
);
```

Supported characters: `0-9`, `.`, `-`, `%`, `O`, `N`, `F`, `o`, `f`, `l`, `i`, `n`, `e`

---

## OTA update flow

1. **DCL lookup**: `DclService.checkForUpdate(vid, pid, currentVersion)` → `DclUpdateResult`
2. **Download + flash**: `MatterChannel.downloadAndFlash(nodeId, otaUrl, ...)` 
   - Emits progress events on `deviceStateUpdates` stream as `{type:"otaProgress", phase:..., progress:..., message:...}`
   - Phases: `download` → `querying` → `installing` → `applying` → `complete` / `dryrun` / `error`
3. **Cancel**: `MatterChannel.cancelOta()` — marks `NotAvailable` then waits 3 s before stopping provider (lets device record a clean "no update" response)
4. **Dry run** (`dryRun: true`): BDX transfer completes but `handleApplyUpdateRequest` returns `Discontinue`

OTA endpoint detection is in `DeviceProvider.detectAndUpdateOtaSupport(deviceId)`.

---

## Subscription recovery

Subscriptions use `autoResubscribe = true`. If the SDK's exponential backoff
grows beyond 30 s (permanent UDP socket failure after power cycle),
`MatterBridge.startSubscriptionForNode` forces a clean restart after a 2 s pause.

After a successful `toggle()` command, `DeviceProvider` updates `_liveCache` with
the new on/off state so the UI stays in sync even when the subscription is stale.

---

## Commissioning flow (BLE manual code)

- `SetupPayloadHelper.parse(raw)` handles both `"MT:…"` QR payloads and 11-digit
  numeric manual codes via `OnboardingPayloadParser`
- Manual codes have `hasShortDiscriminator = true`; the BLE scan filter uses
  the 4-bit value in `disc[11:8]` of the service data byte 2 (mask `0x0F`)
- Manual codes do **not** encode discovery capabilities → `capabilitiesUnknown = true`
  → UI shows both BLE and IP options, defaults to BLE
- Discriminator from manual codes is **not** pre-filled in the IP form
  (it's a 4-bit short discriminator, not usable for full 12-bit mDNS lookup)
