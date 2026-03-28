import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/services/cluster_parser.dart';
import 'package:matter_home/services/matter_channel.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/ui/theme.dart';

void main() {
  testWidgets('App theme and channel smoke test', (tester) async {
    expect(buildAppTheme(), isA<ThemeData>());
    // MatterChannel implements MatterPort (all four sub-interfaces).
    final MatterPort channel = MatterChannel();
    expect(channel, isNotNull);
    expect(channel, isA<MatterSubscriptionPort>());
    expect(channel, isA<MatterCommissionPort>());
    expect(channel, isA<MatterClusterPort>());
    expect(channel, isA<MatterFabricPort>());
  });

  test('parseClusters returns empty list for null input', () {
    expect(parseClusters(null), isEmpty);
    expect(parseClusters('[]'), isEmpty);
  });

  test('extractReadings returns empty list for empty endpoints', () {
    expect(extractReadings([], DeviceType.unknown), isEmpty);
  });
}
