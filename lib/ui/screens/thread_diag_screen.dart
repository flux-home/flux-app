import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/thread_models.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/ui/widgets/info_row.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

// ── Routing role helpers ──────────────────────────────────────────────────────

Color _roleColor(BuildContext context, int? role) {
  final cs = Theme.of(context).colorScheme;
  return switch (role) {
    6 => const Color(0xFF7C4DFF), // Leader   — purple
    5 => const Color(0xFF34A853), // Router   — green
    4 => const Color(0xFF00897B), // REED     — teal
    3 => cs.primary, // End Device — blue
    2 => const Color(0xFFF9AB00), // Sleepy   — amber
    _ => cs.onSurfaceVariant, // unknown / unassigned
  };
}

IconData _roleIcon(int? role) => switch (role) {
  6 => Icons.star_outlined,
  5 => Icons.account_tree_outlined,
  4 => Icons.device_hub_outlined,
  3 => Icons.devices_outlined,
  2 => Icons.nights_stay_outlined,
  _ => Icons.help_outline,
};

// ── LQI visual helpers ────────────────────────────────────────────────────────

/// Maps LQI 0–3 to filled/hollow bars.
Widget _lqiBars(BuildContext context, int lqi) {
  final cs = Theme.of(context).colorScheme;
  final filled = lqi.clamp(0, 3);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      3,
      (i) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Icon(
          i < filled ? Icons.signal_cellular_alt : Icons.signal_cellular_0_bar,
          size: 14,
          color: i < filled ? _lqiColor(context, lqi) : cs.onSurfaceVariant.withAlpha(60),
        ),
      ),
    ),
  );
}

Color _lqiColor(BuildContext context, int lqi) {
  final cs = Theme.of(context).colorScheme;
  return switch (lqi) {
    3 => const Color(0xFF34A853),
    2 => const Color(0xFFF9AB00),
    1 => cs.error,
    _ => cs.onSurfaceVariant,
  };
}

/// Maps LQI (0–255 scale for NeighborTable) to 0–3 bars.
int _lqiToBars(int lqi255) => switch (lqi255) {
  >= 200 => 3,
  >= 100 => 2,
  >= 50 => 1,
  _ => 0,
};

// ── Screen ────────────────────────────────────────────────────────────────────

class ThreadDiagScreen extends StatefulWidget {
  const ThreadDiagScreen({required this.device, super.key});
  final MatterDevice device;

  @override
  State<ThreadDiagScreen> createState() => _ThreadDiagScreenState();
}

