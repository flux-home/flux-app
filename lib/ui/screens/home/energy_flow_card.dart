import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/models/energy_flow.dart';
import 'package:matter_home/models/energy_summary.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/utils/power_format.dart';

// Per-participant accents, matching the roles used elsewhere in the app.
const _solarColor   = Color(0xFFF6D08A); // amber
const _importColor  = Color(0xFFF2A9A0); // coral
const _exportColor  = Color(0xFFA9E0C0); // mint
const _batteryColor = Color(0xFFA9E0C0); // mint
const _carColor     = Color(0xFFCDBBEF); // lavender
const _heatColor    = Color(0xFFA9D8EE); // sky
const _homeColor    = Color(0xFFF3B8D6); // pink

/// Charge state is not a flow, so it deliberately sits outside the flow palette
/// — a neutral readout rather than another coloured participant. Sharing the
/// battery's mint made a level look like the power moving in or out of it.
const _chargeColor  = Color(0xFFDCE3DF); // near-white

/// Live energy flow: one fixed row per participant, each a bar growing out from
/// a shared centre line — left when it is **supplying** the house, right when it
/// is **consuming**.
///
/// Direction is the side, not the presence of a row. That matters for a house
/// running zero feed-in, where the grid deliberately hovers at zero and flips
/// sign every few seconds: as a ledger of transfers it had to add, remove and
/// re-order a row each time, which is unreadable. Here the same house shows a
/// grid bar resting quietly at the centre, twitching a few watts either way.
///
/// The row set never changes, so nothing ever appears, disappears or moves.
/// An idle participant simply has no bar.
///
/// Consumer bars are segmented by **which source is paying for them**
/// (see [attributeEnergy]), so the picture still answers "is the car charging
/// on sunlight?" without spending a row per source/sink pair.
class EnergyFlowCard extends StatefulWidget {
  const EnergyFlowCard({super.key});

  @override
  State<EnergyFlowCard> createState() => _EnergyFlowCardState();
}

class _EnergyFlowCardState extends State<EnergyFlowCard> {
  /// Below this a reversible flow reads as balanced rather than as a direction.
  /// Zero feed-in regulates around zero, so the raw sign is meaningless noise
  /// down here — showing it would flip the bar across the centre continuously.
  static const _deadbandW = 40.0;

  /// Smoothing applied to the bar lengths only (never to the printed value).
  /// The regulator hunts faster than the eye can read; without this the bars
  /// shiver even when nothing meaningful is changing.
  static const _smoothing = 0.25; // fraction of the gap closed per update

  final Map<String, double> _smoothed = {};

  double _smooth(String key, double target) {
    final prev = _smoothed[key];
    final next = prev == null ? target : prev + (target - prev) * _smoothing;
    _smoothed[key] = next;
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s  = context.watch<DeviceProvider>().energySummary;

    if (!s.hasAnyRole) {
      return _Frame(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Assign an energy role to a device to see the flow.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
      );
    }

    // Who pays for what — used to segment the consumer bars.
    final byUse = <EnergyEndpoint, List<EnergyTransfer>>{};
    for (final t in attributeEnergy(s)) {
      (byUse[t.to] ??= []).add(t);
    }

    final rows = _buildRows(s, byUse);
    final scale = rows.fold<double>(
        200, (m, r) => r.watts.abs() > m ? r.watts.abs() : m);

    return _Frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HouseTotal(watts: s.houseLoad),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text('SUPPLYING', style: _legendStyle(cs)),
                const Spacer(),
                Text('CONSUMING', style: _legendStyle(cs)),
              ],
            ),
          ),
          for (final r in rows)
            _BarRow(row: r, scale: scale, smoothed: _smooth(r.key, r.watts)),
          const SizedBox(height: 6),
          for (final g in _gauges(s)) _GaugeRow(gauge: g),
        ],
      ),
    );
  }

  TextStyle _legendStyle(ColorScheme cs) => TextStyle(
        fontFamily: 'monospace', fontSize: 8.5, fontWeight: FontWeight.w700,
        letterSpacing: 1.2, color: cs.onSurfaceVariant.withValues(alpha: 0.7),
      );

  /// The fixed row set. Order is supply-ish first, then the house and its
  /// appliances — and it never changes, whatever the numbers do.
  List<_Row> _buildRows(
      EnergySummary s, Map<EnergyEndpoint, List<EnergyTransfer>> byUse) {
    List<_Seg> segs(EnergyEndpoint use, Color fallback) {
      final ts = byUse[use];
      if (ts == null || ts.isEmpty) return [_Seg(1, fallback)];
      return [for (final t in ts) _Seg(t.watts, _sourceColor(t.from))];
    }

    return [
      if (s.hasPv)
        _Row('solar', 'SOLAR', -s.pvProduction, [_Seg(1, _solarColor)], null),
      if (s.hasGrid)
        // ONE row for the grid, signed: importing pulls it left, exporting
        // pushes it right. This is the row that used to thrash.
        _Row('grid', 'GRID', netFlow(consuming: s.gridExport, supplying: s.gridImport, deadbandW: _deadbandW),
            s.gridExport > s.gridImport
                ? segs(EnergyEndpoint.grid, _exportColor)
                : [_Seg(1, _importColor)],
            _balanceNote(s.gridExport - s.gridImport, 'importing', 'exporting')),
      if (s.hasBattery)
        _Row('battery', 'BATTERY', netFlow(consuming: s.batteryCharge, supplying: s.batteryDischarge, deadbandW: _deadbandW),
            s.batteryCharge > s.batteryDischarge
                ? segs(EnergyEndpoint.battery, _batteryColor)
                : [_Seg(1, _batteryColor)],
            _balanceNote(
                s.batteryCharge - s.batteryDischarge, 'discharging', 'charging')),
      _Row('home', 'HOME', s.restOfHome,
          segs(EnergyEndpoint.restOfHome, _homeColor), null),
      if (s.hasHeatPump)
        _Row('heat', 'HEAT PUMP', s.heatPump,
            segs(EnergyEndpoint.heatPump, _heatColor), null),
      if (s.hasCar)
        _Row('car', 'CAR', s.carCharging,
            segs(EnergyEndpoint.car, _carColor), null),
    ];
  }

  String? _balanceNote(double net, String whenSupplying, String whenConsuming) {
    if (net.abs() < _deadbandW) return 'balanced';
    return net > 0 ? whenConsuming : whenSupplying;
  }

  List<_Gauge> _gauges(EnergySummary s) => [
        if (s.batterySocPercent != null)
          _Gauge(
            name: 'BATTERY',
            percent: s.batterySocPercent!,
            // What the level is DOING, next to what it is. Read off the same
            // deadband as the bar above, so the two can never disagree — the
            // bar cannot sit at "balanced" while this claims it is charging.
            note: switch (netFlow(
                consuming: s.batteryCharge, supplying: s.batteryDischarge,
                deadbandW: _deadbandW)) {
              > 0 => 'charging',
              < 0 => 'discharging',
              _   => 'idle',
            },
          ),
        if (s.carSocPercent != null)
          _Gauge(
            name: 'CAR',
            percent: s.carSocPercent!,
            note: s.carCharging > _deadbandW ? 'charging' : 'plugged in',
          ),
      ];
}

