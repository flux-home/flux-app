import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_live_data.dart';
import '../../models/device_type.dart';
import '../../models/matter_device.dart';
import '../../providers/device_provider.dart';
import '../../services/matter_channel.dart';
import '../widgets/dot_matrix_painter.dart';
import 'device_settings_screen.dart';

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
      final r = _readingFromCluster(cluster, deviceType);
      if (r != null) out.add(r);
    }
  }
  return out;
}

_Reading? _readingFromCluster(_LiveCluster cluster, DeviceType deviceType) {
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
      final positions = int.tryParse(raw(0x0000) ?? '');
      final current   = int.tryParse(raw(0x0001) ?? '');
      if (current == null) return null;
      final label = (positions != null && positions > 2)
          ? 'Position $current'
          : current == 0 ? 'Released' : 'Pressed';
      return _Reading(
        icon: Icons.smart_button_outlined,
        iconColor: current == 0 ? Colors.grey.shade500 : Colors.green.shade400,
        label: 'Switch',
        displayValue: label,
        unit: '',
      );
    }

    // ── On/Off 0x0006 ───────────────────────────────────────────────────────
    case 0x0006: {
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
    }

    // ── Level Control 0x0008 ─────────────────────────────────────────────────
    case 0x0008: {
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
    }

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

class _LiveEndpoint {
  final int            endpoint;
  final List<int>      deviceTypeIds;
  final List<_LiveCluster> clusters;
  const _LiveEndpoint({required this.endpoint,
                       required this.deviceTypeIds, required this.clusters});
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;
  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  // ── Pending write state (local) ────────────────────────────────────────────
  int? _pendingSetpt;
  int? _pendingMode;

  // ── Basic info (not subscribed, load once per session) ────────────────────
  bool _basicInfoLoaded = false;

  // ── Cluster-based readings (cached) ───────────────────────────────────────
  List<_Reading>? _readings;
  bool            _readingsLoading = false;

  // ── Helpers ────────────────────────────────────────────────────────────────

  DeviceProvider get _provider => context.read<DeviceProvider>();
  MatterDevice?  get _device   => _provider.findById(widget.deviceId);
  DeviceLiveData? get _live    => _provider.liveDataFor(widget.deviceId);

