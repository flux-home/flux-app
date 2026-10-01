import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/matter_device.dart';

import '../support/matter_fakes.dart';

void main() {
  MatterDevice battery() {
    final now = DateTime(2024);
    return MatterDevice(
      id: 'bat-1',
      name: 'Marstek Venus',
      deviceType: DeviceType.batteryStorage,
      nodeId: 0x1D,
      commissionedAt: now,
      lastModified: now,
      kind: DeviceKind.modbus,
      isOnline: true,
    );
  }

  test('powerAdjust routes to the device with its kind and endpoint', () async {
    final (provider, fake) = await buildProvider(devices: [battery()]);
    final ok = await provider.powerAdjust('bat-1',
        powerMw: -300000, duration: const Duration(minutes: 30));
    expect(ok, isTrue);
    expect(fake.powerAdjustCalls, hasLength(1));
    final c = fake.powerAdjustCalls.single;
    expect(c.nodeId, 0x1D);
    expect(c.powerMw, -300000);
    expect(c.duration, const Duration(minutes: 30));
    expect(c.kind, DeviceKind.modbus);
    expect(c.endpoint, 1);
  });

  test('cancelPowerAdjust routes to the device', () async {
    final (provider, fake) = await buildProvider(devices: [battery()]);
    expect(await provider.cancelPowerAdjust('bat-1'), isTrue);
    expect(fake.cancelPowerAdjustCalls.single.kind, DeviceKind.modbus);
  });

  test('unknown device id sends nothing', () async {
    final (provider, fake) = await buildProvider(devices: [battery()]);
    expect(await provider.powerAdjust('nope',
        powerMw: 1000, duration: const Duration(minutes: 5)), isFalse);
    expect(fake.powerAdjustCalls, isEmpty);
  });
}
