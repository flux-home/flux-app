import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/basic_info.dart';
import 'package:matter_home/models/device_live_data.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/energy_bucket.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/cluster_parser.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/ui/screens/device_settings_screen.dart';
import 'package:matter_home/ui/theme.dart';
import 'package:matter_home/ui/widgets/dot_matrix_painter.dart';
import 'package:provider/provider.dart';

part 'device_detail/switch_card.dart';
part 'device_detail/on_off_card.dart';
part 'device_detail/brightness_card.dart';
part 'device_detail/color_temperature_card.dart';
part 'device_detail/readings_section.dart';
part 'device_detail/window_covering_card.dart';
part 'device_detail/fan_control_card.dart';
part 'device_detail/smoke_alarm_card.dart';
part 'device_detail/thermostat_card.dart';
part 'device_detail/connecting_banner.dart';
part 'device_detail/energy_card.dart';
part 'device_detail/door_lock_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({required this.deviceId, super.key});
  final String deviceId;

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  // ── Pending write state (local) ────────────────────────────────────────────
  int? _pendingSetpt;
  int? _pendingMode;

  // ── Basic info (not subscribed, load once per session) ────────────────────
  bool _basicInfoLoaded = false;

  // ── Thermostat: refresh limits once per screen instance ───────────────────
  bool _thermoLimitsLoaded = false;

  // ── Readings ───────────────────────────────────────────────────────────────
  /// One-shot cluster JSON parse — never wiped once set.
  List<ClusterReading>? _clusterReadings;

  /// True when the On/Off cluster (0x0006) on this device has a non-empty
  /// AcceptedCommandList — i.e. the device is genuinely controllable even if
  /// its [DeviceType] does not declare [DeviceType.hasOnOff].
  bool _onOffIsControllable = false;

  /// Displayed list: _clusterReadings merged with live readings.
  List<ClusterReading>? _readings;
  bool _readingsLoading = false;

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
    final view = _provider.viewFor(widget.deviceId);
    if (view != null) {
      setState(() => _readings = _merged(view));
    } else {
      setState(() {});
    }
  }

  void _seedReadingsFromCache() {
    final view = _provider.viewFor(widget.deviceId);
    if (view == null) return;
    // Seed _clusterReadings from cache if available.
    if (_clusterReadings == null) {
      final cached = _provider.clusterCacheFor(widget.deviceId);
      if (cached != null) {
        final endpoints = parseClusters(cached);
        _clusterReadings = extractReadings(endpoints, view.deviceType);
        _onOffIsControllable = onOffClusterIsControllable(endpoints);
      }
    }
    setState(() => _readings = _merged(view));
  }

  /// Merges live subscription readings into the cluster-JSON base.
  ///
  /// Live readings update matching entries (by label) so sensors driven by
  /// subscriptions stay fresh.  Cluster-only readings (CO2, PM2.5, …) that
  /// have no live counterpart are preserved untouched.
  List<ClusterReading> _merged(DeviceView view) {
    final live = liveReadings(view);
    final cluster = _clusterReadings;

    if (cluster == null || cluster.isEmpty) return live;
    if (live.isEmpty) return cluster;

    // Build a mutable map of live readings keyed by label; consume each
    // entry at most once so duplicates aren't accidentally collapsed.
    final liveByLabel = <String, ClusterReading>{for (final r in live) r.label: r};
    return [
      // Replace matching cluster entries with their live version.
      for (final r in cluster) liveByLabel.remove(r.label) ?? r,
      // Append any live readings that had no cluster equivalent.
      ...liveByLabel.values,
    ];
  }

  Future<void> _maybeLoadMissing() async {
    final view = _provider.viewFor(widget.deviceId);
    if (view == null) return;

    // All three branches are independent — run them in parallel so readings,
    // basic info, and thermostat limits all arrive as fast as the network allows.
    await Future.wait([_maybeLoadBasicInfo(view), _maybeLoadThermoLimits(view), _maybeLoadReadings()]);
  }

  Future<void> _maybeLoadBasicInfo(DeviceView view) async {
    if (_basicInfoLoaded) return;
    _basicInfoLoaded = true;
    final info = await context.read<MatterClusterPort>().readBasicInfo(view.nodeId);
    if (mounted && info != null) {
      _provider.updateBasicInfo(
        widget.deviceId,
        BasicInfo.nonEmpty(info.productName),
        BasicInfo.nonEmpty(info.serialNumber),
        BasicInfo.nonEmpty(info.softwareVersion),
        vendorName: BasicInfo.nonEmpty(info.vendorName),
        vendorId: BasicInfo.nonEmpty(info.vendorId),
        productId: BasicInfo.nonEmpty(info.productId),
        hwVersion: BasicInfo.nonEmpty(info.hwVersion),
        manufacturingDate: BasicInfo.nonEmpty(info.manufacturingDate),
        partNumber: BasicInfo.nonEmpty(info.partNumber),
        productUrl: BasicInfo.nonEmpty(info.productUrl),
        uniqueId: BasicInfo.nonEmpty(info.uniqueId),
        swVersionNum: info.softwareVersionNum,
      );
      await _provider.detectAndUpdateOtaSupport(widget.deviceId);
    }
  }

  Future<void> _maybeLoadThermoLimits(DeviceView view) async {
    if (_thermoLimitsLoaded || view.deviceType != DeviceType.thermostat) return;
    _thermoLimitsLoaded = true;
    await _provider.refreshDevice(widget.deviceId);
  }

  Future<void> _maybeLoadReadings() async {
    if (_provider.clusterCacheFor(widget.deviceId) != null) return;
    await _loadReadings();
  }

  Future<void> _setSetpointC(double? tempC) async {
    final nodeId = _provider.viewFor(widget.deviceId)?.nodeId;
    if (nodeId == null) return;

    if (tempC == null) {
      setState(() => _pendingMode = 0);
      await context.read<MatterClusterPort>().writeSystemMode(nodeId, 0);
      if (mounted) setState(() => _pendingMode = null);
      return;
    }

    final state = _provider.viewFor(widget.deviceId)?.thermoState;
    final centi = (tempC * 100).round();
    final currentMode = _pendingMode ?? state?.systemMode ?? 0;

    if (currentMode == 0) {
      setState(() => _pendingMode = 4);
      await context.read<MatterClusterPort>().writeSystemMode(nodeId, 4);
      if (!mounted) return;
    }

    setState(() => _pendingSetpt = centi);
    await context.read<MatterClusterPort>().writeHeatingSetpoint(nodeId, centi);
    await Future<void>.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _pendingSetpt = null;
        _pendingMode = null;
      });
    }
  }

  Future<void> _loadReadings() async {
    final view = _provider.viewFor(widget.deviceId);
    if (view == null) return;

    // If we already have cluster readings cached, just re-merge and return.
    if (_clusterReadings != null) {
      setState(() => _readings = _merged(view));
      return;
    }

    setState(() => _readingsLoading = true);
    try {
      final jsonStr = await context.read<MatterClusterPort>().readClusters(view.nodeId);
      if (!mounted) return;
      if (jsonStr != null) _provider.cacheClusterJson(widget.deviceId, jsonStr);
      final endpoints = parseClusters(jsonStr);
      _clusterReadings = extractReadings(endpoints, view.deviceType);
      _onOffIsControllable = onOffClusterIsControllable(endpoints);
      setState(() {
        _readings = _merged(view);
        _readingsLoading = false;
      });
    } on Exception catch (_) {
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
            body: const Center(child: Text('Device not found')),
          );
        }
        return _buildScaffold(context, view, provider);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, DeviceView view, DeviceProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final productName = view.displayProductName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(view.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              productName ?? view.deviceType.displayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Device settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => DeviceSettingsScreen(device: view.device)),
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
            _ConnectingBanner(isStale: view.isStale),
            if (view.deviceType.isSwitch && view.isOnline) ...[
              _SwitchCard(view: view, readings: _clusterReadings ?? const []),
              const SizedBox(height: 12),
            ],
            if (view.deviceType.hasBrightness && view.isOnline && !view.deviceType.isSwitch) ...[
              _BrightnessCard(brightness: view.brightness, onChanged: (v) => provider.setBrightness(view.id, v)),
              const SizedBox(height: 12),
            ],
            if (view.deviceType.hasOnOff && view.isOnline && !view.deviceType.isSwitch) ...[_OnOffCard(view: view), const SizedBox(height: 12)],
            if (_onOffIsControllable && !view.deviceType.hasOnOff && view.isOnline && !view.deviceType.isSwitch) ...[_OnOffCard(view: view), const SizedBox(height: 12)],
            if (view.deviceType == DeviceType.thermostat && view.isOnline) ...[
              _ThermostatCard(
                state: view.thermoState,
                pendingSetpt: _pendingSetpt,
                pendingMode: _pendingMode,
                onSetSetpoint: _setSetpointC,
              ),
              const SizedBox(height: 12),
            ],
            if (view.deviceType.hasWindowCovering && view.isOnline) ...[
              _WindowCoveringCard(view: view),
              const SizedBox(height: 12),
            ],
            if (view.deviceType.hasFanControl && view.isOnline) ...[
              _FanControlCard(view: view),
              const SizedBox(height: 12),
            ],
            if (view.deviceType.hasColorTemp && view.isOnline) ...[
              _ColorTemperatureCard(view: view),
              const SizedBox(height: 12),
            ],
            if (view.deviceType == DeviceType.smokeCOAlarm) ...[
              _SmokeAlarmCard(view: view),
              const SizedBox(height: 12),
            ],
            if (view.deviceType == DeviceType.doorLock) ...[
              DoorLockCard(view: view),
              const SizedBox(height: 12),
            ],
            if ((view.deviceType.hasEnergyMeasurement ||
                    (view.live?.activePower != null)) &&
                view.live != null) ...[
              EnergyCard(
                live:             view.live!,
                history:          context.read<DeviceProvider>().energyHistoryFor(view.id),
                currentBucketWh:  context.read<DeviceProvider>().energyCurrentBucketWhFor(view.id),
              ),
              const SizedBox(height: 12),
            ],
            // For switch devices, filter out per-endpoint switch readings
            // (already shown in _SwitchCard) — keep battery etc.
            // When a device is controllable via AcceptedCommandList but its
            // DeviceType doesn't declare hasOnOff, the dedicated _OnOffCard is
            // already shown above; suppress the fallback 0x0006 sensor tile
            // (label='Power', unit='') so the two don't coexist.
            // When EnergyCard is shown, suppress the individual power/energy
            // readings that would duplicate its display.
            _ReadingsSection(
              readings: () {
                var r = _readings;
                if (view.deviceType.isSwitch) {
                  r = r?.where((x) => x.endpoint == null).toList();
                }
                if (_onOffIsControllable && !view.deviceType.hasOnOff) {
                  r = r?.where((x) => !(x.label == 'Power' && x.unit.isEmpty)).toList();
                }
                if (view.deviceType.hasEnergyMeasurement ||
                    (view.live?.activePower != null)) {
                  const energyLabels = {
                    'Power', 'Voltage', 'Current',
                    'Energy imported', 'Energy exported',
                  };
                  r = r?.where((x) => !energyLabels.contains(x.label)).toList();
                }
                return r;
              }(),
              loading: _readingsLoading,
            ),
          ],
        ),
      ),
    );
  }
}