class _ThreadDiagScreenState extends State<ThreadDiagScreen> {
  _LoadState _state = _LoadState.idle;
  ThreadNetworkDiagnostics? _data;
  String? _error;
  DateTime? _fetchedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = _LoadState.loading;
      _error = null;
    });
    try {
      final data = await context.read<MatterFabricPort>().readThreadNetworkDiagnostics(widget.device.nodeId);
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _state = _LoadState.done;
          _error =
              'Thread Network Diagnostics cluster not available on this device.\n\n'
              'This cluster is only present on Matter devices that use Thread '
              'as their network transport.';
        });
      } else {
        setState(() {
          _data = data;
          _state = _LoadState.done;
          _fetchedAt = DateTime.now();
        });
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.done;
        _error = e.toString();
      });
    }
  }

  // ── Copy ──────────────────────────────────────────────────────────────────

  void _copyText() {
    final d = _data;
    if (d == null) return;
    final buf = StringBuffer()
      ..writeln('Thread Network Diagnostics — ${widget.device.name}')
      ..writeln('Read at: ${_fetchedAt?.toLocal()}')
      ..writeln()
      ..writeln('Network')
      ..writeln('  Name:             ${d.networkName ?? '—'}')
      ..writeln('  Channel:          ${d.channel ?? '—'}')
      ..writeln(
        '  PAN ID:           ${d.panId != null ? '0x${d.panId!.toRadixString(16).padLeft(4, '0').toUpperCase()}' : '—'}',
      )
      ..writeln('  Extended PAN ID:  ${d.extendedPanId ?? '—'}')
      ..writeln('  Mesh prefix:      ${d.meshLocalPrefix ?? '—'}')
      ..writeln()
      ..writeln('Node Status')
      ..writeln('  Routing role:     ${d.routingRoleLabel}')
      ..writeln('  Partition ID:     ${d.partitionId ?? '—'}')
      ..writeln('  Leader router:    ${d.leaderRouterId != null ? 'Router #${d.leaderRouterId}' : '—'}')
      ..writeln('  Weighting:        ${d.weighting ?? '—'}')
      ..writeln()
      ..writeln('Neighbors (${d.neighbors.length})');
    for (final n in d.neighbors) {
      buf.writeln(
        '  ${n.extAddress}  RLOC16:0x${n.rloc16.toRadixString(16).padLeft(4, '0').toUpperCase()}'
        '  LQI:${n.lqi}  RSSI:${n.averageRssi ?? '?'}dBm  ${n.isChild ? '[Child]' : '[Peer]'}  '
        '${n.fullThreadDevice ? '[FTD]' : '[MTD]'}  age:${n.age}s',
      );
    }
    buf
      ..writeln()
      ..writeln('Routes (${d.routes.length})');
    for (final r in d.routes) {
      buf.writeln(
        '  Router#${r.routerId}  RLOC16:0x${r.rloc16.toRadixString(16).padLeft(4, '0').toUpperCase()}'
        '  NextHop:${r.nextHop == 0xFF ? 'none' : r.nextHop}'
        '  Cost:${r.pathCost}  LQI:${r.lqiIn}/${r.lqiOut}  age:${r.age}s'
        '${r.linkEstablished ? '  [Link]' : ''}',
      );
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagnostics copied'), duration: Duration(seconds: 2)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thread Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              widget.device.name,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (_data != null) IconButton(icon: const Icon(Icons.copy_outlined), tooltip: 'Copy', onPressed: _copyText),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: _state == _LoadState.loading ? null : _load,
          ),
        ],
      ),
      body: switch (_state) {
        _LoadState.loading => const Center(child: CircularProgressIndicator()),
        _LoadState.idle => const SizedBox.shrink(),
        _LoadState.done => _buildBody(context),
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_outlined, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final d = _data!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Timestamp ────────────────────────────────────────────────────
        if (_fetchedAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Read at ${_timeStr(_fetchedAt!)}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),

        // ── Routing role badge ────────────────────────────────────────────
        _RoleBanner(role: d.routingRole, label: d.routingRoleLabel),
        const SizedBox(height: 16),

        // ── Network identity ──────────────────────────────────────────────
        const SectionLabel('Network'),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                InfoRow(label: 'Network name', value: d.networkName ?? '—'),
                InfoRow(label: 'Channel', value: d.channel != null ? '${d.channel}' : '—'),
                InfoRow(
                  label: 'PAN ID',
                  value: d.panId != null ? '0x${d.panId!.toRadixString(16).padLeft(4, '0').toUpperCase()}' : '—',
                  mono: true,
                ),
                InfoRow(label: 'Extended PAN ID', value: d.extendedPanId ?? '—', mono: true),
                InfoRow(label: 'Mesh prefix', value: d.meshLocalPrefix ?? '—', mono: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Node status ───────────────────────────────────────────────────
        const SectionLabel('Node status'),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                InfoRow(label: 'Partition ID', value: d.partitionId != null ? '${d.partitionId}' : '—'),
                InfoRow(label: 'Leader router', value: d.leaderRouterId != null ? 'Router #${d.leaderRouterId}' : '—'),
                InfoRow(label: 'Weighting', value: d.weighting != null ? '${d.weighting}' : '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Neighbors ─────────────────────────────────────────────────────
        SectionLabel('Neighbors  (${d.neighbors.length})'),
        const SizedBox(height: 6),
        if (d.neighbors.isEmpty)
          const _EmptyCard('No neighbors found')
        else
          Card(
            child: Column(
              children: d.neighbors.asMap().entries.map((e) {
                final last = e.key == d.neighbors.length - 1;
                return Column(
                  children: [
                    _NeighborTile(n: e.value),
                    if (!last)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 16),

        // ── Routing table ──────────────────────────────────────────────────
        SectionLabel('Routing table  (${d.routes.length})'),
        const SizedBox(height: 6),
        if (d.routes.isEmpty)
          const _EmptyCard('Routing table empty')
        else
          Card(
            child: Column(
              children: d.routes.asMap().entries.map((e) {
                final last = e.key == d.routes.length - 1;
                return Column(
                  children: [
                    _RouteTile(r: e.value),
                    if (!last)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  String _timeStr(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

enum _LoadState { idle, loading, done }

// ── Routing role banner ───────────────────────────────────────────────────────

class _RoleBanner extends StatelessWidget {
  const _RoleBanner({required this.role, required this.label});
  final int? role;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(context, role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        border: Border.all(color: color.withAlpha(100)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(_roleIcon(role), color: color, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Routing role', style: TextStyle(fontSize: 11, color: color.withAlpha(200))),
              Text(
                label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Neighbor tile ─────────────────────────────────────────────────────────────

class _NeighborTile extends StatelessWidget {
  const _NeighborTile({required this.n});
  final ThreadNeighborInfo n;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bars = _lqiToBars(n.lqi);
    final color = _lqiColor(context, bars);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: address + role badges
          Row(
            children: [
              Expanded(
                child: Text(
                  n.extAddress,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              _Badge(
                n.isChild ? 'Child' : 'Peer',
                n.isChild ? cs.primaryContainer : cs.secondaryContainer,
                n.isChild ? cs.onPrimaryContainer : cs.onSecondaryContainer,
              ),
              const SizedBox(width: 4),
              _Badge(
                n.fullThreadDevice ? 'FTD' : 'MTD',
                n.fullThreadDevice ? cs.tertiaryContainer : cs.surfaceContainerHighest,
                n.fullThreadDevice ? cs.onTertiaryContainer : cs.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Bottom row: metrics
          Row(
            children: [
              _lqiBars(context, bars),
              const SizedBox(width: 8),
              Text('LQI ${n.lqi}', style: TextStyle(fontSize: 11, color: color)),
              const SizedBox(width: 12),
              if (n.averageRssi != null) ...[
                Icon(Icons.signal_wifi_4_bar_outlined, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 3),
                Text('${n.averageRssi} dBm', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(width: 12),
              ],
              Text(
                'RLOC16 0x${n.rloc16.toRadixString(16).padLeft(4, '0').toUpperCase()}',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              Text('${n.age}s ago', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
          if (n.frameErrorRate > 0 || n.messageErrorRate > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Frame err ${n.frameErrorRate}%  ·  Msg err ${n.messageErrorRate}%',
              style: TextStyle(
                fontSize: 10,
                color: n.frameErrorRate > 10 || n.messageErrorRate > 10
                    ? Theme.of(context).colorScheme.error
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Route tile ────────────────────────────────────────────────────────────────

class _RouteTile extends StatelessWidget {
  const _RouteTile({required this.r});
  final ThreadRouteInfo r;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final noRoute = r.nextHop == 0xFF;
    final rloc16Str = '0x${r.rloc16.toRadixString(16).padLeft(4, '0').toUpperCase()}';
    final nextHopStr = noRoute ? '—' : 'Router #${r.nextHop}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Router ID circle
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: r.linkEstablished ? cs.primaryContainer : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '#${r.routerId}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: r.linkEstablished ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rloc16Str,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (r.allocated) _Badge('Allocated', cs.primaryContainer, cs.onPrimaryContainer),
                    if (r.linkEstablished) ...[
                      const SizedBox(width: 4),
                      _Badge('Linked', const Color(0xFF34A853).withAlpha(40), const Color(0xFF34A853)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Next: $nextHopStr', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    Text('Cost: ${r.pathCost}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    Text('LQI ↓${r.lqiIn} ↑${r.lqiOut}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const Spacer(),
                    Text('${r.age}s', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.bg, this.fg);
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      ),
    ),
  );
}
