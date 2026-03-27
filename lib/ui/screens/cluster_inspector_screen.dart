import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/matter_device.dart';
import '../../services/matter_channel.dart';

// ---------------------------------------------------------------------------
// Well-known Matter device type names (spec §7 + Node types §2)
// ---------------------------------------------------------------------------

const _kDeviceTypeNames = <int, String>{
  // ── Node / infrastructure ───────────────────────────────────────────────
  0x0011: 'Root Node',
  0x0016: 'Secondary Network Interface',
  0x0014: 'OTA Provider',
  0x0012: 'OTA Requestor',
  0x0013: 'Bridged Node',
  0x000E: 'Aggregator',
  // ── Lighting ─────────────────────────────────────────────────────────────
  0x0100: 'On/Off Light',
  0x0101: 'Dimmable Light',
  0x010C: 'Color Temp. Light',
  0x010D: 'Extended Color Light',
  0x0109: 'Light Sensor',           // reuse (also in sensors below)
  // ── Switches ─────────────────────────────────────────────────────────────
  0x0103: 'On/Off Switch',
  0x0104: 'Dimmer Switch',
  0x0105: 'Color Dimmer Switch',
  0x000F: 'Generic Switch',
  // ── Plugs / outlets ──────────────────────────────────────────────────────
  0x010A: 'On/Off Plug-in Unit',
  0x010B: 'Dimmable Plug-in Unit',
  // ── HVAC ─────────────────────────────────────────────────────────────────
  0x0301: 'Thermostat',
  0x002B: 'Fan',
  0x002D: 'Air Purifier',
  0x0072: 'Air Purifier (alt)',
  0x0073: 'Air Quality Sensor',
  0x0071: 'HEPA Filter Monitoring',
  // ── Sensors ───────────────────────────────────────────────────────────────
  0x0302: 'Temperature Sensor',
  0x0307: 'Humidity Sensor',
  0x0305: 'Pressure Sensor',
  0x0306: 'Flow Sensor',
  0x0015: 'Contact Sensor',
  0x0106: 'Light Sensor',
  0x0107: 'Occupancy Sensor',
  0x0076: 'Smoke / CO Alarm',
  0x002C: 'Air Quality Sensor',
  0x002E: 'Water Freeze Detector',
  0x0041: 'Water Leak Detector',
  // ── Access control ────────────────────────────────────────────────────────
  0x000A: 'Door Lock',
  0x000B: 'Door Lock Controller',
  0x0202: 'Window Covering',
  0x0203: 'Window Covering Controller',
  // ── Energy ───────────────────────────────────────────────────────────────
  0x050C: 'EVSE',
  0x0050: 'Heat Pump',
  0x0510: 'Solar Power',
  0x0511: 'Battery Storage',
  // ── AV / Media ────────────────────────────────────────────────────────────
  0x0022: 'Speaker',
  0x0023: 'Cast Video Player',
  0x002A: 'Basic Video Player',
  0x0028: 'Video Remote Control',
  0x0035: 'Casting Video Client',
  0x0024: 'Content App',
  // ── Robotic ───────────────────────────────────────────────────────────────
  0x0074: 'Robotic Vacuum',
};

String _deviceTypeName(int id) =>
    _kDeviceTypeNames[id] ??
    '0x${id.toRadixString(16).toUpperCase().padLeft(4, '0')}';

