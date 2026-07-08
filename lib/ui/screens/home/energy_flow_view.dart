import 'package:flutter/material.dart';
import 'package:matter_home/models/energy_role.dart';
import 'package:matter_home/models/energy_summary.dart';
import 'package:matter_home/utils/power_format.dart';

/// Live home energy-flow overview.
///
/// Draws the roles the user has assigned as nodes — PV on top, Grid and Battery
/// flanking the House in the middle, monitored consumers (Car, Heat Pump) plus
/// a derived "Rest of home" below — connected by animated flow lines whose
/// direction and speed follow the live [EnergySummary].
///
/// Nodes for roles with no assigned device are hidden, so a partial setup still
/// reads cleanly.
class HomeEnergyOverview extends StatefulWidget {
  const HomeEnergyOverview({required this.summary, super.key});

  final EnergySummary summary;

  @override
  State<HomeEnergyOverview> createState() => _HomeEnergyOverviewState();
}

class _HomeEnergyOverviewState extends State<HomeEnergyOverview>
    with SingleTickerProviderStateMixin {
  // A continuously increasing "seconds" clock shared by every flow line, so
  // each line can advance its dot at its own power-proportional speed without
  // wrap-around jumps (pos = (seconds * crossingsPerSec) % 1).
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController.unbounded(vsync: this)
      ..animateTo(1e6, duration: const Duration(seconds: 1000000));
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s  = widget.summary;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.home_outlined, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text('HOME ENERGY',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),

            // ── PV (top) ──────────────────────────────────────────────────
            if (s.hasPv) ...[
              Center(
                child: _EnergyNode(
                  role:  EnergyRole.pv,
                  watts: s.pvProduction,
                  color: const Color(0xFFF5A623),
                ),
              ),
              _VFlow(clock: _clock, watts: s.pvProduction, downward: true,
                  color: const Color(0xFFF5A623)),
            ],

            // ── Grid · House · Battery (middle) ───────────────────────────
            // Top-align so every circle sits at the same y and the horizontal
            // connector (same height as a circle) runs exactly through their
            // centres. Grid sits left, House follows the flow to its right, and
            // the battery (when present) sits on the far right.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.hasGrid) ...[
                    _EnergyNode(
                      role:  EnergyRole.grid,
                      watts: s.gridImport > 0 ? s.gridImport : s.gridExport,
                      color: s.gridExport > 0
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE05353),
                      caption: s.gridExport > 0 ? 'exporting' : 'importing',
                    ),
                    Expanded(
                      child: _HFlow(
                        clock: _clock,
                        watts: s.gridImport > 0 ? s.gridImport : s.gridExport,
                        // Import flows grid → house (rightward = forward).
                        forward: s.gridImport >= s.gridExport,
                        color: s.gridExport > 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE05353),
                      ),
                    ),
                  ],
                  _HouseNode(load: s.houseLoad),
                  if (s.hasBattery) ...[
                    Expanded(
                      child: _HFlow(
                        clock: _clock,
                        watts: s.batteryDischarge > 0
                            ? s.batteryDischarge
                            : s.batteryCharge,
                        // Discharge flows battery → house (leftward = forward
                        // points toward the house on the right-hand connector).
                        forward: s.batteryCharge >= s.batteryDischarge,
                        color: const Color(0xFF3DBFA0),
                      ),
                    ),
                    _EnergyNode(
                      role:  EnergyRole.homeBattery,
                      watts: s.batteryDischarge > 0
                          ? s.batteryDischarge
                          : s.batteryCharge,
                      color: const Color(0xFF3DBFA0),
                      caption: s.batterySocPercent != null
                          ? '${s.batterySocPercent}%'
                          : (s.batteryCharge > 0 ? 'charging' : 'discharging'),
                    ),
                  ],
                ],
              ),
            ),

            // ── Consumers (bottom) ────────────────────────────────────────
            if (s.hasCar || s.hasHeatPump) ...[
              _VFlow(clock: _clock, watts: s.houseLoad, downward: true,
                  color: cs.primary),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.hasCar)
                    _EnergyNode(
                      role:  EnergyRole.carCharger,
                      watts: s.carCharging,
                      color: const Color(0xFF8E7CFF),
                    ),
                  if (s.hasHeatPump)
                    _EnergyNode(
                      role:  EnergyRole.heatPump,
                      watts: s.heatPump,
                      color: const Color(0xFF4FC3E8),
                    ),
                  _EnergyNode.rest(watts: s.restOfHome, color: cs.onSurfaceVariant),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nodes
// ─────────────────────────────────────────────────────────────────────────────

