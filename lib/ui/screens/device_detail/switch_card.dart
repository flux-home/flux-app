part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Switch state card  (BILRESA and similar multi-mode scroll-wheel remotes)
//
// Layout:
//   ┌──────────────────────────────────────────┐
//   │  ╭───╮      ╭───╮      ╭───╮             │  ← slot pills (1 / 2 / 3)
//   │  │ 1 │      │ 2 │      │ 3 │             │
//   │  ╰───╯      ╰───╯      ╰───╯             │
//   │  Lamp        —          —                │  ← linked device name
//   │                                          │
//   │        ·  ·  ·  ·  ·                    │
//   │     ·              ·                     │
//   │   ·    C L I C K    ·                   │  ← glyph-dot wheel
//   │     ·              ·                     │
//   │        ·  ·  ·  ·  ·                    │
//   └──────────────────────────────────────────┘
//
// The wheel's ring dots animate:
//   press → full ring lit, CLICK fully lit
//   cw    → sweeping arc clockwise,  CLICK dim
//   ccw   → sweeping arc CCW,        CLICK dim
//   idle  → all dots dim,            CLICK dim
// ─────────────────────────────────────────────────────────────────────────────

enum _CtrlKind { press, cw, ccw }

_CtrlKind? _kindOf(ClusterReading r) {
  if (r.icon == Icons.rotate_right ||
      r.icon == Icons.swipe_up_outlined)   { return _CtrlKind.cw; }
  if (r.icon == Icons.rotate_left  ||
      r.icon == Icons.swipe_down_outlined) { return _CtrlKind.ccw; }
  if (r.icon == Icons.radio_button_checked  ||
      r.icon == Icons.radio_button_unchecked ||
      r.icon == Icons.smart_button_outlined) { return _CtrlKind.press; }
  return null;
}

class _VirtualSwitch {
  _VirtualSwitch(this.label);
  final String   label;
  final Set<int> pressEps = {};
  final Set<int> cwEps    = {};
  final Set<int> ccwEps   = {};
  Set<int> get allEps => {...pressEps, ...cwEps, ...ccwEps};
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({required this.view, required this.readings});
  final DeviceView           view;
  final List<ClusterReading> readings;

  List<_VirtualSwitch> _buildSwitches() {
    final map   = <String, _VirtualSwitch>{};
    final order = <String>[];
    for (final r in readings) {
      final ep    = r.endpoint;
      final group = r.group ?? '${r.endpoint}';
      final kind  = _kindOf(r);
      if (ep == null || kind == null) continue;
      if (!map.containsKey(group)) {
        map[group] = _VirtualSwitch(group);
        order.add(group);
      }
      switch (kind) {
        case _CtrlKind.press: map[group]!.pressEps.add(ep);
        case _CtrlKind.cw:    map[group]!.cwEps.add(ep);
        case _CtrlKind.ccw:   map[group]!.ccwEps.add(ep);
      }
    }
    return order.map((g) => map[g]!).toList();
  }