const _kClusterNames = <int, String>{
  0x0003: 'Identify',
  0x0004: 'Groups',
  0x0005: 'Scenes',
  0x0006: 'On/Off',
  0x0008: 'Level Control',
  0x001D: 'Descriptor',
  0x001E: 'Binding',
  0x001F: 'Access Control',
  0x0025: 'Actions',
  0x0028: 'Basic Information',
  0x002A: 'OTA Software Update Requestor',
  0x002B: 'Localization Configuration',
  0x002C: 'Time Format Localization',
  0x002D: 'Unit Localization',
  0x002E: 'Power Source Configuration',
  0x002F: 'Power Source',
  0x0030: 'General Commissioning',
  0x0031: 'Network Commissioning',
  0x0032: 'Diagnostic Logs',
  0x0033: 'General Diagnostics',
  0x0034: 'Software Diagnostics',
  0x0035: 'Thread Network Diagnostics',
  0x0036: 'Wi-Fi Network Diagnostics',
  0x0037: 'Ethernet Network Diagnostics',
  0x0038: 'Time Synchronization',
  0x003B: 'Switch',
  0x003C: 'Administrator Commissioning',
  0x003E: 'Node Operational Credentials',
  0x003F: 'Group Key Management',
  0x0040: 'Fixed Label',
  0x0041: 'User Label',
  0x0045: 'Boolean State',
  0x0046: 'ICD Management',
  0x0050: 'Mode Select',
  0x0059: 'Scenes Management',
  0x0071: 'HEPA Filter Monitoring',
  0x0072: 'Activated Carbon Filter Monitoring',
  0x0080: 'Boolean State Configuration',
  0x0081: 'Valve Configuration and Control',
  0x0090: 'Electrical Energy Measurement',
  0x0091: 'Electrical Power Measurement',
  0x0096: 'Microwave Oven Control',
  0x0101: 'Door Lock',
  0x0102: 'Window Covering',
  0x0200: 'Pump Configuration and Control',
  0x0201: 'Thermostat',
  0x0202: 'Fan Control',
  0x0204: 'Thermostat User Interface Configuration',
  0x0300: 'Color Control',
  0x0301: 'Ballast Configuration',
  0x0400: 'Illuminance Measurement',
  0x0402: 'Temperature Measurement',
  0x0403: 'Pressure Measurement',
  0x0404: 'Flow Measurement',
  0x0405: 'Relative Humidity Measurement',
  0x0406: 'Occupancy Sensing',
  0x040C: 'Carbon Monoxide Concentration',
  0x040D: 'Carbon Dioxide Concentration',
  0x042A: 'PM2.5 Concentration',
  0x0500: 'IAS Zone',
  0x0503: 'Wake on LAN',
  0x0504: 'Channel',
  0x0507: 'Media Input',
  0x050A: 'Content Launcher',
  0x050B: 'Audio Output',
  0x050C: 'Application Launcher',
  0x050D: 'Application Basic',
  0x050E: 'Account Login',
};

const _kAttrNames = <int, Map<int, String>>{
  0x0006: {0x0000: 'OnOff', 0x4000: 'GlobalSceneControl', 0x4001: 'OnTime', 0x4002: 'OffWaitTime', 0x4003: 'StartUpOnOff'},
  0x0008: {0x0000: 'CurrentLevel', 0x0001: 'RemainingTime', 0x000F: 'Options', 0x0010: 'OnOffTransitionTime', 0x0011: 'OnLevel', 0x0012: 'OnTransitionTime', 0x0013: 'OffTransitionTime'},
  0x001D: {0x0000: 'DeviceTypeList', 0x0001: 'ServerList', 0x0002: 'ClientList', 0x0003: 'PartsList'},
  0x0028: {0x0000: 'DataModelRevision', 0x0001: 'VendorName', 0x0002: 'VendorID', 0x0003: 'ProductName', 0x0004: 'ProductID', 0x0005: 'NodeLabel', 0x0006: 'Location', 0x0007: 'HardwareVersion', 0x0008: 'HardwareVersionString', 0x0009: 'SoftwareVersion', 0x000A: 'SoftwareVersionString', 0x000B: 'ManufacturingDate', 0x000C: 'PartNumber', 0x000E: 'SerialNumber', 0x000F: 'LocalConfigDisabled', 0x0010: 'Reachable', 0x0011: 'UniqueID'},
  0x0030: {0x0000: 'Breadcrumb', 0x0001: 'BasicCommissioningInfo', 0x0002: 'RegulatoryConfig', 0x0003: 'LocationCapability', 0x0004: 'SupportsConcurrentConnection'},
  0x0031: {0x0000: 'MaxNetworks', 0x0001: 'Networks', 0x0002: 'ScanMaxTimeSeconds', 0x0003: 'ConnectMaxTimeSeconds', 0x0004: 'InterfaceEnabled', 0x0005: 'LastNetworkingStatus', 0x0006: 'LastNetworkID', 0x0007: 'LastConnectErrorValue'},
  0x0033: {0x0000: 'NetworkInterfaces', 0x0001: 'RebootCount', 0x0002: 'UpTime', 0x0003: 'TotalOperationalHours', 0x0004: 'BootReason', 0x0008: 'TestEventTriggersEnabled'},
  0x003E: {0x0000: 'NOCs', 0x0001: 'Fabrics', 0x0002: 'SupportedFabrics', 0x0003: 'CommissionedFabrics', 0x0004: 'TrustedRootCertificates', 0x0005: 'CurrentFabricIndex'},
  0x0046: {0x0000: 'IdleModeDuration', 0x0001: 'ActiveModeDuration', 0x0002: 'ActiveModeThreshold'},
  0x0201: {0x0000: 'LocalTemperature', 0x0001: 'OutdoorTemperature', 0x0003: 'AbsMinHeatSetpointLimit', 0x0004: 'AbsMaxHeatSetpointLimit', 0x0005: 'AbsMinCoolSetpointLimit', 0x0006: 'AbsMaxCoolSetpointLimit', 0x0010: 'LocalTemperatureCalibration', 0x0011: 'OccupiedCoolingSetpoint', 0x0012: 'OccupiedHeatingSetpoint', 0x0015: 'MinHeatSetpointLimit', 0x0016: 'MaxHeatSetpointLimit', 0x0017: 'MinCoolSetpointLimit', 0x0018: 'MaxCoolSetpointLimit', 0x001B: 'ControlSequenceOfOperation', 0x001C: 'SystemMode', 0x001E: 'ThermostatRunningMode', 0x0025: 'HVACSystemTypeConfiguration', 0x0029: 'SetpointChangeSource', 0x002A: 'SetpointChangeAmount', 0x002B: 'SetpointChangeSourceTimestamp'},
  0x0402: {0x0000: 'MeasuredValue', 0x0001: 'MinMeasuredValue', 0x0002: 'MaxMeasuredValue', 0x0003: 'Tolerance'},
  0x0405: {0x0000: 'MeasuredValue', 0x0001: 'MinMeasuredValue', 0x0002: 'MaxMeasuredValue', 0x0003: 'Tolerance'},
};

