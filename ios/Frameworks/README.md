# ios/Frameworks/Matter.xcframework

Pre-built Matter SDK framework for the Flux iOS app.

## Contents

| Slice | Architectures | Use |
|---|---|---|
| `ios-arm64` | arm64 | Physical iPhone/iPad |

> The simulator slice (`ios-arm64_x86_64-simulator`) is not distributed —
> build from source with `--build` if you need it.

## Source

| Field | Value |
|---|---|
| Repository | https://github.com/project-chip/connectedhomeip |
| Tag | `v1.5.0.0` |
| Commit | `191158d3bb1dd6f5381bcb9a3e3b7b1f340a3185` |
| Xcode | 16.4 |
| iOS deployment target | 14.0 |

## How to rebuild

```bash
bash ios/get_chip_sdk_ios.sh --build
```

Or download the pre-built asset from the release (fast, no Xcode compile needed):

```bash
bash ios/get_chip_sdk_ios.sh --ci   # requires: gh auth login
```

Release: https://github.com/locomuco/fluxhome/releases/tag/chip-sdk-v1.5.0.0

This script:
1. Clones `connectedhomeip` at the pinned tag into `/tmp/connectedhomeip`
2. Syncs the Darwin submodules (shallow)
3. Bootstraps the CHIP Python build environment (`scripts/activate.sh`)
4. Builds `Matter.framework` for `iphoneos` (arm64) via `xcodebuild`
5. Builds `Matter.framework` for `iphonesimulator` (arm64 + x86_64) via `xcodebuild`
6. Packages both slices into `Matter.xcframework` via `xcodebuild -create-xcframework`
7. Copies the result here

Prerequisites (one-time):
```bash
brew install cmake ninja python@3.11
xcodebuild -downloadPlatform iOS   # downloads iOS Simulator runtime (~9 GB)
```

To upgrade to a newer connectedhomeip release, update `CHIP_TAG` in
`get_chip_sdk_ios.sh` and delete `/tmp/connectedhomeip` before re-running.
