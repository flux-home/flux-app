import 'package:flutter/foundation.dart' show immutable;

import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/room.dart';

/// One thing a group of devices can be asked to do together.
///
/// Deliberately coarse: these are the knobs that mean the same thing on every
/// device that has them, which is what makes them safe to move for a whole room
/// at once. Anything device-specific (a lock's PIN, a thermostat's mode) has no
/// group meaning and belongs on the device itself.
enum GroupControl { onOff, brightness, colorTemp }

/// A room's worth of devices, viewed as one thing.
///
/// This is the shim the room-level UI talks to instead of reaching into a list
/// of [DeviceView]s and working out what they have in common on the spot. It
/// answers two questions the widgets keep needing:
///
///  * *what can this room do* — [supports] / [isSharedBy] / [membersFor], and
///  * *what is it doing now* — [onCount], [brightness], [colorTempMireds].
///
/// Capability is read leniently, the same way DeviceProvider.toggle does it:
/// a declared device type OR a live attribute that has actually turned up. Some
/// real bulbs under-declare (an IKEA sensor that accepts On/Off), and a room
/// control that ignored the live evidence would refuse to drive lights the
/// device screen drives fine.
///
/// Nothing here is lighting-specific — Climate can group the same way once it
/// has group-shaped controls of its own.
@immutable
class DeviceGroup {
  const DeviceGroup({required this.room, required this.devices});

  final Room room;
  final List<DeviceView> devices;

  int  get count   => devices.length;
  bool get isEmpty => devices.isEmpty;

  /// Devices we can expect to reach right now. Group commands still go to
  /// everything that supports the control — a light that has just come back is
  /// better woken than skipped — but a room with nothing reachable has its
  /// controls disabled rather than silently doing nothing.
  List<DeviceView> get reachable =>
      [for (final d in devices) if (d.isOnline && !d.isStale) d];

  bool get isStale => reachable.isEmpty;

  /// The devices in this room that can take [c].
  List<DeviceView> membersFor(GroupControl c) =>
      [for (final d in devices) if (_can(d, c)) d];

  /// Whether anything here can take [c] at all.
  bool supports(GroupControl c) => membersFor(c).isNotEmpty;

  /// Whether *every* device here can take [c] — a true common denominator.
  /// When this is false the control still works, on the subset that has it,
  /// and the UI says so rather than pretending the room is uniform.
  bool isSharedBy(GroupControl c) => membersFor(c).length == count;

  // ── Current state ─────────────────────────────────────────────────────────

  int  get onCount => membersFor(GroupControl.onOff).where((d) => d.isOn).length;
  bool get anyOn   => onCount > 0;
  bool get allOn   => supports(GroupControl.onOff) &&
      onCount == membersFor(GroupControl.onOff).length;

  /// Mean brightness (0–1) over the devices that have actually reported a
  /// level, or null while none has. Reported levels only: [DeviceView.brightness]
  /// falls back to 1.0 when there is no level, which would drag the average of a
  /// dim room up towards full.
  double? get brightness {
    final levels = [
      for (final d in membersFor(GroupControl.brightness))
        if (d.live?.levelRaw != null) d.live!.levelRaw! / 254.0,
    ];
    if (levels.isEmpty) return null;
    return levels.reduce((a, b) => a + b) / levels.length;
  }

  /// Mean colour temperature in mireds over those that have reported one, or
  /// null while none has.
  int? get colorTempMireds {
    final mireds = [
      for (final d in membersFor(GroupControl.colorTemp))
        if (d.colorTempMireds != null) d.colorTempMireds!,
    ];
    if (mireds.isEmpty) return null;
    return (mireds.reduce((a, b) => a + b) / mireds.length).round();
  }

  static bool _can(DeviceView v, GroupControl c) {
    final attrs = v.live?.attrs ?? const <String, dynamic>{};
    return switch (c) {
      GroupControl.onOff =>
          v.deviceType.hasOnOff || attrs.containsKey('onOff'),
      GroupControl.brightness =>
          v.deviceType.hasBrightness || attrs.containsKey('level'),
      GroupControl.colorTemp =>
          v.deviceType.hasColorTemp || attrs.containsKey('colorTempMireds'),
    };
  }
}