// Global attributes common to all clusters
const _kGlobalAttrs = <int, String>{
  0xFFF8: 'GeneratedCommandList',
  0xFFF9: 'AcceptedCommandList',
  0xFFFA: 'EventList',
  0xFFFB: 'AttributeList',
  0xFFFC: 'FeatureMap',
  0xFFFD: 'ClusterRevision',
};

// ── Command names per cluster ─────────────────────────────────────────────
const _kCommandNames = <int, Map<int, String>>{
  0x0003: {0: 'Identify', 1: 'TriggerEffect'},
  0x0004: {0: 'AddGroup', 1: 'ViewGroup', 2: 'GetGroupMembership', 3: 'RemoveGroup', 4: 'RemoveAllGroups', 5: 'AddGroupIfIdentifying'},
  0x0006: {0: 'Off', 1: 'On', 2: 'Toggle', 64: 'OffWithEffect', 65: 'OnWithRecallGlobalScene', 66: 'OnWithTimedOff'},
  0x0008: {0: 'MoveToLevel', 1: 'Move', 2: 'Step', 3: 'Stop', 4: 'MoveToLevelWithOnOff', 5: 'MoveWithOnOff', 6: 'StepWithOnOff', 7: 'StopWithOnOff'},
  0x001E: {0: 'Bind', 1: 'Unbind'},
  0x0028: {0: 'MfgSpecificPing'},
  0x002A: {0: 'AnnounceOTAProvider'},    // OTA Requestor — the key one
  0x0029: {0: 'QueryImage', 1: 'ApplyUpdateRequest', 2: 'NotifyUpdateApplied'},  // OTA Provider
  0x0030: {0: 'ArmFailSafe', 2: 'SetRegulatoryConfig', 4: 'CommissioningComplete'},
  0x0031: {0: 'ScanNetworks', 2: 'AddOrUpdateWiFiNetwork', 4: 'AddOrUpdateThreadNetwork', 6: 'RemoveNetwork', 8: 'ConnectNetwork', 10: 'ReorderNetwork'},
  0x003C: {0: 'OpenCommissioningWindow', 1: 'OpenBasicCommissioningWindow', 2: 'RevokeCommissioning'},
  0x003E: {0: 'AttestationRequest', 2: 'CertificateChainRequest', 4: 'CSRRequest', 6: 'AddNOC', 7: 'UpdateNOC', 9: 'UpdateFabricLabel', 10: 'RemoveFabric', 11: 'AddTrustedRootCertificate'},
  0x003F: {0: 'KeySetWrite', 1: 'KeySetRead', 3: 'KeySetRemove', 4: 'KeySetReadAllIndices'},
  0x0046: {0: 'RegisterClient', 2: 'UnregisterClient', 3: 'StayActiveRequest', 4: 'GetOperatingInfo'},
  0x0050: {0: 'ChangeToMode'},
  0x0101: {0: 'LockDoor', 1: 'UnlockDoor', 3: 'UnlockWithTimeout'},
  0x0102: {0: 'UpOrOpen', 1: 'DownOrClose', 2: 'StopMotion', 4: 'GoToLiftValue', 5: 'GoToLiftPercentage', 7: 'GoToTiltValue', 8: 'GoToTiltPercentage'},
  0x0201: {0: 'SetpointRaiseLower', 1: 'SetWeeklySchedule', 2: 'GetWeeklySchedule', 3: 'ClearWeeklySchedule'},
  0x0300: {0: 'MoveToHue', 1: 'MoveHue', 2: 'StepHue', 3: 'MoveToSaturation', 4: 'MoveSaturation', 5: 'StepSaturation', 6: 'MoveToHueAndSaturation', 7: 'MoveToColor', 8: 'MoveColor', 9: 'StepColor', 10: 'MoveToColorTemperature'},
};

