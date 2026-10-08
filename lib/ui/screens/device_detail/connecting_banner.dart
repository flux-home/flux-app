part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reconnecting banner
// ─────────────────────────────────────────────────────────────────────────────
//
// A status line, not a picture. What stood here was a sonar pulse expanding
// through a dot grid with no text at all: users could see that something was
// happening but not what, to which device, or whether to do anything. It also
// said nothing to a screen reader, and it implied a continuous sweep when the
// controller actually retries on a backoff.
//
// So it says the words instead, in the same 5×7 dot-matrix face the readings
// use, with three cycling dots for the one thing an animation genuinely
// conveys better than text: that this is still in progress rather than a
// verdict. The dots cycle in place — brightness, never width — because a
// string that grows re-centres and re-scales the whole line on every tick.
//
// The pitch is driven by the height, so only about a dozen characters fit
// before the dots stop being legible. That is why the headline is one word and
// the fact that matters — when this device was last heard from — sits beneath
// it in ordinary small text rather than being squeezed into the matrix.

enum _BannerPhase { hidden, visible, leaving }

class _ConnectingBanner extends StatefulWidget {
  const _ConnectingBanner({required this.isStale, this.lastSeen});
  final bool isStale;

  /// When the controller last had a reading from this device, if known.
  final DateTime? lastSeen;

  @override
  State<_ConnectingBanner> createState() => _ConnectingBannerState();
}

