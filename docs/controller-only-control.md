# Controller-only device control

Devices commissioned onto the Flux Controller's fabric are controlled
**exclusively** through the controller's CoAP/DTLS session — never by the
phone opening a direct Matter CASE session to the device. There is no
local-CHIP control fallback and no "standalone" device-control mode.

## Why

`FluxCoapService` already implements the full `MatterPort` control surface
against an already-complete flux-proto contract:

```
POST /command   ← DeviceCommand        → BoolResult   (cluster commands: OnOff, Level, Lock, …)
POST /write      ← WriteAttrRequest     → BoolResult   (attribute writes: setpoint, fan mode, …)
POST /read       ← ReadRequest          → BoolResult   (data arrives via /events, see below)
GET  /events?id= Observe                → DeviceStateEvent (live state + read results)
GET  /devices                           → DeviceList
```

These endpoints are authenticated by the CoAP/DTLS pre-shared key (PSK), **not**
Matter fabric membership — so the phone never needs its own operational
identity on the controller's fabric to control a device. (This superseded
`docs/controller-enrollment-flow.md` — see that file for history.)

## How it's wired

- `DeviceProvider` (`lib/providers/device_provider.dart`) holds a single
  swappable `MatterPort _channel`:
  - **No controller connected yet:** `NullMatterPort`
    (`lib/services/null_matter_port.dart`) — an inert placeholder where every
    method is a safe no-op, so the UI simply shows no live control.
  - **Controller connected:** `FluxCoapService`, swapped in via
    `DeviceProvider.adoptHubMode(svc)` once `HubConnection` reports a service
    (background mDNS discovery on boot, the Flux Hub "↺" button, or adding a
    controller for the first time).
- `lib/main.dart`'s `MatterClusterPort` / `MatterFabricPort` `ProxyProvider`s
  mirror the same rule: `hub.service ?? nullChannel` — never `localChannel`.

## What still uses local CHIP (`MatterChannel`) directly

A few operations are inherently local to the phone and stay wired to
`MatterChannel` regardless of controller connection:

- BLE commissioning Pass 1 (throwaway local fabric) and the ECM handoff
  (`openCommissioningWindow` / `readFabrics` / `removeFabric`) — see
  `flux-proto/docs/multiadmin-rework.md`.
- OTA download/flash (`downloadAndFlash` / `cancelOta`) — the phone pushes
  firmware straight to the device.
- Local radio operations (`scanWifiNetworks`, `discoverThreadNetworks`,
  `readSystemThreadCredentials`).

These are exposed via `Provider<MatterCommissionPort>`/`Provider<MatterChannel>`
in `main.dart`, separate from the swappable `MatterClusterPort`/`MatterFabricPort`
used for day-2 device control.
