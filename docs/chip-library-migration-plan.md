> Historical document — superseded; kept for reference.

# Plan: Replace Hand-Rolled Chip Widgets with Flutter Chip Library

## Summary

The codebase has **four distinct places** where UI elements that look and behave like
chips have been built manually with `Container` + `BoxDecoration` + `BorderRadius`.
Flutter's built-in chip library (`Chip`, `ChoiceChip`, `RawChip`) already covers all
of them. The app even uses `ChoiceChip` in one place (`_FanControlCard`), which proves
the intent — but the pattern was not applied consistently everywhere.

---

## Finding 1 — `_FnKey` (ON/OFF toggle buttons) → `ChoiceChip`

**File:** `lib/ui/screens/device_detail/device_cards.dart`
**Widget:** `_FnKey`, used inside `_OnOffCard`

### What it does now
An `AnimatedContainer` pill button, styled white-on-black (selected) or
transparent-with-border (unselected). Wired up with `GestureDetector.onTap`.
Carries its own selection colour, border, text-colour, and font-weight logic.

```dart
// ~80 lines of custom AnimatedContainer logic
class _FnKey extends StatelessWidget {
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? Colors.white : ...),
        ),
        child: Center(child: Text(label, style: TextStyle(...))),
      ),
    );
  }
}
```

### What `ChoiceChip` already covers
`ChoiceChip` is precisely for exclusive selection inside a set — exactly what ON/OFF
is. The `_FanControlCard` immediately below in the same file already uses `ChoiceChip`
for fan-mode selection; the two cards are architecturally identical but implemented
differently.

### Migration sketch
```dart
// In _OnOffCard — replace the Row of _FnKey widgets:
Wrap(
  spacing: 8,
  children: [
    ChoiceChip(
      label: const Text('ON'),
      selected: !isStale && isOn,
      onSelected: (!isStale && !isOn) ? (_) => toggle() : null,
    ),
    ChoiceChip(
      label: const Text('OFF'),
      selected: !isStale && !isOn,
      onSelected: (!isStale && isOn) ? (_) => toggle() : null,
    ),
  ],
)
```

The dark-card background of `_OnOffCard` is set by `Card(color: const Color(0xFF1A1A1A))`.
`ChoiceChip` picks up the app's `ChipTheme` (or Material 3 defaults), which adapts to
dark surfaces. If the pill-on-black look must be preserved exactly, add a targeted
`ChipTheme` override at the card level — still far less code than `_FnKey`.

### What is removed
`_FnKey` class (~40 lines). The inconsistency between `_OnOffCard` and `_FanControlCard`
is eliminated.

---

## Finding 2 — `_buildCommandChips` (command-list attribute) → `Chip`

**File:** `lib/ui/screens/cluster_inspector_screen.dart`
**Method:** `_AttrRow._buildCommandChips`

### What it does now
Renders each Matter command ID as a hand-crafted badge:
```dart
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: cs.secondaryContainer,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(label, style: TextStyle(color: cs.onSecondaryContainer, ...)),
);
```

These are **read-only, non-interactive** labels — exactly what `Chip` is designed for.

### Migration sketch
```dart
Chip(
  label: Text(label),
  backgroundColor: cs.secondaryContainer,
  labelStyle: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: cs.onSecondaryContainer,
  ),
  side: BorderSide.none,
  padding: const EdgeInsets.symmetric(horizontal: 4),
  visualDensity: VisualDensity.compact,
)
```

`Chip` handles the rounded rectangle, surface colour, and label layout natively.
`visualDensity: VisualDensity.compact` keeps the same tight feel.

---

## Finding 3 — `_buildFeatureMapChips` (feature-map bits) → `Chip`

**File:** `lib/ui/screens/cluster_inspector_screen.dart`
**Method:** `_AttrRow._buildFeatureMapChips`

### What it does now
Same hand-rolled `Container` pattern as Finding 2, but with two styles:
- a monospace hex badge (`surfaceContainerHighest` + outline border)
- per-bit name chips (`primaryContainer`)

