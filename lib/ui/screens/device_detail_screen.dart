import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/basic_info.dart';
import '../../models/device_type.dart';
import '../../models/matter_device.dart';
import '../../models/thermostat_models.dart';
import '../../providers/device_provider.dart';
import '../../services/matter_channel.dart';
import '../widgets/dot_matrix_painter.dart';
import '../widgets/info_row.dart';
import 'device_settings_screen.dart';

part 'device_detail/cluster_readings.dart';
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
  List<_Reading>? _readings;
  bool            _readingsLoading = false;

  // ── Cached provider ref (safe to use in dispose) ──────────────────────────
  late final DeviceProvider _provider;

  MatterDevice? get _device => _provider.findById(widget.deviceId);

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
      final device = _device;
      if (device != null) setState(() =>
          _readings = _extractReadings(_parseClusters(cached), device.deviceType));
    }
    setState(() {});
  }

  void _seedReadingsFromCache() {
    final cached = _provider.clusterCacheFor(widget.deviceId);
    if (cached == null) return;
    final device = _device; if (device == null) return;
    setState(() =>
        _readings = _extractReadings(_parseClusters(cached), device.deviceType));
  }

  Future<void> _maybeLoadMissing() async {
    final device = _device;
    if (device == null || !device.isOnline) return;

    if (!_basicInfoLoaded) {
      _basicInfoLoaded = true;
      final info = await context.read<MatterChannel>().readBasicInfo(device.nodeId);
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
    final nodeId = _device?.nodeId; if (nodeId == null) return;
    final centi  = (tempC * 100).round().clamp(500, 3500);
    setState(() => _pendingSetpt = centi);
    await context.read<MatterChannel>().writeHeatingSetpoint(nodeId, centi);
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
    final device = _device; if (device == null) return;
    final cached = _provider.clusterCacheFor(widget.deviceId);
    if (cached != null) {
      setState(() {
        _readings = _extractReadings(_parseClusters(cached), device.deviceType);
        _readingsLoading = false;
      });
      return;
    }
    setState(() => _readingsLoading = true);
    try {
      final jsonStr = await context.read<MatterChannel>().readClusters(device.nodeId);
      if (!mounted) return;
      if (jsonStr != null) _provider.cacheClusterJson(widget.deviceId, jsonStr);
      setState(() {
        _readings = _extractReadings(_parseClusters(jsonStr), device.deviceType);
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
        final device = provider.findById(widget.deviceId);
        if (device == null) {
          return Scaffold(appBar: AppBar(),
              body: const Center(child: Text('Device not found')));
        }
        return _buildScaffold(context, device, provider);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, MatterDevice device, DeviceProvider provider) {
    final cs        = Theme.of(context).colorScheme;
    final liveData  = provider.liveDataFor(widget.deviceId);
    final isStale   = liveData?.isStale ?? false;
    final productName = device.productName?.isNotEmpty == true
        ? device.productName!
        : liveData?.productName?.isNotEmpty == true
            ? liveData!.productName!
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            Text(productName ?? device.deviceType.displayName,
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
                MaterialPageRoute(builder: (_) => DeviceSettingsScreen(device: device))),
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
              if (device.deviceType.hasOnOff && device.isOnline) ...[
                _OnOffCard(device: device),
                const SizedBox(height: 12),
              ],
              if (device.deviceType.hasBrightness && device.isOnline) ...[
                _BrightnessCard(
                  brightness: device.brightness,
                  onChanged:  (v) => provider.setBrightness(device.id, v),
                ),
                const SizedBox(height: 12),
              ],
              if (device.deviceType == DeviceType.thermostat && device.isOnline) ...[
                _ThermostatCard(
                  state:           liveData?.thermoState,
                  pendingSetpt:    _pendingSetpt,
                  pendingMode:     _pendingMode,
                  humidityCenti:   liveData?.humidityCenti,
                  battery:         liveData?.batteryInfo,
                  serialNumber:    liveData?.serialNumber,
                  softwareVersion: liveData?.softwareVersion,
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
