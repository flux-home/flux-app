import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/commissionable_device.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/matter_channel.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Matter sub-screen
// ---------------------------------------------------------------------------

/// Which device this Matter screen is about — the controller's fabric, or this
/// phone's own admin identity + commissioning.
enum MatterScope { controller, phone }

class MatterSettingsScreen extends StatefulWidget {
  const MatterSettingsScreen({super.key, this.scope = MatterScope.controller});

  final MatterScope scope;

  @override
  State<MatterSettingsScreen> createState() => _MatterSettingsScreenState();
}

class _MatterSettingsScreenState extends State<MatterSettingsScreen> {
  String? _hubFabricId;    // the controller's fabric (via CoAP)
  String? _phoneFabricId;  // this phone's own CHIP admin fabric
  bool _scanning = false;
  List<CommissionableDevice> _found = const [];
  String? _scanError;

  bool get _isController => widget.scope == MatterScope.controller;

  @override
  void initState() {
    super.initState();
    if (_isController) {
      // Hub fabric: MatterFabricPort is proxied from the controller.
      context.read<MatterFabricPort>().getFabricId().then((id) {
        if (mounted) setState(() => _hubFabricId = id ?? 'N/A');
      });
    } else {
      // This phone's own Matter fabric + commissionable scan (on-device CHIP).
      context.read<MatterChannel>().getFabricId().then((id) {
        if (mounted) setState(() => _phoneFabricId = id ?? 'N/A');
      });
      _scan();
    }
  }

  /// Commissionable-device scan is a *phone* capability (BLE / on-network),
  /// so it goes through MatterChannel — the controller can't scan for these.
  Future<void> _scan() async {
    setState(() { _scanning = true; _scanError = null; });
    try {
      final devices =
          await context.read<MatterChannel>().discoverCommissionableNodes();
      if (mounted) setState(() { _found = devices; _scanning = false; });
    } on Exception catch (e) {
      if (mounted) setState(() { _scanError = e.toString(); _scanning = false; });
    }
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all devices?'),
        content: const Text(
          'All devices will be removed from local storage. '
          'The physical devices are NOT factory-reset and must be '
          'unpaired manually before they can be re-commissioned.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      await context.read<DeviceProvider>().clearAllDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All devices cleared')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matter'),
        actions: _isController
            ? null
            : [
                IconButton(
                  icon: _scanning
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_outlined),
                  tooltip: 'Scan for devices',
                  onPressed: _scanning ? null : _scan,
                ),
              ],
      ),
      body: ListView(children: _isController ? _controllerBody(cs) : _phoneBody(cs)),
    );
  }

  // ── CONTROLLER: the home's real Matter fabric ─────────────────────────────
  List<Widget> _controllerBody(ColorScheme cs) => [
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            ListTile(
              leading: Icon(Icons.memory, color: cs.primary),
              title: const Text('Fabric ID'),
              subtitle: Text(_hubFabricId ?? '…',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              trailing: (_hubFabricId != null && _hubFabricId != 'N/A')
                  ? IconButton(icon: const Icon(Icons.copy_outlined), tooltip: 'Copy',
                      onPressed: () => _copy(_hubFabricId!, 'Fabric ID'))
                  : null,
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
            ListTile(
              dense: true,
              leading: Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
              title: Text("Your devices are commissioned onto the controller's fabric.",
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            ),
          ]),
        ),
        const SizedBox(height: 40),
      ];

  // ── THIS PHONE: its own admin identity + commissioning ────────────────────
  List<Widget> _phoneBody(ColorScheme cs) => [
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            ListTile(
              leading: Icon(Icons.vpn_key_outlined, color: cs.primary),
              title: const Text('Fabric ID'),
              subtitle: Text(_phoneFabricId ?? '…',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              trailing: (_phoneFabricId != null && _phoneFabricId != 'N/A')
                  ? IconButton(icon: const Icon(Icons.copy_outlined), tooltip: 'Copy',
                      onPressed: () => _copy(_phoneFabricId!, 'Fabric ID'))
                  : null,
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
            ListTile(
              dense: true,
              leading: Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
              title: Text(
                  "This phone's Matter admin identity — used to commission new devices onto the controller.",
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            ),
          ]),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: SectionLabel('Commissionable devices nearby')),
        _NearbyDevicesSection(devices: _found, scanning: _scanning, error: _scanError),
        const SizedBox(height: 24),
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 6), child: SectionLabel('Device management')),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            leading: Icon(Icons.delete_sweep_outlined, color: cs.error),
            title: Text('Clear local device cache', style: TextStyle(color: cs.error)),
            subtitle: const Text("Removes this phone's copies only — devices stay on the controller"),
            onTap: _clearAll,
          ),
        ),
        const SizedBox(height: 40),
      ];
}

// ---------------------------------------------------------------------------
// Nearby commissionable devices section
// ---------------------------------------------------------------------------

class _NearbyDevicesSection extends StatelessWidget {
  const _NearbyDevicesSection({
    required this.devices,
    required this.scanning,
    required this.error,
  });
  final List<CommissionableDevice> devices;
  final bool    scanning;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (scanning && devices.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ListTile(
          leading: const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Scanning…',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    if (error != null && devices.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ListTile(
          leading: Icon(Icons.error_outline, color: cs.error),
          title: const Text('Scan failed'),
          subtitle: Text(error!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
      );
    }

    if (devices.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ListTile(
          leading: Icon(Icons.wifi_find_outlined, color: cs.onSurfaceVariant),
          title: Text('No commissionable devices found',
              style: TextStyle(color: cs.onSurfaceVariant)),
          subtitle: Text('Tap ↻ to scan again',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (int i = 0; i < devices.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
            _CommissionableDeviceTile(device: devices[i]),
          ],
        ],
      ),
    );
  }
}

class _CommissionableDeviceTile extends StatelessWidget {
  const _CommissionableDeviceTile({required this.device});
  final CommissionableDevice device;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    IconData icon = Icons.device_unknown_outlined;
    if (device.deviceType > 0) {
      final dt = DeviceType.fromMatterDeviceTypeId(device.deviceType);
      if (dt != DeviceType.unknown) icon = dt.icon;
    }

    final hint = device.pairingHintText;

    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Row(
        children: [
          Expanded(
            child: Text(
              device.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (device.isIcd) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Battery / sleepy device',
              child: Icon(Icons.battery_4_bar_outlined,
                  size: 14, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (device.vendorId > 0)
            Text(
              'VID:0x${device.vendorId.toRadixString(16).toUpperCase().padLeft(4, "0")}'
              '  PID:0x${device.productId.toRadixString(16).toUpperCase().padLeft(4, "0")}',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11,
                  color: cs.onSurfaceVariant),
            ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 11,
                      color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    hint,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: device.isOpen
          ? Text(
              device.modeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: device.isEnhanced
                    ? Colors.green.shade400
                    : Colors.orange.shade400,
              ),
            )
          : null,
      isThreeLine: device.vendorId > 0 && hint != null,
    );
  }
}


// ---------------------------------------------------------------------------
// Thread sub-screen — auto-scans, shows PAN names only
// ---------------------------------------------------------------------------

/// Merged view of a Thread network: mDNS-discovered border routers + optional
