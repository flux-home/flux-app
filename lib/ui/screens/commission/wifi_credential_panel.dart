import 'package:flutter/material.dart';
import 'package:matter_home/models/wifi_network.dart';
import 'package:matter_home/services/wifi_scan_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Wi-Fi credential panel  (bottom-sheet body)
// ─────────────────────────────────────────────────────────────────────────────

class WifiCredentialPanel extends StatefulWidget {
  const WifiCredentialPanel({
    required this.ssidCtrl,
    required this.passCtrl,
    required this.onConfirm,
    super.key,
  });
  final TextEditingController ssidCtrl;
  final TextEditingController passCtrl;
  final VoidCallback           onConfirm;

  @override
  State<WifiCredentialPanel> createState() => _WifiCredentialPanelState();
}

class _WifiCredentialPanelState extends State<WifiCredentialPanel> {
  bool             _showPassword   = false;
  bool             _loadingNetworks = true;
  List<WifiNetwork> _networks       = [];

  @override
  void initState() {
    super.initState();
    _scanNetworks();
  }

  Future<void> _scanNetworks() async {
    final result = await context.read<WifiScanService>().scan();
    if (!mounted) return;
    setState(() {
      _networks        = result.networks;
      _loadingNetworks = false;
      if (widget.ssidCtrl.text.isEmpty && result.autoSelected != null) {
        widget.ssidCtrl.text = result.autoSelected!.ssid;
      }
    });
  }

  static InputDecoration _fieldDeco(String hint, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
    filled: true,
    fillColor: Colors.white10,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: Colors.white24, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: Colors.white24, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: Colors.white60, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    suffixIcon: suffix,
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withAlpha(240),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),

          // ── SSID ──────────────────────────────────────────────────────────
          if (_loadingNetworks)
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: const Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38),
                ),
              ),
            )
          else if (_networks.isEmpty)
            TextField(
              controller: widget.ssidCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: _fieldDeco('Network name (SSID)'),
              textInputAction: TextInputAction.next,
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _networks.any((n) => n.ssid == widget.ssidCtrl.text) ? widget.ssidCtrl.text : null,
              hint: const Text('Select network', style: TextStyle(color: Colors.white38, fontSize: 14)),
              dropdownColor: Colors.grey.shade900,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              icon: const Icon(Icons.expand_more, color: Colors.white38),
              decoration: _fieldDeco(''),
              isExpanded: true,
              items: _networks
                  .map(
                    (n) => DropdownMenuItem(
                      value: n.ssid,
                      child: Row(
                        children: [
                          Icon(
                            n.rssi > -60 ? Icons.wifi : n.rssi > -75 ? Icons.wifi_2_bar : Icons.wifi_1_bar,
                            size: 16,
                            color: n.isConnected ? Colors.white70 : Colors.white38,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(n.ssid, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: n.isConnected ? Colors.white : Colors.white70)),
                          ),
                          if (n.isConnected) const Text(' ✓', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  widget.ssidCtrl.text = v;
                  setState(() {});
                }
              },
            ),

          const SizedBox(height: 10),

          // ── Password ───────────────────────────────────────────────────────
          TextField(
            controller: widget.passCtrl,
            obscureText: !_showPassword,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _fieldDeco(
              'Password',
              suffix: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => widget.onConfirm(),
          ),

          const SizedBox(height: 16),

          // ── Connect ────────────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onConfirm,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Center(
                child: Text(
                  'Connect',
                  style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
