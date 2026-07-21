---
name: flux-ui
description: Flux app UI design system — Teenage-Engineering-inspired conventions for building/settings screens (tokens, panels, wording, connection state)
---

# Flux UI — design system

The concrete design language for the Flux Flutter app, distilled from the
Teenage Engineering sensibility: **form follows function, ruthless clarity,
technical-but-friendly, restraint over decoration.** Use this when building or
reworking any settings/config surface so screens stay consistent.

For open-ended critique of an existing screen, use the `design-review` skill
(the TE persona). This skill is the rulebook — the tokens and patterns already
agreed on.

## First principles

1. **Two devices, always distinguishable.** The system is a **controller** (the
   Flux hardware) and **this phone**. Every screen must make clear which box a
   setting acts on. The top-level model is two labelled panels: `CONTROLLER`
   and `THIS PHONE`.
2. **One word: "controller."** Never "hub" in user-facing copy (buttons,
   titles, snackbars, logs the user reads, status). Code identifiers
   (`HubConnection`, `ControllerStatus.noHub`) are exempt — internal only.
3. **Say the state in plain language.** "Connected", "Offline", "Connecting…"
   — not jargon. Keep protocol nouns (fabric, dataset, Ext PAN ID) *inside*
   detail screens, never on menu tiles.
4. **Icons earn their place.** No decorative leading icons on nav rows. The
   only iconography that survives is meaningful: the connection-state **dot**
   and the trailing chevron. When in doubt, remove it.

## Tokens

Connection-state accents (define as file-level consts; keep identical across
screens):

```dart
const _onlineColor     = Color(0xFF9FD8A8); // green  — connected, local
const _remoteColor     = Color(0xFFA9C7F2); // blue   — connected, remote tunnel
const _connectingColor = Color(0xFFBFC4CC); // grey   — connecting / standby / off
const _offlineColor    = Color(0xFFF2A9A0); // coral  — offline / error
```

**Panel label** (the TE instrument-panel header) — wide-tracked monospace,
uppercase, muted, no glyph:

```dart
Text(text, style: TextStyle(
  fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700,
  letterSpacing: 2.4, color: cs.onSurfaceVariant));
// padding: EdgeInsets.fromLTRB(20, 0, 20, 10)
```

**Grouping** — one `Card` per panel (`margin: horizontal 16`,
`clipBehavior: Clip.antiAlias`), rows separated by
`Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant)`.

**Nav row** — `ListTile(title: Text(label), trailing: Icon(chevron_right))`.
No leading icon.

## Patterns

**Connection widget.** The `CONTROLLER` panel opens with a dedicated
connection-state tile: coloured dot (leading) + plain state ("Connected") +
one-line detail ("Local network" / "Remote · encrypted tunnel"), tapping
through to a Connection detail screen. State → (dot, title, subtitle) via a
`switch` on `ControllerStatus` + `ConnectionKind`.

**Connection detail screen.** Breaks the single live connection into its two
independent paths — `LOCAL NETWORK` and `REMOTE ACCESS` — each a card with a
State row (label left, dot + value right) and value rows (monospace, right-
aligned, ellipsised). `ConnectionKind` is mutually exclusive (loopback host =
remote, else local), so the inactive path reads "Standby".

**Scope-split screens.** When a concept exists on both devices (Matter,
Thread), don't cram both into one screen with sections — parameterise the
screen with a scope enum (`MatterScope { controller, phone }`,
`ThreadScope { controller, phone }`) and route two separate menu entries, one
under each panel. Controller scope shows the real fabric / operational Thread
network + Sync; phone scope shows this phone's admin identity / scanned
credentials. Keep the appBar title plain ("Matter", "Thread"); the panel the
user came from plus the in-screen caption carry the "whose" context.

## Reference implementation

- `lib/ui/screens/settings_screen.dart` — the two-panel layout + tokens.
- `lib/ui/screens/settings/connection_screen.dart` — local/remote detail.
- `lib/ui/screens/settings/matter_settings_screen.dart` / `thread_settings_screen.dart`
  — the scope-split pattern.
