import 'package:flutter/material.dart';
import 'package:matter_home/models/thread_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Thread border router detail screen (Thread settings flavour)
// ─────────────────────────────────────────────────────────────────────────────

const _kTxtFieldInfo = <String, ({String name, String description})>{
  'rv': (name: 'Revision',         description: 'The Thread version. Usually 1 or higher.'),
  'nn': (name: 'Network Name',     description: 'Human-readable name of the Thread mesh.'),
  'xp': (name: 'Extended PAN ID',  description: '64-bit hex ID that uniquely identifies this mesh.'),
  'tv': (name: 'Thread Version',   description: 'Specific stack version (e.g. 1.3.0).'),
  'vn': (name: 'Vendor Name',      description: 'Manufacturer of the border router device.'),
  'mn': (name: 'Model Name',       description: 'Model of the border router device.'),
  'at': (name: 'Active Timestamp', description: '64-bit value ensuring all devices have the latest settings.'),
  'sq': (name: 'Sequence Number',  description: 'Increments every time the network configuration changes.'),
  'sb': (name: 'State Bitmap',     description: 'Connectivity and service flags for this border router.'),
  'bb': (name: 'BBR Sequence',     description: 'Backbone Border Router sequence number.'),
  'dn': (name: 'Domain Name',      description: 'Thread domain name (Thread 1.2+).'),
  'id': (name: 'Border Agent ID',  description: '128-bit unique identifier for this border agent.'),
};

class ThreadBorderRouterDetailScreen extends StatelessWidget {
  const ThreadBorderRouterDetailScreen({required this.router, super.key});
  final ThreadBorderRouter router;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final title = router.vendorName.isNotEmpty && router.modelName.isNotEmpty
        ? '${router.vendorName} ${router.modelName}' : router.serviceName;

    final knownKeys   = _kTxtFieldInfo.keys.toList();
    final unknownKeys = router.txt.keys.where((k) => !knownKeys.contains(k)).toList()..sort();
    final orderedKeys = [...knownKeys.where(router.txt.containsKey), ...unknownKeys];

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                router.host.isNotEmpty ? '${router.host}:${router.port}' : router.serviceName,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
      body: orderedKeys.isEmpty
          ? const Center(child: Text('No TXT record data available'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orderedKeys.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final key  = orderedKeys[i];
                final val  = router.txt[key] ?? '';
                final info = _kTxtFieldInfo[key];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: cs.primaryContainer, borderRadius: BorderRadius.circular(6)),
                        child: Text(key, style: TextStyle(fontFamily: 'monospace', fontSize: 12,
                            fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (info != null) ...[
                            Text(info.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(info.description, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            const SizedBox(height: 6),
                          ],
                          SelectableText(
                            val.isNotEmpty ? val : '(empty)',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w500,
                                color: val.isNotEmpty ? cs.primary : cs.onSurfaceVariant),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
