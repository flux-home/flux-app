import 'package:flutter/material.dart';
import 'package:matter_home/models/network_diagnostics.dart';
import 'package:matter_home/services/network_diagnostics_engine.dart';
import 'package:matter_home/ui/theme.dart';
import 'package:matter_home/ui/widgets/info_row.dart';
import 'package:matter_home/ui/widgets/section_label.dart';

// ── Status colour / icon helpers ────────────────────────────────────────────────────
Color diagStatusColor(BuildContext context, DiagStatus s) => switch (s) {
  DiagStatus.ok      => kColorSuccess,
  DiagStatus.warning => kColorWarning,
  DiagStatus.fail    => Theme.of(context).colorScheme.error,
};

IconData diagStatusIcon(DiagStatus s) => switch (s) {
  DiagStatus.ok      => Icons.check_circle_outline,
  DiagStatus.warning => Icons.warning_amber_outlined,
  DiagStatus.fail    => Icons.cancel_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────
// Shared diagnostic widgets — used by NetworkCheckScreen and the BR detail screen
// ─────────────────────────────────────────────────────────────────────────────

// ── Summary banner ────────────────────────────────────────────────────────────

class DiagSummaryBanner extends StatelessWidget {
  const DiagSummaryBanner({required this.overall, required this.allChecks, super.key});
  final DiagStatus overall;
  final List<DiagCheckResult> allChecks;

  @override
  Widget build(BuildContext context) {
    final color     = diagStatusColor(context, overall);
    final failCount = allChecks.where((c) => c.status == DiagStatus.fail).length;
    final warnCount = allChecks.where((c) => c.status == DiagStatus.warning).length;

    final label = switch (overall) {
      DiagStatus.ok      => 'All checks passed',
      DiagStatus.warning => '$warnCount warning${warnCount == 1 ? '' : 's'}',
      DiagStatus.fail    =>
        '$failCount issue${failCount == 1 ? '' : 's'} found'
        '${warnCount > 0 ? '  ·  $warnCount warning${warnCount == 1 ? '' : 's'}' : ''}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        border: Border.all(color: color.withAlpha(100)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(diagStatusIcon(overall), color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Diagnostic card ────────────────────────────────────────────────────────────

class DiagCard extends StatelessWidget {
  const DiagCard({required this.checks, super.key});
  final List<DiagCheckResult> checks;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: checks.asMap().entries.map((e) {
        final last = e.key == checks.length - 1;
        return Column(children: [
          DiagCheckRow(check: e.value),
          if (!last)
            Divider(height: 1, indent: 48, endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant),
        ]);
      }).toList(),
    ),
  );
}

// ── Check row (expandable) ────────────────────────────────────────────────────

class DiagCheckRow extends StatefulWidget {
  const DiagCheckRow({required this.check, super.key});
  final DiagCheckResult check;

  @override
  State<DiagCheckRow> createState() => _DiagCheckRowState();
}

class _DiagCheckRowState extends State<DiagCheckRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final c         = widget.check;
    final color     = diagStatusColor(context, c.status);
    final hasDetail = c.bullets.isNotEmpty || c.hint != null ||
        (c.subtitle != null && c.subtitle!.contains('\n'));

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: hasDetail ? () => setState(() => _expanded = !_expanded) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(diagStatusIcon(c.status), color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    if (c.subtitle != null && !c.subtitle!.contains('\n'))
                      Text(c.subtitle!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ]),
                ),
                if (hasDetail)
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: cs.onSurfaceVariant),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (c.subtitle != null && c.subtitle!.contains('\n'))
                    Text(c.subtitle!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  for (final b in c.bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(b, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    ),
                  if (c.hint != null) ...[
                    if (c.bullets.isNotEmpty) const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(c.hint!,
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5)),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Bullet list ───────────────────────────────────────────────────────────────

class DiagBulletList extends StatelessWidget {
  const DiagBulletList(this.items, {super.key});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.circle, size: 5, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(item, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
          ]),
        )).toList(),
      ),
    );
  }
}

// ── Border router detail screen ────────────────────────────────────────────────

class NetworkCheckBorderRouterScreen extends StatelessWidget {
  const NetworkCheckBorderRouterScreen({
    required this.br,
    required this.savedExtPanId,
    super.key,
  });
  final BorderRouterDiagnostic br;  // from network_diagnostics.dart via engine
  final String? savedExtPanId;

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final checks = borderRouterChecks(br, savedExtPanId);
    final worst  = worstStatus(checks);

    final appBarSub = [
      if (br.hostsV6Ula.isNotEmpty)        br.hostsV6Ula.first
      else if (br.hostsV6Gua.isNotEmpty)   br.hostsV6Gua.first
      else if (br.hostsV4.isNotEmpty)      br.hostsV4.first
      else                                 br.serviceName,
    ].first;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(brLabel(br), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(appBarSub, style: TextStyle(fontSize: 11, fontFamily: 'monospace',
              color: cs.onSurfaceVariant, fontWeight: FontWeight.normal)),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DiagSummaryBanner(overall: worst, allChecks: checks),
          const SizedBox(height: 20),
          const SectionLabel('Checks'),
          const SizedBox(height: 6),
          DiagCard(checks: checks),
          const SizedBox(height: 20),
          const SectionLabel('Identity'),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(children: [
                InfoRow(label: 'Network name',    value: br.networkName),
                InfoRow(label: 'Extended PAN ID', value: br.extPanId, mono: true),
                if (br.hostsV4.isNotEmpty)         InfoRow(label: 'IPv4',           value: br.hostsV4.join(', '), mono: true),
                if (br.hostsV6Ula.isNotEmpty)      InfoRow(label: 'IPv6 ULA',       value: br.hostsV6Ula.join(', '), mono: true),
                if (br.hostsV6Gua.isNotEmpty)      InfoRow(label: 'IPv6 GUA',       value: br.hostsV6Gua.join(', '), mono: true),
                if (br.hostsV6LinkLocal.isNotEmpty) InfoRow(label: 'IPv6 link-local', value: br.hostsV6LinkLocal.join(', '), mono: true),
                InfoRow(label: 'Service', value: br.serviceName, mono: true),
              ]),
            ),
          ),
          if (br.stateBitmap != null) ...[
            const SizedBox(height: 20),
            const SectionLabel('State Bitmap  (sb)'),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(children: [
                  InfoRow(label: 'Raw (hex)',
                      value: '0x${br.stateBitmap!.raw.toRadixString(16).padLeft(8, '0').toUpperCase()}', mono: true),
                  InfoRow(label: 'Connection mode',
                      value: '${br.stateBitmap!.connectionMode} — ${br.stateBitmap!.connectionModeLabel}'),
                  InfoRow(label: 'Thread interface',
                      value: '${br.stateBitmap!.threadInterfaceStatus} — ${br.stateBitmap!.threadInterfaceLabel}'),
                  InfoRow(label: 'Availability',
                      value: br.stateBitmap!.availability == 1 ? 'High' : 'Infrequent'),
                  if (br.stateBitmap!.bbrActive)
                    InfoRow(label: 'BBR',
                        value: br.stateBitmap!.bbrIsPrimary ? 'Active (Primary)' : 'Active (Secondary)'),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