class _EnergyNode extends StatelessWidget {
  const _EnergyNode({
    required this.role,
    required this.watts,
    required this.color,
    this.caption,
  }) : _label = null;

  const _EnergyNode.rest({required this.watts, required this.color})
      : role    = EnergyRole.none,
        caption = null,
        _label  = 'Rest of home';

  final EnergyRole role;
  final double     watts;
  final Color      color;
  final String?    caption;
  final String?    _label;

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final (val, unit) = formatPowerW(watts);
    final icon      = role == EnergyRole.none ? Icons.house_siding_outlined : role.icon;
    final label     = _label ?? role.label;

    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(120), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(children: [
              TextSpan(
                  text: val,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
              TextSpan(
                  text: ' $unit',
                  style: TextStyle(fontSize: 11, color: color)),
            ]),
          ),
          if (caption != null)
            Text(caption!,
                style: TextStyle(fontSize: 10, color: color.withAlpha(200))),
        ],
      ),
    );
  }
}

class _HouseNode extends StatelessWidget {
  const _HouseNode({required this.load});
  final double load;

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final (val, unit) = formatPowerW(load);

    return SizedBox(
      width: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(38),
              shape: BoxShape.circle,
              border: Border.all(color: cs.primary.withAlpha(170), width: 2.5),
            ),
            child: Icon(Icons.home_rounded, color: cs.primary, size: 32),
          ),
          const SizedBox(height: 6),
          Text('Home', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: val,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
              TextSpan(text: ' $unit', style: TextStyle(fontSize: 11, color: cs.primary)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flow connectors — a dim rail with a moving dot whose speed ∝ power.
// A single shared "seconds" clock drives every line; pos wraps continuously.
// ─────────────────────────────────────────────────────────────────────────────

class _HFlow extends StatelessWidget {
  const _HFlow({
    required this.clock,
    required this.watts,
    required this.forward,
    required this.color,
  });

  final Animation<double> clock;
  final double watts;
  final bool   forward;
  final Color  color;

  @override
  Widget build(BuildContext context) => SizedBox(
        // Matches the circle diameter so, when top-aligned with the nodes, the
        // rail's centre line runs exactly through the circle centres.
        height: 60,
        child: AnimatedBuilder(
          animation: clock,
          builder: (_, __) => CustomPaint(
            painter: _FlowPainter(
              seconds: clock.value,
              watts:   watts,
              forward: forward,
              color:   color,
              horizontal: true,
            ),
            size: Size.infinite,
          ),
        ),
      );
}

class _VFlow extends StatelessWidget {
  const _VFlow({
    required this.clock,
    required this.watts,
    required this.downward,
    required this.color,
  });

  final Animation<double> clock;
  final double watts;
  final bool   downward;
  final Color  color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 26,
        child: AnimatedBuilder(
          animation: clock,
          builder: (_, __) => CustomPaint(
            painter: _FlowPainter(
              seconds: clock.value,
              watts:   watts,
              forward: downward,
              color:   color,
              horizontal: false,
            ),
            size: Size.infinite,
          ),
        ),
      );
}

class _FlowPainter extends CustomPainter {
  const _FlowPainter({
    required this.seconds,
    required this.watts,
    required this.forward,
    required this.color,
    required this.horizontal,
  });

  final double seconds;
  final double watts;
  final bool   forward;
  final Color  color;
  final bool   horizontal;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final Offset a, b;
    if (horizontal) {
      a = Offset(0, cy);
      b = Offset(size.width, cy);
    } else {
      a = Offset(cx, 0);
      b = Offset(cx, size.height);
    }

    // Dim rail — always visible.
    canvas.drawLine(
      a, b,
      Paint()
        ..color = color.withAlpha(36)
        ..strokeWidth = 1.5,
    );

    if (watts < 1) return; // effectively idle — no moving dot

    // One gentle dot drifts along the rail. Speed varies only slightly with
    // power (0.2 … 0.6 Hz) so the diagram reads calm, not busy — magnitude is
    // conveyed by the node values, not by frantic motion.
    final speed = (0.2 + watts / 12000).clamp(0.2, 0.6);
    final t = (seconds * speed) % 1.0;
    final frac = forward ? t : 1.0 - t;

    final dot = Offset.lerp(a, b, frac)!;
    // Soft leading fade in/out at the ends so the dot doesn't pop.
    final edge = (frac < 0.12
            ? frac / 0.12
            : frac > 0.88 ? (1 - frac) / 0.12 : 1.0)
        .clamp(0.0, 1.0);
    canvas.drawCircle(
      dot, 2.5, Paint()..color = color.withAlpha((edge * 235).round()));
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.seconds != seconds ||
      old.watts   != watts ||
      old.forward != forward ||
      old.color   != color;
}
