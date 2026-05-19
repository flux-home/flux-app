import 'package:flutter/material.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/ui/screens/commission/dataset_picker_sheet.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Thread dataset header + picker
// ─────────────────────────────────────────────────────────────────────────────

class ThreadDatasetHeader extends StatefulWidget {
  const ThreadDatasetHeader({
    required this.activeDataset,
    required this.threadCtrl,
    required this.showHex,
    required this.onToggleHex,
    required this.onDatasetChanged,
    super.key,
  });
  final ThreadDataset?            activeDataset;
  final TextEditingController     threadCtrl;
  final bool                      showHex;
  final VoidCallback               onToggleHex;
  final ValueChanged<ThreadDataset> onDatasetChanged;

  @override
  State<ThreadDatasetHeader> createState() => _ThreadDatasetHeaderState();
}

class _ThreadDatasetHeaderState extends State<ThreadDatasetHeader> {
  Future<void> _pickDataset() async {
    final datasets = await context.read<ThreadSettingsService>().loadDatasets();
    if (!mounted) return;

    final picked = await showModalBottomSheet<ThreadDataset>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DatasetPickerSheet(datasets: datasets, active: widget.activeDataset),
    );
    if (picked != null) widget.onDatasetChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final active = widget.activeDataset;

    final String title;
    final String? subtitle;
    if (active == null) {
      title    = 'No dataset configured';
      subtitle = null;
    } else if (active.isEmpty) {
      title    = 'Empty dataset';
      subtitle = 'No credentials — device joins via MeshCoP';
    } else {
      title    = active.label;
      subtitle = active.hex.length > 16 ? '${active.hex.substring(0, 16)}…' : active.hex;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onToggleHex,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.memory_outlined, size: 16, color: cs.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.secondary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontFamily: active != null && !active.isEmpty ? 'monospace' : null,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz_outlined, size: 18),
                  tooltip: 'Choose dataset',
                  visualDensity: VisualDensity.compact,
                  color: cs.secondary,
                  onPressed: _pickDataset,
                ),
                Icon(widget.showHex ? Icons.expand_less : Icons.expand_more, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),

        if (widget.showHex) ...[
          const SizedBox(height: 10),
          TextField(
            controller: widget.threadCtrl,
            decoration: const InputDecoration(
              labelText: 'Active Operational Dataset (hex TLV)',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            maxLines: 3,
            minLines: 2,
          ),
        ],
      ],
    );
  }
}
