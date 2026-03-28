import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/basic_info.dart';
import '../../models/device_type.dart';
import '../../models/device_view.dart';
import '../../models/thermostat_models.dart';
import '../../providers/device_provider.dart';
import '../../services/cluster_parser.dart';
import '../../services/matter_port.dart';
import '../widgets/dot_matrix_painter.dart';
import '../widgets/info_row.dart';
import 'device_settings_screen.dart';

part 'device_detail/device_cards.dart';
part 'device_detail/thermostat_card.dart';

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
  List<ClusterReading>? _readings;
  bool                  _readingsLoading = false;

  // ── Cached provider ref (safe to use in dispose) ──────────────────────────
  late final DeviceProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<DeviceProvider>();
    _provider.addListener(_onProviderUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedReadingsFromCache();
      _maybeLoadMissing();
    });
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final cached = _provider.clusterCacheFor(widget.deviceId);
    if (cached != null && _readings == null) {
      final view = _provider.viewFor(widget.deviceId);
      if (view != null) {
        setState(() =>
            _readings = extractReadings(parseClusters(cached), view.deviceType));
      }
    }
    setState(() {});
  }

  void _seedReadingsFromCache() {
    final cached = _provider.clusterCacheFor(widget.deviceId);
    if (cached == null) return;
    final view = _provider.viewFor(widget.deviceId);
    if (view == null) return;
    setState(() =>
        _readings = extractReadings(parseClusters(cached), view.deviceType));
  }

  Future<void> _maybeLoadMissing() async {
    final view = _provider.viewFor(widget.deviceId);
    if (view == null) return;

    // Always attempt; readBasicInfo returns null if the device is unreachable.
    if (!_basicInfoLoaded) {
      _basicInfoLoaded = true;
      final info =
          await context.read<MatterClusterPort>().readBasicInfo(view.nodeId);
      if (mounted && info != null) {
        _provider.updateBasicInfo(
          widget.deviceId,
          BasicInfo.nonEmpty(info.productName),
          BasicInfo.nonEmpty(info.serialNumber),
          BasicInfo.nonEmpty(info.softwareVersion),
          vendorName:        BasicInfo.nonEmpty(info.vendorName),
          vendorId:          BasicInfo.nonEmpty(info.vendorId),
          productId:         BasicInfo.nonEmpty(info.productId),
          hwVersion:         BasicInfo.nonEmpty(info.hwVersion),
          manufacturingDate: BasicInfo.nonEmpty(info.manufacturingDate),
          partNumber:        BasicInfo.nonEmpty(info.partNumber),
          productUrl:        BasicInfo.nonEmpty(info.productUrl),
          uniqueId:          BasicInfo.nonEmpty(info.uniqueId),
          swVersionNum:      info.softwareVersionNum,
        );
        await _provider.detectAndUpdateOtaSupport(widget.deviceId);
      }
    }

    if (_provider.clusterCacheFor(widget.deviceId) == null) {
      await _loadReadings();
    }
  }

  Future<void> _setSetpointC(double tempC) async {
    final nodeId = _provider.viewFor(widget.deviceId)?.nodeId;
    if (nodeId == null) return;
    final centi = (tempC * 100).round().clamp(500, 3500);
    setState(() => _pendingSetpt = centi);
    await context.read<MatterClusterPort>().writeHeatingSetpoint(nodeId, centi);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _pendingSetpt = null);
  }

  Future<void> _setMode(int mode) async {
    final nodeId = _provider.viewFor(widget.deviceId)?.nodeId;
    if (nodeId == null) return;
    setState(() => _pendingMode = mode);
    await context.read<MatterClusterPort>().writeSystemMode(nodeId, mode);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _pendingMode = null);
  }

  Future<void> _loadReadings() async {
    final view = _provider.viewFor(widget.deviceId);
    if (view == null) return;
    final cached = _provider.clusterCacheFor(widget.deviceId);
    if (cached != null) {
      setState(() {
        _readings        = extractReadings(parseClusters(cached), view.deviceType);
        _readingsLoading = false;
      });
      return;
    }
    setState(() => _readingsLoading = true);
    try {
      final jsonStr =
          await context.read<MatterClusterPort>().readClusters(view.nodeId);
      if (!mounted) return;
      if (jsonStr != null) _provider.cacheClusterJson(widget.deviceId, jsonStr);
      setState(() {
        _readings        = extractReadings(parseClusters(jsonStr), view.deviceType);
        _readingsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _readingsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        final view = provider.viewFor(widget.deviceId);
        if (view == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Device not found')));
        }
        return _buildScaffold(context, view, provider);
      },
    );
  }

  Widget _buildScaffold(
      BuildContext context, DeviceView view, DeviceProvider provider) {
    final cs          = Theme.of(context).colorScheme;
    final productName = view.displayProductName;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(view.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            Text(
              productName ?? view.deviceType.displayName,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (view.isStale) ...[
              const SizedBox(width: 6),
              Icon(Icons.cloud_off_outlined,
                  size: 12,
                  color: cs.onSurfaceVariant.withAlpha(150)),
            ],
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Device settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DeviceSettingsScreen(device: view.device)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            if (view.deviceType.hasOnOff && view.isOnline) ...[
              _OnOffCard(view: view),
              const SizedBox(height: 12),
            ],
            if (view.deviceType.hasBrightness && view.isOnline) ...[
              _BrightnessCard(
                brightness: view.brightness,
                onChanged:  (v) => provider.setBrightness(view.id, v),
              ),
              const SizedBox(height: 12),
            ],
            if (view.deviceType == DeviceType.thermostat && view.isOnline) ...[
              _ThermostatCard(
                state:           view.thermoState,
                pendingSetpt:    _pendingSetpt,
                pendingMode:     _pendingMode,
                humidityCenti:   view.humidityCenti,
                battery:         view.batteryInfo,
                serialNumber:    view.serialNumber,
                softwareVersion: view.softwareVersion,
                onSetSetpoint:   _setSetpointC,
                onSetMode:       _setMode,
              ),
              const SizedBox(height: 12),
            ],
            if (view.deviceType == DeviceType.contactSensor) ...[
              _ContactStateCard(
                contactState: view.contactState,
                isStale:      view.isStale,
              ),
              const SizedBox(height: 12),
            ],
            _ReadingsSection(
              readings: _readings,
              loading:  _readingsLoading,
            ),
          ],
        ),
      ),
    );
  }
}
