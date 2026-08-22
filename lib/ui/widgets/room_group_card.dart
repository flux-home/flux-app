import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:matter_home/models/device_group.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:provider/provider.dart';

/// The room's controls, above its devices.
///
/// Shows only what the room actually has in common: the switch appears when
/// something can be switched, the sliders when something can be dimmed or
/// warmed. A control that only part of the room supports still appears — it
/// would be worse to hide dimming because one bulb in the room is on/off only —
/// but it says how many devices it moves, so nothing changes silently.
///
/// Everything here goes through [DeviceGroup], so this widget never works out
/// capabilities itself, and Climate can reuse it once it has group controls.
class RoomGroupCard extends StatefulWidget {
  const RoomGroupCard({
    required this.group,
    this.accent,
    this.onTap,
    this.showName = true,
    super.key,
  });

  final DeviceGroup group;

  /// Opens the room. When set, the name and summary become the tap target —
  /// the switch and sliders keep their own gestures, so the row acts like a
  /// list entry without swallowing the controls.
  final VoidCallback? onTap;

  /// Whether to print the room's name. Off inside the room itself, where the
  /// app bar already says where you are.
  final bool showName;

  /// Category accent, used for the switch and slider so the room controls read
  /// as part of the section rather than as another device.
  final Color? accent;

  @override
  State<RoomGroupCard> createState() => _RoomGroupCardState();
}

class _RoomGroupCardState extends State<RoomGroupCard> {
  // Practical range, matching the device screen: 153 mireds (6500 K) – 500 (2000 K).
  static const _minMireds = 153.0;
  static const _maxMireds = 500.0;

  // While a finger is down the slider follows the finger, not the devices: the
  // group's mean only catches up after the writes land and would otherwise
  // yank the thumb back mid-drag.
  double? _dragBrightness;
  double? _dragMireds;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = widget.group;
    final accent = widget.accent ?? cs.primary;
    final provider = context.read<DeviceProvider>();
    final enabled = !g.isStale;

    final hasOnOff = g.supports(GroupControl.onOff);
    final hasDim   = g.supports(GroupControl.brightness);
    final hasTemp  = g.supports(GroupControl.colorTemp);
    if (!hasOnOff && !hasDim && !hasTemp) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.showName)
                                  Text(g.room.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                Text(_summary(g),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          if (widget.onTap != null)
                            Icon(Icons.chevron_right,
                                size: 20, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasOnOff)
                  Switch(
                    value: g.anyOn,
                    activeThumbColor: accent,
                    onChanged: enabled
                        ? (on) => unawaited(provider.groupSetOn(
                            [for (final d in g.membersFor(GroupControl.onOff)) d.id],
                            on))
                        : null,
                  ),
              ],
            ),
            if (hasDim)
              _ControlRow(
                icon: Icons.brightness_6_outlined,
                accent: accent,
                // Nothing has reported a level yet: park the thumb mid-scale
                // rather than at 0, which would read as "the room is off".
                value: _dragBrightness ?? g.brightness ?? 0.5,
                min: 0,
                max: 1,
                trailing: '${(((_dragBrightness ?? g.brightness) ?? 0) * 100).round()}%',
                subject: g.isSharedBy(GroupControl.brightness)
                    ? null
                    : '${g.membersFor(GroupControl.brightness).length} of ${g.count}',
                enabled: enabled,
                onChanged: (v) => setState(() => _dragBrightness = v),
                onChangeEnd: (v) {
                  setState(() => _dragBrightness = null);
                  unawaited(provider.groupSetBrightness(
                      [for (final d in g.membersFor(GroupControl.brightness)) d.id],
                      v));
                },
              ),
            if (hasTemp)
              _ControlRow(
                icon: Icons.wb_sunny_outlined,
                accent: accent,
                value: _dragMireds ??
                    (g.colorTempMireds?.toDouble().clamp(_minMireds, _maxMireds) ??
                        (_minMireds + _maxMireds) / 2),
                min: _minMireds,
                max: _maxMireds,
                trailing: _kelvin(_dragMireds ?? g.colorTempMireds?.toDouble()),
                subject: g.isSharedBy(GroupControl.colorTemp)
                    ? null
                    : '${g.membersFor(GroupControl.colorTemp).length} of ${g.count}',
                enabled: enabled,
                onChanged: (v) => setState(() => _dragMireds = v),
                onChangeEnd: (v) {
                  setState(() => _dragMireds = null);
                  unawaited(provider.groupSetColorTemperature(
                      [for (final d in g.membersFor(GroupControl.colorTemp)) d.id],
                      v.round()));
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _summary(DeviceGroup g) {
    final n = g.count;
    final unit = n == 1 ? 'device' : 'devices';
    if (g.isStale) return '$n $unit · offline';
    if (!g.supports(GroupControl.onOff)) return '$n $unit';
    return '${g.onCount} of ${g.membersFor(GroupControl.onOff).length} on';
  }

  static String _kelvin(double? mireds) =>
      mireds == null ? '--' : '${(1000000 / mireds).round()}K';
}

/// One group slider: icon, track, and a value on the right, with the "n of m"
/// note underneath when the control does not cover the whole room.
class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.accent,
    required this.value,
    required this.min,
    required this.max,
    required this.trailing,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
    this.subject,
  });

  final IconData icon;
  final Color    accent;
  final double   value;
  final double   min;
  final double   max;
  final String   trailing;
  final String?  subject;
  final bool     enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17,
                color: enabled ? cs.onSurfaceVariant : cs.onSurfaceVariant.withAlpha(90)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accent,
                  trackHeight: 3,
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: enabled ? onChanged : null,
                  onChangeEnd: enabled ? onChangeEnd : null,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(trailing,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ),
          ],
        ),
        if (subject != null)
          Padding(
            padding: const EdgeInsets.only(left: 25, bottom: 4),
            child: Text('applies to $subject',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ),
      ],
    );
  }
}