class _ConnectingBannerState extends State<_ConnectingBanner>
    with TickerProviderStateMixin {
  late final AnimationController _dotsCtrl;
  late final AnimationController _exitCtrl;
  late _BannerPhase _phase;

  @override
  void initState() {
    super.initState();
    _phase = widget.isStale ? _BannerPhase.visible : _BannerPhase.hidden;

    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (_phase == _BannerPhase.visible) _dotsCtrl.repeat();

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _dotsCtrl.stop();
          setState(() => _phase = _BannerPhase.hidden);
        }
      });
  }

  @override
  void didUpdateWidget(_ConnectingBanner old) {
    super.didUpdateWidget(old);

    if (old.isStale && !widget.isStale && _phase == _BannerPhase.visible) {
      _exitCtrl.forward();
      setState(() => _phase = _BannerPhase.leaving);
    }

    if (!old.isStale && widget.isStale && _phase == _BannerPhase.hidden) {
      _exitCtrl.reset();
      _dotsCtrl.repeat();
      setState(() => _phase = _BannerPhase.visible);
    }
  }

  @override
  void dispose() {
    _dotsCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  /// "last reading 14:52", or "14:52 yesterday" once it is not today.
  ///
  /// A clock time rather than "47 minutes ago": the elapsed form has to be
  /// recomputed to stay true, and a stale "2 minutes ago" is a worse lie than
  /// no number at all. A wall-clock time is still correct an hour later.
  String? get _lastSeenLabel {
    final t = widget.lastSeen;
    if (t == null) return null;
    final now = DateTime.now();
    final hhmm = '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? 'last reading $hhmm' : 'last reading $hhmm, ${_dayOf(t)}';
  }

  static String _dayOf(DateTime t) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final days = midnight.difference(DateTime(t.year, t.month, t.day)).inDays;
    if (days == 1) return 'yesterday';
    return '${t.day}/${t.month}';
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _BannerPhase.hidden) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final label = _lastSeenLabel;

    // One semantics node for the pair: a screen reader should hear the state
    // and the fact together, which the old animation gave it no way to do.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          label: label == null
              ? 'Reconnecting to this device'
              : 'Reconnecting to this device. $label',
          excludeSemantics: true,
          child: Card(
            color: const Color(0xFF1A1A1A),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, label == null ? 16 : 10),
              child: Column(
                children: [
                  SizedBox(
                    height: 22,
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _dotsCtrl,
                      builder: (_, __) => CustomPaint(
                        painter: _ReconnectingPainter(
                          text: 'RECONNECTING',
                          t: _dotsCtrl.value,
                          litColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (label != null) ...[
                    const SizedBox(height: 9),
                    Text(
                      label,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );

    if (_phase == _BannerPhase.visible) return content;

    return SizeTransition(
      sizeFactor: Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(
          parent: _exitCtrl,
          curve: const Interval(0.1, 1.0, curve: Curves.easeInCubic),
        ),
      ),
      axisAlignment: -1,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(
            parent: _exitCtrl,
            curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
          ),
        ),
        child: content,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

/// [text] in the shared 5×7 face, followed by three dots that light in turn.
///
/// Reuses [dotMatrixGlyphs] rather than carrying its own table, so the face
/// cannot drift from the readings it sits above. The three dots are laid out on
/// the same pitch and sit on the baseline row, which is where the font's own
/// full stop sits.
class _ReconnectingPainter extends CustomPainter {
  const _ReconnectingPainter({
    required this.text,
    required this.t,
    required this.litColor,
  });

  final String text;

  /// Normalised animation position [0.0, 1.0).
  final double t;
  final Color litColor;

  static const _rows     = 7;
  static const _gap      = 2.0;
  static const _dots     = 3;
  /// Columns each trailing dot occupies, matching the font's 3-col full stop.
  static const _dotCols  = 3;
  /// Baseline row — the row the font's own '.' is drawn on.
  static const _dotRow   = 5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final chars = text.characters.toList();
    if (chars.isEmpty) return;

    // Text columns + one blank column between glyphs, then a word space and
    // the three dots, each with its own inter-glyph column.
    final textCols =
        chars.fold(0, (s, c) => s + dotMatrixCharCols(c)) + (chars.length - 1);
    const trailing = _dotCols * _dots + _dots;   // dots + separating columns
    final totalCols = textCols + 1 + trailing;

    final stepW = (size.width  + _gap) / totalCols;
    final stepH = (size.height + _gap) / _rows;
    final step  = math.min(stepW, stepH);
    final r     = (step - _gap) / 2;
    if (r <= 0) return;

    final matW = step * totalCols - _gap;
    final matH = step * _rows     - _gap;
    final ox   = (size.width  - matW) / 2;
    final oy   = (size.height - matH) / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    var cx = ox;
    for (final ch in chars) {
      final glyph = dotMatrixGlyphs[ch] ?? dotMatrixGlyphs['-']!;
      final cols  = dotMatrixCharCols(ch);
      paint.color = litColor;
      for (var row = 0; row < _rows; row++) {
        final bits = glyph[row];
        for (var col = 0; col < cols; col++) {
          if (((bits >> ((cols - 1) - col)) & 1) == 1) {
            canvas.drawCircle(
              Offset(cx + col * step + step / 2, oy + row * step + step / 2),
              r, paint,
            );
          }
        }
      }
      cx += cols * step + step;
    }

    // ── the three dots ──────────────────────────────────────────────────────
    //
    // One bright at a time, travelling left to right, with the others held at a
    // low floor so the group keeps its shape and the line does not appear to
    // change length. A quarter of the cycle is left empty, which gives the
    // sequence a beginning and stops it reading as a spinner.
    cx += step;   // word space
    for (var i = 0; i < _dots; i++) {
      final slot  = t * (_dots + 1);           // +1 → the empty beat
      final near  = (slot - i).abs();
      final level = near < 1.0 ? 1.0 - near : 0.0;
      paint.color = litColor.withValues(alpha: 0.16 + 0.84 * level);
      canvas.drawCircle(
        Offset(cx + step / 2 + step, oy + _dotRow * step + step / 2),
        r, paint,
      );
      cx += _dotCols * step + step;
    }
  }

  @override
  bool shouldRepaint(_ReconnectingPainter old) =>
      old.t != t || old.text != text || old.litColor != litColor;
}
