import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/services/matter_port.dart' show MatterClusterPort;

// ── Quality ───────────────────────────────────────────────────────────────────

enum ClusterQuality { good, moderate, poor, bad }

Color qualityColor(ClusterQuality q) => switch (q) {
  ClusterQuality.good     => Colors.green.shade500,
  ClusterQuality.moderate => Colors.amber.shade600,
  ClusterQuality.poor     => Colors.orange.shade600,
  ClusterQuality.bad      => Colors.red.shade600,
};

// ── Reading model ─────────────────────────────────────────────────────────────

class ClusterReading {

  const ClusterReading({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.displayValue,
    required this.unit,
    this.quality,
    this.subtitle,
    this.endpoint,
    this.group,
  });
  final IconData       icon;
  final Color          iconColor;
  final String         label;
  final String         displayValue;
  final String         unit;
  final ClusterQuality? quality;
  final String?        subtitle;
  /// Non-null only for Switch cluster (0x003B) entries — carries the endpoint
  /// so the switch card can build its per-control map.
  final int?           endpoint;
  /// Semantic group label (from tag ns=8, tag=6) — ties related switch
  /// endpoints (press / CW / CCW) into one virtual switch row.
  final String?        group;
}

// ── Parsed endpoint / cluster models ─────────────────────────────────────────

class LiveAttr {
  const LiveAttr({required this.id, required this.raw});
  final int    id;
  final String raw;
}

class LiveCluster {
  const LiveCluster({
    required this.endpoint,
    required this.clusterId,
    required this.attrs,
    this.deviceTypeIds,
  });
  final int            endpoint;
  final int            clusterId;
  final List<int>?     deviceTypeIds;
  final List<LiveAttr> attrs;
}

class SemanticTag {
  const SemanticTag(this.namespaceId, this.tag, this.label);
  final int     namespaceId;
  final int     tag;
  final String? label;
}

class LiveEndpoint {
  const LiveEndpoint({
    required this.endpoint,
    required this.deviceTypeIds,
    required this.clusters,
    this.semanticTags = const [],
  });
  final int               endpoint;
  final List<int>         deviceTypeIds;
  final List<LiveCluster> clusters;
  final List<SemanticTag> semanticTags;
}

// ── Public API ────────────────────────────────────────────────────────────────

/// A virtual switch group — one logical control on a multi-button device.
/// Each group has up to three sets of endpoints: press, clockwise, and
/// counter-clockwise, derived from semantic tags on the Switch cluster.
class SwitchGroup {
  const SwitchGroup({
    required this.label,
    required this.pressEndpoints,
    required this.cwEndpoints,
    required this.ccwEndpoints,
  });

  final String   label;
  final List<int> pressEndpoints;
  final List<int> cwEndpoints;
  final List<int> ccwEndpoints;

  List<int> get allEndpoints => [...pressEndpoints, ...cwEndpoints, ...ccwEndpoints];
}

