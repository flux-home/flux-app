import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/power_adjust.dart';

/// Live attributes as the controller publishes them for a Marstek Venus E.
Map<String, dynamic> _marstek({int state = 1, int? power, int? remaining}) => {
      'esaFeatureMap': 1,
      'esaType': 5,
      'esaCanGenerate': true,
      'powerAdjMinPower': -2500000,
      'powerAdjMaxPower': 2500000,
      'powerAdjMaxDuration': 14400,
      'esaState': state,
      if (power != null) 'powerAdjPower': power,
      if (remaining != null) 'powerAdjRemaining': remaining,
    };

void main() {
  group('PowerAdjust.fromAttrs', () {
    test('reads capability and idle state', () {
      final a = PowerAdjust.fromAttrs(_marstek())!;
      expect(a.minPowerMw, -2500000);
      expect(a.maxPowerMw, 2500000);
      expect(a.maxDuration, const Duration(hours: 4));
      expect(a.isActive, isFalse);
      expect(a.canCharge, isTrue);
      expect(a.canDischarge, isTrue);
      expect(a.activePowerMw, isNull);
    });

    test('reads a running hold', () {
      final a = PowerAdjust.fromAttrs(
          _marstek(state: 3, power: -300000, remaining: 95))!;
      expect(a.isActive, isTrue);
      expect(a.activePowerMw, -300000);
      expect(a.remaining, const Duration(seconds: 95));
    });

    test('ignores hold details while not active', () {
      final a = PowerAdjust.fromAttrs(_marstek(power: 0, remaining: 0))!;
      expect(a.activePowerMw, isNull);
      expect(a.remaining, isNull);
    });

    test('null without the PowerAdjustment feature bit', () {
      expect(PowerAdjust.fromAttrs({..._marstek(), 'esaFeatureMap': 0x2}), isNull);
      expect(PowerAdjust.fromAttrs({'activePower': 1000}), isNull);
    });

    test('a Matter battery without the capability struct falls back to AbsMin/Max', () {
      final a = PowerAdjust.fromAttrs({
        'esaFeatureMap': 0x1,
        'esaState': 1,
        'absMinPower': -5000000,
        'absMaxPower': 3000000,
      })!;
      expect(a.minPowerMw, -5000000);
      expect(a.maxPowerMw, 3000000);
      expect(a.maxDuration, PowerAdjust.fallbackMaxDuration);
    });

    test('null when no usable range is known', () {
      expect(PowerAdjust.fromAttrs({'esaFeatureMap': 1, 'esaState': 1}), isNull);
      expect(
          PowerAdjust.fromAttrs({
            'esaFeatureMap': 1,
            'powerAdjMinPower': 0,
            'powerAdjMaxPower': 0,
          }),
          isNull);
    });

    test('charge-only device', () {
      final a = PowerAdjust.fromAttrs({
        'esaFeatureMap': 1,
        'powerAdjMinPower': 0,
        'powerAdjMaxPower': 11000000,
      })!;
      expect(a.canCharge, isTrue);
      expect(a.canDischarge, isFalse);
    });
  });

  test('clampPowerMw keeps setpoints in range', () {
    final a = PowerAdjust.fromAttrs(_marstek())!;
    expect(a.clampPowerMw(9000000), 2500000);
    expect(a.clampPowerMw(-9000000), -2500000);
    expect(a.clampPowerMw(300000), 300000);
  });

  test('durationChoices stop at the device maximum', () {
    final a = PowerAdjust.fromAttrs({..._marstek(), 'powerAdjMaxDuration': 3600})!;
    expect(a.durationChoices().last, const Duration(hours: 1));
    final tiny = PowerAdjust.fromAttrs({..._marstek(), 'powerAdjMaxDuration': 300})!;
    expect(tiny.durationChoices(), [const Duration(minutes: 5)]);
  });

  test('Battery Storage device type (0x0018) is an energy device', () {
    final t = DeviceType.fromMatterDeviceTypeId(0x0018);
    expect(t, DeviceType.batteryStorage);
    expect(t.hasEnergyMeasurement, isTrue);
  });
}
