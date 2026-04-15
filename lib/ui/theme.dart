import 'package:flutter/material.dart';

const _seed   = Color(0xFF1B6CA8); // Matter brand blue

/// Shared corner radius — matches device card tiles and camera-view pills.
const kButtonRadius = 22.0;

/// Minimum tap-target height for all buttons.
const _kButtonH = 52.0;

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final cs = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

  // Shared shape used by every button type.
  final _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kButtonRadius),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,

    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),

    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(kButtonRadius)),
      ),
    ),

    // ── Filled (primary action) ───────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape:       _shape,
        minimumSize: const Size(0, _kButtonH),
        padding:     const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation:   0,
      ),
    ),

    // ── Outlined (secondary / destructive) ───────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape:       _shape,
        minimumSize: const Size(0, _kButtonH),
        padding:     const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        side:        BorderSide(color: cs.outline, width: 1.5),
      ),
    ),

    // ── Text (low-emphasis / dialog cancel) ──────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape:       _shape,
        minimumSize: const Size(0, 44),
        padding:     const EdgeInsets.symmetric(horizontal: 16),
      ),
    ),

    // ── Elevated (not used in core UI, kept for completeness) ────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape:       _shape,
        minimumSize: const Size(0, _kButtonH),
        elevation:   0,
      ),
    ),
  );
}
