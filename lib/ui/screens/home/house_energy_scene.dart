import 'package:flutter/material.dart';
import 'package:matter_home/models/energy_scene.dart';
import 'package:matter_home/models/energy_summary.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/utils/power_format.dart';
import 'package:provider/provider.dart';

// Soft pastel accents per asset.
const _pvColor      = Color(0xFFF6D08A); // amber
const _gridImport   = Color(0xFFF2A9A0); // coral
const _gridExport   = Color(0xFFA9E0C0); // mint
const _batteryColor = Color(0xFFA9E0C0); // mint
const _carColor     = Color(0xFFCDBBEF); // lavender
const _heatColor    = Color(0xFFA9D8EE); // sky
const _homeColor    = Color(0xFFF3B8D6); // pink

/// A clean isometric wireframe house with roof solar panels, overlaid with
/// pastel-outlined pills (short label + current value) for each assigned
/// energy asset. Informational only — no interactivity.
class HouseEnergyScene extends StatelessWidget {
  const HouseEnergyScene({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s  = context.watch<DeviceProvider>().energySummary;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: kSceneAspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // House drawn in the upper portion, leaving a band for badges.
              CustomPaint(
                painter: _WireframeHouse(
                    color: cs.onSurface.withValues(alpha: 0.9)),
              ),
              // Solar stays on the roof.
              if (s.hasPv)
                Align(
                  alignment: Alignment(SceneAsset.pv.anchor.dx * 2 - 1,
                      SceneAsset.pv.anchor.dy * 2 - 1),
                  child: _Pill(
                      desc: 'Solar',
                      value: _fmt(s.pvProduction),
                      color: _pvColor),
                ),
              // Everything else below the house.
              Positioned(
                left: 4, right: 4, bottom: 2,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final o in _belowHouse(s))
                      _Pill(desc: o.desc, value: o.value, color: o.color),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double watts) {
    final (v, u) = formatPowerW(watts);
    return '$v $u';
  }

  /// Assigned assets other than solar, shown in the row below the house.
  List<_Overlay> _belowHouse(EnergySummary s) {
    final out = <_Overlay>[];
    void add(SceneAsset a, bool on, double watts, Color color, [String? desc]) {
      if (!on) return;
      out.add(_Overlay(a, desc ?? a.shortLabel, _fmt(watts), color));
    }

    final exporting = s.gridExport > s.gridImport;
    add(SceneAsset.grid, s.hasGrid, exporting ? s.gridExport : s.gridImport,
        exporting ? _gridExport : _gridImport,
        exporting ? 'Grid · Export' : 'Grid · Import');
    add(SceneAsset.battery, s.hasBattery,
        s.batteryDischarge > s.batteryCharge ? s.batteryDischarge : s.batteryCharge,
        _batteryColor);
    add(SceneAsset.heatPump, s.hasHeatPump, s.heatPump, _heatColor);
    add(SceneAsset.carCharger, s.hasCar, s.carCharging, _carColor);
    add(SceneAsset.home, true, s.houseLoad.abs(), _homeColor);
    return out;
  }
}

class _Overlay {
  const _Overlay(this.asset, this.desc, this.value, this.color);
  final SceneAsset asset;
  final String desc;
  final String value;
  final Color color;
}

/// Pastel-outlined pill: short description above the current value.
class _Pill extends StatelessWidget {
  const _Pill({required this.desc, required this.value, required this.color});
  final String desc;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC0E0E12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            desc.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WireframeHouse extends CustomPainter {
  _WireframeHouse({required this.color});
  final Color color;

  // House dimensions in scene units (centred on the origin footprint).
  static const _w = 2.0;  // half-width  (x)
  static const _d = 1.5;  // half-depth  (y)
  static const _h = 1.55; // wall height (z)
  static const _r = 1.5;  // roof rise   (z)

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 11;
    final hw = unit * 0.9, hh = unit * 0.5, hz = unit * 0.95;

    Offset raw(double x, double y, double z) =>
        Offset((x - y) * hw, (x + y) * hh - z * hz);

    final verts = [
      raw(_w, -_d, 0), raw(_w, _d, 0), raw(-_w, _d, 0),
      raw(_w, -_d, _h), raw(_w, _d, _h), raw(-_w, _d, _h),
      raw(-_w, 0, _h + _r), raw(_w, 0, _h + _r),
    ];
    var minX = verts.first.dx, maxX = minX, minY = verts.first.dy, maxY = minY;
    for (final v in verts) {
      minX = v.dx < minX ? v.dx : minX;
      maxX = v.dx > maxX ? v.dx : maxX;
      minY = v.dy < minY ? v.dy : minY;
      maxY = v.dy > maxY ? v.dy : maxY;
    }
    // Centre horizontally; centre vertically within the top band so the row of
    // badges below the house has room.
    const topBand = 0.72;
    final tx = (size.width - (maxX - minX)) / 2 - minX;
    final ty = (size.height * topBand - (maxY - minY)) / 2 - minY;
    Offset p(double x, double y, double z) => raw(x, y, z).translate(tx, ty);

    final b = p(_w, -_d, 0),  c = p(_w, _d, 0),  dd = p(-_w, _d, 0);
    final b2 = p(_w, -_d, _h), c2 = p(_w, _d, _h), d2 = p(-_w, _d, _h);
    final rL = p(-_w, 0, _h + _r), rR = p(_w, 0, _h + _r);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;

    Path poly(List<Offset> pts) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      return path..close();
    }

    canvas
      ..drawPath(poly([b, c, c2, b2]), stroke)
      ..drawPath(poly([c, dd, d2, c2]), stroke)
      ..drawPath(poly([d2, c2, rR, rL]), stroke)
      ..drawPath(poly([b2, c2, rR]), stroke)
      ..drawLine(rL, rR, stroke);

    Offset onSlope(double a, double t) => Offset.lerp(
          Offset.lerp(rL, rR, a)!,
          Offset.lerp(d2, c2, a)!,
          t,
        )!;

    final panel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = color;

    const a0 = 0.15, a1 = 0.85, t0 = 0.15, t1 = 0.85;
    canvas.drawPath(
      poly([onSlope(a0, t0), onSlope(a1, t0), onSlope(a1, t1), onSlope(a0, t1)]),
      panel,
    );
    for (var i = 1; i < 4; i++) {
      final a = a0 + (a1 - a0) * i / 4;
      canvas.drawLine(onSlope(a, t0), onSlope(a, t1), panel);
    }
    for (var i = 1; i < 3; i++) {
      final t = t0 + (t1 - t0) * i / 3;
      canvas.drawLine(onSlope(a0, t), onSlope(a1, t), panel);
    }
  }

  @override
  bool shouldRepaint(_WireframeHouse old) => old.color != color;
}