Color _sourceColor(EnergyEndpoint e) => switch (e) {
      EnergyEndpoint.solar   => _solarColor,
      EnergyEndpoint.grid    => _importColor,
      EnergyEndpoint.battery => _batteryColor,
      _                      => _homeColor,
    };

// ── Row model ───────────────────────────────────────────────────────────────

class _Seg {
  const _Seg(this.weight, this.color);
  final double weight;
  final Color  color;
}

class _Row {
  const _Row(this.key, this.label, this.watts, this.segments, this.note);
  final String     key;
  final String     label;
  /// Negative = supplying the house (bar grows left), positive = consuming.
  final double     watts;
  final List<_Seg> segments;
  final String?    note;
}

// ── Pieces ──────────────────────────────────────────────────────────────────

class _BarRow extends StatelessWidget {
  const _BarRow({required this.row, required this.scale, required this.smoothed});
  final _Row   row;
  final double scale;
  final double smoothed;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final idle = row.watts.abs() < 1;
    final (v, u) = formatPowerW(row.watts.abs());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(row.label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5,
                    color: idle
                        ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                        : cs.onSurface)),
          ),
          Expanded(
            child: SizedBox(
              height: 12,
              child: CustomPaint(
                painter: _DivergingBarPainter(
                  watts: smoothed,
                  scale: scale,
                  segments: row.segments,
                  centreLine: cs.onSurface.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              idle ? (row.note ?? '—') : '$v $u',
              textAlign: TextAlign.right,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: idle ? 10 : 14,
                fontFamily: idle ? 'monospace' : null,
                fontWeight: FontWeight.w700,
                color: idle ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a bar out from the centre — left for supplying, right for consuming —
/// split into segments by whichever source is paying for it.
class _DivergingBarPainter extends CustomPainter {
  const _DivergingBarPainter({
    required this.watts,
    required this.scale,
    required this.segments,
    required this.centreLine,
  });

  final double     watts;
  final double     scale;
  final List<_Seg> segments;
  final Color      centreLine;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    canvas.drawRect(
      Rect.fromLTWH(cx - 0.5, 0, 1, size.height),
      Paint()..color = centreLine,
    );

    final half = (watts.abs() / scale).clamp(0.0, 1.0) * (size.width / 2 - 2);
    if (half < 0.5) return;

    final total = segments.fold<double>(0, (a, s) => a + s.weight);
    final toRight = watts > 0;
    var x = toRight ? cx + 1 : cx - 1 - half;

    // Segments run outward from the centre, so the biggest contributor sits
    // nearest the line on both sides and the eye compares like with like.
    final ordered = toRight ? segments : segments.reversed.toList();
    for (final s in ordered) {
      final w = half * (s.weight / total);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 1, w.clamp(0.0, half), size.height - 2),
          const Radius.circular(2),
        ),
        Paint()..color = s.color,
      );
      x += w;
    }
  }

  @override
  bool shouldRepaint(_DivergingBarPainter old) =>
      old.watts != watts || old.scale != scale || old.segments != segments;
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text('ENERGY FLOW', style: TextStyle(
              fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700,
              letterSpacing: 2.4, color: cs.onSurfaceVariant)),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _HouseTotal extends StatelessWidget {
  const _HouseTotal({required this.watts});
  final double watts;

  @override
  Widget build(BuildContext context) {
    final (v, u) = formatPowerW(watts);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$v $u', style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
          const SizedBox(width: 9),
          const Text('HOME NOW', style: TextStyle(
              fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 1.4, color: _homeColor)),
        ],
      ),
    );
  }
}

class _Gauge {
  const _Gauge({required this.name, required this.percent, required this.note});
  final String name;
  final int    percent;
  final String note;
}

class _GaugeRow extends StatelessWidget {
  const _GaugeRow({required this.gauge});
  final _Gauge gauge;

  static const _cells = 10;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filled = (gauge.percent / 100 * _cells).round();

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(gauge.name, style: const TextStyle(
                fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 0.5, color: _chargeColor)),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < _cells; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: i < filled
                          ? _chargeColor
                          : cs.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text('${gauge.percent}%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 74,
            child: Text(gauge.note,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 9.5,
                    color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
