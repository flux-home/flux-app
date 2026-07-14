# iOS build wiring for flux-ice (remote-access tunnel)

The Swift shim (`Runner/bridge/FluxIceBridge.swift`) + bridging-header import
(`Runner/Runner-Bridging-Header.h`) are written, but the native C must be added
to the Xcode project on a **macOS** machine (it cannot be compiled on the Linux
dev host). iOS is a Darwin/BSD target, so — like Android and unlike the ESP-IDF
controller — it uses the **unpatched libjuice + the BSD bridge**; no lwIP, no
port patch.

## Add to the Runner target

Compile these sources from the `flux-interface` submodule (repo root) plus
libjuice:

```
flux-interface/flux-ice/core/flux_ice.c
flux-interface/flux-ice/core/flux_ice_types.c
flux-interface/flux-ice/udp/flux_ice_bridge_bsd.c
flux-interface/flux-ice/mobile/flux_ice_mobile.c
flux-interface/flux-ice/third_party/libjuice/src/*.c
```

Recommended: a small **CocoaPods** podspec (or an Xcode static-library
subproject) that builds the above with:

- **Header search paths:** `flux-interface/flux-ice/include`,
  `flux-interface/flux-ice/third_party/libjuice/include`,
  `flux-interface/flux-ice/third_party/libjuice/include/juice`,
  `flux-interface/flux-ice/third_party/libjuice/src`
- **Preprocessor defs:** `NO_SERVER=1`, `JUICE_STATIC=1` (client only; internal
  crypto — libjuice uses arc4random / getifaddrs on Darwin natively).
- Do **not** define `USE_NETTLE`; do not build libjuice's `server.c`.

The bridging header already does `#import "flux_ice/flux_ice_mobile.h"`, so once
the header search path is set, `FluxIceBridge.swift` sees the C API. Registration
is wired in `AppDelegate.didInitializeImplicitFlutterEngine`.

## Contract (must match Android)

- MethodChannel `com.fluxhome.app/flux_ice`: `start{stunHost?,stunPort} ->
  {handle:Int, offer:String}`, `setAnswer{handle,answer}->Int`,
  `localPort{handle}->Int`, `stop{handle}`.
- EventChannel `com.fluxhome.app/flux_ice_events`: listen-arg = handle; emits the
  ICE state int (0 NEW … 3 CONNECTED … 4 FAILED, 5 CLOSED).

The Dart side (`lib/services/flux_ice_channel.dart`) is platform-agnostic and
already targets this contract.
