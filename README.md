# Flux

![Flux feature graphic](store-feature-graphic-v2.png)

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

## Legal notices

This project is licensed under the **Apache License 2.0** — see [`LICENSE`](LICENSE).
See [`NOTICE`](NOTICE) for third-party attributions.

**Trademarks**
- *Matter* is a trademark of the Connectivity Standards Alliance (CSA).
- *Thread* is a trademark of the Thread Group, Inc.
- Use of these names in this project is nominative/descriptive only. This project is not
  certified by, endorsed by, or affiliated with the CSA or the Thread Group.

**connectedhomeip (CHIP SDK)**
This app is built on top of [`project-chip/connectedhomeip`](https://github.com/project-chip/connectedhomeip),
licensed under Apache 2.0. The compiled AAR is not bundled in this repository;
use `android/get_chip_sdk.sh` to obtain it.

**CSA Distributed Compliance Ledger (DCL)**
The OTA update feature queries the public DCL REST API at `https://on.dcl.csa-iot.org`.
This is a CSA-operated service; its use is subject to CSA's terms.
