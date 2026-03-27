part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reading data model
// ─────────────────────────────────────────────────────────────────────────────

enum _Quality { good, moderate, poor, bad }

Color _qualityColor(_Quality q) => switch (q) {
  _Quality.good     => Colors.green.shade500,
  _Quality.moderate => Colors.amber.shade600,
  _Quality.poor     => Colors.orange.shade600,
  _Quality.bad      => Colors.red.shade600,
};

class _Reading {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   displayValue;
  final String   unit;
  final _Quality? quality;      // null = no quality indicator
  final String?  subtitle;

  const _Reading({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.displayValue,
    required this.unit,
    this.quality,
    this.subtitle,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Reading extraction from live cluster data
// ─────────────────────────────────────────────────────────────────────────────

List<_Reading> _extractReadings(
    List<_LiveEndpoint> endpoints, DeviceType deviceType) {
  final out = <_Reading>[];
  for (final ep in endpoints) {
    for (final cluster in ep.clusters) {
      final r = _readingFromCluster(cluster, deviceType, ep.semanticTags);
      if (r != null) out.add(r);
    }
  }
  return out;
}

_Reading? _readingFromCluster(
    _LiveCluster cluster, DeviceType deviceType,
    [List<_SemanticTag> tags = const []]) {
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
      return _Reading(
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
      if (deviceType == DeviceType.thermostat) return null; // shown in dial card
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null || v == 0xFFFF) return null;
      final pct = v / 100.0;
      final q = pct < 25 || pct > 75 ? _Quality.poor
               : pct < 35 || pct > 65 ? _Quality.moderate
               : _Quality.good;
      return _Reading(
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
      final q = v <= 12   ? _Quality.good
               : v <= 35.4 ? _Quality.moderate
               : v <= 55.4 ? _Quality.poor
               : _Quality.bad;
      return _Reading(
        icon: Icons.grain_outlined,
        iconColor: _qualityColor(q),
        label: 'PM2.5',
        displayValue: v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0),
        unit: 'µg/m³',
        quality: q,
      );

    // ── CO2 Concentration 0x040D ────────────────────────────────────────────
    case 0x040D:
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v < 800  ? _Quality.good
               : v < 1500 ? _Quality.moderate
               : v < 2500 ? _Quality.poor
               : _Quality.bad;
      return _Reading(
        icon: Icons.co2_outlined,
        iconColor: _qualityColor(q),
        label: 'CO₂',
        displayValue: v.toStringAsFixed(0),
        unit: 'ppm',
        quality: q,
        subtitle: switch (q) {
          _Quality.good     => 'Good',
          _Quality.moderate => 'Elevated',
          _Quality.poor     => 'High',
          _Quality.bad      => 'Very high',
        },
      );

    // ── CO Concentration 0x040C ─────────────────────────────────────────────
    case 0x040C:
      final v = double.tryParse(raw(0x0000) ?? '');
      if (v == null || v.isNaN || v < 0) return null;
      final q = v < 9  ? _Quality.good
               : v < 35 ? _Quality.moderate
               : v < 70 ? _Quality.poor
               : _Quality.bad;
      return _Reading(
        icon: Icons.warning_amber_outlined,
        iconColor: _qualityColor(q),
        label: 'Carbon Monoxide',
        displayValue: v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0),
        unit: 'ppm',
        quality: q,
      );

    // ── Illuminance Measurement 0x0400 ──────────────────────────────────────
    case 0x0400:
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null || v == 0 || v == 0xFFFF) return null;
      // Matter spec: lux = 10^((value − 1) / 10 000)
      final lux = math.pow(10.0, (v - 1) / 10000.0);
      final display = lux < 10    ? lux.toStringAsFixed(1)
                    : lux < 1000  ? lux.toStringAsFixed(0)
                    : '${(lux / 1000).toStringAsFixed(1)} k';
      return _Reading(
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
      // Matter spec unit: 0.1 kPa → ÷10 = kPa, ×10 = hPa. Since 1 kPa = 10 hPa:
      // value / 10 kPa → value × 1 hPa
      return _Reading(
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
      return _Reading(
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
      return _Reading(
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
      // StateValue = true means "contact" / "closed" per the spec
      final closed = v == 'true';
      return _Reading(
        icon: closed ? Icons.sensor_door_outlined : Icons.meeting_room_outlined,
        iconColor: closed ? Colors.green.shade500 : Colors.orange.shade500,
        label: 'Contact',
        displayValue: closed ? 'Closed' : 'Open',
        unit: '',
      );

    // ── Power Source 0x002F (battery) ───────────────────────────────────────
    case 0x002F:
      if (deviceType == DeviceType.thermostat) return null; // shown in thermostat card
      // BatPercentRemaining attr 0x000C: raw 0–200, divide by 2 for %
      final pctRaw  = int.tryParse(raw(0x000C) ?? '');
      final lvlRaw  = int.tryParse(raw(0x000E) ?? '');
      final voltRaw = int.tryParse(raw(0x000B) ?? '');
      if (pctRaw == null && lvlRaw == null && voltRaw == null) return null;

      String display;
      String unit;
      _Quality? q;
      Color color;
      if (pctRaw != null) {
        final pct = pctRaw ~/ 2;
        display = '$pct';
        unit    = '%';
        q = pct > 60 ? _Quality.good : pct > 20 ? _Quality.moderate : _Quality.bad;
        color = _qualityColor(q);
      } else if (lvlRaw != null) {
        display = switch (lvlRaw) { 0 => 'OK', 1 => 'Warning', 2 => 'Critical', _ => '?' };
        unit    = '';
        q = switch (lvlRaw) { 0 => _Quality.good, 1 => _Quality.moderate, _ => _Quality.bad };
        color = _qualityColor(q);
      } else {
        display = (voltRaw! / 1000.0).toStringAsFixed(2);
        unit    = 'V';
        color   = Colors.green.shade500;
      }
      final icon = q == _Quality.bad ? Icons.battery_alert
                 : q == _Quality.good ? Icons.battery_full
                 : Icons.battery_3_bar;
      return _Reading(
        icon: icon, iconColor: color,
        label: 'Battery', displayValue: display, unit: unit, quality: q,
      );

    // ── Switch 0x003B ────────────────────────────────────────────────────────
    case 0x003B: {
      final current = int.tryParse(raw(0x0001) ?? '');
      if (current == null) return null;
      final active  = current > 0;

      // ── Derive label and icon from SemanticTags ────────────────────────────
      //
      // Namespace 8  tag 6  label=N  → group / ring index N
      // Namespace 67 tag 1           → Down
      // Namespace 67 tag 2           → Up
      // Namespace 67 tag 3           → Clockwise
      // Namespace 67 tag 4           → CounterClockwise
      // Namespace 67 tag 8  label=t  → control kind ("rotary" or "button")

      final groupLabel = tags
          .where((t) => t.namespaceId == 8 && t.tag == 6)
          .map((t) => t.label)
          .firstOrNull ?? '${cluster.endpoint}';

      final isButton  = tags.any((t) => t.namespaceId == 67 && t.tag == 8 && t.label == 'button');
      final isCW      = tags.any((t) => t.namespaceId == 67 && t.tag == 3);
      final isCCW     = tags.any((t) => t.namespaceId == 67 && t.tag == 4);
      final isUp      = tags.any((t) => t.namespaceId == 67 && t.tag == 2);
      final isDown    = tags.any((t) => t.namespaceId == 67 && t.tag == 1);

      final IconData  icon;
      final String    label;

      if (isCW) {
        icon  = Icons.rotate_right;
        label = 'Ring $groupLabel →';
      } else if (isCCW) {
        icon  = Icons.rotate_left;
        label = 'Ring $groupLabel ←';
      } else if (isButton) {
        icon  = active ? Icons.radio_button_checked : Icons.radio_button_unchecked;
        label = 'Button $groupLabel';
      } else if (isUp) {
        icon  = Icons.swipe_up_outlined;
        label = 'Switch $groupLabel ↑';
      } else if (isDown) {
        icon  = Icons.swipe_down_outlined;
        label = 'Switch $groupLabel ↓';
      } else {
        icon  = Icons.smart_button_outlined;
        label = tags.isEmpty ? 'Switch' : 'Switch $groupLabel';
      }

      return _Reading(
        icon:         icon,
        iconColor:    active ? Colors.green.shade400 : Colors.grey.shade500,
        label:        label,
        // Numeric string → _ReadingCard renders it through DotMatrixPainter
        displayValue: '$current',
        unit:         '',
      );
    }

    // ── On/Off 0x0006 — handled by dedicated _OnOffCard; skip from grid ───────
    case 0x0006:
      if (deviceType.hasOnOff) return null;
      final v = raw(0x0000);
      if (v == null) return null;
      final isOn = v == 'true';
      return _Reading(
        icon: isOn ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
        iconColor: isOn ? Colors.green.shade400 : Colors.grey.shade500,
        label: 'Power',
        displayValue: isOn ? 'On' : 'Off',
        unit: '',
      );

    // ── Level Control 0x0008 — handled by _BrightnessCard; skip from grid ────
    case 0x0008:
      if (deviceType.hasBrightness) return null;
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null) return null;
      final pct = (v / 254.0 * 100).round();
      return _Reading(
        icon: Icons.brightness_6_outlined,
        iconColor: Colors.amber.shade400,
        label: 'Level',
        displayValue: pct.toString(),
        unit: '%',
      );

    // ── Air Quality 0x005B ──────────────────────────────────────────────────
    case 0x005B:
      final v = int.tryParse(raw(0x0000) ?? '');
      if (v == null || v == 0) return null; // 0 = Unknown
      const labels = {1:'Good', 2:'Fair', 3:'Moderate', 4:'Poor', 5:'Very Poor', 6:'Extremely Poor'};
      final label  = labels[v]; if (label == null) return null;
      final q = switch (v) {
        1      => _Quality.good,
        2 || 3 => _Quality.moderate,
        4      => _Quality.poor,
        _      => _Quality.bad,
      };
      return _Reading(
        icon: Icons.air_outlined, iconColor: _qualityColor(q),
        label: 'Air Quality', displayValue: label, unit: '', quality: q,
      );

    default: return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal data models (for cluster loading)
// ─────────────────────────────────────────────────────────────────────────────

const _kGlobalAttrIds = {0xFFF8, 0xFFF9, 0xFFFA, 0xFFFB, 0xFFFC, 0xFFFD};

class _LiveAttr {
  final int    id;
  final String raw;
  const _LiveAttr({required this.id, required this.raw});
}

class _LiveCluster {
  final int           endpoint;
  final int           clusterId;
  final List<int>?    deviceTypeIds;
  final List<_LiveAttr> attrs;
  const _LiveCluster({required this.endpoint, required this.clusterId,
                      required this.attrs, this.deviceTypeIds});
}

/// A parsed SemanticTag entry from the Descriptor cluster's TagList (attr 0x0004).
class _SemanticTag {
  final int     namespaceId;
  final int     tag;
  final String? label;   // null when the TLV Optional was absent ("Optional.empty")
  const _SemanticTag(this.namespaceId, this.tag, this.label);
}

class _LiveEndpoint {
  final int                endpoint;
  final List<int>          deviceTypeIds;
  final List<_LiveCluster> clusters;
  /// SemanticTags from the Descriptor cluster's TagList attribute, parsed once
  /// during [_parseClusters]. Empty list when none are present.
  final List<_SemanticTag> semanticTags;
  const _LiveEndpoint({
    required this.endpoint,
    required this.deviceTypeIds,
    required this.clusters,
    this.semanticTags = const [],
  });
}


// ─────────────────────────────────────────────────────────────────────────────
// JSON → live endpoint model
// ─────────────────────────────────────────────────────────────────────────────

List<_LiveEndpoint> _parseClusters(String? jsonStr) {
  if (jsonStr == null || jsonStr == '[]') return [];
  final raw = json.decode(jsonStr) as List<dynamic>;
  final Map<int, Map<int, _LiveCluster>> byEpCluster = {};
  for (final entry in raw) {
    final ep  = (entry['endpoint'] as num).toInt();
    final cid = (entry['clusterId'] as num).toInt();
    List<int>? deviceTypeIds;
    if (cid == 0x001D && entry['deviceTypes'] != null) {
      deviceTypeIds = (entry['deviceTypes'] as List<dynamic>)
          .map((e) => (e as num).toInt()).toList();
    }
    final attrs = <_LiveAttr>[];
    for (final a in (entry['attributes'] as List<dynamic>)) {
      final attrId = (a['id'] as num).toInt();
      if (_kGlobalAttrIds.contains(attrId)) continue;
      attrs.add(_LiveAttr(id: attrId, raw: a['value']?.toString() ?? 'null'));
    }
    byEpCluster.putIfAbsent(ep, () => {})[cid] =
        _LiveCluster(endpoint: ep, clusterId: cid, attrs: attrs,
                     deviceTypeIds: deviceTypeIds);
  }
  return [
    for (final ep in (byEpCluster.keys.toList()..sort()))
      _LiveEndpoint(
        endpoint:      ep,
        deviceTypeIds: byEpCluster[ep]![0x001D]?.deviceTypeIds ?? [],
        clusters:      (byEpCluster[ep]!.values.toList()
            ..sort((a, b) => a.clusterId.compareTo(b.clusterId))),
        semanticTags:  _parseSemanticTagsForEp(byEpCluster[ep]![0x001D]),
      ),
  ];
}

List<_SemanticTag> _parseSemanticTagsForEp(_LiveCluster? descriptor) {
  if (descriptor == null) return const [];
  final tagListAttr = descriptor.attrs.where((a) => a.id == 0x0004).firstOrNull;
  if (tagListAttr == null || tagListAttr.raw == 'null' || tagListAttr.raw == '[]') {
    return const [];
  }
  return _parseSemanticTags(tagListAttr.raw);
}

/// Parses the Java toString() representation of a List<SemanticTagStruct>.
List<_SemanticTag> _parseSemanticTags(String raw) {
  final result = <_SemanticTag>[];
  final re = RegExp(
    r'namespaceID:\s*(\d+)\s+tag:\s*(\d+)\s+label:\s*Optional(?:\[([^\]]*)\]|\.empty)',
  );
  for (final m in re.allMatches(raw)) {
    final ns    = int.tryParse(m.group(1) ?? '');
    final tag   = int.tryParse(m.group(2) ?? '');
    final label = m.group(3);
    if (ns != null && tag != null) result.add(_SemanticTag(ns, tag, label));
  }
  return result;
}
