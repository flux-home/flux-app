import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/models/network_diagnostics.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/ui/widgets/info_row.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

// ── Check status ──────────────────────────────────────────────────────────────

enum _Status { ok, warning, fail }

Color _statusColor(BuildContext context, _Status s) => switch (s) {
  _Status.ok => const Color(0xFF34A853),
  _Status.warning => const Color(0xFFF9AB00),
  _Status.fail => Theme.of(context).colorScheme.error,
};

IconData _statusIcon(_Status s) => switch (s) {
  _Status.ok => Icons.check_circle_outline,
  _Status.warning => Icons.warning_amber_outlined,
  _Status.fail => Icons.cancel_outlined,
};

// ── Check result ──────────────────────────────────────────────────────────────

class _CheckResult {
  const _CheckResult({required this.status, required this.title, this.subtitle, this.bullets = const [], this.hint});
  final _Status status;
  final String title;
  final String? subtitle;
  final List<String> bullets;
  final String? hint;
}

// ── Diagnostic section (phone / network / matter) ─────────────────────────────

class _DiagSection {
  const _DiagSection({required this.heading, required this.checks});
  final String heading;
  final List<_CheckResult> checks;
}

// ── TLV helper ────────────────────────────────────────────────────────────────

String? _extractExtPanId(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s'), '');
  if (clean.length < 4 || clean.length.isOdd) return null;
  try {
    var i = 0;
    while (i + 3 < clean.length) {
      final type = int.parse(clean.substring(i, i + 2), radix: 16);
      final len = int.parse(clean.substring(i + 2, i + 4), radix: 16);
      final dataEnd = i + 4 + len * 2;
      if (dataEnd > clean.length) break;
      if (type == 0x02) return clean.substring(i + 4, dataEnd).toLowerCase();
      i = dataEnd;
    }
  } on Exception catch (_) {}
  return null;
}

// ── Checks for a single border router ────────────────────────────────────────

