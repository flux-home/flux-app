# Architecture Decision Records — flux-app

**App-local** ADRs live here — decisions confined to the Flutter app (dart:ffi
packaging, connection/service swap, discovery caching, UI wiring).

**Cross-cutting** decisions that also bind `flux-controller` (the wire protocol,
proto messages, the trust/credential model) do **not** live here — they live in
`flux-proto/docs/adr/`, the neutral home both repos treat as canonical. Cite
those by number, e.g. "per flux-proto ADR-0002".

## Conventions

- One decision per file: `NNNN-kebab-title.md`, numbered monotonically.
- Copy `0000-template.md` to start.
- **Status:** `Proposed → Accepted → Superseded by ADR-NNNN`. Supersede, never delete.
- **Land the ADR in the same PR as the change it describes** so the two can't drift.

## Index

| # | Title | Status |
|---|-------|--------|
| [0001](0001-bind-flux-ice-via-platform-channel.md) | Bind flux-ice via a platform channel, not dart:ffi | Accepted (design) |
| [0002](0002-consume-flux-interface-submodule.md) | Consume flux-interface as a submodule, build from source | Accepted (design) |
| [0003](0003-lan-first-remote-fallback-fsm.md) | LAN-first / remote-fallback connection FSM | Accepted (design) |
