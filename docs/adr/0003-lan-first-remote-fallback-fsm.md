# ADR-0003: LAN-first / remote-fallback connection FSM

- **Status:** Accepted (design stage — not yet implemented)
- **Date:** 2026-07-13
- **Scope:** app-only
- **Relates to:** flux-interface ADR-0001 (loopback), ADR-0010 (consent teardown); `hub_connection.dart`

## Context

§7.2 sketched "try LAN, else bring up FluxIceSession, reuse the HubConnection
swap" but left the transitions undefined — when to try remote, when to fall
back, how to reconnect after the ADR-0010 consent teardown, and
background/resume behavior.

## Decision

A LAN-first state machine in `HubConnection`, remote strictly as fallback:

```
Idle → DiscoverLAN (mDNS, ~2–3s)
   ├ found ──────────▶ LANActive ──(onReachability fails)─┐
   └ not found ─▶ RemoteConnect (cached remote_cfg →       │
        FluxIceSession via rendezvous+STUN)                │
          ├ ok ─▶ RemoteActive ─(loopback fails / consent  │
          │        teardown)──────────────────────────────┤
          └ fail ─▶ Offline (backoff, surface UI)          │
                                                           ▼
                                                  re-enter DiscoverLAN
```

- **Never run remote while LAN works** — remote is entered only when LAN
  discovery *and* reachability both fail (LAN is faster, free, no rendezvous/STUN).
- **Teardown → re-discover LAN first** (a dead remote session often means the
  network changed — e.g. the user got home).
- **Background/resume:** on resume, run a lightweight reachability probe; a
  session that died past the ~30 s consent window reconnects from DiscoverLAN.
- **Backoff + explicit UI state** (`Connecting / Remote / Offline`).
- The `FluxCoapService` swap (`setService`) stays the sole integration point;
  every `MatterPort` consumer is unchanged.

## Consequences

- First off-LAN connect eats the full LAN-discovery timeout (~2–3 s) before ICE
  starts — accepted; optimize later if measured bad.
- Consumers react to the same service-swap they already handle.

## Alternatives considered

- **"Skip LAN discovery on a known-foreign network" shortcut** — deferred: a
  latency optimization; start simple and measure first.
