# ADR-0002: Consume flux-interface as a submodule, build from source

- **Status:** Accepted (design stage — not yet implemented)
- **Date:** 2026-07-13
- **Scope:** app-only
- **Relates to:** flux-interface ADR-0008; flux-app ADR-0001

## Context

flux-ice now lives in the flux-interface repo (flux-interface ADR-0008). The app
today has **no git submodules** and consumes native code as prebuilt blobs (CHIP
via `get_chip_sdk_ios.sh`) and the wire schema as a **hand-copied**
`lib/services/proto/flux.pb.dart`. It now needs the flux-ice **C source** too,
which a copy-a-generated-file approach can't deliver. The overriding goal is
provable sync across app ↔ interface ↔ controller.

## Decision

Add **flux-interface as the app's single git submodule** and build from it:

- Compile flux-ice C from the pinned source via Gradle `externalNativeBuild`
  (CMake, Android) and CMake/CocoaPods (iOS), delivered to the platform-channel
  shim (ADR-0001).
- **Generate `flux.pb.dart` from the pinned SHA**, retiring the hand-copy — one
  SHA now proves the app shares schema + ICE + ADRs with the controller.

## Consequences

- The app gains its **first** git submodule and an NDK/CMake native-build step
  it doesn't have today — a one-time build-infra cost.
- Proto drift from hand-copying is eliminated.
- CI must build arm64 Android + iOS from the submodule (M4).

## Alternatives considered

- **Prebuilt-blob fetch script (mirror the CHIP pattern)** — rejected as the
  default: treats our own fast-moving C as an opaque versioned blob across a
  three-way triangle, the classic drift setup. Kept as the fallback if the team
  insists on a submodule-free app, but then wire-version checks become
  load-bearing.