List<_CheckResult> _brChecks(BorderRouterDiagnostic br, String? savedExtPanId) {
  final checks = <_CheckResult>[];

  // IPv4
  if (br.hasIpv4) {
    checks.add(
      _CheckResult(
        status: _Status.ok,
        title: 'IPv4 address resolved',
        bullets: br.hostsV4.map((a) => '$a  (IPv4)').toList(),
      ),
    );
  } else {
    checks.add(
      const _CheckResult(
        status: _Status.warning,
        title: 'No IPv4 address resolved',
        subtitle: 'Border router found via mDNS but no A record returned',
      ),
    );
  }

  // IPv6
  if (br.hasRoutableIpv6) {
    final v6 = [...br.hostsV6Ula, ...br.hostsV6Gua];
    checks.add(
      _CheckResult(
        status: _Status.ok,
        title: 'IPv6 routable address resolved',
        subtitle: 'Phone can reach the border router over IPv6',
        bullets: v6.map((a) {
          final tag = br.hostsV6Gua.contains(a) ? 'GUA' : 'ULA';
          return '$a  ($tag)';
        }).toList(),
      ),
    );
  } else if (br.hostsV6LinkLocal.isNotEmpty) {
    checks.add(
      _CheckResult(
        status: _Status.warning,
        title: 'IPv6 link-local only',
        subtitle: 'No routable IPv6 address for this border router',
        bullets: br.hostsV6LinkLocal.map((a) => '$a  (link-local)').toList(),
        hint:
            'The border router is visible via mDNS but only advertises '
            'a link-local IPv6 address. Thread devices on the mesh use '
            'routable ULA addresses. This may prevent the CHIP SDK from '
            'opening a CASE session. Check that SLAAC is enabled on your '
            'router and that the border router has a prefix delegation.',
      ),
    );
  } else {
    checks.add(
      const _CheckResult(
        status: _Status.fail,
        title: 'No IPv6 address resolved',
        subtitle: 'Border router resolved IPv4 only — Thread CASE will fail',
        hint:
            'The border router has no IPv6 address reachable from this '
            'phone. Thread is IPv6-only. Even if BLE commissioning and '
            'Thread join succeed, the CHIP SDK cannot open a CASE session '
            'to the device.\n\n'
            'Fix: enable SLAAC / DHCPv6 on your Wi-Fi router so both the '
            'phone and border router receive a ULA or GUA IPv6 address.',
      ),
    );
  }

  // TCP reachability
  if (br.tcpReachable != null) {
    checks.add(
      br.tcpReachable!
          ? const _CheckResult(
              status: _Status.ok,
              title: 'Directly reachable',
              subtitle:
                  'The app can open a direct connection to this border '
                  'router — IP routing between your phone and the border '
                  'router is working.',
            )
          : const _CheckResult(
              status: _Status.fail,
              title: 'Not directly reachable',
              subtitle:
                  'Found via network scan but a direct connection attempt '
                  'timed out.',
              hint:
                  "Your phone and this border router can see each other's "
                  'announcements, but cannot exchange data directly. This '
                  'is the most common cause of commissioning stalling at '
                  'the final step.\n\n'
                  'Common causes:\n'
                  '• Phone on 5 GHz / 6 GHz, border router on 2.4 GHz '
                  'with band isolation enabled on your router\n'
                  '• Border router on a separate "IoT" or "smart home" '
                  'network segment\n'
                  '• Guest Wi-Fi network — guest clients cannot reach '
                  'devices on the main network\n'
                  '• "Client isolation" or "AP isolation" enabled on your '
                  'router\n\n'
                  'What to do: try switching your phone to 2.4 GHz, or '
                  'connect both devices to the same main home network.',
            ),
    );
  }

  // IPv4 subnet match
  if (br.sameSubnetAsPhone != null) {
    checks.add(
      br.sameSubnetAsPhone!
          ? const _CheckResult(
              status: _Status.ok,
              title: 'Same network segment (IPv4)',
              subtitle:
                  'Phone and border router are on the same IPv4 subnet — '
                  'direct communication should work.',
            )
          : const _CheckResult(
              status: _Status.warning,
              title: 'Different network segments (IPv4)',
              subtitle:
                  'Phone and border router have IP addresses on different '
                  'subnets.',
              hint:
                  'Your phone and this border router are on different IP '
                  'address ranges. Direct communication requires your '
                  'router to forward traffic between the two segments, '
                  'which is not always configured.\n\n'
                  'This often happens when the border router is placed on '
                  'a dedicated "IoT" or "smart home" VLAN while the phone '
                  'is on the main network. Check your router settings or '
                  'move the border router to the same network as your '
                  'phone.',
            ),
    );
  }

  // IPv6 /64 prefix match
  if (br.ipv6PrefixMatchesPhone != null) {
    checks.add(
      br.ipv6PrefixMatchesPhone!
          ? const _CheckResult(
              status: _Status.ok,
              title: 'Same IPv6 network segment',
              subtitle:
                  'Phone and border router share the same IPv6 /64 prefix '
                  '— Thread device addresses will be routable.',
            )
          : const _CheckResult(
              status: _Status.warning,
              title: 'Different IPv6 network segments',
              subtitle:
                  'Phone and border router have IPv6 addresses on '
                  'different /64 segments.',
              hint:
                  'Thread devices get their IPv6 addresses from the border '
                  "router's mesh-local prefix. If your phone is on a "
                  'different IPv6 segment, it may not be able to reach '
                  'those devices directly.\n\n'
                  'This can happen on mesh Wi-Fi systems where different '
                  'nodes assign different IPv6 prefixes, or when a router '
                  'uses separate IPv6 ranges for different network '
                  'segments. Check that your router provides a single '
                  'consistent IPv6 prefix to all devices.',
            ),
    );
  }

  // State bitmap
  final bm = br.stateBitmap;
  if (bm == null) {
    checks.add(
      const _CheckResult(
        status: _Status.warning,
        title: 'State bitmap absent',
        subtitle: 'Border router did not include an sb TXT record',
      ),
    );
  } else {
    checks
      ..add(switch (bm.threadInterfaceStatus) {
        2 => _CheckResult(status: _Status.ok, title: 'Thread interface active', subtitle: bm.threadInterfaceLabel),
        1 => _CheckResult(
          status: _Status.warning,
          title: 'Thread interface initialised but not attached',
          subtitle: bm.threadInterfaceLabel,
          hint:
              'The border router has initialised its Thread interface '
              'but has not yet joined a Thread partition. '
              'A device can receive credentials but may not find the '
              'Thread network to join. Try rebooting the border router.',
        ),
        _ => _CheckResult(
          status: _Status.fail,
          title: 'Thread interface not initialised',
          subtitle: bm.threadInterfaceLabel,
          hint:
              'The border router has no active Thread interface. '
              'Devices will not be able to join the Thread network '
              'even if the credentials are correct. '
              'Try rebooting the border router.',
        ),
      })
      ..add(
        bm.hasExternalConnectivity
            ? _CheckResult(
                status: _Status.ok,
                title: 'External connectivity (${bm.connectionModeLabel})',
                subtitle: 'Border router has an active IP connection',
              )
            : const _CheckResult(
                status: _Status.fail,
                title: 'No external connectivity',
                subtitle: 'Connection mode = 0 in state bitmap',
                hint:
                    'The border router reports no external IP connectivity. '
                    'The CHIP SDK cannot reach commissioned devices even if '
                    'they are on the Thread mesh. '
                    "Check the border router's internet / LAN connection.",
              ),
      );
  }

  // Dataset match
  if (savedExtPanId != null && savedExtPanId.isNotEmpty) {
    final match = br.extPanId.toLowerCase() == savedExtPanId.toLowerCase();
    checks.add(
      match
          ? _CheckResult(
              status: _Status.ok,
              title: 'Dataset matches this border router',
              subtitle: 'Extended PAN ID: ${br.extPanId}',
            )
          : _CheckResult(
              status: _Status.fail,
              title: 'Dataset / border router mismatch',
              subtitle: 'Configured: $savedExtPanId\nThis router: ${br.extPanId}',
              hint:
                  'The Thread dataset stored in the app belongs to a '
                  'different Thread network than this border router. '
                  'The device will receive credentials for network '
                  '"$savedExtPanId" but can only reach '
                  '"${br.extPanId}" — commissioning will time out at '
                  'the CASE stage.\n\n'
                  'Fix: update the Thread dataset in Settings → Thread.',
            ),
    );
  }

  return checks;
}