// ── Feature-map bit names per cluster ────────────────────────────────────
const _kFeatureMapBits = <int, Map<int, String>>{
  0x0006: {0: 'Lighting', 2: 'DeadFrontBehavior', 3: 'OffOnly'},
  0x0008: {0: 'OnOff', 1: 'Lighting', 2: 'Frequency'},
  0x002A: {0: 'UpdateToken'},   // OTA Requestor
  0x0031: {0: 'WiFi', 1: 'Thread', 2: 'Ethernet'},
  0x003B: {0: 'LatchingSwitch', 1: 'MomentarySwitch', 2: 'MSRelease', 3: 'MSLongPress', 4: 'MSMultiPress'},
  0x0046: {0: 'CheckInProtocol', 1: 'UserActiveModeTrigger', 2: 'LongIdleTime', 3: 'MaximumCheckInBackOff'},
  0x0050: {0: 'OnOff'},
  0x0101: {0: 'PINCredential', 1: 'RFIDCredential', 2: 'FingerCredential', 7: 'Logging', 8: 'WeekDayAccess', 9: 'YearDayAccess', 10: 'HolidaySchedules', 11: 'Unbolting'},
  0x0201: {0: 'Heating', 1: 'Cooling', 2: 'Occupancy', 3: 'ScheduleConfiguration', 4: 'Setback', 5: 'AutoMode', 6: 'LocalTemperatureNotExposed'},
  0x0300: {0: 'HueSaturation', 1: 'EnhancedHue', 2: 'ColorLoop', 3: 'XY', 4: 'ColorTemperature'},
};

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ClusterInspectorScreen extends StatefulWidget {
  final MatterDevice device;
  const ClusterInspectorScreen({super.key, required this.device});

  @override
  State<ClusterInspectorScreen> createState() => _ClusterInspectorScreenState();
}