  @override
  void initState() {
    super.initState();
    _provider.addListener(_onProviderUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedReadingsFromCache();
      _maybeLoadMissing();
    });
  }

  @override
  void dispose() {
    try { _provider.removeListener(_onProviderUpdate); } catch (_) {}
    super.dispose();
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    // Subscription pushed a cluster-cache update — refresh readings.
    final cached = _provider.clusterCacheFor(widget.deviceId);
    if (cached != null && _readings == null) {
      final device = _device;
      if (device != null) {
        setState(() =>
          _readings = _extractReadings(_parseClusters(cached), device.deviceType));
      }
    }
    setState(() {}); // rebuild to pick up liveData changes
  }

  void _seedReadingsFromCache() {
    final cached = _provider.clusterCacheFor(widget.deviceId);
    if (cached == null) return;
    final device = _device;
    if (device == null) return;
    setState(() =>
      _readings = _extractReadings(_parseClusters(cached), device.deviceType));
  }

  /// Loads data not covered by subscriptions (basic info, cluster JSON).
  Future<void> _maybeLoadMissing() async {
    final device = _device;
    if (device == null || !device.isOnline) return;

    if (!_basicInfoLoaded) {
      _basicInfoLoaded = true;
      final info = await context.read<MatterChannel>().readBasicInfo(device.nodeId);
      if (mounted && info != null) {
        _provider.updateBasicInfo(
            widget.deviceId, info.productName, info.serialNumber, info.softwareVersion,
            vendorName:        info.vendorName.isNotEmpty        ? info.vendorName        : null,
            vendorId:          info.vendorId.isNotEmpty          ? info.vendorId          : null,
            productId:         info.productId.isNotEmpty         ? info.productId         : null,
            hwVersion:         info.hwVersion.isNotEmpty         ? info.hwVersion         : null,
            manufacturingDate: info.manufacturingDate.isNotEmpty ? info.manufacturingDate : null,
            partNumber:        info.partNumber.isNotEmpty        ? info.partNumber        : null,
            productUrl:        info.productUrl.isNotEmpty        ? info.productUrl        : null,
            uniqueId:          info.uniqueId.isNotEmpty          ? info.uniqueId          : null,
        );
      }
    }

    if (_provider.clusterCacheFor(widget.deviceId) == null) {
      await _loadReadings();
    }
  }

  Future<void> _setSetpointC(double tempC) async {
    final nodeId = _device?.nodeId; if (nodeId == null) return;
    final centi  = (tempC * 100).round().clamp(500, 3500);
    setState(() => _pendingSetpt = centi);
    await context.read<MatterChannel>().writeHeatingSetpoint(nodeId, centi);
    // Subscription will confirm the new value; clear pending after a short guard.
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _pendingSetpt = null);
  }

  Future<void> _setMode(int mode) async {
    final nodeId = _device?.nodeId; if (nodeId == null) return;
    setState(() => _pendingMode = mode);
    await context.read<MatterChannel>().writeSystemMode(nodeId, mode);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _pendingMode = null);
  }

  Future<void> _loadReadings() async {
    final provider = _provider;
    final device   = _device; if (device == null) return;

    final cached = provider.clusterCacheFor(widget.deviceId);
    if (cached != null) {
      setState(() {
        _readings        = _extractReadings(_parseClusters(cached), device.deviceType);
        _readingsLoading = false;
      });
      return;
    }

    setState(() => _readingsLoading = true);
    try {
      final jsonStr = await context.read<MatterChannel>().readClusters(device.nodeId);
      if (!mounted) return;
      if (jsonStr != null) provider.cacheClusterJson(widget.deviceId, jsonStr);
      setState(() {
        _readings        = _extractReadings(_parseClusters(jsonStr), device.deviceType);
        _readingsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _readingsLoading = false);
    }
  }

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
        ),
    ];
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        final device = provider.findById(widget.deviceId);
        if (device == null) {
          return Scaffold(appBar: AppBar(),
              body: const Center(child: Text('Device not found')));
        }
        return _buildScaffold(context, device, provider);
      },
    );
  }

  Widget _buildScaffold(
      BuildContext context, MatterDevice device, DeviceProvider provider) {
    final cs       = Theme.of(context).colorScheme;
    final liveData   = provider.liveDataFor(widget.deviceId);
    final thermo     = liveData?.thermoState;
    final humidity   = liveData?.humidityCenti;
    final battery    = liveData?.batteryInfo;
    final serial     = liveData?.serialNumber;
    final swVer      = liveData?.softwareVersion;
    final productName = (device.productName?.isNotEmpty ?? false)
        ? device.productName!
        : (liveData?.productName?.isNotEmpty ?? false)
            ? liveData!.productName!
            : null;
    final isStale    = liveData?.isStale ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            Text(
                productName ?? device.deviceType.displayName,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            if (isStale) ...[
              const SizedBox(width: 6),
              Icon(Icons.cloud_off_outlined, size: 12,
                   color: cs.onSurfaceVariant.withAlpha(150)),
            ],
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Device settings',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => DeviceSettingsScreen(device: device))),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.refreshDevice(widget.deviceId);
          await _loadReadings();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              if (device.deviceType.hasBrightness && device.isOnline) ...[
                _BrightnessCard(
                  brightness: device.brightness,
                  onChanged:  (v) => provider.setBrightness(device.id, v),
                ),
                const SizedBox(height: 12),
              ],

              if (device.deviceType == DeviceType.thermostat && device.isOnline) ...[
                _ThermostatCard(
                  state:           thermo,
                  pendingSetpt:    _pendingSetpt,
                  pendingMode:     _pendingMode,
                  humidityCenti:   humidity,
                  battery:         battery,
                  serialNumber:    serial,
                  softwareVersion: swVer,
                  onSetSetpoint:   _setSetpointC,
                  onSetMode:       _setMode,
                ),
                const SizedBox(height: 12),
              ],

              _ReadingsSection(
                readings:  _readings,
                loading:   _readingsLoading,
                onRefresh: _loadReadings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero card  — icon + toggle only, matches home-screen tile style
// ─────────────────────────────────────────────────────────────────────────────

const _kCardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(20)),
  side: BorderSide(color: Colors.white, width: 1.5),
);

class _HeroCard extends StatelessWidget {
  final MatterDevice device;
  final VoidCallback onToggle;
  const _HeroCard({required this.device, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isActive = device.isOnline && device.isOn;

    return Card(
      color: Colors.transparent,
      shape: _kCardShape,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(device.deviceType.icon, size: 26,
                color: isActive ? cs.primary : Colors.white70),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              device.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 15),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          if (device.deviceType.hasOnOff)
            _ToggleSwitch(device: device, onToggle: onToggle),
        ]),
      ),
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  final MatterDevice device;
  final VoidCallback onToggle;
  const _ToggleSwitch({required this.device, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: device.isOnline ? onToggle : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44, height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: device.isOn && device.isOnline ? cs.primary : Colors.white30,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: device.isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20, height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brightness card
// ─────────────────────────────────────────────────────────────────────────────

class _BrightnessCard extends StatelessWidget {
  final double brightness;
  final ValueChanged<double> onChanged;
  const _BrightnessCard({required this.brightness, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.brightness_6_outlined, size: 18),
            const SizedBox(width: 8),
            Text('Brightness', style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${(brightness * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
          Slider(value: brightness, onChangeEnd: onChanged, onChanged: (_) {},
                 min: 0.01, max: 1.0),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sensor readings section
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingsSection extends StatelessWidget {
  final List<_Reading>? readings;
  final bool loading;
  final VoidCallback onRefresh;

  const _ReadingsSection({
    required this.readings,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (readings == null || readings!.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        mainAxisSpacing:  10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount:   readings!.length,
      itemBuilder: (_, i) => _ReadingCard(reading: readings![i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual reading tile  — home-screen card style + dot-matrix value
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingCard extends StatelessWidget {
  final _Reading reading;
  const _ReadingCard({required this.reading});

  /// True when the displayValue is a plain number (usable as dot-matrix input).
  bool get _isNumeric => double.tryParse(reading.displayValue) != null;

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final isNum   = _isNumeric;
    final hasUnit = reading.unit.isNotEmpty;

    return Card(
      color: Colors.white.withAlpha(18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: Colors.white, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top-left: icon + label + quality dot ──────────────────────
            Row(children: [
              Icon(reading.icon, size: 14, color: reading.iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(reading.label,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11,
                        fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (reading.quality != null)
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: _qualityColor(reading.quality!),
                    shape: BoxShape.circle,
                  ),
                ),
            ]),

            // ── Centre: value ──────────────────────────────────────────────
            Expanded(
              child: Center(
                child: SizedBox(
                  height: 38,
                  width: double.infinity,
                  child: isNum
                      ? CustomPaint(
                          painter: DotMatrixPainter(
                            text:     reading.displayValue,
                            litColor: Colors.white,
                            dimColor: Colors.white.withAlpha(28),
                          ),
                        )
                      : Center(
                          child: Text(
                            reading.displayValue,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
              ),
            ),

            // ── Bottom-right: unit ─────────────────────────────────────────
            if (hasUnit || reading.subtitle != null)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  reading.subtitle != null && !hasUnit
                      ? reading.subtitle!
                      : reading.unit,
                  style: TextStyle(
                    color: reading.quality != null
                        ? _qualityColor(reading.quality!)
                        : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thermostat card
// ─────────────────────────────────────────────────────────────────────────────

class _ThermostatCard extends StatelessWidget {
  final ThermostatState?               state;
  final int?                           pendingSetpt;
  final int?                           pendingMode;
  final int?                           humidityCenti;
  final BatteryInfo?                   battery;
  final String?                        serialNumber;
  final String?                        softwareVersion;
  final Future<void> Function(double)  onSetSetpoint;
  final Future<void> Function(int)     onSetMode;

  const _ThermostatCard({
    required this.state,           required this.pendingSetpt,
    required this.pendingMode,     required this.humidityCenti,
    required this.battery,         required this.serialNumber,
    required this.softwareVersion, required this.onSetSetpoint,
    required this.onSetMode,
  });

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final setpointC = pendingSetpt != null
        ? pendingSetpt! / 100.0
        : state?.heatingSetptC;

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _ThermostatDial(
            measuredTempC:     state?.localTempC,
            setpointC:         setpointC,
            supportsCooling:   state?.supportsCooling ?? false,
            coolingSetptC:     state?.coolingSetptC,
            onSetpointChanged: (v) {},
            onSetpointEnd:     state != null ? onSetSetpoint : (_) {},
          ),
          const SizedBox(height: 16),
          if (state != null)
            _ModeSelector(
              modes:    state!.availableModes,
              current:  pendingMode ?? state!.systemMode,
              onSelect: onSetMode,
            ),
          if (humidityCenti != null || battery != null) ...[
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (humidityCenti != null)
                _SensorPill(
                  icon: Icons.water_drop_outlined,
                  iconColor: Colors.lightBlue[300]!,
                  value: '${(humidityCenti! / 100.0).toStringAsFixed(0)} %',
                  label: 'humidity',
                ),
              if (humidityCenti != null && battery != null)
                const SizedBox(width: 24),
              if (battery != null) _BatteryPill(battery: battery!),
            ]),
          ],
          if (serialNumber != null || softwareVersion != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (serialNumber    != null) _InfoLine(label: 'Serial',     value: serialNumber!),
            if (softwareVersion != null) _InfoLine(label: 'SW version', value: softwareVersion!),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thermostat dial (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

const _dialGlyphs = <String, List<int>>{
  '0': [0x0E,0x11,0x13,0x15,0x19,0x11,0x0E], '1': [0x04,0x0C,0x04,0x04,0x04,0x04,0x0E],
  '2': [0x0E,0x11,0x01,0x06,0x08,0x10,0x1F], '3': [0x0E,0x11,0x01,0x06,0x01,0x11,0x0E],
  '4': [0x02,0x06,0x0A,0x12,0x1F,0x02,0x02], '5': [0x1F,0x10,0x1E,0x01,0x01,0x11,0x0E],
  '6': [0x0E,0x10,0x1E,0x11,0x11,0x11,0x0E], '7': [0x1F,0x01,0x02,0x04,0x08,0x08,0x08],
  '8': [0x0E,0x11,0x11,0x0E,0x11,0x11,0x0E], '9': [0x0E,0x11,0x11,0x0F,0x01,0x01,0x0E],
  '.': [0x00,0x00,0x00,0x00,0x00,0x02,0x02], '-': [0x00,0x00,0x00,0x1F,0x00,0x00,0x00],
};
int _dialCharCols(String ch) => ch == '.' ? 3 : 5;

const _kArcStart = 135.0 * math.pi / 180.0;
const _kArcSweep = 270.0 * math.pi / 180.0;
const _kTempMin  = 5.0;
const _kTempMax  = 35.0;

class _ThermostatDial extends StatefulWidget {
  final double? measuredTempC, setpointC, coolingSetptC;
  final bool    supportsCooling;
  final void Function(double) onSetpointChanged, onSetpointEnd;

  const _ThermostatDial({
    required this.measuredTempC, required this.setpointC,
    required this.supportsCooling, required this.coolingSetptC,
    required this.onSetpointChanged, required this.onSetpointEnd,
  });

  @override
  State<_ThermostatDial> createState() => _ThermostatDialState();
}

class _ThermostatDialState extends State<_ThermostatDial> {
  double? _dragTemp;
  double get _setpoint => _dragTemp ?? widget.setpointC ?? 20.0;
  bool   get _hasData  => widget.setpointC != null;

  double _angleToTemp(double angleDeg) {
    final startDeg = _kArcStart * 180 / math.pi;
    var rel = ((angleDeg - startDeg) % 360 + 360) % 360;
    if (rel > 270) rel = (rel - 270 < 360 - rel) ? 270 : 0;
    return (_kTempMin + (rel / 270) * (_kTempMax - _kTempMin))
        .clamp(_kTempMin, _kTempMax);
  }

  void _handleDrag(Offset pos, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    var deg = math.atan2(pos.dy - c.dy, pos.dx - c.dx) * 180 / math.pi;
    if (deg < 0) deg += 360;
    final snapped = ((_angleToTemp(deg) * 2).round() / 2.0)
        .clamp(_kTempMin, _kTempMax);
    setState(() => _dragTemp = snapped);
    widget.onSetpointChanged(snapped);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final side = c.maxWidth;
      return SizedBox(width: side, height: side,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) { if (_hasData) _handleDrag(d.localPosition, Size(side, side)); },
          onPanEnd: (_) {
            if (_dragTemp != null) {
              widget.onSetpointEnd(_dragTemp!);
              setState(() => _dragTemp = null);
            }
          },
          child: CustomPaint(painter: _DialPainter(
            measuredTempC: widget.measuredTempC,
            setpointC:     _hasData ? _setpoint : null,
            coolingSetptC: widget.supportsCooling ? widget.coolingSetptC : null,
          )),
        ),
      );
    });
  }
}

class _DialPainter extends CustomPainter {
  final double? measuredTempC, setpointC, coolingSetptC;
  const _DialPainter({required this.measuredTempC, required this.setpointC,
                      this.coolingSetptC});

  double _frac(double t) =>
      ((t - _kTempMin) / (_kTempMax - _kTempMin)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final c  = Offset(cx, cy);
    final r  = math.min(cx, cy) - 20;
    final rc = Rect.fromCircle(center: c, radius: r);

    canvas.drawArc(rc, _kArcStart, _kArcSweep, false,
        Paint()..color=Colors.white.withAlpha(45)..style=PaintingStyle.stroke
               ..strokeWidth=2.5..strokeCap=StrokeCap.round);

    if (setpointC != null) {
      final f = _frac(setpointC!);
      if (f > 0) canvas.drawArc(rc, _kArcStart, _kArcSweep * f, false,
          Paint()..color=Colors.white..style=PaintingStyle.stroke
                 ..strokeWidth=2.5..strokeCap=StrokeCap.round);
      final ka = _kArcStart + _kArcSweep * f;
      final kp = c + Offset(math.cos(ka)*r, math.sin(ka)*r);
      canvas.drawCircle(kp, 9, Paint()..color=Colors.white);
      canvas.drawCircle(kp, 9, Paint()..color=Colors.white.withAlpha(80)
          ..style=PaintingStyle.stroke..strokeWidth=3);
    }
    if (measuredTempC != null) {
      final ma = _kArcStart + _kArcSweep * _frac(measuredTempC!);
      final d  = Offset(math.cos(ma), math.sin(ma));
      canvas.drawLine(c+d*(r-9), c+d*(r+9),
          Paint()..color=Colors.white..strokeWidth=2..strokeCap=StrokeCap.round);
    }
    if (coolingSetptC != null) {
      final ca = _kArcStart + _kArcSweep * _frac(coolingSetptC!);
      final d  = Offset(math.cos(ca), math.sin(ca));
      canvas.drawLine(c+d*(r-6), c+d*(r+6),
          Paint()..color=Colors.lightBlue.withAlpha(200)..strokeWidth=1.5
                 ..strokeCap=StrokeCap.round);
    }
    _dotMatrix(canvas, c+Offset(0,-r*0.18),
        setpointC!=null ? setpointC!.toStringAsFixed(1) : '--.-',
        mW:r*1.0, mH:r*0.30, color:Colors.white);
    _dotMatrix(canvas, c+Offset(0,r*0.22),
        measuredTempC!=null ? measuredTempC!.toStringAsFixed(1) : '--.-',
        mW:r*0.70, mH:r*0.20, color:Colors.white.withAlpha(160));
  }

  void _dotMatrix(Canvas canvas, Offset centre, String text,
      {required double mW, required double mH, required Color color}) {
    final chars = text.characters.toList();
    if (chars.isEmpty) return;
    final total = chars.fold(0, (s, c) => s + _dialCharCols(c)) + (chars.length-1);
    const gap   = 2.0;
    final step  = math.min((mW+gap)/total, (mH+gap)/7);
    final r     = (step-gap)/2;
    final ox    = centre.dx - (step*total-gap)/2;
    final oy    = centre.dy - (step*7-gap)/2;
    final p     = Paint()..color=color..style=PaintingStyle.fill;
    double cx   = ox;
    for (final ch in chars) {
      final g    = _dialGlyphs[ch] ?? _dialGlyphs['-']!;
      final cols = _dialCharCols(ch);
      for (int row = 0; row < 7; row++) {
        for (int col = 0; col < cols; col++) {
          if (((g[row] >> ((cols-1)-col)) & 1) == 1)
            canvas.drawCircle(
                Offset(cx+col*step+step/2, oy+row*step+step/2), r, p);
        }
      }
      cx += cols*step + step;
    }
  }

  @override
  bool shouldRepaint(_DialPainter o) =>
      o.measuredTempC!=measuredTempC||o.setpointC!=setpointC||o.coolingSetptC!=coolingSetptC;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InfoLine extends StatelessWidget {
  final String label, value;
  const _InfoLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: Theme.of(context)
            .textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(
            fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _SensorPill extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String value, label;
  const _SensorPill({required this.icon, required this.iconColor,
                     required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: iconColor), const SizedBox(width: 6),
      Text(value, style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: cs.onSurfaceVariant)),
    ]);
  }
}

class _BatteryPill extends StatelessWidget {
  final BatteryInfo battery;
  const _BatteryPill({required this.battery});
  @override
  Widget build(BuildContext context) {
    if (battery.percent != null) {
      final pct = battery.percent!;
      final icon  = pct>75?Icons.battery_full:pct>50?Icons.battery_5_bar
                   :pct>25?Icons.battery_3_bar:pct>10?Icons.battery_1_bar:Icons.battery_alert;
      final color = pct>25?Colors.green.shade400:pct>10?Colors.orange.shade400:Colors.red.shade400;
      return _SensorPill(icon:icon, iconColor:color, value:'$pct %', label:'battery');
    }
    if (battery.chargeLevel != null) {
      final (icon, color, text) = switch (battery.chargeLevel!) {
        1 => (Icons.battery_3_bar, Colors.orange.shade400, 'Warning'),
        2 => (Icons.battery_alert,  Colors.red.shade400,   'Critical'),
        _ => (Icons.battery_full,   Colors.green.shade400, 'OK'),
      };
      return _SensorPill(icon:icon, iconColor:color, value:text, label:'battery');
    }
    if (battery.voltageMilliV != null) {
      return _SensorPill(icon:Icons.battery_std, iconColor:Colors.green.shade400,
          value:'${(battery.voltageMilliV!/1000.0).toStringAsFixed(2)} V', label:'battery');
    }
    return const SizedBox.shrink();
  }
}

class _ModeSelector extends StatelessWidget {
  final List<({int mode, String label})> modes;
  final int? current;
  final ValueChanged<int> onSelect;
  const _ModeSelector({required this.modes, required this.current, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
      children: modes.map((m) {
        final sel = current == m.mode;
        return ChoiceChip(
          label: Text(m.label), selected: sel,
          onSelected: (_) => onSelect(m.mode),
          selectedColor: Colors.black87, backgroundColor: Colors.transparent,
          labelStyle: TextStyle(fontWeight: sel?FontWeight.bold:FontWeight.normal,
                                color: sel?Colors.white:Colors.black87),
          side: BorderSide(color: sel?Colors.black87:Colors.black26),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
