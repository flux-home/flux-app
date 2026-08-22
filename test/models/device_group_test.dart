import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/device_group.dart';
import 'package:matter_home/models/device_live_data.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/room.dart';

DeviceView _view({
  String id = 'dev-1',
  DeviceType type = DeviceType.dimmableLight,
  bool isOnline = true,
  bool isStale = false,
  Map<String, dynamic> attrs = const {},
}) {
  final now = DateTime(2024);
  return DeviceView(
    MatterDevice(
      id: id,
      name: id,
      deviceType: type,
      nodeId: 1000,
      commissionedAt: now,
      lastModified: now,
      managedBy: ManagedBy.controller,
      isOnline: isOnline,
    ),
    DeviceLiveData(attrs: attrs, isStale: isStale, updatedAt: now),
  );
}

const _room = Room(id: 3, name: 'Kitchen');

void main() {
  group('capabilities', () {
    test('a control every device has is shared', () {
      final g = DeviceGroup(room: _room, devices: [
        _view(id: 'a'),
        _view(id: 'b'),
      ]);
      expect(g.supports(GroupControl.brightness), isTrue);
      expect(g.isSharedBy(GroupControl.brightness), isTrue);
    });

    test('a control only some have is supported but not shared', () {
      final g = DeviceGroup(room: _room, devices: [
        _view(id: 'a'),
        _view(id: 'b', type: DeviceType.onOffLight),
      ]);
      expect(g.supports(GroupControl.brightness), isTrue);
      expect(g.isSharedBy(GroupControl.brightness), isFalse);
      expect(g.membersFor(GroupControl.brightness).single.id, 'a');
      // On/off is the one thing both have.
      expect(g.isSharedBy(GroupControl.onOff), isTrue);
    });

    test('a control nobody has is not offered', () {
      final g = DeviceGroup(room: _room, devices: [_view()]);
      expect(g.supports(GroupControl.colorTemp), isFalse);
    });

    test('a live attribute counts even when the type does not declare it', () {
      // The IKEA-style under-declaring device: reports as a sensor, accepts
      // On/Off, and the subscription has already proved it.
      final g = DeviceGroup(room: _room, devices: [
        _view(
          type: DeviceType.airQualitySensor,
          attrs: const {'onOff': true, 'colorTempMireds': 300},
        ),
      ]);
      expect(g.supports(GroupControl.onOff), isTrue);
      expect(g.supports(GroupControl.colorTemp), isTrue);
    });
  });

  group('state', () {
    test('counts only the devices that can be switched', () {
      final g = DeviceGroup(room: _room, devices: [
        _view(id: 'a', attrs: const {'onOff': true}),
        _view(id: 'b', attrs: const {'onOff': false}),
        _view(id: 'c', type: DeviceType.temperatureSensor),
      ]);
      expect(g.count, 3);
      expect(g.onCount, 1);
      expect(g.anyOn, isTrue);
      expect(g.allOn, isFalse);
      expect(g.membersFor(GroupControl.onOff).length, 2);
    });

    test('brightness averages only reported levels', () {
      final g = DeviceGroup(room: _room, devices: [
        _view(id: 'a', attrs: const {'level': 254}),
        _view(id: 'b', attrs: const {'level': 0}),
        _view(id: 'c'), // dimmable, nothing reported yet
      ]);
      // 1.0 and 0.0 → 0.5. Were 'c' counted as its 1.0 fallback it would be 0.67.
      expect(g.brightness, closeTo(0.5, 0.001));
    });

    test('brightness is null until something reports a level', () {
      expect(DeviceGroup(room: _room, devices: [_view()]).brightness, isNull);
    });

    test('colour temperature averages the reported mireds', () {
      final g = DeviceGroup(room: _room, devices: [
        _view(id: 'a', type: DeviceType.colorTemperatureLight,
            attrs: const {'colorTempMireds': 200}),
        _view(id: 'b', type: DeviceType.colorTemperatureLight,
            attrs: const {'colorTempMireds': 401}),
      ]);
      expect(g.colorTempMireds, 301); // rounded, not truncated
    });

    test('a room with nothing reachable is stale', () {
      final offline = DeviceGroup(room: _room, devices: [
        _view(id: 'a', isOnline: false),
        _view(id: 'b', isStale: true),
      ]);
      expect(offline.isStale, isTrue);

      final mixed = DeviceGroup(room: _room, devices: [
        _view(id: 'a', isOnline: false),
        _view(id: 'b'),
      ]);
      expect(mixed.isStale, isFalse);
      expect(mixed.reachable.single.id, 'b');
    });
  });
}
