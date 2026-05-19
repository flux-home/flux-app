import 'package:flutter/material.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/ui/widgets/bottom_sheet_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dataset picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class DatasetPickerSheet extends StatelessWidget {
  const DatasetPickerSheet({required this.datasets, this.active, super.key});
  final List<ThreadDataset> datasets;
  final ThreadDataset?      active;

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final allItems = [ThreadDataset.empty, ...datasets];

    return BottomSheetScaffold(
      title: 'Thread dataset',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          ...allItems.map((ds) {
            final isActive = active != null && active == ds;
            final subtitle = ds.isEmpty
                ? 'No credentials — device joins via MeshCoP'
                : ds.hex.length > 20
                ? '${ds.hex.substring(0, 20)}…'
                : ds.hex;
            return ListTile(
              leading: Icon(
                isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isActive ? cs.primary : cs.onSurfaceVariant,
              ),
              title: Text(ds.label, style: TextStyle(fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
              subtitle: Text(
                subtitle,
                style: TextStyle(
                  fontFamily: ds.isEmpty ? null : 'monospace',
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
              onTap: () => Navigator.pop(context, ds),
            );
          }),
        ],
      ),
    );
  }
}
