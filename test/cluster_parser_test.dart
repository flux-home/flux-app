import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/services/cluster_parser.dart';

void main() {
  group('parseClusters', () {
    test('returns empty list for null input', () {
      expect(parseClusters(null), isEmpty);
    });

    test('returns empty list for empty JSON array', () {
      expect(parseClusters('[]'), isEmpty);
    });

    test('parses a single cluster entry', () {
      const json = '''[{
        "endpoint": 1,
        "clusterId": 6,
        "attributes": [
          {"id": 0, "value": "true"}
        ]
      }]''';
      final endpoints = parseClusters(json);
      expect(endpoints, hasLength(1));
      expect(endpoints.first.endpoint, equals(1));
      expect(endpoints.first.clusters, hasLength(1));
      expect(endpoints.first.clusters.first.clusterId, equals(6));
    });

    test('strips global attributes (0xFFF8-0xFFFD except 0xFFF9)', () {
      const json = '''[{
        "endpoint": 0,
        "clusterId": 6,
        "attributes": [
          {"id": 65528, "value": "0"},
          {"id": 65530, "value": "0"},
          {"id": 65531, "value": "0"},
          {"id": 65533, "value": "0"},
          {"id": 0,     "value": "true"}
        ]
      }]''';
      final endpoints = parseClusters(json);
      final cluster = endpoints.first.clusters.first;
      // Only the non-global attr 0x0000 should remain (0xFFF9 is kept too but absent here)
      expect(cluster.attrs, hasLength(1));
      expect(cluster.attrs.first.id, equals(0));
    });

    test('sorts endpoints in ascending order', () {
      const json = '''[
        {"endpoint": 3, "clusterId": 6, "attributes": []},
        {"endpoint": 1, "clusterId": 6, "attributes": []},
        {"endpoint": 2, "clusterId": 6, "attributes": []}
      ]''';
      final endpoints = parseClusters(json);
      expect(endpoints.map((e) => e.endpoint).toList(), equals([1, 2, 3]));
    });
  });

  group('onOffClusterIsControllable', () {
    test('returns false when On/Off cluster absent', () {
      const json = '''[{"endpoint": 0, "clusterId": 8, "attributes": []}]''';
      final endpoints = parseClusters(json);
      expect(onOffClusterIsControllable(endpoints), isFalse);
    });

    test('returns false when AcceptedCommandList is empty', () {
      const json = '''[{
        "endpoint": 0,
        "clusterId": 6,
        "attributes": [{"id": 65529, "value": "[]"}]
      }]''';
      final endpoints = parseClusters(json);
      expect(onOffClusterIsControllable(endpoints), isFalse);
    });

    test('returns true when AcceptedCommandList has entries', () {
      const json = '''[{
        "endpoint": 0,
        "clusterId": 6,
        "attributes": [{"id": 65529, "value": "[0, 1, 2]"}]
      }]''';
      final endpoints = parseClusters(json);
      expect(onOffClusterIsControllable(endpoints), isTrue);
    });
  });

  group('extractReadings', () {
    test('returns empty list for empty endpoints', () {
      expect(extractReadings([], DeviceType.unknown), isEmpty);
    });

    test('skips On/Off cluster for device type that already has hasOnOff', () {
      const json = '''[{
        "endpoint": 1,
        "clusterId": 6,
        "attributes": [{"id": 0, "value": "true"}]
      }]''';
      final endpoints = parseClusters(json);
      // onOffLight has hasOnOff → should skip the 0x0006 reading
      final readings = extractReadings(endpoints, DeviceType.onOffLight);
      expect(readings.where((r) => r.label == 'Power'), isEmpty);
    });

    test('extracts On/Off as a reading for unknown device type', () {
      const json = '''[{
        "endpoint": 1,
        "clusterId": 6,
        "attributes": [{"id": 0, "value": "true"}]
      }]''';
      final endpoints = parseClusters(json);
      final readings = extractReadings(endpoints, DeviceType.unknown);
      expect(readings.any((r) => r.label == 'Power'), isTrue);
    });

    test('extracts temperature reading from cluster 0x0402', () {
      const json = '''[{
        "endpoint": 1,
        "clusterId": 1026,
        "attributes": [{"id": 0, "value": "2150"}]
      }]''';
      final endpoints = parseClusters(json);
      final readings = extractReadings(endpoints, DeviceType.temperatureSensor);
      expect(readings, hasLength(1));
      expect(readings.first.label, equals('Temperature'));
      expect(readings.first.displayValue, equals('21.5'));
      expect(readings.first.unit, equals('°C'));
    });

    test('returns null for temperature sentinel value -32768', () {
      const json = '''[{
        "endpoint": 1,
        "clusterId": 1026,
        "attributes": [{"id": 0, "value": "-32768"}]
      }]''';
      final endpoints = parseClusters(json);
      final readings = extractReadings(endpoints, DeviceType.temperatureSensor);
      expect(readings, isEmpty);
    });
  });

  group('PM2.5 quality thresholds (shared constants)', () {
    test('good quality below 12 µg/m³', () {
      const json = '''[{
        "endpoint": 1,
        "clusterId": 1066,
        "attributes": [{"id": 0, "value": "5.0"}]
      }]''';
      final endpoints = parseClusters(json);
      final r = extractReadings(endpoints, DeviceType.airQualitySensor).first;
      expect(r.quality, equals(ClusterQuality.good));
    });

    test('bad quality above 55.4 µg/m³', () {
      const json = '''[{
        "endpoint": 1,
        "clusterId": 1066,
        "attributes": [{"id": 0, "value": "100.0"}]
      }]''';
      final endpoints = parseClusters(json);
      final r = extractReadings(endpoints, DeviceType.airQualitySensor).first;
      expect(r.quality, equals(ClusterQuality.bad));
    });
  });

  group('qualityColor', () {
    testWidgets('returns distinct colors for each quality level', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      final good = qualityColor(ClusterQuality.good);
      final bad  = qualityColor(ClusterQuality.bad);
      expect(good, isNot(equals(bad)));
    });
  });
}
