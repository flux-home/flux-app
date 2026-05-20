# Work-in-progress files

Files in this directory are **not part of the build**. They are excluded
from `dart analyze` via `analysis_options.yaml` so half-finished work
doesn't generate analyzer noise that drowns real errors.

When a file here is ready to ship:

1. Move it back to its intended location under `lib/`.
2. Wire it in (e.g. add to `device_detail_screen.dart`'s `part` directives,
   add the matching DeviceProvider methods, etc).
3. Make sure `dart analyze` is clean.

## Currently shelved

| File | Reason |
|---|---|
| `device_detail/door_lock_card.dart` | References `DeviceView.lockState`, `DeviceProvider.lockDoor/unlockDoor` — none of which exist yet. Matching Kotlin work in `android/app/.../bridge/DoorLockBridge.kt` + `chip/clusters/DoorLockCluster.kt`. |
| `device_detail/water_heater_card.dart` | Compiles today but is not part-of `device_detail_screen.dart`, so it never gets included in any device-type switch. Matching Kotlin work in `WaterHeaterBridge.kt` + `WaterHeaterCluster.kt`. |
