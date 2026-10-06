import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import 'package:provider/provider.dart';


import 'package:matter_home/models/energy_role.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;
import 'package:matter_home/services/proto/flux.pbenum.dart' as $enum;
import 'package:matter_home/ui/screens/settings/grid_settings_screen.dart';
import 'package:matter_home/utils/power_format.dart';

/// What the system is doing right now, and roughly what is left of today.
///
/// The automation is allowed to limit the roof and command the battery without
/// being asked. That is only acceptable if it says so in words, where the
/// energy is, rather than in a log nobody opens — a system that silently does
/// the right thing is indistinguishable from a broken one until the bill
/// arrives.
///
/// Two things, deliberately separated:
///
///   * the HEADLINE is the present tense — one sentence naming what is being
///     limited or stored and why;
///   * the LIST is the rest of today — when the roof is forecast to make more
///     than the grid will accept, and what will happen to the difference.
///
/// Everything here is derived from what the controller already publishes: the
/// inverter's own DEM hold says what it is limited to, the battery's charge
/// level says whether there is anywhere to put surplus, and the solar forecast
/// says when the two will matter. The only figure the app cannot learn is the
/// export cap, which comes from the grid operator and is asked for once.
class TodayPlanCard extends StatefulWidget {
  const TodayPlanCard({super.key});

  @override
  State<TodayPlanCard> createState() => _TodayPlanCardState();
}

class _TodayPlanCardState extends State<TodayPlanCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<DeviceProvider>();
      p
        ..fetchEnergyLimits()
        ..fetchEnergyControl()
        ..fetchEnergyEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DeviceProvider>();
    final cs = Theme.of(context).colorScheme;
    // The controller owns the limit — it is what enforces it. This card reads
    // the cached copy and never invents one, so a house with no limit set shows
    // what it is doing without claiming to know what it is allowed to do.
    final limits = p.energyLimits;
    final cap = (limits != null && limits.enabled && limits.exportLimitW > 0)
        ? limits.exportLimitW
        : null;

    final plan = _Plan.from(p, cap);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Today', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            _Headline(plan: plan),
            if (plan.because != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 17),
                child: Text(plan.because!,
                    style: TextStyle(
                        fontSize: 13, height: 1.3, color: cs.onSurfaceVariant)),
              ),
            ],
            if (plan.events.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final e in plan.events) _EventRow(event: e),
            ],
            if (p.energyEvents.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _Divider(),
              const SizedBox(height: 10),
              for (final e in p.energyEvents.reversed.take(6))
                _LogRow(event: e, devices: p.deviceViews),
            ],
            if (cap == null) ...[
              const SizedBox(height: 12),
              const _NoLimitSet(),
            ],
          ],
        ),
      ),
    );
  }
}

// ── the model ───────────────────────────────────────────────────────────────

enum _Tone { ok, holding, warn }

class _Event {
  const _Event(this.when, this.text, this.tone);
  final String when;
  final String text;
  final _Tone tone;
}

/// A reading of the present and a rough outline of what is left of today.
///
/// Rough on purpose. The point is to set an expectation ("around midday the
/// roof will make more than the grid takes, and it will go into the battery"),
/// not to promise a schedule the weather can falsify by lunchtime.
class _Plan {
  const _Plan({
    required this.headline,
    required this.because,
    required this.tone,
    required this.events,
  });

  final String headline;
  final String? because;
  final _Tone tone;
  final List<_Event> events;

