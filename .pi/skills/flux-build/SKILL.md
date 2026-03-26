---
name: flux-build
description: Builds the Flux Flutter app and installs the release APK on the connected Android device over WiFi ADB. Use when the user asks to build, install, deploy, or "do it again" after code changes.
---

# flux-build

Builds the Flux Flutter/Android app and installs it on the WiFi-connected device.

## Environment

```bash
export JAVA_HOME=/home/tado/workspace/jdk-17
export PATH=$JAVA_HOME/bin:$PATH
```

## Build

```bash
cd /home/tado/workspace/flux/app && flutter build apk --release
```

## Connect device over WiFi (if not already connected)

Plug in USB once, then:

```bash
adb tcpip 5555
sleep 2
IP=$(adb shell ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
adb connect $IP:5555
# USB can be unplugged after this
```

Check connection:

```bash
adb devices
```

The device should show as `<IP>:5555  device`.

## Install

```bash
adb -s 192.168.1.123:5555 install -r /home/tado/workspace/flux/app/build/app/outputs/flutter-apk/app-release.apk
```

## Build + Install in one shot

```bash
export JAVA_HOME=/home/tado/workspace/jdk-17 && \
export PATH=$JAVA_HOME/bin:$PATH && \
cd /home/tado/workspace/flux/app && \
flutter build apk --release && \
adb -s 192.168.1.123:5555 install -r build/app/outputs/flutter-apk/app-release.apk
```

## Notes

- The WiFi ADB target is `192.168.1.123:5555` (Pixel, last seen on this network).
- If the device is unreachable, plug in USB, run the "Connect device over WiFi" steps above, then unplug.
- Use `flutter build apk --debug` and `app-debug.apk` for debug builds when needed.
