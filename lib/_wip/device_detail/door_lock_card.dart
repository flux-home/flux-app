import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Door Lock Card
//
// Glyph: dot-matrix padlock — 5 × 9 LED-style grid.
//
//   · ● ● ● ·   row 0 — arch top arc
//   ● · · · ●   row 1 — left arm  /  right arm (pivot side, FIXED)
//   ● · · · ●   row 2 — arms
//   ● · · · ●   row 3 — arms at body-entry level
//   ● ● ● ● ●   row 4 — body top          ← pivot Y sits at top of this row
//   ● · · · ●   row 5 — body sides
//   ● · ● · ●   row 6 — body sides + keyhole dot (col 2)
//   ● · · · ●   row 7 — body sides
//   ● ● ● ● ●   row 8 — body bottom
//
// The RIGHT ARM (col 4) is the fixed / hinge arm — it never moves.
// The LEFT ARM (col 0, rows 1–3) and TOP ARC (row 0, cols 1–3) rotate
// clockwise around the pivot (col-4 centre, top of row 4) as openProgress
// goes 0 → 1.  At 90 ° the arch has swept upward-right off the canvas;
// only the right-arm stub and body remain — clearly unlocked.
//
// The full background grid is always painted at low opacity (LED-matrix
// "off" state), so the arch silhouette stays visible as a ghost even after
// the arch has rotated away, making the state instantly readable.
//
// Interaction:
//   Tap   — toggle (unlock without PIN, or lock)
//   Hold  — unlock with PIN dialog
//
// No optimistic state updates; [_busy] suppresses interaction in-flight.
// ─────────────────────────────────────────────────────────────────────────────

class DoorLockCard extends StatefulWidget {
  const DoorLockCard({required this.view, super.key});
  final DeviceView view;

  @override
  State<DoorLockCard> createState() => _DoorLockCardState();
}

