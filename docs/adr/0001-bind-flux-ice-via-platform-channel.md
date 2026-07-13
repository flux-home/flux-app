# ADR-0001: Bind flux-ice via a platform channel, not dart:ffi

- **Status:** Accepted (design stage — not yet implemented)
- **Date:** 2026-07-13
- **Scope:** app-only
- **Relates to:** flux-interface ADR-0001 (encapsulation); flux-app ADR-0002

## Context

The design proposed reaching flux-ice from Dart via `dart:ffi` (§7.2/§7.3,
"no platform-channel boilerplate"). But the app has **zero dart:ffi** today; it
integrates all native code (the CHIP SDK) via **platform channels**
(`MatterChannel` uses `MethodChannel`/`EventChannel`) over prebuilt native libs
(`jniLibs`, `ios/Frameworks`). Crucially, the packet data plane never crosses
into Dart: the C glue owns both the external and the loopback socket, and Dart's
`coap` client just connects to `coaps://127.0.0.1:<port>`. Dart needs only a
low-frequency control surface (start/stop, config + candidates, loopback port +
state stream).

## Decision

Bind flux-ice from Dart with a **platform channel** (`MethodChannel` +
`EventChannel`), mirroring `MatterChannel` — not `dart:ffi`.

## Consequences

- ffi's zero-copy advantage is moot (no packets cross the boundary); the control
  surface is exactly what a MethodChannel/EventChannel does well.
- Reuses the app's proven native-lib delivery and platform-channel muscle; one
  native-integration pattern in the app, not two.
- Requires a thin Kotlin + Swift shim on each platform (the cost of not using
  ffi) — small relative to the shared C.

## Alternatives considered

- **dart:ffi (the doc's proposal)** — rejected: the app has never built an ffi
  toolchain (no ffigen, no per-ABI static-lib linking), and the data plane
  wouldn't use ffi's strengths anyway.