// ── Non-BR sections (phone / network / matter) ────────────────────────────────

List<_DiagSection> _buildNonBrSections(NetworkDiagnosticsReport r, String? savedExtPanId) {
  final sections = <_DiagSection>[];
  final phoneChecks = <_CheckResult>[];
  final networkChecks = <_CheckResult>[];

  // ── IPv6 check ────────────────────────────────────────────────────────────
  final ipv6 = r.phoneIpv6;
  final _CheckResult ipv6Check;
  if (ipv6.hasRoutableIpv6) {
    final addrs = [...ipv6.ulaAddresses, ...ipv6.guaAddresses];
    ipv6Check = _CheckResult(
      status: _Status.ok,
      title: 'Your network supports IPv6',
      subtitle:
          'Thread smart home devices communicate exclusively over IPv6 '
          '— a modern internet address format. Your phone has a working '
          'IPv6 address on this network and can reach Thread devices '
          'after they join.',
      bullets: addrs.map((a) {
        final tag = ipv6.guaAddresses.contains(a) ? 'public' : 'private';
        return '$a  ($tag)';
      }).toList(),
    );
  } else if (ipv6.linkLocalAddresses.isNotEmpty) {
    ipv6Check = _CheckResult(
      status: _Status.warning,
      title: 'IPv6 is only partially set up',
      subtitle:
          'Your phone has an IPv6 address, but it only works within a '
          'single network segment and cannot reach Thread devices across '
          'the home network.',
      bullets: ipv6.linkLocalAddresses.map((a) => '$a  (segment-local only)').toList(),
      hint:
          'What to do: Log in to your Wi-Fi router and look for an IPv6 '
          'setting — it is sometimes labelled "SLAAC", "DHCPv6", or simply '
          '"IPv6". Enable it and reconnect your phone to Wi-Fi.\n\n'
          'Without a proper IPv6 address, the app can send your device its '
          'network settings over Bluetooth, but it cannot finish setup '
          'because it cannot find the device on the network afterwards.',
    );
  } else {
    ipv6Check = const _CheckResult(
      status: _Status.fail,
      title: 'Your network does not support IPv6',
      subtitle:
          'Thread smart home devices only communicate over IPv6 — a '
          'modern internet address format that your current Wi-Fi network '
          'is not providing to this phone.',
      hint:
          'What to do: Log in to your Wi-Fi router settings and enable '
          'IPv6. Look for options labelled "IPv6", "SLAAC", or "DHCPv6". '
          'Once enabled, reconnect your phone to Wi-Fi and run this check '
          'again.\n\n'
          'Note: some older or ISP-provided routers may need a firmware '
          'update before IPv6 can be turned on. Contact your internet '
          'provider if the option is missing.',
    );
  }
  phoneChecks.add(ipv6Check);

  // ── Wi-Fi band check ──────────────────────────────────────────────────────
  final wb = r.wifi;
  if (wb.frequencyMhz > 0) {
    if (wb.is24Ghz) {
      phoneChecks.add(
        const _CheckResult(
          status: _Status.ok,
          title: 'Phone is on 2.4 GHz Wi-Fi',
          subtitle:
              'Most Thread Border Routers support 2.4 GHz — no band '
              'mismatch expected.',
        ),
      );
    } else if (wb.hasBandSuffix) {
      // e.g. connected to "MyHome_5G" — likely a band-specific SSID
      phoneChecks.add(
        _CheckResult(
          status: _Status.warning,
          title: 'Phone is on a band-specific Wi-Fi network (${wb.band})',
          subtitle: '"${wb.ssid}" looks like a ${wb.band}-only network.',
          hint:
              'Your router appears to use separate network names for its '
              '2.4 GHz and ${wb.band} radios. Thread Border Routers that '
              'only support 2.4 GHz will be on the other network and may '
              'not be visible from here.\n\n'
              'What to do: connect your phone to the 2.4 GHz network '
              '(usually the one without "_5G" or "_5GHz" in the name) and '
              'run this check again.',
        ),
      );
    } else if (r.borderRouters.isEmpty) {
      // On 5/6 GHz with no BRs found — may be band isolation
      phoneChecks.add(
        _CheckResult(
          status: _Status.warning,
          title: 'Phone is on ${wb.band} Wi-Fi — no border routers found',
          subtitle:
              'Some Thread Border Routers only support 2.4 GHz and may '
              'not be visible on ${wb.band}.',
          hint:
              'Your phone is connected to a ${wb.band} Wi-Fi network but '
              'no Thread Border Routers were discovered. Some border '
              'routers (and certain router models) do not bridge local '
              'device announcements between the 2.4 GHz and ${wb.band} '
              'radios, even when they share the same network name.\n\n'
              'What to do: try switching your phone to the 2.4 GHz '
              'network and running this check again.',
        ),
      );
    } else {
      // On 5/6 GHz but BRs were found — multicast bridges fine on this router
      phoneChecks.add(
        _CheckResult(
          status: _Status.ok,
          title: 'Phone is on ${wb.band} Wi-Fi',
          subtitle:
              'Border router(s) are visible — your router bridges local '
              'network announcements across Wi-Fi bands.',
        ),
      );
    }
  }

  sections.add(_DiagSection(heading: 'This phone', checks: phoneChecks));

  // ── mDNS / multicast check ────────────────────────────────────────────────
  networkChecks.add(
    r.multicastLockAcquired
        ? const _CheckResult(
            status: _Status.ok,
            title: 'Device discovery is working',
            subtitle:
                'Your phone can receive local network announcements. '
                'After a device joins Thread, the app will find it '
                'automatically and complete the setup.',
          )
        : const _CheckResult(
            status: _Status.fail,
            title: 'Device discovery may be blocked',
            subtitle:
                'The app was unable to listen for local network '
                'announcements on your current Wi-Fi connection.',
            hint:
                'What this means: after a smart device joins Thread, the '
                'app searches for it on your local network. Your Wi-Fi '
                'connection is currently blocking that search, so setup '
                'will stall at the last step.\n\n'
                'What to do: check that you are connected to your main '
                'home Wi-Fi — not a guest network. Guest networks and '
                'some office or hotel networks block local device discovery '
                'between connected devices. Switching to your regular home '
                'network and running this check again should resolve it.',
          ),
  );

  // ── VPN check (only shown if active) ─────────────────────────────────────
  if (r.vpn.isActive) {
    networkChecks.add(
      const _CheckResult(
        status: _Status.warning,
        title: 'A VPN is active on this phone',
        subtitle:
            'Some VPN configurations can interfere with smart home '
            'device setup.',
        hint:
            'What this means: your phone is routing some or all network '
            'traffic through a VPN server. If the VPN tunnels all traffic '
            '(full-tunnel mode), the app may not be able to open a direct '
            'connection to your Thread device after it joins the network, '
            'because the VPN server has no route back to your home.\n\n'
            'What to do: disable the VPN temporarily while commissioning '
            'the device, then re-enable it afterwards.',
      ),
    );
  }

  sections.add(_DiagSection(heading: 'Network', checks: networkChecks));

  // Matter services
  final _CheckResult matterCheck;
  if (r.matterTcpServices.isNotEmpty) {
    matterCheck = _CheckResult(
      status: _Status.ok,
      title:
          '${r.matterTcpServices.length} Matter device'
          '${r.matterTcpServices.length == 1 ? '' : 's'} visible via mDNS',
      subtitle: 'Border router mDNS proxy is working end-to-end',
      bullets: r.matterTcpServices.toList(),
    );
  } else {
    matterCheck = _CheckResult(
      status: r.borderRouters.isEmpty ? _Status.fail : _Status.warning,
      title: 'No Matter devices visible via _matter._tcp',
      subtitle: r.borderRouters.isEmpty
          ? 'No border router found — mDNS proxy cannot be verified'
          : 'Border router(s) found but no Matter operational nodes visible',
      hint: r.borderRouters.isEmpty
          ? null
          : 'If you have already commissioned Thread devices and they are online, '
                'this indicates the border router is not proxying _matter._tcp mDNS '
                'records from the Thread mesh to the Wi-Fi side.\n\n'
                'This is a common border router firmware limitation. '
                'New device commissioning will fail at the CASE discovery stage. '
                'Check for firmware updates for your border router.',
    );
  }
  sections.add(_DiagSection(heading: 'Commissioned Matter devices', checks: [matterCheck]));

  return sections;
}