class _ClusterInspectorScreenState extends State<ClusterInspectorScreen> {
  late Future<List<Object>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Object>> _load() async {
    final channel = context.read<MatterChannel>();
    final jsonStr = await channel.readClusters(widget.device.nodeId);
    if (jsonStr == null || jsonStr == '[]') return [];

    final raw = json.decode(jsonStr) as List<dynamic>;

    // Group by endpoint → clusterId
    final Map<int, Map<int, _ClusterData>> byEpCluster = {};
    for (final entry in raw) {
      final ep  = (entry['endpoint'] as num).toInt();
      final cid = (entry['clusterId'] as num).toInt();
      final attrs = (entry['attributes'] as List<dynamic>)
          .map((a) => _AttrData(
                id: (a['id'] as num).toInt(),
                value: a['value']?.toString() ?? 'null',
              ))
          .toList();
      // Parse device types from the Descriptor cluster entry
      List<int>? deviceTypeIds;
      if (cid == 0x001D && entry['deviceTypes'] != null) {
        deviceTypeIds = (entry['deviceTypes'] as List<dynamic>)
            .map((e) => (e as num).toInt())
            .toList();
      }
      byEpCluster.putIfAbsent(ep, () => {})[cid] = _ClusterData(
        endpoint:      ep,
        clusterId:     cid,
        attributes:    attrs,
        deviceTypeIds: deviceTypeIds,
      );
    }

    // Build device-type map per endpoint (from Descriptor cluster)
    final Map<int, List<int>> epDeviceTypes = {
      for (final ep in byEpCluster.keys)
        ep: byEpCluster[ep]![0x001D]?.deviceTypeIds ?? [],
    };

    // Flatten into mixed list: _EndpointHeader + _ClusterData, sorted
    final items = <Object>[];
    final sortedEps = byEpCluster.keys.toList()..sort();
    for (final ep in sortedEps) {
      items.add(_EndpointHeader(
        endpoint:      ep,
        deviceTypeIds: epDeviceTypes[ep] ?? [],
      ));
      final clusters    = byEpCluster[ep]!;
      final sortedClusters = clusters.keys.toList()..sort();
      for (final cid in sortedClusters) {
        items.add(clusters[cid]!);
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.device.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Cluster Inspector · '
              '0x${widget.device.nodeId.toRadixString(16).padLeft(16, '0').toUpperCase()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: () => setState(() { _future = _load(); }),
          ),
        ],
      ),
      body: FutureBuilder<List<Object>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Reading all clusters…'),
                ],
              ),
            );
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No cluster data returned'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              if (item is _EndpointHeader) {
                return _EndpointHeaderTile(header: item);
              } else {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ClusterCard(data: item as _ClusterData),
                );
              }
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _AttrData {
  final int id;
  final String value;
  const _AttrData({required this.id, required this.value});
}

class _ClusterData {
  final int endpoint;
  final int clusterId;
  final List<_AttrData> attributes;
  /// Non-null only for the Descriptor cluster (0x001D) — the parsed device type IDs.
  final List<int>? deviceTypeIds;

  const _ClusterData({
    required this.endpoint,
    required this.clusterId,
    required this.attributes,
    this.deviceTypeIds,
  });

  String get clusterName =>
      _kClusterNames[clusterId] ??
      '0x${clusterId.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  String get hexId =>
      '0x${clusterId.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  String attrName(int attrId) {
    final clusterMap = _kAttrNames[clusterId];
    if (clusterMap != null && clusterMap.containsKey(attrId)) {
      return clusterMap[attrId]!;
    }
    if (_kGlobalAttrs.containsKey(attrId)) return _kGlobalAttrs[attrId]!;
    return '0x${attrId.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }
}

/// A synthetic list item that introduces a new endpoint section.
class _EndpointHeader {
  final int endpoint;
  final List<int> deviceTypeIds;
  const _EndpointHeader({required this.endpoint, required this.deviceTypeIds});
}

// ---------------------------------------------------------------------------
// Endpoint section header
// ---------------------------------------------------------------------------

class _EndpointHeaderTile extends StatelessWidget {
  final _EndpointHeader header;
  const _EndpointHeaderTile({required this.header});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── "ENDPOINT N" label ──────────────────────────────────────────
          Row(
            children: [
              Text(
                'ENDPOINT ${header.endpoint}',
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: cs.outlineVariant, thickness: 1)),
            ],
          ),

          // ── Device type chips ───────────────────────────────────────────
          if (header.deviceTypeIds.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: header.deviceTypeIds.map((id) {
                final name = _deviceTypeName(id);
                final hexId = '0x${id.toRadixString(16).toUpperCase().padLeft(4, '0')}';
                // Use a more prominent colour for application types, muted for infra types
                final isInfra = const {0x0011, 0x0016, 0x0014, 0x0012, 0x0013, 0x000E}
                    .contains(id);
                final bg = isInfra
                    ? cs.surfaceContainerHighest
                    : cs.primaryContainer;
                final fg = isInfra
                    ? cs.onSurfaceVariant
                    : cs.onPrimaryContainer;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isInfra ? cs.outlineVariant : cs.primary.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: tt.labelSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        hexId,
                        style: tt.labelSmall?.copyWith(
                          color: fg.withAlpha(150),
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cluster card widget
// ---------------------------------------------------------------------------

class _ClusterCard extends StatefulWidget {
  final _ClusterData data;
  const _ClusterCard({required this.data});

  @override
  State<_ClusterCard> createState() => _ClusterCardState();
}

class _ClusterCardState extends State<_ClusterCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final data = widget.data;

    // Non-global attributes first, then global
    final appAttrs = data.attributes
        .where((a) => !_kGlobalAttrs.containsKey(a.id))
        .toList();
    final globalAttrs = data.attributes
        .where((a) => _kGlobalAttrs.containsKey(a.id))
        .toList();

    return Card(
      color: cs.surfaceContainerHighest,
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Endpoint badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'EP${data.endpoint}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Cluster ID badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data.hexId,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(data.clusterName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    '${appAttrs.length} attr.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...appAttrs.map((a) => _AttrRow(
                attr: a, name: data.attrName(a.id),
                highlight: true, clusterId: data.clusterId)),
            if (globalAttrs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Text('Global attributes',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant)),
              ),
              ...globalAttrs.map((a) => _AttrRow(
                  attr: a, name: data.attrName(a.id),
                  highlight: false, clusterId: data.clusterId)),
            ],
          ],
        ],
      ),
    );
  }
}

