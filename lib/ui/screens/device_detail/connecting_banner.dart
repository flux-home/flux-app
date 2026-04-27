part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Connecting banner — sonar-pulse animation with smooth exit
// ─────────────────────────────────────────────────────────────────────────────
//
// Renders a 7-row × N-column dot grid with a sonar-pulse brightness ring
// expanding from the centre while the device is unreachable.
//
// When isStale flips false the banner fades out and collapses its height so
// the cards below smoothly slide up to fill the gap.

enum _BannerPhase { hidden, visible, leaving }

class _ConnectingBanner extends StatefulWidget {
  const _ConnectingBanner({required this.isStale});
  final bool isStale;

  @override
  State<_ConnectingBanner> createState() => _ConnectingBannerState();
}

class _ConnectingBannerState extends State<_ConnectingBanner>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _exitCtrl;
  late _BannerPhase _phase;

  @override
  void initState() {
    super.initState();
    _phase = widget.isStale ? _BannerPhase.visible : _BannerPhase.hidden;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (_phase == _BannerPhase.visible) _pulseCtrl.repeat();

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _pulseCtrl.stop();
          setState(() => _phase = _BannerPhase.hidden);
        }
      });
  }

  @override
  void didUpdateWidget(_ConnectingBanner old) {
    super.didUpdateWidget(old);

    // Device found → start exit.
    if (old.isStale && !widget.isStale && _phase == _BannerPhase.visible) {
      _exitCtrl.forward();
      setState(() => _phase = _BannerPhase.leaving);
    }

    // Device lost again after connect (edge case) → reset and show.
    if (!old.isStale && widget.isStale && _phase == _BannerPhase.hidden) {
      _exitCtrl.reset();
      _pulseCtrl.repeat();
      setState(() => _phase = _BannerPhase.visible);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _BannerPhase.hidden) return const SizedBox.shrink();

    // The spacing gap is included so it collapses with the banner.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          color: const Color(0xFF1A1A1A),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _SonarPulsePainter(t: _pulseCtrl.value),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );

    if (_phase == _BannerPhase.visible) return content;

    // ── Leaving: fade out then collapse height ────────────────────────────────
    // Fade completes over the first 65 % of the exit duration.
    // Height collapse starts at 10 % so cards below begin moving while the
    // banner is still (briefly) visible — this looks more intentional than
    // collapsing an invisible card.
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

class _SonarPulsePainter extends CustomPainter {
  const _SonarPulsePainter({required this.t});

  /// Normalised animation position [0.0, 1.0).
  final double t;

  static const _rows     = 7;
  static const _gap      = 2.0;
  // Ring brightness falls off linearly over this many dot-widths on each side.
  static const _ringHalf = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Square cells: step is driven by the available height, exactly matching
    // the pitch of the 5×7 glyph painter used elsewhere in the app.
    final step = (size.height + _gap) / _rows;
    final cols = math.max(1, ((size.width + _gap) / step).floor());
    final r    = (step - _gap) / 2.0;

    // Centre the grid in case the width doesn't divide evenly.
    final ox = (size.width  - (step * cols - _gap)) / 2.0;
    final oy = (size.height - (step * _rows - _gap)) / 2.0;

    // Grid centre in dot-space.
    final cx = (cols - 1) / 2.0;
    const cy = (_rows - 1) / 2; // = 3.0

    // Ring travels from centre to just past the farthest corner, giving a
    // clean dark gap before the next pulse begins.
    final maxDist = math.sqrt(cx * cx + cy * cy);
    final radius  = t * (maxDist + 3.0);

    // Short centre-flash at the origin of each pulse.
    final centerFlash = math.max(0.0, 1.0 - t * 9.0);

    // Ring fades as it expands — distant wavefronts are slightly dimmer.
    final ringFade = 1.0 - t * 0.45;

    final paint = Paint()..style = PaintingStyle.fill;

    for (var row = 0; row < _rows; row++) {
      for (var col = 0; col < cols; col++) {
        final dx   = col - cx;
        final dy   = row - cy;
        final dist = math.sqrt(dx * dx + dy * dy);

        // Distance from this dot to the current wavefront.
        final diff = (dist - radius).abs();

        // Smooth peaked brightness at the wavefront, zero beyond _ringHalf.
        final wave = diff < _ringHalf
            ? math.pow(1.0 - diff / _ringHalf, 1.5).toDouble()
            : 0.0;

        // Combine ring with the origin flash (only near-centre dots).
        final brightness =
            (wave * ringFade + (dist < 1.0 ? centerFlash * 0.9 : 0.0))
                .clamp(0.0, 1.0);

        // All dots stay faintly visible; lit dots draw at full radius.
        final alpha = math.max(0.05, brightness);
        final dotR  = brightness > 0.08 ? r : r * 0.55;

        paint.color = Colors.white.withAlpha((alpha * 255).round());
        canvas.drawCircle(
          Offset(ox + col * step + step / 2, oy + row * step + step / 2),
          dotR,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SonarPulsePainter old) => old.t != t;
}