/// Parses a raw Matter cluster JSON string (from [MatterClusterPort.readClusters])
/// into a structured list of [LiveEndpoint]s.
List<LiveEndpoint> parseClusters(String? jsonStr) {
  if (jsonStr == null || jsonStr == '[]') return [];
  final raw = json.decode(jsonStr) as List<dynamic>;
  final byEpCluster = <int, Map<int, LiveCluster>>{};
  for (final rawEntry in raw) {
    final entry = rawEntry as Map<String, dynamic>;
    final ep  = (entry['endpoint'] as num).toInt();
    final cid = (entry['clusterId'] as num).toInt();
    List<int>? deviceTypeIds;
    if (cid == 0x001D && entry['deviceTypes'] != null) {
      deviceTypeIds = (entry['deviceTypes'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList();
    }
    final attrs = <LiveAttr>[];
    for (final rawAttr in (entry['attributes'] as List<dynamic>)) {
      final a = rawAttr as Map<String, dynamic>;
      final attrId = (a['id'] as num).toInt();
      if (_kGlobalAttrIds.contains(attrId)) continue;
      attrs.add(LiveAttr(id: attrId, raw: a['value']?.toString() ?? 'null'));
    }
    byEpCluster.putIfAbsent(ep, () => {})[cid] = LiveCluster(
      endpoint: ep, clusterId: cid, attrs: attrs, deviceTypeIds: deviceTypeIds,
    );
  }
  return [
    for (final ep in (byEpCluster.keys.toList()..sort()))
      LiveEndpoint(
        endpoint:      ep,
        deviceTypeIds: byEpCluster[ep]![0x001D]?.deviceTypeIds ?? [],
        clusters:      (byEpCluster[ep]!.values.toList()
            ..sort((a, b) => a.clusterId.compareTo(b.clusterId))),
        semanticTags:  _parseSemanticTagsForEp(byEpCluster[ep]![0x001D]),
      ),
  ];
}

/// Derives live sensor readings directly from the subscription-driven
/// [DeviceView] cache.  Unlike [extractReadings], these update on every
/// subscription event without needing a fresh cluster-read.
///
/// Attributes not present in [_kLiveRenderers] (control attrs handled by
/// dedicated cards: onOff, level, colorTempMireds, …) are silently skipped —
/// no explicit exclusion list needed.
///
/// **To add a new sensor cluster:** add one entry to [_kLiveRenderers] and one
/// '_render*' function.  Nothing else needs to change anywhere in the Dart code.
List<ClusterReading> liveReadings(DeviceView view) {
  final live = view.live;
  if (live == null) return const [];
  return [
    for (final e in live.attrs.entries)
      _kLiveRenderers[e.key]?.call(e.value),
  ].whereType<ClusterReading>().toList();
}

/// Extracts [SwitchGroup]s from a list of [ClusterReading]s produced by
/// [extractReadings] or [liveReadings] for a switch device.
///
/// Groups are built from the [ClusterReading.group] field (semantic tag
/// ns=8, tag=6) and the icon is used to classify each endpoint as
/// press / CW / CCW — the same logic used by the switch card.
List<SwitchGroup> extractSwitchGroups(List<ClusterReading> readings) {
  final groups  = <String, _GroupBuilder>{};
  final order   = <String>[];

  for (final r in readings) {
    final ep    = r.endpoint;
    final label = r.group ?? (ep?.toString() ?? '');
    if (ep == null || label.isEmpty) continue;

    final builder = groups.putIfAbsent(label, () {
      order.add(label);
      return _GroupBuilder(label);
    });

    if (r.icon == Icons.rotate_right || r.icon == Icons.swipe_up_outlined) {
      builder.cw.add(ep);
    } else if (r.icon == Icons.rotate_left || r.icon == Icons.swipe_down_outlined) {
      builder.ccw.add(ep);
    } else {
      builder.press.add(ep);
    }
  }

  return [
    for (final label in order)
      SwitchGroup(
        label:          label,
        pressEndpoints: groups[label]!.press,
        cwEndpoints:    groups[label]!.cw,
        ccwEndpoints:   groups[label]!.ccw,
      ),
  ];
}

class _GroupBuilder {
  _GroupBuilder(this.label);
  final String   label;
  final List<int> press = [];
  final List<int> cw    = [];
  final List<int> ccw   = [];
}

// ── Live-reading registry ─────────────────────────────────────────────────────
//
// Maps subscription attribute keys to renderers.  Keys not listed here are
// silently ignored — control attributes (onOff, level, …) never show up in
// the readings grid without an explicit renderer entry.
// Insertion order = display order.

final _kLiveRenderers = <String, ClusterReading? Function(dynamic)>{
  'contactState':  _renderContact,
  'humidityCenti': _renderHumidity,
  'tempMeasureCenti': _renderTempMeasure,
  'occupancy':     _renderOccupancy,
  'airQuality':    _renderAirQuality,
  'pm25':          _renderPm25,
  'co2Ppm':        _renderCo2,
  'coPpm':         _renderCo,
  // Electrical Power Measurement (0x0090) and Energy Measurement (0x0091).
  // activePower in mW; voltage in mV; activeCurrent in mA; energy in Wh.
  'activePower':        _renderActivePower,
  'voltage':            _renderVoltage,
  'activeCurrent':      _renderActiveCurrent,
  'cumulativeEnergyWh': _renderCumulativeEnergy,
  // batPercentRaw / batChargeLevel intentionally omitted — battery is shown
  // in device settings (DeviceView.batteryInfo), not the readings grid.
};

// ── Per-attribute renderers ───────────────────────────────────────────────────

ClusterReading? _renderContact(dynamic v) {
  final closed = v as bool;
  return ClusterReading(
    icon:         closed ? Icons.sensor_door_outlined : Icons.meeting_room_outlined,
    iconColor:    closed ? Colors.green.shade500 : Colors.orange.shade500,
    label:        'Contact',
    displayValue: closed ? 'Closed' : 'Open',
    unit:         '',
  );
}

ClusterReading? _renderHumidity(dynamic v) => ClusterReading(
  icon:         Icons.water_drop_outlined,
  iconColor:    Colors.lightBlue.shade300,
  label:        'Humidity',
  displayValue: ((v as int) / 100.0).toStringAsFixed(1),
  unit:         '%',
);

ClusterReading? _renderTempMeasure(dynamic v) {
  final centi = v as int;
  if (centi == -32768) return null;
  return ClusterReading(
    icon:         Icons.thermostat_outlined,
    iconColor:    Colors.orange.shade300,
    label:        'Temperature',
    displayValue: (centi / 100.0).toStringAsFixed(1),
    unit:         '°C',
  );
}

ClusterReading? _renderOccupancy(dynamic v) {
  final occupied = ((v as int) & 0x01) == 1;
  return ClusterReading(
    icon:         occupied ? Icons.person : Icons.person_off_outlined,
    iconColor:    occupied ? Colors.indigo.shade400 : Colors.grey.shade400,
    label:        'Occupancy',
    displayValue: occupied ? 'Occupied' : 'Vacant',
    unit:         '',
  );
}

ClusterReading? _renderAirQuality(dynamic v) {
  final (label, color, quality) = switch (v as int) {
    1 => ('Good',       Colors.green.shade500,      ClusterQuality.good),
    2 => ('Fair',       Colors.lightGreen.shade400, ClusterQuality.moderate),
    3 => ('Moderate',   Colors.yellow.shade600,     ClusterQuality.moderate),
    4 => ('Poor',       Colors.orange.shade500,     ClusterQuality.bad),
    5 => ('Very Poor',  Colors.red.shade400,        ClusterQuality.bad),
    6 => ('X.Poor',     Colors.red.shade700,        ClusterQuality.bad),
    _ => ('Unknown',        Colors.grey.shade500,       null as ClusterQuality?),
  };
  return ClusterReading(
    icon:         Icons.air,
    iconColor:    color,
    label:        'Air Quality',
    displayValue: label,
    unit:         '',
    quality:      quality,
  );
}

ClusterReading? _renderPm25(dynamic v) {
  final val = (v as int) / 10.0;
  final q   = val <= 12   ? ClusterQuality.good
              : val <= 35.4 ? ClusterQuality.moderate
              : val <= 55.4 ? ClusterQuality.poor
              : ClusterQuality.bad;
  return ClusterReading(
    icon:         Icons.grain_outlined,
    iconColor:    qualityColor(q),
    label:        'PM2.5',
    displayValue: val < 10 ? val.toStringAsFixed(1) : val.toStringAsFixed(0),
    unit:         'µg/m³',
    quality:      q,
  );
}

ClusterReading? _renderCo2(dynamic v) {
  final ppm = v as int;
  final q   = ppm < 800  ? ClusterQuality.good
              : ppm < 1500 ? ClusterQuality.moderate
              : ppm < 2500 ? ClusterQuality.poor
              : ClusterQuality.bad;
  return ClusterReading(
    icon:         Icons.co2_outlined,
    iconColor:    qualityColor(q),
    label:        'CO₂',
    displayValue: '$ppm',
    unit:         'ppm',
    quality:      q,
    subtitle:     switch (q) {
      ClusterQuality.good     => 'Good',
      ClusterQuality.moderate => 'Elevated',
      ClusterQuality.poor     => 'High',
      ClusterQuality.bad      => 'Very high',
    },
  );
}

ClusterReading? _renderCo(dynamic v) {
  final val = (v as int) / 10.0;
  final q   = val < 9  ? ClusterQuality.good
              : val < 35 ? ClusterQuality.moderate
              : val < 70 ? ClusterQuality.poor
              : ClusterQuality.bad;
  return ClusterReading(
    icon:         Icons.warning_amber_outlined,
    iconColor:    qualityColor(q),
    label:        'Carbon Monoxide',
    displayValue: val < 10 ? val.toStringAsFixed(1) : val.toStringAsFixed(0),
    unit:         'ppm',
    quality:      q,
  );
}

ClusterReading? _renderActivePower(dynamic v) {
  final mw = v as int;
  final w  = mw / 1000.0;
  return ClusterReading(
    icon:         Icons.bolt_outlined,
    iconColor:    Colors.amber.shade600,
    label:        'Power',
    displayValue: w < 10 ? w.toStringAsFixed(1) : w.toStringAsFixed(0),
    unit:         'W',
  );
}

ClusterReading? _renderVoltage(dynamic v) {
  final mv = v as int;
  if (mv <= 0) return null;
  return ClusterReading(
    icon:         Icons.electrical_services_outlined,
    iconColor:    Colors.blue.shade400,
    label:        'Voltage',
    displayValue: (mv / 1000.0).toStringAsFixed(1),
    unit:         'V',
  );
}

ClusterReading? _renderActiveCurrent(dynamic v) {
  final ma   = v as int;
  final amps = ma / 1000.0;
  return ClusterReading(
    icon:         Icons.electric_bolt_outlined,
    iconColor:    Colors.orange.shade400,
    label:        'Current',
    displayValue: amps < 10 ? amps.toStringAsFixed(2) : amps.toStringAsFixed(1),
    unit:         'A',
  );
}

ClusterReading? _renderCumulativeEnergy(dynamic v) {
  final wh = v as int;
  final (display, unit) = wh >= 1000
      ? ((wh / 1000.0).toStringAsFixed(2), 'kWh')
      : ('$wh', 'Wh');
  return ClusterReading(
    icon:         Icons.energy_savings_leaf_outlined,
    iconColor:    Colors.green.shade500,
    label:        'Energy',
    displayValue: display,
    unit:         unit,
  );
}

// ignore: unused_element
ClusterReading? _renderBatteryRaw(dynamic v) {
  final pct = (v as int) ~/ 2; // batPercentRaw is 0–200; half = percent
  final q   = pct > 60 ? ClusterQuality.good
              : pct > 20 ? ClusterQuality.moderate
              : ClusterQuality.bad;
  return ClusterReading(
    icon:         q == ClusterQuality.bad  ? Icons.battery_alert
                : q == ClusterQuality.good ? Icons.battery_full
                : Icons.battery_3_bar,
    iconColor:    qualityColor(q),
    label:        'Battery',
    displayValue: '$pct',
    unit:         '%',
    quality:      q,
  );
}

// ignore: unused_element
ClusterReading? _renderBatteryLvl(dynamic v) {
  final lvl = v as int;
  final q   = switch (lvl) {
    0 => ClusterQuality.good, 1 => ClusterQuality.moderate, _ => ClusterQuality.bad
  };
  return ClusterReading(
    icon:         q == ClusterQuality.bad  ? Icons.battery_alert
                : q == ClusterQuality.good ? Icons.battery_full
                : Icons.battery_3_bar,
    iconColor:    qualityColor(q),
    label:        'Battery',
    displayValue: switch (lvl) { 0 => 'OK', 1 => 'Warning', 2 => 'Critical', _ => '?' },
    unit:         '',
    quality:      q,
  );
}

/// Returns true if any endpoint in [endpoints] exposes the On/Off cluster
/// (0x0006) with a non-empty AcceptedCommandList (attr 0xFFF9).
///
/// This is the Matter-specified way to distinguish a *controllable* On/Off
/// cluster (device accepts On / Off / Toggle commands) from a cluster that
/// is only present for state reporting.  Devices like the IKEA APLSTUGA
/// carry device-type IDs that do not map to [DeviceType.hasOnOff], but their
/// AcceptedCommandList proves they are genuinely switchable.
bool onOffClusterIsControllable(List<LiveEndpoint> endpoints) {
  for (final ep in endpoints) {
    for (final cluster in ep.clusters) {
      if (cluster.clusterId != 0x0006) continue;
      final cmdAttr = cluster.attrs.where((a) => a.id == 0xFFF9).firstOrNull;
      if (cmdAttr == null) continue;
      if (_parseCommandList(cmdAttr.raw).isNotEmpty) return true;
    }
  }
  return false;
}

/// Parses a Kotlin / Java [List.toString] like `"[0, 1, 2]"` into integers.
List<int> _parseCommandList(String raw) =>
    RegExp(r'\d+').allMatches(raw)
        .map((m) => int.tryParse(m.group(0)!))
        .whereType<int>()
        .toList();

/// Converts [LiveEndpoint] list into display-ready [ClusterReading]s for [deviceType].
List<ClusterReading> extractReadings(
    List<LiveEndpoint> endpoints, DeviceType deviceType) {
  final out = <ClusterReading>[];
  for (final ep in endpoints) {
    for (final cluster in ep.clusters) {
      final r = _readingFromCluster(cluster, deviceType, ep.semanticTags);
      if (r != null) out.add(r);
    }
  }
  return out;
}

// ── Private helpers ───────────────────────────────────────────────────────────

// Global attributes stripped from LiveCluster.attrs during parsing.
// 0xFFF9 (AcceptedCommandList) is intentionally kept so that
// onOffClusterIsControllable() can inspect it.
const _kGlobalAttrIds = {0xFFF8, 0xFFFA, 0xFFFB, 0xFFFC, 0xFFFD};

List<SemanticTag> _parseSemanticTagsForEp(LiveCluster? descriptor) {
  if (descriptor == null) return const [];
  final tagListAttr = descriptor.attrs.where((a) => a.id == 0x0004).firstOrNull;
  if (tagListAttr == null || tagListAttr.raw == 'null' || tagListAttr.raw == '[]') {
    return const [];
  }
  return _parseSemanticTags(tagListAttr.raw);
}

List<SemanticTag> _parseSemanticTags(String raw) {
  final result = <SemanticTag>[];
  final re = RegExp(
    r'namespaceID:\s*(\d+)\s+tag:\s*(\d+)\s+label:\s*Optional(?:\[([^\]]*)\]|\.empty)',
  );
  for (final m in re.allMatches(raw)) {
    final ns    = int.tryParse(m.group(1) ?? '');
    final tag   = int.tryParse(m.group(2) ?? '');
    final label = m.group(3);
    if (ns != null && tag != null) result.add(SemanticTag(ns, tag, label));
  }
  return result;
}

ClusterReading? _readingFromCluster(
    LiveCluster cluster, DeviceType deviceType,
    [List<SemanticTag> tags = const []]) {
  String? raw(int attrId) => cluster.attrs
      .where((a) => a.id == attrId)
      .map((a) => a.raw)
      .firstOrNull;

  switch (cluster.clusterId) {

    // ── Temperature Measurement 0x0402 ──────────────────────────────────────
    case 0x0402:
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null || v == -32768) return null;
      final c = v / 100.0;
      return ClusterReading(
        icon: Icons.device_thermostat_outlined,
        iconColor: c > 28 ? Colors.red.shade400
                 : c < 10 ? Colors.lightBlue.shade400
                 : Colors.orange.shade400,
        label: 'Temperature',
        displayValue: c.toStringAsFixed(1),
        unit: '°C',
      );

    // ── Relative Humidity 0x0405 ────────────────────────────────────────────
    case 0x0405:
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null || v == 0xFFFF) return null;
      final pct = v / 100.0;
      final q = pct < 25 || pct > 75 ? ClusterQuality.poor
               : pct < 35 || pct > 65 ? ClusterQuality.moderate
               : ClusterQuality.good;
      return ClusterReading(
        icon: Icons.water_drop_outlined,
        iconColor: Colors.lightBlue.shade400,
        label: 'Humidity',
        displayValue: pct.toStringAsFixed(1),
        unit: '%',
        quality: q,
      );

    // ── PM2.5 Concentration 0x042A ──────────────────────────────────────────
    case 0x042A:
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v.isInfinite || v < 0) return null;
      final q = v <= 12   ? ClusterQuality.good
               : v <= 35.4 ? ClusterQuality.moderate
               : v <= 55.4 ? ClusterQuality.poor
               : ClusterQuality.bad;
      return ClusterReading(
        icon: Icons.grain_outlined,
        iconColor: qualityColor(q),
        label: 'PM2.5',
        displayValue: v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0),
        unit: 'µg/m³',
        quality: q,
      );

    // ── CO2 Concentration 0x040D ────────────────────────────────────────────
    case 0x040D:
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v < 800  ? ClusterQuality.good
               : v < 1500 ? ClusterQuality.moderate
               : v < 2500 ? ClusterQuality.poor
               : ClusterQuality.bad;
      return ClusterReading(
        icon: Icons.co2_outlined,
        iconColor: qualityColor(q),
        label: 'CO₂',
        displayValue: v.toStringAsFixed(0),
        unit: 'ppm',
        quality: q,
        subtitle: switch (q) {
          ClusterQuality.good     => 'Good',
          ClusterQuality.moderate => 'Elevated',
          ClusterQuality.poor     => 'High',
          ClusterQuality.bad      => 'Very high',
        },
      );

    // ── CO Concentration 0x040C ─────────────────────────────────────────────
    case 0x040C:
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v < 9  ? ClusterQuality.good
               : v < 35 ? ClusterQuality.moderate
               : v < 70 ? ClusterQuality.poor
               : ClusterQuality.bad;
      return ClusterReading(
        icon: Icons.warning_amber_outlined,
        iconColor: qualityColor(q),
        label: 'Carbon Monoxide',
        displayValue: v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0),
        unit: 'ppm',
        quality: q,
      );

    // ── Illuminance Measurement 0x0400 ──────────────────────────────────────
    case 0x0400:
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null || v == 0 || v == 0xFFFF) return null;
      final lux = math.pow(10.0, (v - 1) / 10000.0);
      final display = lux < 10    ? lux.toStringAsFixed(1)
                    : lux < 1000  ? lux.toStringAsFixed(0)
                    : '${(lux / 1000).toStringAsFixed(1)} k';
      return ClusterReading(
        icon: Icons.light_mode_outlined,
        iconColor: Colors.amber.shade500,
        label: 'Illuminance',
        displayValue: display,
        unit: 'lux',
      );

    // ── Pressure Measurement 0x0403 ─────────────────────────────────────────
    case 0x0403:
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null || v == -32768) return null;
      return ClusterReading(
        icon: Icons.compress_outlined,
        iconColor: Colors.teal.shade400,
        label: 'Pressure',
        displayValue: v.toStringAsFixed(0),
        unit: 'hPa',
      );

    // ── Flow Measurement 0x0404 ─────────────────────────────────────────────
    case 0x0404:
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null || v == 0xFFFF) return null;
      return ClusterReading(
        icon: Icons.water_outlined,
        iconColor: Colors.blue.shade400,
        label: 'Flow',
        displayValue: (v / 10.0).toStringAsFixed(1),
        unit: 'm³/h',
      );

    // ── Occupancy Sensing 0x0406 ────────────────────────────────────────────
    case 0x0406:
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null) return null;
      final occupied = (v & 0x01) == 1;
      return ClusterReading(
        icon: occupied ? Icons.person : Icons.person_off_outlined,
        iconColor: occupied ? Colors.indigo.shade400 : Colors.grey.shade400,
        label: 'Occupancy',
        displayValue: occupied ? 'Occupied' : 'Vacant',
        unit: '',
      );

    // ── Boolean State 0x0045 (contact sensor) ───────────────────────────────
    case 0x0045:
      final v = raw(0x0000);
      if (v == null) return null;
      final closed = v == 'true';
      return ClusterReading(
        icon: closed ? Icons.sensor_door_outlined : Icons.meeting_room_outlined,
        iconColor: closed ? Colors.green.shade500 : Colors.orange.shade500,
        label: 'Contact',
        displayValue: closed ? 'Closed' : 'Open',
        unit: '',
      );

    // ── Power Source 0x002F (battery) — shown in device settings, not the grid
    case 0x002F:
      return null;

    // ── Switch 0x003B ────────────────────────────────────────────────────────
    case 0x003B: {
      final current = int.tryParse(raw(0x0001) ?? '');
      if (current == null) return null;
      final active  = current > 0;

      final groupLabel = tags
          .where((t) => t.namespaceId == 8 && t.tag == 6)
          .map((t) => t.label)
          .firstOrNull ?? '${cluster.endpoint}';

      final isButton = tags.any((t) => t.namespaceId == 67 && t.tag == 8 && t.label == 'button');
      final isCW     = tags.any((t) => t.namespaceId == 67 && t.tag == 3);
      final isCCW    = tags.any((t) => t.namespaceId == 67 && t.tag == 4);
      final isUp     = tags.any((t) => t.namespaceId == 67 && t.tag == 2);
      final isDown   = tags.any((t) => t.namespaceId == 67 && t.tag == 1);

      final IconData icon;
      final String   label;
      if (isCW) {
        icon = Icons.rotate_right; label = 'Ring $groupLabel →';
      } else if (isCCW) {
        icon = Icons.rotate_left; label = 'Ring $groupLabel ←';
      } else if (isButton) {
        icon  = active ? Icons.radio_button_checked : Icons.radio_button_unchecked;
        label = 'Button $groupLabel';
      } else if (isUp) {
        icon = Icons.swipe_up_outlined; label = 'Switch $groupLabel ↑';
      } else if (isDown) {
        icon = Icons.swipe_down_outlined; label = 'Switch $groupLabel ↓';
      } else {
        icon  = Icons.smart_button_outlined;
        label = tags.isEmpty ? 'Switch' : 'Switch $groupLabel';
      }
      return ClusterReading(
        icon:         icon,
        iconColor:    active ? Colors.green.shade400 : Colors.grey.shade500,
        label:        label,
        displayValue: '$current',
        unit:         '',
        endpoint:     cluster.endpoint,
        group:        groupLabel,
      );
    }

    // ── On/Off 0x0006 — dedicated _OnOffCard handles it; skip from grid ───────
    case 0x0006:
      if (deviceType.hasOnOff) return null;
      final v = raw(0x0000);
      if (v == null) return null;
      final isOn = v == 'true';
      return ClusterReading(
        icon: isOn ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
        iconColor: isOn ? Colors.green.shade400 : Colors.grey.shade500,
        label: 'Power',
        displayValue: isOn ? 'On' : 'Off',
        unit: '',
      );

    // ── Level Control 0x0008 — dedicated _BrightnessCard; skip from grid ─────
    case 0x0008:
      if (deviceType.hasBrightness) return null;
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null) return null;
      final pct = (v / 254.0 * 100).round();
      return ClusterReading(
        icon: Icons.brightness_6_outlined,
        iconColor: Colors.amber.shade400,
        label: 'Level',
        displayValue: pct.toString(),
        unit: '%',
      );

    // ── Air Quality 0x005B ──────────────────────────────────────────────────
    case 0x005B:
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null || v == 0) return null;
      const labels = {1:'Good', 2:'Fair', 3:'Moderate', 4:'Poor', 5:'Very Poor', 6:'X.Poor'};
      final label = labels[v]; if (label == null) return null;
      final q = switch (v) {
        1      => ClusterQuality.good,
        2 || 3 => ClusterQuality.moderate,
        4      => ClusterQuality.poor,
        _      => ClusterQuality.bad,
      };
      return ClusterReading(
        icon: Icons.air_outlined, iconColor: qualityColor(q),
        label: 'Air Quality', displayValue: label, unit: '', quality: q,
      );

    // ── Smoke CO Alarm 0x005C ───────────────────────────────────────────────
    case 0x005C: {
      final smoke = int.tryParse(raw(0x0001) ?? '');
      final co    = int.tryParse(raw(0x0002) ?? '');
      final bat   = int.tryParse(raw(0x0003) ?? '');
      // Represent the worst active state; skip if all normal/unknown
      final worst = [smoke, co, bat].whereType<int>().fold(0, math.max);
      if (worst == 0 && smoke != null) return null; // all normal — no tile needed
      final q = switch (worst) {
        2      => ClusterQuality.bad,
        1      => ClusterQuality.poor,
        _      => ClusterQuality.good,
      };
      final desc = smoke != null && smoke > 0 ? 'Smoke'
                 : co    != null && co    > 0 ? 'CO'
                 : bat   != null && bat   > 0 ? 'Battery' : 'OK';
      return ClusterReading(
        icon: worst > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
        iconColor: qualityColor(q),
        label: 'Alarm', displayValue: desc, unit: '', quality: q,
      );
    }

    // ── Thermostat 0x0201 — setpoint tile for non-thermostat endpoints ──────
    case 0x0201:
      if (deviceType == DeviceType.thermostat) return null;
      final setpt = int.tryParse(raw(0x0012) ?? '');
      if (setpt == null || setpt == -32768) return null;
      return ClusterReading(
        icon: Icons.thermostat,
        iconColor: Colors.orange.shade400,
        label: 'Setpoint',
        displayValue: (setpt / 100.0).toStringAsFixed(1),
        unit: '°C',
      );

    // ── Window Covering 0x0102 — skip dedicated card device types ──────────
    case 0x0102:
      if (deviceType == DeviceType.windowCovering) return null;
      final lift = int.tryParse(raw(0x000E) ?? '');
      if (lift == null) return null;
      final pct = (lift / 100).round();
      return ClusterReading(
        icon: Icons.blinds_outlined,
        iconColor: Colors.blueGrey.shade400,
        label: 'Position',
        displayValue: pct.toString(),
        unit: '%',
      );

    // ── Fan Control 0x0202 — skip dedicated card device types ──────────────
    case 0x0202:
      if (deviceType == DeviceType.fan || deviceType == DeviceType.airPurifier) return null;
      final mode = int.tryParse(raw(0x0000) ?? '');
      if (mode == null) return null;
      const modeLabels = {0:'Off', 1:'Low', 2:'Med', 3:'High', 4:'On', 5:'Auto', 6:'Smart'};
      return ClusterReading(
        icon: Icons.wind_power_outlined,
        iconColor: Colors.lightBlue.shade400,
        label: 'Fan',
        displayValue: modeLabels[mode] ?? '$mode',
        unit: '',
      );

    // ── Color Control 0x0300 — skip dedicated card device types ────────────
    case 0x0300:
      if (deviceType == DeviceType.colorTemperatureLight ||
          deviceType == DeviceType.extendedColorLight) {
        return null;
      }
      final ct = int.tryParse(raw(0x0007) ?? '');
      if (ct == null || ct == 0) return null;
      final k = (1_000_000 / ct).round();
      return ClusterReading(
        icon: Icons.wb_sunny_outlined,
        iconColor: Colors.amber.shade400,
        label: 'Color Temp',
        displayValue: '$k',
        unit: 'K',
      );

    // ── Electrical Power Measurement 0x0090 ──────────────────────────────────
    // ActivePower (0x0006) is a nullable int64 in mW — serialised as a bare
    // number by the cluster inspector so int.tryParse works directly.
    // Voltage and current are shown via live-subscription renderers; only
    // power is shown in the static grid to keep the cluster-read tile minimal.
    case 0x0090: {
      final mw = int.tryParse(raw(0x0006) ?? '');
      if (mw == null) return null;
      final w = mw / 1000.0;
      return ClusterReading(
        icon:         Icons.bolt_outlined,
        iconColor:    Colors.amber.shade600,
        label:        'Power',
        displayValue: w < 10 ? w.toStringAsFixed(1) : w.toStringAsFixed(0),
        unit:         'W',
      );
    }

    // ── Electrical Energy Measurement 0x0091 ──────────────────────────────────
    // CumulativeEnergyImported (0x0001) is an EnergyMeasurementStruct; the
    // cluster inspector serialises it via the SDK struct’s toString(), which
    // is not a parseable number.  Energy is shown only via the live
    // subscription renderer (_renderCumulativeEnergy).
    case 0x0091:
      return null;

    // ── Nitrogen Dioxide 0x0413 ─────────────────────────────────────────────
    case 0x0413: {
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v < 10  ? ClusterQuality.good
               : v < 25  ? ClusterQuality.moderate
               : v < 50  ? ClusterQuality.poor
               : ClusterQuality.bad;
      return ClusterReading(
        icon: Icons.air_outlined, iconColor: qualityColor(q),
        label: 'NO₂', displayValue: v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0),
        unit: 'µg/m³', quality: q,
      );
    }

    // ── Ozone 0x0415 ────────────────────────────────────────────────────────
    case 0x0415: {
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v < 50  ? ClusterQuality.good
               : v < 100 ? ClusterQuality.moderate
               : v < 150 ? ClusterQuality.poor
               : ClusterQuality.bad;
      return ClusterReading(
        icon: Icons.air_outlined, iconColor: qualityColor(q),
        label: 'Ozone', displayValue: v.toStringAsFixed(0), unit: 'µg/m³', quality: q,
      );
    }

    // ── Formaldehyde 0x042B ─────────────────────────────────────────────────
    case 0x042B: {
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v < 100 ? ClusterQuality.good
               : v < 300 ? ClusterQuality.moderate
               : v < 500 ? ClusterQuality.poor
               : ClusterQuality.bad;
      return ClusterReading(
        icon: Icons.science_outlined, iconColor: qualityColor(q),
        label: 'HCHO', displayValue: v.toStringAsFixed(0), unit: 'µg/m³', quality: q,
      );
    }

    // ── PM1 0x042C ──────────────────────────────────────────────────────────
    case 0x042C: {
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v <= 12   ? ClusterQuality.good
               : v <= 35.4 ? ClusterQuality.moderate
               : v <= 55.4 ? ClusterQuality.poor
               : ClusterQuality.bad;
      return ClusterReading(
        icon: Icons.grain_outlined, iconColor: qualityColor(q),
        label: 'PM1', displayValue: v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0),
        unit: 'µg/m³', quality: q,
      );
    }

    // ── PM10 0x042D ─────────────────────────────────────────────────────────
    case 0x042D: {
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v < 50  ? ClusterQuality.good
               : v < 100 ? ClusterQuality.moderate
               : v < 250 ? ClusterQuality.poor
               : ClusterQuality.bad;
      return ClusterReading(
        icon: Icons.grain_outlined, iconColor: qualityColor(q),
        label: 'PM10', displayValue: v.toStringAsFixed(0), unit: 'µg/m³', quality: q,
      );
    }

    // ── TVOC 0x042E ─────────────────────────────────────────────────────────
    case 0x042E: {
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v < 300  ? ClusterQuality.good
               : v < 1000 ? ClusterQuality.moderate
               : v < 3000 ? ClusterQuality.poor
               : ClusterQuality.bad;
      return ClusterReading(
        icon: Icons.science_outlined, iconColor: qualityColor(q),
        label: 'TVOC', displayValue: v.toStringAsFixed(0), unit: 'µg/m³', quality: q,
      );
    }

    // ── Radon 0x042F ────────────────────────────────────────────────────────
    case 0x042F: {
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v < 100  ? ClusterQuality.good
               : v < 300  ? ClusterQuality.moderate
               : v < 1000 ? ClusterQuality.poor
               : ClusterQuality.bad;
      return ClusterReading(
        icon: Icons.radio_outlined, iconColor: qualityColor(q),
        label: 'Radon', displayValue: v.toStringAsFixed(0), unit: 'Bq/m³', quality: q,
      );
    }

    default: return null;
  }
}