class _AttrRow extends StatelessWidget {
  final _AttrData attr;
  final String    name;
  final bool      highlight;
  final int       clusterId;

  const _AttrRow({
    required this.attr,
    required this.name,
    required this.highlight,
    required this.clusterId,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Parse a Java list toString like "[0, 1, 4]" into integers.
  static List<int> _parseIntList(String raw) {
    return RegExp(r'\d+')
        .allMatches(raw)
        .map((m) => int.parse(m.group(0)!))
        .toList();
  }

  /// True when this attribute should get the command-chip rendering.
  bool get _isCommandList =>
      attr.id == 0xFFF8 || attr.id == 0xFFF9;   // Generated / Accepted

  bool get _isFeatureMap => attr.id == 0xFFFC;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hexAttr =
        '0x${attr.id.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    Widget valueWidget;

    if (_isCommandList) {
      valueWidget = _buildCommandChips(context, cs);
    } else if (_isFeatureMap) {
      valueWidget = _buildFeatureMapChips(context, cs);
    } else {
      valueWidget = Text(
        attr.value,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: highlight ? cs.primary : cs.onSurfaceVariant,
        ),
      );
    }

    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: '$name: ${attr.value}'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 1)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: (_isCommandList || _isFeatureMap)
            // Command lists / FeatureMap span full width below the label row
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    SizedBox(
                      width: 60,
                      child: Text(hexAttr,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: cs.onSurfaceVariant)),
                    ),
                    Text(name,
                        style: TextStyle(
                            fontSize: 13,
                            color: highlight ? cs.onSurface : cs.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 60),
                    child: valueWidget,
                  ),
                ],
              )
            // Plain attributes stay on one row
            : Row(children: [
                SizedBox(
                  width: 60,
                  child: Text(hexAttr,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: cs.onSurfaceVariant)),
                ),
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 13,
                          color: highlight ? cs.onSurface : cs.onSurfaceVariant)),
                ),
                const SizedBox(width: 8),
                Flexible(child: valueWidget),
              ]),
      ),
    );
  }

  Widget _buildCommandChips(BuildContext context, ColorScheme cs) {
    final ids   = _parseIntList(attr.value);
    final names = _kCommandNames[clusterId];
    if (ids.isEmpty) {
      return Text('(none)', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: ids.map((id) {
        final label = names?[id]
            ?? '0x${id.toRadixString(16).toUpperCase().padLeft(2, '0')}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSecondaryContainer)),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureMapChips(BuildContext context, ColorScheme cs) {
    final raw  = int.tryParse(attr.value) ?? 0;
    final bits = _kFeatureMapBits[clusterId];
    if (raw == 0) {
      return Text('0x00000000 (none)',
          style: TextStyle(
              fontFamily: 'monospace', fontSize: 11, color: cs.onSurfaceVariant));
    }
    final chips = <Widget>[];
    // Show hex value first
    chips.add(Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        '0x${raw.toRadixString(16).toUpperCase().padLeft(8, '0')}',
        style: TextStyle(
            fontFamily: 'monospace', fontSize: 11, color: cs.onSurfaceVariant),
      ),
    ));
    // Then one chip per set bit
    for (int b = 0; b < 32; b++) {
      if ((raw >> b) & 1 == 0) continue;
      final label = bits?[b] ?? 'bit$b';
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onPrimaryContainer)),
      ));
    }
    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }
}
