import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/ui/widgets/info_row.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Thread dataset detail / edit screen
// ─────────────────────────────────────────────────────────────────────────────

class ThreadDatasetDetailScreen extends StatefulWidget {
  const ThreadDatasetDetailScreen({
    required this.initialHex,
    required this.initialLabel,
    this.isNew    = false,
    this.isActive = false,
    super.key,
  });
  final String initialHex;
  final String initialLabel;
  final bool   isNew;
  final bool   isActive;

  @override
  State<ThreadDatasetDetailScreen> createState() => _ThreadDatasetDetailScreenState();
}

class _ThreadDatasetDetailScreenState extends State<ThreadDatasetDetailScreen> {
  late TextEditingController _hexCtrl;
  late TextEditingController _labelCtrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _hexCtrl   = TextEditingController(text: widget.initialHex);
    _labelCtrl = TextEditingController(text: widget.initialLabel);
    _hexCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete dataset?'),
        content: Text(widget.isActive
            ? '"${widget.initialLabel}" is your active dataset. Deleting it will clear the active '
              'selection and Thread commissioning will require new credentials.'
            : 'Delete "${widget.initialLabel}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      await context.read<ThreadSettingsService>().removeDataset(widget.initialHex.replaceAll(RegExp(r'\s'), ''));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final clean = _hexCtrl.text.replaceAll(RegExp(r'\s'), '');
    final name  = _labelCtrl.text.trim().isNotEmpty
        ? _labelCtrl.text.trim()
        : ThreadTlvDecoder.networkName(clean) ??
              (clean.isNotEmpty ? clean.substring(0, 8.clamp(0, clean.length)) : 'Unnamed dataset');
    final updated = ThreadDataset(label: name, hex: clean);

    if (widget.isNew) {
      if (clean.isNotEmpty) await context.read<ThreadSettingsService>().addDataset(updated);
    } else {
      await context.read<ThreadSettingsService>().updateDataset(widget.initialHex.replaceAll(RegExp(r'\s'), ''), updated);
    }

    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thread dataset saved'), duration: Duration(seconds: 2)));
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final cleanHex = _hexCtrl.text.replaceAll(RegExp(r'\s'), '');
    final fields   = ThreadTlvDecoder.decode(cleanHex);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Add dataset' : 'Edit dataset'),
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete dataset',
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: Icon(_saved ? Icons.check : Icons.save_outlined),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(4, 4, 4, 10), child: SectionLabel('Name')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _labelCtrl,
                decoration: InputDecoration(
                  labelText: 'Dataset name',
                  hintText: 'e.g. Home Thread Network',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  helperText: 'Leave blank to use the name decoded from the TLV',
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (fields.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 10), child: SectionLabel('Decoded fields')),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: fields.map((f) => InfoRow(label: f.label, value: f.value)).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 10), child: SectionLabel('Hex (TLV)')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Operational dataset',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    tooltip: 'Copy hex',
                    visualDensity: VisualDensity.compact,
                    onPressed: cleanHex.isEmpty ? null : () {
                      Clipboard.setData(ClipboardData(text: cleanHex));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Dataset copied'), duration: Duration(seconds: 1)));
                    },
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _hexCtrl,
                  maxLines: null,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 0.5),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Paste hex dataset…',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                  ),
                  keyboardType: TextInputType.multiline,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F\s]'))],
                ),
              ]),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