class _DoorLockCardState extends State<DoorLockCard>
    with SingleTickerProviderStateMixin {
  bool _busy    = false;
  bool _pressed = false;

  late final AnimationController _lockCtrl;
  late final Animation<double>   _lockAnim;

  @override
  void initState() {
    super.initState();
    _lockCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _lockAnim = CurvedAnimation(
      parent: _lockCtrl,
      curve: Curves.easeInOut,
    );
    _syncLock(animate: false);
  }

  @override
  void didUpdateWidget(DoorLockCard old) {
    super.didUpdateWidget(old);
    if (old.view.lockState != widget.view.lockState) _syncLock(animate: true);
  }

  void _syncLock({required bool animate}) {
    final target = switch (widget.view.lockState) {
      1 => 0.0, // Locked
      2 => 1.0, // Unlocked
      3 => 1.0, // Unlatched
      _ => 0.5, // NotFullyLocked / null — arch halfway open
    };
    if (animate) {
      _lockCtrl.animateTo(target,
          duration: const Duration(milliseconds: 560),
          curve: Curves.easeInOut);
    } else {
      _lockCtrl.value = target;
    }
  }

  // ── Commands ───────────────────────────────────────────────────────────────

  Future<void> _onTap(DeviceProvider provider) async {
    if (_busy || widget.view.isStale) return;
    unawaited(HapticFeedback.mediumImpact());
    switch (widget.view.lockState) {
      case 1: // Locked → unlock without PIN
        setState(() => _busy = true);
        try {
          final ok = await provider.unlockDoor(widget.view.id);
          if (!ok && mounted) {
            _showError('Unlock failed. Hold to enter a PIN.');
          }
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      case 2: // Unlocked → lock
      case 3: // Unlatched → lock
        setState(() => _busy = true);
        try {
          final ok = await provider.lockDoor(widget.view.id);
          if (!ok && mounted) {
            _showError('Lock command failed. Check device connection.');
          }
        } finally {
          if (mounted) setState(() => _busy = false);
        }
    }
  }

  Future<void> _onLongPress(DeviceProvider provider) async {
    if (_busy || widget.view.isStale || widget.view.lockState != 1) return;
    unawaited(HapticFeedback.heavyImpact());

    final pin = await showDialog<String?>(
      context: context,
      builder: (_) => const _PinDialog(),
    );
    if (pin == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final ok = await provider.unlockDoor(
        widget.view.id,
        pin: pin.isEmpty ? null : pin,
      );
      if (!ok && mounted) _showError('Unlock failed. Check device or PIN.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _lockCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final view    = widget.view;
    final cs      = Theme.of(context).colorScheme;
    final isStale = view.isStale;
    final canAct  = !isStale && !_busy &&
        (view.lockState == 1 || view.lockState == 2 || view.lockState == 3);
    final canHold = canAct && view.lockState == 1;

    final dotColor = _dotColor(view.lockState, isStale: isStale, cs: cs);
    final hint     = _actionLabel(view.lockState, busy: _busy, isStale: isStale);

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Consumer<DeviceProvider>(
          builder: (context, provider, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Section label ─────────────────────────────────────────────
              Text(
                'DOOR LOCK',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // ── Tap target ────────────────────────────────────────────────
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown:   canAct ? (_) => setState(() => _pressed = true) : null,
                onTapUp:     canAct ? (_) {
                  setState(() => _pressed = false);
                  unawaited(_onTap(provider));
                } : null,
                onTapCancel: () => setState(() => _pressed = false),
                onLongPress: canHold ? () {
                  setState(() => _pressed = false);
                  unawaited(_onLongPress(provider));
                } : null,
                child: AnimatedScale(
                  scale:    _pressed ? 0.95 : 1.0,
                  duration: const Duration(milliseconds: 80),
                  child: AnimatedOpacity(
                    opacity:  _busy ? 0.35 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      children: [

                        // ── Dot padlock glyph ──────────────────────────────
                        Center(
                          child: AnimatedBuilder(
                            animation: _lockAnim,
                            builder: (context, _) => CustomPaint(
                              size: const Size(84, 150),
                              painter: _DotPadlockPainter(
                                openProgress: _lockAnim.value,
                                color: dotColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Action hint ────────────────────────────────────
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: Text(
                            hint,
                            key: ValueKey(hint),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                              letterSpacing: 2,
                              color: canAct
                                  ? dotColor
                                  : cs.onSurfaceVariant.withAlpha(80),
                            ),
                          ),
                        ),

                        // ── PIN hint ───────────────────────────────────────
                        AnimatedOpacity(
                          opacity:  canHold ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'HOLD FOR PIN',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                letterSpacing: 2,
                                fontSize: 9,
                                color: cs.onSurfaceVariant.withAlpha(65),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _dotColor(
  int? lockState, {
  required bool isStale,
  required ColorScheme cs,
}) {
  if (isStale || lockState == null) return cs.onSurfaceVariant.withAlpha(45);
  return cs.onSurfaceVariant;
}

String _actionLabel(
  int? lockState, {
  required bool busy,
  required bool isStale,
}) {
  if (busy)                         return 'SENDING\u2026';
  if (isStale || lockState == null) return '\u2014';
  return switch (lockState) {
    1 => 'TAP TO UNLOCK',
    2 => 'TAP TO LOCK',
    3 => 'TAP TO LOCK',
    _ => 'NOT FULLY LOCKED',
  };
}

// ── Dot Padlock Painter ───────────────────────────────────────────────────────
//
// Renders a 5 × 9 dot grid.  Every cell is painted at low opacity (the
// LED-matrix "off" state), then specific cells are painted at full opacity
// to form the padlock shape.
//
// The ARCH (left arm + top arc) is drawn at a CW-rotated position whose
// angle = openProgress × 90 °.  The pivot is the point where the right arm
// enters the body (col-4 centre, top edge of row 4).
//
// At 0 °  (locked):   full ∩ arch visible above the body.
// At ~30°:            arch peak has swept off the top of the canvas.
// At ~65°:            all arch dots have left the canvas.
// At 90 ° (unlocked): only the right-arm stub (col 4, rows 1–3) and the
//                     body remain bright; the ghost grid shows the arch
//                     silhouette at low opacity.

class _DotPadlockPainter extends CustomPainter {
  const _DotPadlockPainter({
    required this.openProgress,
    required this.color,
  });

  final double openProgress;
  final Color  color;

  static const int _cols = 5;
  static const int _rows = 9;

  @override
  void paint(Canvas canvas, Size size) {
    // Clip to canvas bounds so rotated dots that leave the frame are invisible.
    canvas.clipRect(Offset.zero & size);

    final gx = size.width  / _cols;
    final gy = size.height / _rows;
    final r  = gx * 0.33;               // dot radius ≈ 1/3 of column spacing

    // Centre of grid cell (c, row).
    Offset cell(int c, int row) => Offset((c + 0.5) * gx, (row + 0.5) * gy);

    // Pivot: col-4 centre X, top edge of row 4.
    final pivot = Offset((4 + 0.5) * gx, 4.0 * gy);

    // CW rotation in Flutter's y-down canvas.
    final angle = openProgress * math.pi / 2;
    final cosA  = math.cos(angle);
    final sinA  = math.sin(angle);

    Offset rotated(Offset p) {
      final dx = p.dx - pivot.dx;
      final dy = p.dy - pivot.dy;
      return Offset(
        pivot.dx + dx * cosA - dy * sinA,
        pivot.dy + dx * sinA + dy * cosA,
      );
    }

    // ── 1. Background grid — all 45 positions at very low opacity ──────────
    //       This "ghost" makes the arch's silhouette readable even after the
    //       bright arch dots have rotated off the canvas.
    final ghostPaint = Paint()
      ..color = color.withAlpha(22)
      ..style = PaintingStyle.fill;
    for (var row = 0; row < _rows; row++) {
      for (var c = 0; c < _cols; c++) {
        canvas.drawCircle(cell(c, row), r, ghostPaint);
      }
    }

    final onPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // ── 2. Body — fixed rectangle of dots ──────────────────────────────────
    for (var c = 0; c < _cols; c++) {
      canvas
        ..drawCircle(cell(c, 4), r, onPaint) // top edge
        ..drawCircle(cell(c, 8), r, onPaint); // bottom edge
    }
    for (var row = 5; row <= 7; row++) {
      canvas
        ..drawCircle(cell(0, row), r, onPaint) // left side
        ..drawCircle(cell(4, row), r, onPaint); // right side
    }

    // ── 3. Right arm — the fixed hinge; never moves ─────────────────────────
    for (var row = 1; row <= 3; row++) {
      canvas.drawCircle(cell(4, row), r, onPaint);
    }

    // ── 4. Keyhole — fades out as the lock opens ───────────────────────────
    final khAlpha = (255 * (1.0 - openProgress)).round().clamp(0, 255);
    if (khAlpha > 0) {
      canvas.drawCircle(
        cell(2, 6), r,
        Paint()
          ..color = color.withAlpha(khAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    // ── 5. Arch — left arm + top arc, rotated around pivot ─────────────────
    //
    //   Left arm: col=0, rows 1–3  (the free / non-hinge arm)
    //   Top arc:  row=0, cols 1–3
    //
    //   As openProgress → 1 the dots sweep clockwise and exit the canvas:
    //     • top-arc dots (farthest from pivot) leave first, ~30 °
    //     • left-arm rows 1–2 leave by ~65 °
    //     • left-arm row 3 (closest to pivot) leaves by ~83 °
    //   Beyond those angles the canvas clip hides them cleanly.
    final archCells = [
      (0, 1), (0, 2), (0, 3), // left arm
      (1, 0), (2, 0), (3, 0), // top arc
    ];
    for (final (c, row) in archCells) {
      canvas.drawCircle(rotated(cell(c, row)), r, onPaint);
    }
  }

  @override
  bool shouldRepaint(_DotPadlockPainter old) =>
      old.openProgress != openProgress || old.color != color;
}

// ── PIN dialog ────────────────────────────────────────────────────────────────

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _ctrl    = TextEditingController();
  bool  _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unlock with PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the PIN if your lock requires one, or tap Unlock to '
            'proceed without.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            obscureText: _obscure,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'PIN (optional)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => Navigator.pop(context, _ctrl.text),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
