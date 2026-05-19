import 'package:flutter/material.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/ui/widgets/bottom_sheet_scaffold.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Thread dataset prompt sheet
//
// Shown when the user tries to commission a Thread device but no dataset is
// configured.  Lists saved datasets, "Empty dataset", and an inline
// "Load from Android" row that calls the OS credential picker.
// ─────────────────────────────────────────────────────────────────────────────

class ThreadDatasetPromptSheet extends StatefulWidget {
  const ThreadDatasetPromptSheet({required this.datasets, super.key});
  final List<ThreadDataset> datasets;

  @override
  State<ThreadDatasetPromptSheet> createState() => _ThreadDatasetPromptSheetState();
}

class _ThreadDatasetPromptSheetState extends State<ThreadDatasetPromptSheet> {
  bool    _loadingAndroid = false;
  String? _androidError;

  Future<void> _loadFromAndroid() async {
    setState(() {
      _loadingAndroid = true;
      _androidError   = null;
    });
    try {
      final hex = await context.read<MatterFabricPort>().readAndroidThreadCredentials();

      if (!mounted) return;

      if (hex == null) {
        setState(() {
          _loadingAndroid = false;
          _androidError   = 'Could not contact credential store';
        });
        return;
      }
      if (hex.isEmpty) {
        setState(() { _loadingAndroid = false; });
        return;
      }

      final name = ThreadTlvDecoder.networkName(hex) ?? hex.substring(0, 8.clamp(0, hex.length));
      Navigator.pop(context, ThreadDataset(label: name, hex: hex));
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _loadingAndroid = false;
          _androidError   = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final allItems = [...widget.datasets];

    return BottomSheetScaffold(
      title: 'Thread dataset required',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'No Thread credentials are configured. Choose a dataset to use for this device.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),

            // ── Saved datasets ─────────────────────────────────────────
            ...allItems.map((ds) {
              final subtitle = ds.hex.length > 20 ? '${ds.hex.substring(0, 20)}…' : ds.hex;
              return ListTile(
                leading: Icon(Icons.router_outlined, color: cs.onSurfaceVariant),
                title: Text(ds.label),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: cs.onSurfaceVariant),
                ),
                onTap: () => Navigator.pop(context, ds),
              );
            }),

            const Divider(height: 1),

            // ── Load from Android ──────────────────────────────────────
            ListTile(
              leading: _loadingAndroid
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.android, color: cs.primary),
              title: const Text('Load from Android'),
              subtitle: _androidError != null
                  ? Text(_androidError!, style: TextStyle(color: cs.error, fontSize: 11))
                  : Text('Use a credential stored by another app',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              onTap: _loadingAndroid ? null : _loadFromAndroid,
            ),
        ],
      ),
    );
  }
}