### Migration sketch
```dart
// Hex value chip
Chip(
  label: Text(
    '0x${raw.toRadixString(16).padLeft(8, '0').toUpperCase()}',
    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
  ),
  side: BorderSide(color: cs.outlineVariant),
  backgroundColor: cs.surfaceContainerHighest,
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.symmetric(horizontal: 4),
)

// Bit-name chip
Chip(
  label: Text(label),
  backgroundColor: cs.primaryContainer,
  labelStyle: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: cs.onPrimaryContainer,
  ),
  side: BorderSide.none,
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.symmetric(horizontal: 4),
)
```

---

## Finding 4 — Device-type chips in endpoint header → `Chip` / `RawChip`

**File:** `lib/ui/screens/cluster_inspector_screen.dart`
**Widget:** endpoint header section inside `_EndpointHeader` (or inline in the list builder)

### What it does now
Each device-type ID is rendered as a badge showing `name + hexId` side-by-side:
```dart
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: bg,  // primaryContainer or surfaceContainerHighest
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: isInfra ? cs.outlineVariant : cs.primary.withAlpha(60)),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(name, style: ...),
      const SizedBox(width: 5),
      Text(hexId, style: ... /* monospace, dimmed */),
    ],
  ),
);
```

The two-part label (name + hex) needs a custom label widget, which `Chip` supports
via its `label:` slot (any widget, not just `Text`).

### Migration sketch
```dart
Chip(
  label: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(name, style: tt.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
      const SizedBox(width: 5),
      Text(hexId, style: tt.labelSmall?.copyWith(
        color: fg.withAlpha(150), fontFamily: 'monospace', fontSize: 10)),
    ],
  ),
  backgroundColor: bg,
  side: BorderSide(color: isInfra ? cs.outlineVariant : cs.primary.withAlpha(60)),
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.symmetric(horizontal: 6),
)
```

---

## What is NOT a migration candidate

| Element | Why it stays |
|---|---|
| Endpoint badge (`EP0`) and cluster hex badge (`0x0006`) inside `_ClusterCard` | These are dense 10-pixel labels that use `BorderRadius.circular(4/6)` — far smaller than Flutter chips' minimum tap target. They are purely decorative; forcing them into `Chip` would add unwanted padding and minimum height. Leave as-is. |
| `_FanControlCard` mode chips | Already uses `ChoiceChip` — no change needed. |
| `qr_payload_detail_screen.dart` chip | Already uses `Chip` — no change needed. |

---

## Impact summary

| Location | Current impl | Replace with | Lines saved (est.) |
|---|---|---|---|
| `device_cards.dart` — `_FnKey` | `AnimatedContainer` + `GestureDetector` | `ChoiceChip` | ~40 |
| `cluster_inspector_screen.dart` — `_buildCommandChips` | `Container` per chip | `Chip` | ~15 |
| `cluster_inspector_screen.dart` — `_buildFeatureMapChips` | `Container` per chip (×2 styles) | `Chip` | ~25 |
| `cluster_inspector_screen.dart` — device-type header chips | `Container` + `Row` per chip | `Chip` | ~20 |
| **Total** | | | **~100 lines** |

---

## Migration order

1. **`_buildCommandChips` + `_buildFeatureMapChips`** — pure swap, zero behaviour change,
   no state involved. Do these first to get a feel for the compact chip style.

2. **Device-type header chips** — same pattern, slightly richer label widget.

3. **`_FnKey` → `ChoiceChip`** — last, because it's in the hot device-control path and
   requires visual regression testing on the dark card background.

---

## Notes on theming

All four sites use `ColorScheme` tokens (`primaryContainer`, `secondaryContainer`,
`surfaceContainerHighest`) that `Chip` already uses by default in Material 3. No custom
`ChipTheme` should be needed. If the compact density must be app-wide, add:

```dart
// In theme.dart
chipTheme: const ChipThemeData(
  visualDensity: VisualDensity.compact,
  padding: EdgeInsets.symmetric(horizontal: 4),
),
```

and remove the per-widget overrides.