// ── Overall status helpers ────────────────────────────────────────────────────

_Status _worstStatus(List<_CheckResult> checks) {
  if (checks.any((c) => c.status == _Status.fail)) return _Status.fail;
  if (checks.any((c) => c.status == _Status.warning)) return _Status.warning;
  return _Status.ok;
}

// ── Main screen ───────────────────────────────────────────────────────────────

class NetworkCheckScreen extends StatefulWidget {
  const NetworkCheckScreen({super.key});

  @override
  State<NetworkCheckScreen> createState() => _NetworkCheckScreenState();
}

enum _ScreenState { idle, running, done }

class _NetworkCheckScreenState extends State<NetworkCheckScreen> {
  _ScreenState _state = _ScreenState.idle;
  NetworkDiagnosticsReport? _report;
  String? _savedExtPanId;
  String? _error;

  @override
  void initState() {
    super.initState();
    ThreadSettingsService.load().then((hex) {
      if (mounted) setState(() => _savedExtPanId = _extractExtPanId(hex));
    });
  }

  Future<void> _runCheck() async {
    setState(() {
      _state = _ScreenState.running;
      _error = null;
    });
    final report = await context.read<MatterFabricPort>().runNetworkDiagnostics();
    if (!mounted) return;
    if (report == null) {
      setState(() {
        _state = _ScreenState.idle;
        _error = 'Diagnostics failed — check app permissions and try again.';
      });
      return;
    }
    setState(() {
      _report = report;
      _state = _ScreenState.done;
    });
  }

