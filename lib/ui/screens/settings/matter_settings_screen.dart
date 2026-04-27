import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/commissionable_device.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Matter sub-screen
// ---------------------------------------------------------------------------

class MatterSettingsScreen extends StatefulWidget {
  const MatterSettingsScreen({super.key});

  @override
  State<MatterSettingsScreen> createState() => _MatterSettingsScreenState();
}

class _MatterSettingsScreenState extends State<MatterSettingsScreen> {
  String? _fabricId;
  bool _scanning = false;
  List<CommissionableDevice> _found = const [];
  String? _scanError;

  @override
  void initState() {
    super.initState();
    context.read<MatterFabricPort>().getFabricId().then((id) {
      if (mounted) setState(() => _fabricId = id ?? 'N/A');
    });
    _scan();
  }

  Future<void> _scan() async {
    setState(() { _scanning = true; _scanError = null; });
    try {
      final devices = await context
          .read<MatterFabricPort>()
          .discoverCommissionableNodes();
      if (mounted) setState(() { _found = devices; _scanning = false; });
    } on Exception catch (e) {
      if (mounted) setState(() { _scanError = e.toString(); _scanning = false; });
    }
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
        actions: [
          IconButton(
            icon: _scanning
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_outlined),
            tooltip: 'Scan for devices',
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 6), child: SectionLabel('Fabric')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.vpn_key_outlined, color: cs.primary),
                  title: const Text('Fabric ID'),
                  subtitle: Text(
                    _fabricId ?? '…',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                  trailing: _fabricId != null && _fabricId != 'N/A'
                      ? IconButton(
                          icon: const Icon(Icons.copy_outlined),
                          tooltip: 'Copy',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _fabricId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fabric ID copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        )
                      : null,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 6), child: SectionLabel('Nearby devices')),
          _NearbyDevicesSection(
            devices:  _found,
            scanning: _scanning,
            error:    _scanError,
          ),

          const SizedBox(height: 24),
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 6), child: SectionLabel('Device management')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: Icon(Icons.delete_sweep_outlined, color: cs.error),
              title: Text('Clear all devices',
                  style: TextStyle(color: cs.error)),
              subtitle: const Text('Remove from local storage only'),
              onTap: _clearAll,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
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

    final (modeColor, modeIcon) = device.isEnhanced
        ? (Colors.green.shade500, Icons.lock_open_outlined)
        : device.isBasic
        ? (Colors.orange.shade500, Icons.lock_open_outlined)
        : (cs.onSurfaceVariant, Icons.lock_outlined);

    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(
        device.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (device.ipAddress.isNotEmpty)
            Text(
              '${device.ipAddress}:${device.port}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          if (device.vendorId > 0)
            Text(
              'VID:0x${device.vendorId.toRadixString(16).toUpperCase().padLeft(4, "0")}  '
              'PID:0x${device.productId.toRadixString(16).toUpperCase().padLeft(4, "0")}',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11,
                  color: cs.onSurfaceVariant),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(modeIcon, size: 14, color: modeColor),
          const SizedBox(width: 4),
          Text(
            device.modeLabel,
            style: TextStyle(fontSize: 11, color: modeColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      isThreeLine: device.ipAddress.isNotEmpty && device.vendorId > 0,
    );
  }
}


// ---------------------------------------------------------------------------
// Thread sub-screen — auto-scans, shows PAN names only
// ---------------------------------------------------------------------------

/// Merged view of a Thread network: mDNS-discovered border routers + optional
