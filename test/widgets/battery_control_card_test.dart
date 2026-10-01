import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/power_adjust.dart';
import 'package:matter_home/ui/screens/device_detail_screen.dart';

PowerAdjust _adjust({int state = 1, int? power, int? remaining}) =>
    PowerAdjust.fromAttrs({
      'esaFeatureMap': 1,
      'powerAdjMinPower': -2500000,
      'powerAdjMaxPower': 2500000,
      'powerAdjMaxDuration': 14400,
      'esaState': state,
      if (power != null) 'powerAdjPower': power,
      if (remaining != null) 'powerAdjRemaining': remaining,
    })!;

void main() {
  late List<(int, Duration)> starts;
  late int cancels;

  Widget host(PowerAdjust a, {bool enabled = true}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BatteryControlCard(
              adjust: a,
              enabled: enabled,
              onStart: (mw, d) async {
                starts.add((mw, d));
                return true;
              },
              onCancel: () async {
                cancels++;
                return true;
              },
            ),
          ),
        ),
      );

  setUp(() {
    starts = [];
    cancels = 0;
  });

  testWidgets('idle: start charging sends a positive setpoint', (tester) async {
    await tester.pumpWidget(host(_adjust()));
    expect(find.text('Auto'), findsOneWidget);
    await tester.tap(find.text('Start charging'));
    await tester.pump();
    expect(starts, [(500000, const Duration(hours: 1))]);
    expect(find.text('Sending…'), findsOneWidget);
    // Let the "device didn't confirm" timer fire so no timer is left pending.
    await tester.pump(const Duration(seconds: 21));
  });

  testWidgets('discharge sends a negative setpoint for the chosen time', (tester) async {
    await tester.pumpWidget(host(_adjust()));
    await tester.tap(find.text('Discharge'));
    await tester.pump();
    await tester.tap(find.text('30 min'));
    await tester.pump();
    await tester.tap(find.text('Start discharging'));
    await tester.pump();
    expect(starts, [(-500000, const Duration(minutes: 30))]);
    await tester.pump(const Duration(seconds: 21));
  });

  testWidgets('active hold shows what it does and can return to auto', (tester) async {
    await tester.pumpWidget(host(_adjust(state: 3, power: -300000, remaining: 600)));
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Discharging at 300 W'), findsOneWidget);
    expect(find.text('10 min left, then back to auto'), findsOneWidget);
    expect(find.text('Start discharging'), findsNothing);
    await tester.tap(find.text('Return to auto'));
    await tester.pump();
    expect(cancels, 1);
  });

  testWidgets('disabled while the device is stale', (tester) async {
    await tester.pumpWidget(host(_adjust(), enabled: false));
    await tester.tap(find.text('Start charging'));
    await tester.pump();
    expect(starts, isEmpty);
  });
}
