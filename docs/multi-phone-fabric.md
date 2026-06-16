# Multi-phone setup: controller-owned Matter fabric

This note describes the target architecture for letting **multiple phones**
commission and control devices through one Flux controller, and the concrete
work required to get there. It is the design reference for "step 2"; step 1
(the non-destructive, controller-as-owner groundwork) already ships — see the
[Status](#status) section.

## Goal

Multiple phones, one home. A device commissioned by any phone is immediately
controllable by every other phone and by the controller, without
re-commissioning it per phone.

## Decision: one shared fabric, owned by the controller

A shared Matter fabric needs exactly one **Certificate Authority** (CA) that
holds the root key and issues operational certificates (NOCs). The controller
is the natural CA because it is always-on, central, and already the single
source of truth for the device list.

- **One fabric, commissioned once.** A device joins the shared fabric a single
  time and is reachable by all phones + the controller. No per-phone
  multi-admin re-commissioning, and no burning the device's ~5 fabric slots one
  per phone.
- **Phones are interchangeable.** Add/remove a phone without touching any
  device; each phone just needs its own operational identity on the shared
  fabric.
- **Root key never leaves the controller.** Phones get their own NOCs; they
  never hold the root signing key.

### Why not the alternatives

- *App-as-CA (the old model):* every phone has its own fabric. Devices aren't
  interoperable across phones, and two phones would fight over the controller —
  each repeatedly re-provisioning it with its own fabric. Broken for multi-phone.
- *Plain Matter multi-admin:* every device must be shared to every phone via an
  open-commissioning window, capped at ~5 fabrics, with no single source of
  truth. Painful and non-scaling.

## Bootstrapping: controller self-generates, every phone enrolls

Decided 2026-06-12: the **controller generates its own root CA + fabric on
first boot** and is the CA from birth. The app never seeds and never sends a
root key (the app's root key is sealed in Android Keystore and can't be
exported anyway — that's why the `rcac_priv_key` seed path is unused).

- **Controller still starting up** (`/info.fabricId == 0`): transient — the app
  waits, it does **not** push a fabric.
- **Controller has a fabric:** every phone (including the first) **enrolls** —
  generates a CSR, the controller signs it (`POST /fabric/enroll`), and the
  phone imports the issued NOC. A phone already on that fabric is in sync.

## Commissioning under this model

To commission a device a phone must install the device's NOC, which must be
signed by the fabric CA. We do **not** copy the root key to phones. Instead:

1. **Enroll once.** Over the existing secure CoAP/DTLS channel the phone obtains
   its own operational NOC on the shared fabric (phone sends a CSR, controller
   signs it). The phone is now an admin on the shared fabric.
2. **Commission with delegated signing.** During BLE/Thread commissioning the
   phone uses the CHIP `NOCChainIssuer` callback (already implemented as
   `AppNOCIssuer`) but, instead of signing the device NOC locally, **forwards
   the device CSR to the controller to sign** and installs the returned NOC.
3. **Register + ACL** as today (`grantControllerAccess` + `registerNode`). The
   device is on the shared fabric for everyone; the controller's device list
   syncs to all phones (`DeviceProvider.syncWithController`).

## Work required

### Controller firmware (new)

| Endpoint | Purpose |
|---|---|
| `POST /fabric/enroll` | Body: phone CSR (+ requested node id). Controller signs and returns `{ rootCaTlv, icacTlv?, nocTlv, ipk, fabricId }` for the phone's operational identity. |
| `POST /fabric/sign-noc` | Body: a device CSR captured mid-commissioning. Controller returns the signed device NOC chain. Used by the `NOCChainIssuer` delegation in step 2 of commissioning. |
| `GET /fabric/info` *(optional)* | Expose root public key / fabric metadata so a phone can confirm which fabric it's joining. |

The root CA private key stays on the controller; only signed certificates leave it.

### Native Android / CHIP (new)

- `AppKeyPairDelegate`: generate a CSR for the app's operational key. Today this
  throws (`AppKeyPairDelegate.kt:49`) because the key is Android-Keystore-backed
  — needs a CSR-capable key path (or a dedicated enrollment keypair).
- `AppFabricManager.importFabric(fabricId, rootCaTlv, icacTlv?, nocTlv, opPrivKey?, ipk)`:
  install an externally-issued fabric as the app's operational identity (inverse
  of `exportFabricForController`).
- `ChipClient.adoptFabric(operationalKeyConfig)`: re-initialize the singleton
  `ChipDeviceController` onto the adopted fabric.
- `AppNOCIssuer`: when commissioning on an adopted fabric, forward the device
  CSR to the controller (`POST /fabric/sign-noc`) instead of signing locally.

### Dart / Flutter (new, once the above exist)

- `FluxCoapService.enrollFabric(csr)` / `signDeviceNoc(csr)` clients.
- `MatterFabricPort.importFabricFromController(...)` interface method.
- `FabricSyncService`: handle `FabricState.controllerForeign` by **adopting**
  (enroll → import → adopt) instead of reporting `adoptRequired`.
- Commissioning: route the device CSR through the controller for adopted fabrics.

## Status

**Controller firmware:** `/fabric/enroll` + `/fabric/sign-noc` implemented; the
controller self-generates its CA.

**App — Dart layer (done):**

- Proto regenerated from `flux.proto` with the new fabric messages.
- `FluxCoapService.enrollFabric(csr)` / `signDeviceNoc(csr)` clients.
- `FabricSyncService` realigned to the controller-owned model: `readState()` →
  `{inSync, needsAdopt, controllerNotReady, unknown}`; `ensureInSync()` never
  seeds — on `needsAdopt` it runs the enroll → import flow (`generateOperationalCsr`
  → `enrollFabric` → `importControllerFabric`), returning `adopted`, or
  `adoptRequired` when the platform can't enroll yet.
- `ThreadSyncService` adopt-or-push (controller as source of truth) — fully
  working over existing endpoints.
- Hub settings screen: "Join hub" banner (`needsAdopt`), "hub starting up"
  banner (`controllerNotReady`), "Sync Thread network" action.

**App — native CHIP layer (IMPLEMENTED — pending on-device verification):**

- `SoftwareKeyPairDelegate` (in-memory P256, BouncyCastle PKCS#10 CSR) +
  `AppFabricManager.generateOperationalCsr` — generates + persists a pending
  operational keypair and returns its CSR.
- `AppFabricManager.importAdoptedIdentity` + `adoptedIdentity` +
  `operationalKeyConfig` now prefers the adopted (controller-issued) identity;
  `ChipClient.adoptFabric` tears down and rebuilds `ChipDeviceController` onto it.
- `AppNOCIssuer` forwards the device CSR to `POST /fabric/sign-noc` when on an
  adopted fabric (via `ChipClient.deviceNocSigner` → MainActivity → Dart
  `MatterChannel.deviceNocSigner` → `FluxCoapService.signDeviceNoc`), signing
  locally only in the legacy/standalone (app-as-CA) case.
- Channel methods `generateOperationalCsr` / `importControllerFabric` wired
  through MainActivity → MatterBridge → DeviceInfoBridge; reverse `signDeviceNoc`
  call wired native → Dart.

Builds, installs, launches cleanly (CHIP init OK, BouncyCastle linked). **Not yet
verified end-to-end against a real controller + device.** Known risks to check
on-device:
1. `onNOCChainGeneration` JNI historically needs a non-null intermediate cert;
   if the controller signs device NOCs directly with its root (no ICAC,
   `FabricSignNocResponse.icac_tlv` empty), this may fail — the controller CA may
   need to issue a 3-tier Root→ICAC→NOC chain.
2. `ControllerParams` accepting the externally-issued enrollment NOC chain on
   `adoptFabric`.
3. The native→Dart→CoAP `signDeviceNoc` round trip under the CHIP stack lock
   (uses a bounded 35 s latch off the event-loop thread).
