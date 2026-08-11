import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/thermostat_models.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/energy_role.dart';
import 'package:matter_home/models/switch_group.dart';
import 'package:collection/collection.dart';
import 'package:matter_home/services/cluster_parser.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/ui/screens/cluster_inspector_screen.dart';
import 'package:matter_home/ui/widgets/info_row.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main settings screen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({required this.device, super.key});
  final MatterDevice device;

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  bool _identifying = false;

  Future<void> _identify(MatterDevice d) async {
    if (_identifying) return;
    setState(() => _identifying = true);
    await context.read<MatterClusterPort>().identify(d.nodeId);
    await Future<void>.delayed(const Duration(seconds: 15));
    if (mounted) setState(() => _identifying = false);
  }

  Future<void> _remove(BuildContext context, MatterDevice d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove device?'),
        content: Text(
          '"${d.name}" will be removed from this fabric. '
          'The device will need to be factory-reset before it can be re-commissioned.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && context.mounted) {
      await context.read<DeviceProvider>().removeDevice(d.id);
      if (context.mounted) context.go('/');
    }
  }

  Future<void> _rename(BuildContext context) async {
    final ctrl = TextEditingController(text: widget.device.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Device name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && context.mounted) {
      await context.read<DeviceProvider>().renameDevice(widget.device.id, newName);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        final d = provider.findById(widget.device.id) ?? widget.device;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Device settings', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.drive_file_rename_outline_outlined),
                tooltip: 'Rename',
                onPressed: () => _rename(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Identify + Share buttons ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _identifying ? null : () => _identify(d),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _identifying
                                ? const SizedBox(
                                    key: ValueKey('spinner'),
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.lightbulb_outline,
                                    key: ValueKey('icon'), size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(_identifying ? 'Identifying…' : 'Identify'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Room ─────────────────────────────────────────────────────────
              const SectionLabel('Room'),
              _RoomTile(device: d),
              const SizedBox(height: 20),

              // ── Energy role ───────────────────────────────────────────────
              // Shown for anything that measures power/energy — either by device
              // type or because it's actively reporting active power (some energy
              // devices commission as an "unknown" type). Matches the gate the
              // device-detail EnergyCard uses. Drives the home energy-flow overview.
              if (d.deviceType.hasEnergyMeasurement ||
                  (context.watch<DeviceProvider>().viewFor(d.id)?.hasLivePower ?? false)) ...[
                const SectionLabel('Energy role'),
                _EnergyRoleTile(device: d),
                const SizedBox(height: 20),
              ],

              // ── Tools ─────────────────────────────────────────────────────
              // ── Battery ───────────────────────────────────────────────────────────
              if (context.watch<DeviceProvider>().viewFor(d.id)?.batteryInfo
                  case final BatteryInfo bat when bat.hasData) ...[
                const SectionLabel('Battery'),
                _BatteryCard(battery: bat),
                const SizedBox(height: 20),
              ],

              // ── Linked devices ────────────────────────────────────────────
              if (d.deviceType.isSwitch || d.deviceType == DeviceType.contactSensor) ...[
                const SectionLabel('Linked devices'),
                _AutomationsSummaryTile(device: d),
                const SizedBox(height: 20),
              ],

              const SectionLabel('Tools'),
              Card(
                color: cs.surface,
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: cs.primary),
                  title: const Text('Device info'),
                  subtitle: const Text('Type, node ID, hardware, clusters'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DeviceInfoScreen(device: d),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Remove device ─────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: () => _remove(context, d),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove device'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withAlpha(120)),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Room tile + picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.device});
  final MatterDevice device;

  Future<void> _showSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _RoomPickerSheet(deviceId: device.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final d        = provider.findById(device.id) ?? device;
    final rooms    = provider.rooms;
    final room     = rooms.firstWhere(
      (r) => r.id == d.roomId,
      orElse: () => rooms.first,
    );

    return Card(
      color: cs.surface,
      child: ListTile(
        leading: Icon(Icons.meeting_room_outlined, color: cs.primary),
        title: Text(room.name),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        onTap: () => _showSheet(context),
      ),
    );
  }
}

class _RoomPickerSheet extends StatefulWidget {
  const _RoomPickerSheet({required this.deviceId});
  final String deviceId;

  @override
  State<_RoomPickerSheet> createState() => _RoomPickerSheetState();
}

class _RoomPickerSheetState extends State<_RoomPickerSheet> {
  Future<void> _createRoom(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New room'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Room name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final room = await context.read<DeviceProvider>().createRoom(name);
    if (!context.mounted) return;
    if (room == null) {
      // The controller issues room ids, so an unreachable controller means the
      // room genuinely does not exist yet — better to say so than to show one
      // that would vanish on the next sync.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't reach the controller — room not created")));
      return;
    }
    await context.read<DeviceProvider>().assignRoom(widget.deviceId, room.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final device   = provider.findById(widget.deviceId);
    final rooms    = provider.rooms;
    final currentRoomId = device?.roomId ?? rooms.first.id;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'Room',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final room in rooms)
                  RadioListTile<int>(
                    value:      room.id,
                    groupValue: currentRoomId,
                    secondary:  Icon(
                      Icons.meeting_room_outlined,
                      color: room.id == currentRoomId
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    title: Text(room.name),
                    onChanged: (_) async {
                      await provider.assignRoom(widget.deviceId, room.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.add_circle_outline, color: cs.primary),
                  title: Text(
                    'New room',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => _createRoom(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Energy role tile + picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EnergyRoleTile extends StatelessWidget {
  const _EnergyRoleTile({required this.device});
  final MatterDevice device;

  Future<void> _showSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EnergyRolePickerSheet(deviceId: device.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final d        = provider.findById(device.id) ?? device;
    final role     = d.energyRole;

    return Card(
      color: cs.surface,
      child: ListTile(
        leading: Icon(role.icon, color: cs.primary),
        title: Text(role == EnergyRole.none ? 'Not in energy overview' : role.label),
        subtitle: Text(role == EnergyRole.none
            ? 'Tap to add to the home energy flow'
            : 'Shown on the home energy flow'),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        onTap: () => _showSheet(context),
      ),
    );
  }
}

class _EnergyRolePickerSheet extends StatelessWidget {
  const _EnergyRolePickerSheet({required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final provider    = context.watch<DeviceProvider>();
    final device      = provider.findById(deviceId);
    final currentRole = device?.energyRole ?? EnergyRole.none;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'Energy role',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final role in EnergyRole.assignable)
                  RadioListTile<EnergyRole>(
                    value:      role,
                    groupValue: currentRole,
                    secondary:  Icon(
                      role.icon,
                      color: role == currentRole ? cs.primary : cs.onSurfaceVariant,
                    ),
                    title: Text(role == EnergyRole.none ? 'Not in energy overview' : role.label),
                    onChanged: (_) async {
                      await provider.assignEnergyRole(deviceId, role);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device info sub-screen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({required this.device, super.key});
  final MatterDevice device;

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final view = context.watch<DeviceProvider>().viewFor(widget.device.id);

    final rows = <Widget>[];
    void add(String label, String? value, {bool mono = false, bool link = false}) {
      if (value == null || value.isEmpty) return;
      rows.add(InfoRow(label: label, value: value, mono: mono, link: link));
    }

    add('Product',    view?.displayProductName);
    add('Vendor',     view?.vendorName);
    add('Product ID', view?.productId,   mono: true);
    add('Part no.',   view?.partNumber);
    add('Hardware',   view?.hwVersion);
    add('Firmware',   view?.softwareVersion);
    add('Mfg. date',  view?.manufacturingDate);
    add('Type',       widget.device.deviceType.displayName);
    add('Network',    widget.device.networkType == NetworkType.unknown
        ? null : widget.device.networkType.label);
    add('Node ID', '0x${widget.device.nodeId.toRadixString(16).padLeft(16, '0').toUpperCase()}',
        mono: true);
    add('Commissioned', _formatDate(widget.device.commissionedAt));
    add('Serial no.', view?.serialNumber, mono: true);
    add('Unique ID',  view?.uniqueId,     mono: true);
    add('Product URL', view?.productUrl, link: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device info', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Identity / versions ───────────────────────────────────────────
          Card(
            color: cs.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: rows.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Loading…', style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : Column(children: rows),
            ),
          ),

          // ── Diagnostics / inspect ─────────────────────────────────────────
          // Thread diagnostics and Matter cluster inspection are meaningless for
          // Modbus devices (no Thread mesh, no Matter clusters), so hide the whole
          // card for them.
          if (!widget.device.isModbus) ...[
            const SizedBox(height: 20),
            Card(
              color: cs.surface,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.manage_search, color: cs.primary),
                    title: const Text('Inspect clusters'),
                    subtitle: const Text('View all Matter clusters and attributes'),
                    trailing: const Icon(Icons.chevron_right),
                    // Sole tile in the card now that Thread diagnostics is gone.
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ClusterInspectorScreen(device: widget.device),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.battery});
  final BatteryInfo battery;

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final pct = battery.percent;
    final lvl = battery.chargeLevel;
    final Color color;
    final IconData icon;
    if (pct != null) {
      color = pct > 60 ? Colors.green.shade400
            : pct > 20 ? Colors.orange.shade400
            : Colors.red.shade400;
      icon  = pct > 60 ? Icons.battery_full
            : pct > 20 ? Icons.battery_3_bar
            : Icons.battery_alert;
    } else {
      color = lvl == 0 ? Colors.green.shade400
            : lvl == 1 ? Colors.orange.shade400
            : Colors.red.shade400;
      icon  = lvl == 0 ? Icons.battery_full
            : lvl == 1 ? Icons.battery_3_bar
            : Icons.battery_alert;
    }
    final String label;
    if (pct != null) {
      label = '$pct %';
    } else {
      label = switch (lvl) { 0 => 'OK', 1 => 'Warning', 2 => 'Critical', _ => 'Unknown' };
    }
    return Card(
      color: cs.surface,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: pct != null
            ? LinearProgressIndicator(
                value: pct / 100.0,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linked devices summary tile → pushes to connections screen
// ─────────────────────────────────────────────────────────────────────────────

class _AutomationsSummaryTile extends StatelessWidget {
  const _AutomationsSummaryTile({required this.device});
  final MatterDevice device;

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final connections = context.watch<DeviceProvider>().connectionsFor(device.id);
    final targetIds   = connections.map((c) => c.targetDeviceId).toSet().toList();

    return Card(
      color: cs.surface,
      child: ListTile(
        title: targetIds.isEmpty
            ? Text('No linked devices',
                style: TextStyle(color: cs.onSurfaceVariant))
            : Wrap(
                spacing: 6, runSpacing: 4,
                children: _DeviceChips(deviceIds: targetIds).chips(context),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _ConnectionsScreen(device: device),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connections screen — one card per (target device × slot)
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionsScreen extends StatelessWidget {
  const _ConnectionsScreen({required this.device});
  final MatterDevice device;

  List<SwitchGroup> _groups(DeviceProvider provider) {
    final json = provider.clusterCacheFor(device.id);
    if (json == null) return [];
    return extractSwitchGroups(
        extractReadings(parseClusters(json), device.deviceType));
  }

  @override
  Widget build(BuildContext context) {
    final provider    = context.watch<DeviceProvider>();
    final connections = provider.connectionsFor(device.id);
    final groups      = _groups(provider);
    final cs          = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Linked devices')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          for (final conn in connections)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ConnectionCard(
                source:     device,
                connection: conn,
                groups:     groups,
              ),
            ),
          const SizedBox(height: 4),
          if (groups.isEmpty && device.deviceType.isSwitch)
              Card(
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16,
                          color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Open the device screen first so button data can load.',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          Card(
            color: cs.surface,
            child: ListTile(
              leading: Icon(Icons.add_circle_outline, color: cs.primary),
              title: const Text('Connect a device'),
              enabled: !device.deviceType.isSwitch || groups.isNotEmpty,
              onTap: groups.isNotEmpty || !device.deviceType.isSwitch
                  ? () => showModalBottomSheet<void>(
                      context:            context,
                      isScrollControlled: true,
                      useSafeArea:        true,
                      backgroundColor:    cs.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      builder: (_) => _AddConnectionSheet(
                        source: device,
                        groups: groups,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection card: target device + gesture summary + edit tap
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.source,
    required this.connection,
    required this.groups,
  });
  final MatterDevice       source;
  final DeviceConnection   connection;
  final List<SwitchGroup>  groups;

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final view   = context.read<DeviceProvider>().viewFor(connection.targetDeviceId);
    if (view == null) return const SizedBox.shrink();

    // Gesture summary pills
    final pills = <Widget>[];
    for (final rule in connection.rules) {
      pills.add(_GesturePill(rule: rule));
    }

    return Card(
      color: cs.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet<void>(
          context:            context,
          isScrollControlled: true,
          useSafeArea:        true,
          backgroundColor:    cs.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (_) => _ConnectionDetailSheet(
            source:     source,
            connection: connection,
            targetView: view,
            groups:     groups,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Device icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(view.deviceType.icon,
                    size: 20, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              // Name + pills
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(view.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        if (connection.switchGroup != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Slot ${connection.switchGroup}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSecondaryContainer)),
                          ),
                      ],
                    ),
                    if (pills.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: pills),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gesture pill — compact label for a rule in the connection card
// ─────────────────────────────────────────────────────────────────────────────

class _GesturePill extends StatelessWidget {
  const _GesturePill({required this.rule});
  final AutomationRule rule;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_triggerIcon(rule.trigger), size: 11,
              color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(rule.action.label,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

IconData _triggerIcon(TriggerType t) => switch (t) {
  TriggerType.switchPress  => Icons.radio_button_checked_outlined,
  TriggerType.switchCw     => Icons.keyboard_arrow_up,
  TriggerType.switchCcw    => Icons.keyboard_arrow_down,
  TriggerType.contactOpen  => Icons.meeting_room_outlined,
  TriggerType.contactClose => Icons.sensor_door_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────
// Connection detail sheet — per-gesture action dropdowns + delete
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionDetailSheet extends StatefulWidget {
  const _ConnectionDetailSheet({
    required this.source,
    required this.connection,
    required this.targetView,
    required this.groups,
  });
  final MatterDevice      source;
  final DeviceConnection  connection;
  final DeviceView        targetView;
  final List<SwitchGroup> groups;

  @override
  State<_ConnectionDetailSheet> createState() => _ConnectionDetailSheetState();
}

class _ConnectionDetailSheetState extends State<_ConnectionDetailSheet> {
  // mutable state: trigger → selected action (null = disabled)
  late final Map<TriggerType, AutomationAction?> _selections;

  @override
  void initState() {
    super.initState();
    _selections = {};
    for (final rule in widget.connection.rules) {
      _selections[rule.trigger] = rule.action;
    }
  }

  List<TriggerType> get _triggers {
    if (widget.source.deviceType == DeviceType.contactSensor) {
      return [TriggerType.contactOpen, TriggerType.contactClose];
    }
    final group = widget.groups.firstWhereOrNull(
        (g) => g.label == widget.connection.switchGroup);
    if (group == null) return [TriggerType.switchPress];
    return [
      if (group.pressEndpoints.isNotEmpty) TriggerType.switchPress,
      if (group.cwEndpoints.isNotEmpty)    TriggerType.switchCw,
      if (group.ccwEndpoints.isNotEmpty)   TriggerType.switchCcw,
    ];
  }

  bool get _hasOnOff   => widget.targetView.deviceType.hasOnOff   ||
      (context.read<DeviceProvider>()
          .liveDataFor(widget.targetView.id)?.attrs.containsKey('onOff') ?? false);
  bool get _hasBrightness => widget.targetView.deviceType.hasBrightness ||
      (context.read<DeviceProvider>()
          .liveDataFor(widget.targetView.id)?.attrs.containsKey('level') ?? false);
  bool get _isThermostat  => widget.targetView.deviceType == DeviceType.thermostat ||
      (context.read<DeviceProvider>()
          .liveDataFor(widget.targetView.id)?.attrs.containsKey('localTempCenti') ?? false);

  void _save() {
    final provider = context.read<DeviceProvider>();
    // Delete all existing rules for this connection then recreate from selections.
    provider.disconnectTarget(
      sourceDeviceId: widget.source.id,
      targetDeviceId: widget.connection.targetDeviceId,
      switchGroup:    widget.connection.switchGroup,
    );
    final group = widget.groups.firstWhereOrNull(
        (g) => g.label == widget.connection.switchGroup);
    for (final entry in _selections.entries) {
      final action = entry.value;
      if (action == null) continue;
      provider.upsertRule(AutomationRule(
        sourceDeviceId: widget.source.id,
        trigger:        entry.key,
        switchGroup:    widget.connection.switchGroup,
        endpoints:      _endpointsFor(entry.key, group),
        action:         action,
        targetDeviceIds: [widget.connection.targetDeviceId],
      ));
    }
    Navigator.pop(context);
  }

  List<int> _endpointsFor(TriggerType t, SwitchGroup? group) => switch (t) {
    TriggerType.switchPress => group?.pressEndpoints ?? [],
    TriggerType.switchCw    => group?.cwEndpoints    ?? [],
    TriggerType.switchCcw   => group?.ccwEndpoints   ?? [],
    _                       => [],
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final triggers = _triggers;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.targetView.deviceType.icon,
                      size: 18, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.targetView.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (widget.connection.switchGroup != null)
                      Text('Slot ${widget.connection.switchGroup}',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                )),
              ]),
            ),
            const Divider(height: 24, indent: 24, endIndent: 24),
            // Gesture rows
            for (final trigger in triggers)
              _GestureActionRow(
                trigger:     trigger,
                selected:    _selections[trigger],
                actions:     actionsFor(
                  trigger:       trigger,
                  hasOnOff:      _hasOnOff,
                  hasBrightness: _hasBrightness,
                  isThermostat:  _isThermostat,
                ),
                onChanged: (a) => setState(() => _selections[trigger] = a),
              ),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(children: [
                OutlinedButton.icon(
                  icon:  const Icon(Icons.link_off, size: 16),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error),
                  ),
                  onPressed: () {
                    context.read<DeviceProvider>().disconnectTarget(
                      sourceDeviceId: widget.source.id,
                      targetDeviceId: widget.connection.targetDeviceId,
                      switchGroup:    widget.connection.switchGroup,
                    );
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// One gesture row inside the detail sheet
class _GestureActionRow extends StatelessWidget {
  const _GestureActionRow({
    required this.trigger,
    required this.selected,
    required this.actions,
    required this.onChanged,
  });
  final TriggerType              trigger;
  final AutomationAction?        selected;
  final List<AutomationAction?>  actions;
  final ValueChanged<AutomationAction?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (actions.isEmpty || (actions.length == 1 && actions.first == null)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(children: [
        Icon(_triggerIcon(trigger), size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(trigger.label,
              style: TextStyle(fontSize: 13, color: cs.onSurface)),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AutomationAction?>(
              value:        actions.contains(selected) ? selected : null,
              isExpanded:   true,
              style:        TextStyle(fontSize: 13, color: cs.onSurface),
              dropdownColor: cs.surfaceContainerHigh,
              items: [
                for (final a in actions)
                  DropdownMenuItem(
                    value: a,
                    child: Text(
                      a?.label ?? '— none —',
                      style: TextStyle(
                          fontSize: 13,
                          color: a == null
                              ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                              : cs.onSurface),
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add connection sheet — pick a target device, smart preset applied
// ─────────────────────────────────────────────────────────────────────────────

class _AddConnectionSheet extends StatelessWidget {
  const _AddConnectionSheet({required this.source, required this.groups});
  final MatterDevice      source;
  final List<SwitchGroup> groups;

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    // All devices that have at least one compatible action, excluding self.
    final candidates = provider.linkableTargets(excludingDeviceId: source.id);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text('Connect a device',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text('No compatible devices found.',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (_, i) {
                    final v = candidates[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(v.deviceType.icon,
                            size: 18, color: cs.onPrimaryContainer),
                      ),
                      title:    Text(v.name),
                      subtitle: Text(v.deviceType.displayName,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      onTap: () {
                        provider.connectDevice(
                          sourceDeviceId: source.id,
                          sourceType:     source.deviceType,
                          targetDeviceId: v.id,
                          switchGroups:   groups,
                        );
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device chips helper (used in summary tile)
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceChips {
  const _DeviceChips({required this.deviceIds});
  final List<String> deviceIds;

  List<Widget> chips(BuildContext context) {
    final provider = context.read<DeviceProvider>();
    return [
      for (final id in deviceIds)
        if (provider.viewFor(id) case final view?)
          Chip(
            label:    Text(view.name, style: const TextStyle(fontSize: 11)),
            avatar:   Icon(view.deviceType.icon, size: 13),
            padding:  const EdgeInsets.symmetric(horizontal: 4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
    ];
  }
}