  @override
  Widget build(BuildContext context) {
    final switches = _buildSwitches();

    final curEp    = view.switchCurrentEndpoint ?? 0;
    final lastEp   = view.switchLastEndpoint    ?? 0;
    final activeEp = curEp > 0 ? curEp : lastEp;
    final isLive   = curEp > 0;

    // Resolve active slot + gesture.
    int        activeIdx     = -1;
    _CtrlKind? activeGesture;

    if (switches.isNotEmpty) {
      for (var i = 0; i < switches.length; i++) {
        final sw = switches[i];
        if (sw.pressEps.contains(activeEp)) { activeIdx = i; activeGesture = _CtrlKind.press; break; }
        if (sw.cwEps.contains(activeEp))    { activeIdx = i; activeGesture = _CtrlKind.cw;    break; }
        if (sw.ccwEps.contains(activeEp))   { activeIdx = i; activeGesture = _CtrlKind.ccw;   break; }
      }
    } else {
      // No cluster readings yet — infer from raw live fields.
      if (curEp > 0) {
        activeGesture = _CtrlKind.press;
      } else if (lastEp > 0) {
        activeGesture = (view.switchLastPosition ?? 1) == 2
            ? _CtrlKind.ccw
            : _CtrlKind.cw;
      }
    }

    final provider = context.read<DeviceProvider>();
    final links    = provider.linksFor(view.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Slot pills ────────────────────────────────────────────────
            if (switches.isNotEmpty)
              Row(
                children: [
                  for (var i = 0; i < switches.length; i++) ...[
                    Expanded(
                      child: _SlotPill(
                        label:      switches[i].label,
                        isActive:   i == activeIdx,
                        linkedName: _linkedName(links, switches[i].label, provider),
                      ),
                    ),
                    if (i < switches.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),

            if (switches.isNotEmpty) const SizedBox(height: 16),

            // ── Wheel ─────────────────────────────────────────────────────
            AspectRatio(
              aspectRatio: 1,
              child: _WheelWidget(
                gesture:          activeGesture,
                isLive:           isLive,
                animationTrigger: view.live?.attrs['switchPressTime'],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _linkedName(
    List<SwitchLink> links,
    String groupLabel,
    DeviceProvider provider,
  ) {
    final link = links.where((l) => l.switchGroup == groupLabel).firstOrNull;
    if (link == null || link.targetDeviceIds.isEmpty) return null;
    return provider.viewFor(link.targetDeviceIds.first)?.name;
  }
}

// ── Slot pill ─────────────────────────────────────────────────────────────────

class _SlotPill extends StatelessWidget {
  const _SlotPill({
    required this.label,
    required this.isActive,
    this.linkedName,
  });
  final String  label;
  final bool    isActive;
  final String? linkedName;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final color = isActive
        ? kBrandGreen
        : cs.onSurface.withValues(alpha: 0.2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve:    Curves.easeOut,
          height:   52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: isActive ? 2.0 : 1.0),
            color:  isActive
                ? kBrandGreen.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize:      22,
                fontWeight:    FontWeight.w700,
                color:         color,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          linkedName ?? '—',
          style: TextStyle(
            fontSize:      11,
            letterSpacing: 0.3,
            color: isActive
                ? cs.onSurface.withValues(alpha: 0.7)
                : cs.onSurface.withValues(alpha: 0.25),
          ),
          maxLines:  1,
          overflow:  TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Animated glyph-dot wheel ──────────────────────────────────────────────────

class _WheelWidget extends StatefulWidget {
  const _WheelWidget({
    required this.gesture,
    required this.isLive,
    this.animationTrigger,
  });
  final _CtrlKind? gesture;
  final bool       isLive;
  final Object?    animationTrigger;

  @override
  State<_WheelWidget> createState() => _WheelWidgetState();
}

class _WheelWidgetState extends State<_WheelWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation      _curved;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _sync();
  }

  @override
  void didUpdateWidget(_WheelWidget old) {
    super.didUpdateWidget(old);
    if (old.gesture != widget.gesture ||
        old.animationTrigger != widget.animationTrigger) _sync();
  }

  void _sync() {
    if (widget.gesture == _CtrlKind.cw ||
        widget.gesture == _CtrlKind.ccw) {
      _ctrl.forward(from: 0);
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final raw  = _ctrl.value;
        // Fade the arc out over the last 35% of the sweep.
        final fade = raw < 0.65
            ? 1.0
            : 1.0 - ((raw - 0.65) / 0.35).clamp(0.0, 1.0);
        return CustomPaint(
          painter: _WheelPainter(
            gesture: widget.gesture,
            // Eased phase drives arc position; reversed for CCW.
            phase:   widget.gesture == _CtrlKind.ccw
                ? 1.0 - _curved.value
                : _curved.value,
            fade:    fade,
            isLive:  widget.isLive,
            color:   Colors.white,
          ),
        );
      },
    );
  }
}

// ── Wheel painter ─────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  const _WheelPainter({
    required this.gesture,
    required this.phase,
    required this.fade,
    required this.isLive,
    required this.color,
  });
  final _CtrlKind? gesture;
  final double     phase;   // 0..1 eased animation progress
  final double     fade;    // 1.0 = full, 0.0 = invisible
  final bool       isLive;
  final Color      color;

  // Number of dots evenly spaced around the ring.
  static const _nDots  = 36;
  // How many dots make up the lit arc (120° = 1/3 of ring).
  static const _arcLen = _nDots ~/ 3;

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final center = Offset(cx, cy);
    final ringR  = math.min(cx, cy) - 10;
    final dotR   = ringR * 0.030;

    // ── Ring of glyph dots ───────────────────────────────────────────────────
    for (var i = 0; i < _nDots; i++) {
      // Start at 12 o'clock, advance clockwise.
      final angle = 2 * math.pi * i / _nDots - math.pi / 2;
      final pos   = center + Offset(
        math.cos(angle) * ringR,
        math.sin(angle) * ringR,
      );
      canvas.drawCircle(pos, dotR, Paint()..color = _dotColor(i));
    }

    // ── "CLICK" in the centre ────────────────────────────────────────────────
    final clickAlpha = switch (gesture) {
      _CtrlKind.press => isLive ? 230 : 170,
      _           => 55,
    };
    paintDotMatrix(
      canvas,
      center,
      'CLICK',
      maxWidth:  ringR * 1.1,
      maxHeight: ringR * 0.28,
      color:     color.withAlpha(clickAlpha),
    );
  }

  Color _dotColor(int i) {
    const baseAlpha = 38;

    if (gesture == null) { return color.withAlpha(baseAlpha); }

    if (gesture == _CtrlKind.press) {
      return color.withAlpha(isLive ? 220 : 130);
    }

    // CW / CCW — sweeping gradient arc.
    // Leading edge index (dot that the bright tip is currently at).
    final lead = (phase * _nDots).toInt() % _nDots;

    // Distance "behind" the leading edge in the direction of travel.
    final dist = gesture == _CtrlKind.cw
        ? (lead - i + _nDots) % _nDots   // CW: dots behind = smaller index
        : (i - lead + _nDots) % _nDots;  // CCW: behind = larger index

    if (dist >= _arcLen) { return color.withAlpha(baseAlpha); }

    // Quadratic falloff: leading edge bright, tail dim.
    final t     = 1.0 - dist / _arcLen;
    final alpha = (baseAlpha + t * t * (225 - baseAlpha)).round().clamp(0, 255);
    final dimmed = isLive ? alpha : (alpha * 0.6).round().clamp(baseAlpha, 255);
    // Fade back to baseAlpha (not to 0) so arc dots never go darker than the ring.
    final faded = (baseAlpha + (dimmed - baseAlpha) * fade).round().clamp(0, 255);
    return color.withAlpha(faded);
  }

  @override
  bool shouldRepaint(_WheelPainter o) =>
      o.gesture != gesture ||
      o.phase   != phase   ||
      o.fade    != fade    ||
      o.isLive  != isLive  ||
      o.color   != color;
}