  // ── Copy ──────────────────────────────────────────────────────────────────

  void _copyReport() {
    final r = _report;
    if (r == null) return;
    final buf = StringBuffer();

    void writeChecks(String heading, List<_CheckResult> checks) {
      buf.writeln('=== $heading ===');
      for (final c in checks) {
        final icon = switch (c.status) {
          _Status.ok => '✓',
          _Status.warning => '⚠',
          _Status.fail => '✗',
        };
        buf.writeln('$icon ${c.title}');
        if (c.subtitle != null) {
          buf.writeln('  ${c.subtitle}');
        }
        for (final b in c.bullets) {
          buf.writeln('  · $b');
        }
        if (c.hint != null) {
          buf.writeln('  ℹ ${c.hint}');
        }
      }
      buf.writeln();
    }

    for (final s in _buildNonBrSections(r, _savedExtPanId)) {
      if (s.heading == 'Commissioned Matter devices') continue; // added after BRs
      writeChecks(s.heading, s.checks);
    }
    for (final br in r.borderRouters) {
      final label = _brLabel(br);
      writeChecks(label, _brChecks(br, _savedExtPanId));
    }
    // Matter section last
    final matterSection = _buildNonBrSections(
      r,
      _savedExtPanId,
    ).firstWhere((s) => s.heading == 'Commissioned Matter devices');
    writeChecks(matterSection.heading, matterSection.checks);

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagnostics copied to clipboard'), duration: Duration(seconds: 2)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Network Check'),
      actions: [
        if (_state == _ScreenState.done)
          IconButton(icon: const Icon(Icons.copy_outlined), tooltip: 'Copy report', onPressed: _copyReport),
      ],
    ),
    body: switch (_state) {
      _ScreenState.idle => _buildIdle(context),
      _ScreenState.running => _buildRunning(context),
      _ScreenState.done => _buildResults(context),
    },
  );

  // ── Idle ──────────────────────────────────────────────────────────────────

  Widget _buildIdle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.network_check_outlined, size: 64, color: cs.primary.withAlpha(160)),
          const SizedBox(height: 20),
          Text(
            'Diagnose your Thread & IPv6 network',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'This check scans your network for issues that can prevent '
            'Matter over Thread commissioning — no device required.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          const _BulletList([
            'Phone IPv6 connectivity',
            'mDNS multicast reachability',
            'Thread Border Router health & addresses',
            'Thread dataset / network match',
            'Matter mDNS proxy (_matter._tcp)',
          ]),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error, fontSize: 13),
            ),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: _runCheck,
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Run check  (~6 s)'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Running ───────────────────────────────────────────────────────────────

  Widget _buildRunning(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: cs.primary),
          const SizedBox(height: 24),
          Text('Scanning network…', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            'Discovering border routers & Matter devices',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults(BuildContext context) {
    final r = _report!;
    final sections = _buildNonBrSections(r, _savedExtPanId);

    // Compute overall status across everything
    final allChecks = <_CheckResult>[
      ...sections.expand((s) => s.checks),
      ...r.borderRouters.expand((br) => _brChecks(br, _savedExtPanId)),
    ];
    final overall = _worstStatus(allChecks);

    // Split sections: phone+network before BRs, matter after
    final preBr = sections.where((s) => s.heading != 'Commissioned Matter devices').toList();
    final postBr = sections.where((s) => s.heading == 'Commissioned Matter devices').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Summary banner
        _SummaryBanner(overall: overall, allChecks: allChecks),
        const SizedBox(height: 20),

        // Phone + network inline
        for (final s in preBr) ...[
          SectionLabel(s.heading),
          const SizedBox(height: 6),
          _DiagCard(checks: s.checks),
          const SizedBox(height: 16),
        ],

        // Border routers — nav cards
        const SectionLabel('Thread Border Routers'),
        const SizedBox(height: 6),
        if (r.borderRouters.isEmpty)
          const _DiagCard(
            checks: [
              _CheckResult(
                status: _Status.fail,
                title: 'No border routers found',
                subtitle: 'No _meshcop._udp services visible on this network',
                hint:
                    'Ensure your Thread Border Router is powered on and '
                    'connected to the same Wi-Fi network as this phone. '
                    'If your router has client isolation / IGMP snooping '
                    'enabled it may block mDNS multicast entirely.',
              ),
            ],
          )
        else
          Card(
            child: Column(
              children: r.borderRouters.asMap().entries.map((entry) {
                final idx = entry.key;
                final br = entry.value;
                final last = idx == r.borderRouters.length - 1;
                return Column(
                  children: [
                    _BrSummaryTile(
                      br: br,
                      savedExtPanId: _savedExtPanId,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => _BorderRouterDetailScreen(br: br, savedExtPanId: _savedExtPanId),
                        ),
                      ),
                    ),
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

        // Matter devices
        for (final s in postBr) ...[
          SectionLabel(s.heading),
          const SizedBox(height: 6),
          _DiagCard(checks: s.checks),
          const SizedBox(height: 16),
        ],

        OutlinedButton.icon(
          onPressed: _runCheck,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('Run again'),
        ),
      ],
    );
  }
}

// ── Border router summary tile (shown on main results screen) ─────────────────

String _brLabel(BorderRouterDiagnostic br) =>
    br.vendorName.isNotEmpty && br.modelName.isNotEmpty ? '${br.vendorName} ${br.modelName}' : br.serviceName;

class _BrSummaryTile extends StatelessWidget {
  const _BrSummaryTile({required this.br, required this.savedExtPanId, required this.onTap});
  final BorderRouterDiagnostic br;
  final String? savedExtPanId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checks = _brChecks(br, savedExtPanId);
    final worst = _worstStatus(checks);
    final color = _statusColor(context, worst);

    // One-line address summary
    final String addrSummary;
    if (br.hasRoutableIpv6 && br.hasIpv4) {
      addrSummary = 'IPv4 + IPv6';
    } else if (br.hasRoutableIpv6) {
      addrSummary = 'IPv6 only';
    } else if (br.hostsV6LinkLocal.isNotEmpty) {
      addrSummary = 'IPv4 + link-local IPv6';
    } else if (br.hasIpv4) {
      addrSummary = 'IPv4 only — no IPv6';
    } else {
      addrSummary = 'No addresses resolved';
    }

    final failCount = checks.where((c) => c.status == _Status.fail).length;
    final warnCount = checks.where((c) => c.status == _Status.warning).length;
    final statusSummary = switch (worst) {
      _Status.ok => 'All checks passed',
      _Status.warning => '$warnCount warning${warnCount == 1 ? '' : 's'}',
      _Status.fail =>
        '$failCount issue${failCount == 1 ? '' : 's'}'
            '${warnCount > 0 ? ' · $warnCount warning${warnCount == 1 ? '' : 's'}' : ''}',
    };

    return ListTile(
      onTap: onTap,
      leading: Icon(_statusIcon(worst), color: color, size: 22),
      title: Text(_brLabel(br), style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(br.networkName, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          Text(addrSummary, style: TextStyle(fontSize: 11, color: br.hasRoutableIpv6 ? cs.onSurfaceVariant : color)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusSummary,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
        ],
      ),
      isThreeLine: true,
    );
  }
}

// ── Border router detail screen ───────────────────────────────────────────────

class _BorderRouterDetailScreen extends StatelessWidget {
  const _BorderRouterDetailScreen({required this.br, required this.savedExtPanId});
  final BorderRouterDiagnostic br;
  final String? savedExtPanId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checks = _brChecks(br, savedExtPanId);
    final worst = _worstStatus(checks);

    // Subtitle shown under the AppBar title
    final appBarSub = [
      if (br.hostsV6Ula.isNotEmpty)
        br.hostsV6Ula.first
      else if (br.hostsV6Gua.isNotEmpty)
        br.hostsV6Gua.first
      else if (br.hostsV4.isNotEmpty)
        br.hostsV4.first
      else
        br.serviceName,
    ].first;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_brLabel(br), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              appBarSub,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Mini status banner ───────────────────────────────────────────
          _SummaryBanner(overall: worst, allChecks: checks),
          const SizedBox(height: 20),

          // ── Checks ───────────────────────────────────────────────────────
          const SectionLabel('Checks'),
          const SizedBox(height: 6),
          _DiagCard(checks: checks),
          const SizedBox(height: 20),

          // ── Identity ─────────────────────────────────────────────────────
          const SectionLabel('Identity'),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  InfoRow(label: 'Network name', value: br.networkName),
                  InfoRow(label: 'Extended PAN ID', value: br.extPanId, mono: true),
                  if (br.hostsV4.isNotEmpty) InfoRow(label: 'IPv4', value: br.hostsV4.join(', '), mono: true),
                  if (br.hostsV6Ula.isNotEmpty) InfoRow(label: 'IPv6 ULA', value: br.hostsV6Ula.join(', '), mono: true),
                  if (br.hostsV6Gua.isNotEmpty) InfoRow(label: 'IPv6 GUA', value: br.hostsV6Gua.join(', '), mono: true),
                  if (br.hostsV6LinkLocal.isNotEmpty)
                    InfoRow(label: 'IPv6 link-local', value: br.hostsV6LinkLocal.join(', '), mono: true),
                  InfoRow(label: 'Service', value: br.serviceName, mono: true),
                ],
              ),
            ),
          ),

          // ── State bitmap raw ─────────────────────────────────────────────
          if (br.stateBitmap != null) ...[
            const SizedBox(height: 20),
            const SectionLabel('State Bitmap  (sb)'),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: [
                    InfoRow(
                      label: 'Raw (hex)',
                      value: '0x${br.stateBitmap!.raw.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                      mono: true,
                    ),
                    InfoRow(
                      label: 'Connection mode',
                      value: '${br.stateBitmap!.connectionMode} — ${br.stateBitmap!.connectionModeLabel}',
                    ),
                    InfoRow(
                      label: 'Thread interface',
                      value: '${br.stateBitmap!.threadInterfaceStatus} — ${br.stateBitmap!.threadInterfaceLabel}',
                    ),
                    InfoRow(label: 'Availability', value: br.stateBitmap!.availability == 1 ? 'High' : 'Infrequent'),
                    if (br.stateBitmap!.bbrActive)
                      InfoRow(
                        label: 'BBR',
                        value: br.stateBitmap!.bbrIsPrimary ? 'Active (Primary)' : 'Active (Secondary)',
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Summary banner ─────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.overall, required this.allChecks});
  final _Status overall;
  final List<_CheckResult> allChecks;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, overall);
    final failCount = allChecks.where((c) => c.status == _Status.fail).length;
    final warnCount = allChecks.where((c) => c.status == _Status.warning).length;

    final label = switch (overall) {
      _Status.ok => 'All checks passed',
      _Status.warning => '$warnCount warning${warnCount == 1 ? '' : 's'}',
      _Status.fail =>
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
          Icon(_statusIcon(overall), color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Diagnostic card ────────────────────────────────────────────────────────────

class _DiagCard extends StatelessWidget {
  const _DiagCard({required this.checks});
  final List<_CheckResult> checks;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: checks.asMap().entries.map((e) {
        final last = e.key == checks.length - 1;
        return Column(
          children: [
            _CheckRow(check: e.value),
            if (!last)
              Divider(height: 1, indent: 48, endIndent: 16, color: Theme.of(context).colorScheme.outlineVariant),
          ],
        );
      }).toList(),
    ),
  );
}

// ── Check row (expandable) ────────────────────────────────────────────────────

class _CheckRow extends StatefulWidget {
  const _CheckRow({required this.check});
  final _CheckResult check;

  @override
  State<_CheckRow> createState() => _CheckRowState();
}

class _CheckRowState extends State<_CheckRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.check;
    final color = _statusColor(context, c.status);
    final hasDetail = c.bullets.isNotEmpty || c.hint != null || (c.subtitle != null && c.subtitle!.contains('\n'));

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
                  child: Icon(_statusIcon(c.status), color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      if (c.subtitle != null && !c.subtitle!.contains('\n'))
                        Text(c.subtitle!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (hasDetail)
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c.hint!,
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList(this.items);
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 5, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