  factory _Plan.from(DeviceProvider p, int? cap) {
    final s = p.energySummary;

    // The inverter's own hold is the authority on whether it is being limited:
    // the controller publishes the setpoint it asserted, so there is no need to
    // infer a limit from the power curve.
    int? pvLimitW;
    for (final d in p.deviceViews) {
      if (d.energyRole != EnergyRole.pv) continue;
      final a = d.live?.powerAdjust;
      if (a != null && a.isActive && a.activePowerMw != null) {
        pvLimitW = (a.activePowerMw!.abs() / 1000).round();
        break;
      }
    }

    final batteries = s.batteries;
    final full = batteries.isNotEmpty &&
        batteries.every((b) => (b.socPercent ?? 0) >= 97);
    final anyCharging = batteries.any((b) => b.netW > 50);

    // Facts first. The engine's own words come after the numbers, because the
    // numbers are what a glance is for and the sentence is what a second look
    // is for.
    final parts = <String>[];
    if (s.pvProduction > 20) {
      parts.add('Roof ${powerLabelW(s.pvProduction)}');
    }
    if (s.gridExport > 20) {
      parts.add('exporting ${powerLabelW(s.gridExport)}');
    } else if (s.gridImport > 20) {
      parts.add('importing ${powerLabelW(s.gridImport)}');
    }
    if (s.batteryCharge > 20) {
      parts.add('battery +${powerLabelW(s.batteryCharge)}');
    } else if (s.batteryDischarge > 20) {
      parts.add('battery −${powerLabelW(s.batteryDischarge)}');
    }
    parts.add('house ${powerLabelW(s.homeExcludingAssets + s.heatPump + s.carCharging)}');

    final headline = parts.join(' · ');

    final _Tone tone;
    if (pvLimitW != null && full) {
      tone = _Tone.warn;
    } else if (pvLimitW != null) {
      tone = _Tone.holding;
    } else {
      tone = _Tone.ok;
    }

    final String? because;
    if (pvLimitW != null && full) {
      because = 'Roof capped at ${powerLabelW(pvLimitW.toDouble())} — '
          'battery full, so the rest is left on the roof.';
    } else if (pvLimitW != null && anyCharging) {
      because = 'Roof capped at ${powerLabelW(pvLimitW.toDouble())} — '
          'the extra is going into the battery.';
    } else if (pvLimitW != null) {
      because = 'Roof capped at ${powerLabelW(pvLimitW.toDouble())} '
          'to stay under the feed-in limit.';
    } else {
      because = null;
    }

    return _Plan(
      headline: headline,
      because: because,
      tone: tone,
      events: _outlook(p, cap, full),
    );
  }

  /// When the roof is forecast to beat the cap, and what becomes of the excess.
  static List<_Event> _outlook(DeviceProvider p, int? cap, bool batteriesFull) {
    final f = p.solarForecast;
    if (f == null || f.isEmpty || cap == null) return const [];

    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59);
    final perHour = 3600 / f.resolution.inSeconds;

    DateTime? from;
    DateTime? to;
    var excessWh = 0.0;
    var remainingWh = 0.0;

    for (var i = 0; i < f.wattHours.length; i++) {
      final t = f.timeAt(i);
      if (t.isBefore(now) || t.isAfter(endOfDay)) continue;
      final w = f.wattHours[i] * perHour;      // interval Wh -> average W
      remainingWh += f.wattHours[i];
      if (w <= cap) continue;
      from ??= t;
      to = t.add(f.resolution);
      excessWh += (w - cap) / perHour;
    }

    final out = <_Event>[];

    if (remainingWh > 100) {
      out.add(_Event(
        _clock(now),
        '${(remainingWh / 1000).toStringAsFixed(1)} kWh still forecast from '
        'the roof before dark.',
        _Tone.ok,
      ));
    }

    if (from == null || to == null || excessWh < 100) {
      if (remainingWh > 100) {
        out.add(_Event('—',
            'None of it is expected to beat the '
            '${powerLabelW(cap.toDouble())} limit, so nothing should need '
            'holding back.',
            _Tone.ok));
      }
      return out;
    }

    out.add(_Event(
      '${_clock(from)}–${_clock(to)}',
      'The roof should make more than the grid will take — about '
      '${(excessWh / 1000).toStringAsFixed(1)} kWh above the limit.',
      _Tone.holding,
    ));

    out.add(_Event(
      '—',
      batteriesFull
          ? 'The battery is full, so that is likely to be left on the roof '
            'rather than stored.'
          : 'That should go into the battery instead of being thrown away.',
      batteriesFull ? _Tone.warn : _Tone.ok,
    ));

    return out;
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── pieces ──────────────────────────────────────────────────────────────────

Color _toneColor(BuildContext c, _Tone t) => switch (t) {
      _Tone.ok => Theme.of(c).colorScheme.primary,
      _Tone.holding => const Color(0xFFE8C14A),
      _Tone.warn => const Color(0xFFE0894A),
    };

class _Headline extends StatelessWidget {
  const _Headline({required this.plan});
  final _Plan plan;

