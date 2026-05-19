import 'package:flutter/material.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/models/wifi_network.dart';
import 'package:matter_home/services/wifi_scan_service.dart';
import 'package:matter_home/ui/screens/commission/thread_dataset_header.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Network credentials section
// ─────────────────────────────────────────────────────────────────────────────

class NetworkSection extends StatefulWidget {
  const NetworkSection({
    required this.netType,
    required this.threadCtrl,
    required this.ssidCtrl,
    required this.passCtrl,
    required this.showThreadDataset,
    required this.showPassword,
    required this.onNetTypeChanged,
    required this.onShowDatasetChanged,
    required this.onShowPasswordChanged,
    required this.onDatasetChanged,
    this.activeDataset,
    super.key,
  });
  final int netType;
  final TextEditingController threadCtrl;
  final TextEditingController ssidCtrl;
  final TextEditingController passCtrl;
  final bool showThreadDataset;
  final bool showPassword;
  final ThreadDataset? activeDataset;
  final ValueChanged<int> onNetTypeChanged;
  final ValueChanged<bool> onShowDatasetChanged;
  final ValueChanged<bool> onShowPasswordChanged;
  final ValueChanged<ThreadDataset> onDatasetChanged;

  @override
  State<NetworkSection> createState() => _NetworkSectionState();
}

class _NetworkSectionState extends State<NetworkSection> {
  List<WifiNetwork> _networks       = [];
  bool              _loadingNetworks = false;
  WifiNetwork?      _selected;

  @override
  void initState() {
    super.initState();
    if (widget.netType == 1) _loadNetworks();
  }

  @override
  void didUpdateWidget(NetworkSection old) {
    super.didUpdateWidget(old);
    if (widget.netType == 1 && old.netType != 1 && _networks.isEmpty) {
      _loadNetworks();
    }
  }

  Future<void> _loadNetworks() async {
    if (_loadingNetworks) return;
    setState(() => _loadingNetworks = true);

    final result = await context.read<WifiScanService>().scan();
    if (!mounted) return;

    if (result.permissionDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.permanentlyDenied
                ? 'Location permission permanently denied — open Settings to enable Wi-Fi scanning.'
                : 'Location permission is required to scan for Wi-Fi networks.',
          ),
          action: result.permanentlyDenied ? const SnackBarAction(label: 'Settings', onPressed: openAppSettings) : null,
        ),
      );
      setState(() => _loadingNetworks = false);
      return;
    }

    setState(() {
      _networks = result.networks;
      _loadingNetworks = false;
      if (_selected == null && widget.ssidCtrl.text.isEmpty && result.autoSelected != null) {
        _pickNetwork(result.autoSelected!);
      }
    });
  }

  void _pickNetwork(WifiNetwork net) {
    setState(() => _selected = net);
    widget.ssidCtrl.text = net.ssid;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Type selector ──────────────────────────────────────────
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, icon: Icon(Icons.memory_outlined, size: 16), label: Text('Thread')),
                ButtonSegment(value: 1, icon: Icon(Icons.wifi_outlined, size: 16), label: Text('Wi-Fi')),
                ButtonSegment(value: 2, icon: Icon(Icons.lan_outlined, size: 16), label: Text('None')),
              ],
              selected: {widget.netType},
              onSelectionChanged: (s) => widget.onNetTypeChanged(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 14),

            // ── Thread ─────────────────────────────────────────────────
            if (widget.netType == 0) ...[
              ThreadDatasetHeader(
                activeDataset: widget.activeDataset,
                threadCtrl: widget.threadCtrl,
                showHex: widget.showThreadDataset,
                onToggleHex: () => widget.onShowDatasetChanged(!widget.showThreadDataset),
                onDatasetChanged: widget.onDatasetChanged,
              ),
            ],

            // ── Wi-Fi ──────────────────────────────────────────────────
            if (widget.netType == 1) ...[
              DropdownButtonFormField<String>(
                initialValue: _selected?.ssid,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi network',
                  prefixIcon: _loadingNetworks
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : const Icon(Icons.wifi_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh_outlined, size: 20),
                    tooltip: 'Rescan',
                    onPressed: _loadingNetworks ? null : _loadNetworks,
                  ),
                ),
                hint: Text(_loadingNetworks ? 'Scanning…' : 'Select a network'),
                items: _networks
                    .map(
                      (net) => DropdownMenuItem(
                        value: net.ssid,
                        child: Row(
                          children: [
                            _WifiSignalIcon(bars: net.bars, color: cs.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Expanded(child: Text(net.ssid, overflow: TextOverflow.ellipsis)),
                            if (net.isConnected) ...[
                              const SizedBox(width: 6),
                              Text('connected', style: TextStyle(fontSize: 11, color: cs.primary)),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (ssid) {
                  if (ssid == null) return;
                  final net = _networks.firstWhere((n) => n.ssid == ssid);
                  _pickNetwork(net);
                },
                validator: (v) => (v == null || v.isEmpty) ? 'Select a network' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: widget.passCtrl,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(widget.showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => widget.onShowPasswordChanged(!widget.showPassword),
                  ),
                ),
                obscureText: !widget.showPassword,
                textInputAction: TextInputAction.done,
                validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
              ),
            ],

            // ── None ───────────────────────────────────────────────────
            if (widget.netType == 2)
              Text(
                'No network credentials — for Ethernet-only devices.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Wi-Fi signal icon ─────────────────────────────────────────────────────────

class _WifiSignalIcon extends StatelessWidget {
  const _WifiSignalIcon({required this.bars, required this.color});
  final int   bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = switch (bars) {
      4 || 3 => Icons.wifi,
      2      => Icons.wifi_2_bar,
      1      => Icons.wifi_1_bar,
      _      => Icons.wifi_off_outlined,
    };
    final opacity = bars >= 3 ? 1.0 : bars == 2 ? 0.75 : 0.5;
    return Icon(icon, size: 18, color: color.withValues(alpha: opacity));
  }
}
