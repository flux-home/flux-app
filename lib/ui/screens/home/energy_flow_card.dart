import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/models/energy_flow.dart';
import 'package:matter_home/models/energy_summary.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/utils/power_format.dart';

// Per-participant accents, matching the roles used elsewhere in the app.
const _solarColor  = Color(0xFFF6D08A); // amber
const _importColor = Color(0xFFF2A9A0); // coral
const _exportColor = Color(0xFFA9E0C0); // mint
const _batteryColor = Color(0xFFA9E0C0); // mint
const _carColor    = Color(0xFFCDBBEF); // lavender
const _heatColor   = Color(0xFFA9D8EE); // sky
const _homeColor   = Color(0xFFF3B8D6); // pink

/// Live energy flow, as a ledger of attributed transfers.
///
/// One row per transfer — "Solar → Car 3.6 kW" — because the question this
/// screen exists to answer is not how much is moving but *where it is going*.
/// The attribution itself lives in [attributeEnergy]; this widget only draws it.
///
/// Charge levels are deliberately NOT rows in that list: a charge level is a
/// state, not a flow, so it keeps its own line and stays visible when nothing
/// is moving to or from it — a car still reads 78% while drawing nothing.
class EnergyFlowCard extends StatefulWidget {
  const EnergyFlowCard({super.key});

  @override
  State<EnergyFlowCard> createState() => _EnergyFlowCardState();
}

class _EnergyFlowCardState extends State<EnergyFlowCard> {
  /// How long a transfer stays on screen after it stops, and how long it then
  /// takes to fade. A flow that ends should not yank the rows below it upward
  /// mid-glance — the eye is usually still on the number when it goes.
  static const _hold     = Duration(seconds: 10);
  static const _fade     = Duration(milliseconds: 1500);
  static const _collapse = Duration(milliseconds: 300);

  /// Rows in display order, including ones that have stopped and are on their
  /// way out. Order is deliberately sticky: a row never moves once placed, so
  /// nothing under the finger shifts. New transfers join at the end.
  final List<_RowState> _rows = [];
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Folds the current attribution into [_rows], keeping stopped ones alive
  /// until they have finished fading.
  void _sync(List<EnergyTransfer> transfers) {
    final now = DateTime.now();
    final seen = <_RowKey>{};

    for (final t in transfers) {
      final key = (t.from, t.to);
      seen.add(key);
      final i = _rows.indexWhere((r) => r.key == key);
      if (i == -1) {
        _rows.add(_RowState(key, t.watts));
      } else {
        _rows[i]
          ..watts = t.watts
          ..stoppedAt = null;   // came back before it finished fading
      }
    }

    for (final r in _rows) {
      if (seen.contains(r.key)) continue;
      r.watts = 0;
      r.stoppedAt ??= now;
    }
    _rows.removeWhere((r) => r.stoppedAt != null &&
        now.difference(r.stoppedAt!) > _hold + _fade + _collapse);

    // Only tick while something is on its way out; a steady house costs nothing.
    final fading = _rows.any((r) => r.stoppedAt != null);
    if (fading && _ticker == null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {});
      });
    } else if (!fading) {
      _ticker?.cancel();
      _ticker = null;
    }
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

    _sync(attributeEnergy(s));
    final gauges = _gauges(s);
    final now = DateTime.now();

    return _Frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HouseTotal(watts: s.houseLoad),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('Nothing is moving right now.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            )
          else
            // A stopped row leaves in three beats: it rests at 0 W long enough
            // to be seen doing it, fades, and only then gives up its height.
            // Collapsing at the same moment it fades would still move the rows
            // below it while the eye is on them.
            for (final r in _rows)
              Builder(builder: (_) {
                final since = r.stoppedAt == null
                    ? Duration.zero
                    : now.difference(r.stoppedAt!);
                final leaving = r.stoppedAt != null && since >= _hold;
                final gone    = r.stoppedAt != null && since >= _hold + _fade;
                return AnimatedSize(
                  duration: _collapse,
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: gone
                      ? const SizedBox(width: double.infinity, height: 0)
                      : AnimatedOpacity(
                          duration: _fade,
                          curve: Curves.easeOut,
                          opacity: leaving ? 0 : 1,
                          child: _TransferRow(
                            transfer:
                                EnergyTransfer(r.key.$1, r.key.$2, r.watts),
                          ),
                        ),
                );
              }),
          if (gauges.isNotEmpty) const SizedBox(height: 6),
          for (final g in gauges) _GaugeRow(gauge: g),
        ],
      ),
    );
  }

  List<_Gauge> _gauges(EnergySummary s) => [
        if (s.batterySocPercent != null)
          _Gauge(
            name: 'BATTERY',
            color: _batteryColor,
            percent: s.batterySocPercent!,
            note: s.batteryCharge > 20
                ? 'charging'
                : s.batteryDischarge > 20 ? 'discharging' : 'idle',
          ),
        if (s.carSocPercent != null)
          _Gauge(
            name: 'CAR',
            color: _carColor,
            percent: s.carSocPercent!,
            note: s.carCharging > 20 ? 'charging' : 'plugged in',
          ),
      ];
}

typedef _RowKey = (EnergyEndpoint, EnergyEndpoint);

class _RowState {
  _RowState(this.key, this.watts);
  final _RowKey key;
  double watts;
  /// When this transfer stopped, or null while it is still flowing.
  DateTime? stoppedAt;
}

Color _colorFor(EnergyEndpoint e, {required bool asSource}) => switch (e) {
      EnergyEndpoint.solar      => _solarColor,
      // The grid is the one endpoint that means opposite things on each side:
      // coral when it is selling to us, mint when we are selling to it.
      EnergyEndpoint.grid       => asSource ? _importColor : _exportColor,
      EnergyEndpoint.battery    => _batteryColor,
      EnergyEndpoint.heatPump   => _heatColor,
      EnergyEndpoint.car        => _carColor,
      EnergyEndpoint.restOfHome => _homeColor,
    };

// ── Pieces ──────────────────────────────────────────────────────────────────

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

class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.transfer});
  final EnergyTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _colorFor(transfer.from, asSource: true);
    final (v, u) = formatPowerW(transfer.watts);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(width: 7, height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(transfer.from.label.toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          SizedBox(
            width: 34, height: 8,
            child: CustomPaint(painter: _ArrowPainter(color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(transfer.to.label.toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          Text('$v $u', style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// A line with a solid head — direction without spending a glyph on it.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width - 8, y), stroke);
    final head = Path()
      ..moveTo(size.width - 9, y - 3)
      ..lineTo(size.width, y)
      ..lineTo(size.width - 9, y + 3)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}

class _Gauge {
  const _Gauge({required this.name, required this.color,
                required this.percent, required this.note});
  final String name;
  final Color  color;
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
            width: 62,
            child: Text(gauge.name, style: TextStyle(
                fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 0.8, color: gauge.color)),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < _cells; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(child: Container(
                    height: 13,
                    decoration: BoxDecoration(
                      color: i < filled
                          ? gauge.color
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
            width: 38,
            child: Text('${gauge.percent}%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 66,
            child: Text(gauge.note, style: TextStyle(
                fontFamily: 'monospace', fontSize: 9.5,
                color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