  @override
  Widget build(BuildContext context) {
    final c = _toneColor(context, plan.tone);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8, height: 8,
          margin: const EdgeInsets.only(top: 6, right: 9),
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        Expanded(
          child: Text(plan.headline,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    height: 1.35, fontWeight: FontWeight.w500,
                  )),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final _Event event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(event.when,
                style: TextStyle(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 12.5,
                  color: cs.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: Text(event.text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: event.tone == _Tone.ok
                      ? cs.onSurfaceVariant
                      : _toneColor(context, event.tone),
                )),
          ),
        ],
      ),
    );
  }
}

/// The limit lives in Settings → Energy setup → Energy Management, because the
/// controller owns it. Asking for it here would create a second copy of a value
/// that is only meaningful in one place.
class _NoLimitSet extends StatelessWidget {
  const _NoLimitSet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No feed-in limit set, so nothing is being held back.',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const GridSettingsScreen()),
          ),
          child: const Text('Set it'),
        ),
      ],
    );
  }
}


class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(
      height: 1, color: Theme.of(context).colorScheme.outlineVariant);
}

/// One decision, in the past tense.
///
/// The controller stores what happened and to which device; the sentence is
/// built here, so the wording can improve without a firmware flash. Anything
/// automatic that spends money or throws energy away earns a line — that is the
/// difference between a system that is trusted and one that is merely obeyed.
class _LogRow extends StatelessWidget {
  const _LogRow({required this.event, required this.devices});

  final $proto.EnergyEvent event;
  final List<DeviceView> devices;

  String _name(Int64 nodeId) {
    if (nodeId.toInt() == 0) return 'the house';
    for (final d in devices) {
      if (d.nodeId == nodeId.toInt()) return d.name;
    }
    return 'a device';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = event.valueW.abs();
    final name = _name(event.nodeId);

    final String text;
    switch (event.kind) {
      case $enum.EnergyEventKind.ENERGY_EVENT_LIMIT_APPLIED:
        text = 'Capped $name at ${powerLabelW(w.toDouble())} — the roof was '
            'making more than the grid will take.';
      case $enum.EnergyEventKind.ENERGY_EVENT_LIMIT_RAISED:
        text = 'Raised $name to ${powerLabelW(w.toDouble())} — more room to '
            'store.';
      case $enum.EnergyEventKind.ENERGY_EVENT_LIMIT_CLEARED:
        text = 'Stopped capping $name.';
      case $enum.EnergyEventKind.ENERGY_EVENT_ABSORB_START:
        text = 'Started charging $name at ${powerLabelW(w.toDouble())} — '
            'surplus the grid would not take.';
      case $enum.EnergyEventKind.ENERGY_EVENT_ABSORB_STOP:
        text = 'Stopped charging $name — no surplus left.';
      case $enum.EnergyEventKind.ENERGY_EVENT_BATTERY_FULL:
        text = '$name full — surplus is being left on the roof.';
      case $enum.EnergyEventKind.ENERGY_EVENT_BATTERY_STALL:
        text = '$name is not taking the setpoints it accepts.';
      case $enum.EnergyEventKind.ENERGY_EVENT_METER_LOST:
        text = 'Lost the meter — fell back to the safe limit.';
      case $enum.EnergyEventKind.ENERGY_EVENT_METER_OK:
        text = 'Measuring at ${_name(event.nodeId)} again.';
      case $enum.EnergyEventKind.ENERGY_EVENT_CONFIG_SET:
        text = 'Feed-in limit set to ${powerLabelW(w.toDouble())}.';
      case $enum.EnergyEventKind.ENERGY_EVENT_HOUSE_ON_SOLAR:
        text = 'House running on the roof.';
      case $enum.EnergyEventKind.ENERGY_EVENT_HOUSE_ON_BATTERY:
        text = 'House running on the battery, not the grid.';
      case $enum.EnergyEventKind.ENERGY_EVENT_HOUSE_ON_GRID:
        text = 'House back on the grid.';
      default:
        return const SizedBox.shrink();
    }

    final at = event.at.toInt();
    final clock = at == 0
        ? '--:--'
        : () {
            final t = DateTime.fromMillisecondsSinceEpoch(at * 1000).toLocal();
            return '${t.hour.toString().padLeft(2, '0')}:'
                '${t.minute.toString().padLeft(2, '0')}';
          }();

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(clock,
                style: TextStyle(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 12.5,
                  color: cs.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, height: 1.3, color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
