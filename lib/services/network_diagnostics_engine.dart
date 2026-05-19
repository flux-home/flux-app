import 'package:matter_home/models/network_diagnostics.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Network diagnostics engine — pure computation, no Flutter widgets
// ─────────────────────────────────────────────────────────────────────────────

// ── Status enum ───────────────────────────────────────────────────────────────

enum DiagStatus { ok, warning, fail }

// ── Result / section models ───────────────────────────────────────────────────

class DiagCheckResult {
  const DiagCheckResult({
    required this.status,
    required this.title,
    this.subtitle,
    this.bullets = const [],
    this.hint,
  });
  final DiagStatus   status;
  final String       title;
  final String?      subtitle;
  final List<String> bullets;
  final String?      hint;
}

class DiagSection {
  const DiagSection({required this.heading, required this.checks});
  final String              heading;
  final List<DiagCheckResult> checks;
}

// ── Aggregation helper ─────────────────────────────────────────────────────────

DiagStatus worstStatus(List<DiagCheckResult> checks) {
  if (checks.any((c) => c.status == DiagStatus.fail))    return DiagStatus.fail;
  if (checks.any((c) => c.status == DiagStatus.warning)) return DiagStatus.warning;
  return DiagStatus.ok;
}

// ── Border-router label ────────────────────────────────────────────────────────

String brLabel(BorderRouterDiagnostic br) =>
    br.vendorName.isNotEmpty && br.modelName.isNotEmpty
        ? '${br.vendorName} ${br.modelName}'
        : br.serviceName;

// ── TLV helper ────────────────────────────────────────────────────────────────

String? extractExtPanId(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s'), '');
  if (clean.length < 4 || clean.length.isOdd) return null;
  try {
    var i = 0;
    while (i + 3 < clean.length) {
      final type   = int.parse(clean.substring(i, i + 2), radix: 16);
      final len    = int.parse(clean.substring(i + 2, i + 4), radix: 16);
      final dataEnd = i + 4 + len * 2;
      if (dataEnd > clean.length) break;
      if (type == 0x02) return clean.substring(i + 4, dataEnd).toLowerCase();
      i = dataEnd;
    }
  } on Exception catch (_) {}
  return null;
}

// ── Border-router checks ───────────────────────────────────────────────────────

List<DiagCheckResult> borderRouterChecks(BorderRouterDiagnostic br, String? savedExtPanId) {
  final checks = <DiagCheckResult>[];

  // IPv4
  if (br.hasIpv4) {
    checks.add(DiagCheckResult(
      status: DiagStatus.ok, title: 'IPv4 address resolved',
      bullets: br.hostsV4.map((a) => '$a  (IPv4)').toList(),
    ));
  } else {
    checks.add(const DiagCheckResult(
      status: DiagStatus.warning, title: 'No IPv4 address resolved',
      subtitle: 'Border router found via mDNS but no A record returned',
    ));
  }

  // IPv6
  if (br.hasRoutableIpv6) {
    final v6 = [...br.hostsV6Ula, ...br.hostsV6Gua];
    checks.add(DiagCheckResult(
      status: DiagStatus.ok, title: 'IPv6 routable address resolved',
      subtitle: 'Phone can reach the border router over IPv6',
      bullets: v6.map((a) {
        final tag = br.hostsV6Gua.contains(a) ? 'GUA' : 'ULA';
        return '$a  ($tag)';
      }).toList(),
    ));
  } else if (br.hostsV6LinkLocal.isNotEmpty) {
    checks.add(DiagCheckResult(
      status: DiagStatus.warning, title: 'IPv6 link-local only',
      subtitle: 'No routable IPv6 address for this border router',
      bullets: br.hostsV6LinkLocal.map((a) => '$a  (link-local)').toList(),
      hint: 'The border router is visible via mDNS but only advertises a link-local IPv6 address. '
            'Thread devices on the mesh use routable ULA addresses. This may prevent the CHIP SDK from '
            'opening a CASE session. Check that SLAAC is enabled on your router and that the border '
            'router has a prefix delegation.',
    ));
  } else {
    checks.add(const DiagCheckResult(
      status: DiagStatus.fail, title: 'No IPv6 address resolved',
      subtitle: 'Border router resolved IPv4 only — Thread CASE will fail',
      hint: 'The border router has no IPv6 address reachable from this phone. Thread is IPv6-only. '
            'Even if BLE commissioning and Thread join succeed, the CHIP SDK cannot open a CASE session '
            'to the device.\n\nFix: enable SLAAC / DHCPv6 on your Wi-Fi router so both the phone and '
            'border router receive a ULA or GUA IPv6 address.',
    ));
  }

  // TCP reachability
  if (br.tcpReachable != null) {
    checks.add(br.tcpReachable!
        ? const DiagCheckResult(
            status: DiagStatus.ok, title: 'Directly reachable',
            subtitle: 'The app can open a direct connection to this border router — IP routing between '
                      'your phone and the border router is working.')
        : const DiagCheckResult(
            status: DiagStatus.fail, title: 'Not directly reachable',
            subtitle: 'Found via network scan but a direct connection attempt timed out.',
            hint: "Your phone and this border router can see each other's announcements, but cannot "
                  'exchange data directly. This is the most common cause of commissioning stalling at '
                  'the final step.\n\nCommon causes:\n'
                  '• Phone on 5 GHz / 6 GHz, border router on 2.4 GHz with band isolation\n'
                  '• Border router on a separate "IoT" or "smart home" network segment\n'
                  '• Guest Wi-Fi network — guest clients cannot reach devices on the main network\n'
                  '• "Client isolation" or "AP isolation" enabled on your router\n\n'
                  'What to do: try switching your phone to 2.4 GHz, or connect both devices to the '
                  'same main home network.'));
  }

  // IPv4 subnet match
  if (br.sameSubnetAsPhone != null) {
    checks.add(br.sameSubnetAsPhone!
        ? const DiagCheckResult(
            status: DiagStatus.ok, title: 'Same network segment (IPv4)',
            subtitle: 'Phone and border router are on the same IPv4 subnet — direct communication should work.')
        : const DiagCheckResult(
            status: DiagStatus.warning, title: 'Different network segments (IPv4)',
            subtitle: 'Phone and border router have IP addresses on different subnets.',
            hint: 'Your phone and this border router are on different IP address ranges. Direct '
                  'communication requires your router to forward traffic between the two segments.\n\n'
                  'This often happens when the border router is placed on a dedicated "IoT" VLAN while '
                  'the phone is on the main network.'));
  }

  // IPv6 prefix match
  if (br.ipv6PrefixMatchesPhone != null) {
    checks.add(br.ipv6PrefixMatchesPhone!
        ? const DiagCheckResult(
            status: DiagStatus.ok, title: 'Same IPv6 network segment',
            subtitle: 'Phone and border router share the same IPv6 /64 prefix — Thread device addresses will be routable.')
        : const DiagCheckResult(
            status: DiagStatus.warning, title: 'Different IPv6 network segments',
            subtitle: 'Phone and border router have IPv6 addresses on different /64 segments.',
            hint: 'Thread devices get their IPv6 addresses from the border router\'s mesh-local prefix. '
                  'If your phone is on a different IPv6 segment, it may not be able to reach those '
                  'devices directly.'));
  }

  // State bitmap
  final bm = br.stateBitmap;
  if (bm == null) {
    checks.add(const DiagCheckResult(
      status: DiagStatus.warning, title: 'State bitmap absent',
      subtitle: 'Border router did not include an sb TXT record'));
  } else {
    checks
      ..add(switch (bm.threadInterfaceStatus) {
        2 => DiagCheckResult(status: DiagStatus.ok,      title: 'Thread interface active',                      subtitle: bm.threadInterfaceLabel),
        1 => DiagCheckResult(status: DiagStatus.warning, title: 'Thread interface initialised but not attached', subtitle: bm.threadInterfaceLabel,
              hint: 'The border router has initialised its Thread interface but has not yet joined a '
                    'Thread partition. Try rebooting the border router.'),
        _ => DiagCheckResult(status: DiagStatus.fail,    title: 'Thread interface not initialised',             subtitle: bm.threadInterfaceLabel,
              hint: 'The border router has no active Thread interface. Devices will not be able to join '
                    'the Thread network. Try rebooting the border router.'),
      })
      ..add(bm.hasExternalConnectivity
          ? DiagCheckResult(status: DiagStatus.ok, title: 'External connectivity (${bm.connectionModeLabel})',
              subtitle: 'Border router has an active IP connection')
          : const DiagCheckResult(status: DiagStatus.fail, title: 'No external connectivity',
              subtitle: 'Connection mode = 0 in state bitmap',
              hint: 'The border router reports no external IP connectivity. The CHIP SDK cannot reach '
                    'commissioned devices even if they are on the Thread mesh.'));
  }

  // Dataset match
  if (savedExtPanId != null && savedExtPanId.isNotEmpty) {
    final match = br.extPanId.toLowerCase() == savedExtPanId.toLowerCase();
    checks.add(match
        ? DiagCheckResult(status: DiagStatus.ok, title: 'Dataset matches this border router',
            subtitle: 'Extended PAN ID: ${br.extPanId}')
        : DiagCheckResult(status: DiagStatus.fail, title: 'Dataset / border router mismatch',
            subtitle: 'Configured: $savedExtPanId\nThis router: ${br.extPanId}',
            hint: 'The Thread dataset stored in the app belongs to a different Thread network than this '
                  'border router. Fix: update the Thread dataset in Settings → Thread.'));
  }

  return checks;
}

// ── Non-BR sections (phone / network / matter) ────────────────────────────────

List<DiagSection> buildDiagSections(NetworkDiagnosticsReport r, String? savedExtPanId) {
  final sections     = <DiagSection>[];
  final phoneChecks  = <DiagCheckResult>[];
  final networkChecks = <DiagCheckResult>[];

  // IPv6
  final ipv6 = r.phoneIpv6;
  if (ipv6.hasRoutableIpv6) {
    final addrs = [...ipv6.ulaAddresses, ...ipv6.guaAddresses];
    phoneChecks.add(DiagCheckResult(
      status: DiagStatus.ok, title: 'Your network supports IPv6',
      subtitle: 'Thread smart home devices communicate exclusively over IPv6 — your phone has a working '
                'IPv6 address on this network and can reach Thread devices after they join.',
      bullets: addrs.map((a) {
        final tag = ipv6.guaAddresses.contains(a) ? 'public' : 'private';
        return '$a  ($tag)';
      }).toList(),
    ));
  } else if (ipv6.linkLocalAddresses.isNotEmpty) {
    phoneChecks.add(DiagCheckResult(
      status: DiagStatus.warning, title: 'IPv6 is only partially set up',
      subtitle: 'Your phone has an IPv6 address, but it only works within a single network segment.',
      bullets: ipv6.linkLocalAddresses.map((a) => '$a  (segment-local only)').toList(),
      hint: 'What to do: Log in to your Wi-Fi router and look for an IPv6 setting — it is sometimes '
            'labelled "SLAAC", "DHCPv6", or simply "IPv6". Enable it and reconnect your phone to Wi-Fi.',
    ));
  } else {
    phoneChecks.add(const DiagCheckResult(
      status: DiagStatus.fail, title: 'Your network does not support IPv6',
      subtitle: 'Thread smart home devices only communicate over IPv6 — your current Wi-Fi network is '
                'not providing an IPv6 address to this phone.',
      hint: 'What to do: Log in to your Wi-Fi router settings and enable IPv6. Look for options labelled '
            '"IPv6", "SLAAC", or "DHCPv6". Once enabled, reconnect your phone to Wi-Fi and run this '
            'check again.',
    ));
  }

  // Wi-Fi band
  final wb = r.wifi;
  if (wb.frequencyMhz > 0) {
    if (wb.is24Ghz) {
      phoneChecks.add(const DiagCheckResult(
        status: DiagStatus.ok, title: 'Phone is on 2.4 GHz Wi-Fi',
        subtitle: 'Most Thread Border Routers support 2.4 GHz — no band mismatch expected.'));
    } else if (wb.hasBandSuffix) {
      phoneChecks.add(DiagCheckResult(
        status: DiagStatus.warning, title: 'Phone is on a band-specific Wi-Fi network (${wb.band})',
        subtitle: '"${wb.ssid}" looks like a ${wb.band}-only network.',
        hint: 'Your router appears to use separate network names for its 2.4 GHz and ${wb.band} radios. '
              'Thread Border Routers that only support 2.4 GHz will be on the other network.\n\n'
              'What to do: connect your phone to the 2.4 GHz network and run this check again.'));
    } else if (r.borderRouters.isEmpty) {
      phoneChecks.add(DiagCheckResult(
        status: DiagStatus.warning, title: 'Phone is on ${wb.band} Wi-Fi — no border routers found',
        subtitle: 'Some Thread Border Routers only support 2.4 GHz and may not be visible on ${wb.band}.',
        hint: 'What to do: try switching your phone to the 2.4 GHz network and running this check again.'));
    } else {
      phoneChecks.add(DiagCheckResult(
        status: DiagStatus.ok, title: 'Phone is on ${wb.band} Wi-Fi',
        subtitle: 'Border router(s) are visible — your router bridges local network announcements across Wi-Fi bands.'));
    }
  }

  sections.add(DiagSection(heading: 'This phone', checks: phoneChecks));

  // mDNS / multicast
  networkChecks.add(r.multicastLockAcquired
      ? const DiagCheckResult(
          status: DiagStatus.ok, title: 'Device discovery is working',
          subtitle: 'Your phone can receive local network announcements. After a device joins Thread, '
                    'the app will find it automatically and complete the setup.')
      : const DiagCheckResult(
          status: DiagStatus.fail, title: 'Device discovery may be blocked',
          subtitle: 'The app was unable to listen for local network announcements on your current Wi-Fi connection.',
          hint: 'What this means: after a smart device joins Thread, the app searches for it on your '
                'local network. Your Wi-Fi connection is currently blocking that search, so setup will '
                'stall at the last step.\n\nWhat to do: check that you are connected to your main home '
                'Wi-Fi — not a guest network.'));

  // VPN
  if (r.vpn.isActive) {
    networkChecks.add(const DiagCheckResult(
      status: DiagStatus.warning, title: 'A VPN is active on this phone',
      subtitle: 'Some VPN configurations can interfere with smart home device setup.',
      hint: 'What this means: your phone is routing traffic through a VPN. If it tunnels all traffic, '
            'the app may not be able to open a direct connection to your Thread device.\n\n'
            'What to do: disable the VPN temporarily while commissioning the device.'));
  }

  sections.add(DiagSection(heading: 'Network', checks: networkChecks));

  // Matter services
  final DiagCheckResult matterCheck;
  if (r.matterTcpServices.isNotEmpty) {
    matterCheck = DiagCheckResult(
      status: DiagStatus.ok,
      title: '${r.matterTcpServices.length} Matter device${r.matterTcpServices.length == 1 ? '' : 's'} visible via mDNS',
      subtitle: 'Border router mDNS proxy is working end-to-end',
      bullets: r.matterTcpServices.toList(),
    );
  } else {
    matterCheck = DiagCheckResult(
      status: r.borderRouters.isEmpty ? DiagStatus.fail : DiagStatus.warning,
      title: 'No Matter devices visible via _matter._tcp',
      subtitle: r.borderRouters.isEmpty
          ? 'No border router found — mDNS proxy cannot be verified'
          : 'Border router(s) found but no Matter operational nodes visible',
      hint: r.borderRouters.isEmpty ? null :
          'If you have already commissioned Thread devices and they are online, this indicates the border '
          'router is not proxying _matter._tcp mDNS records from the Thread mesh to the Wi-Fi side.\n\n'
          'This is a common border router firmware limitation. Check for firmware updates for your border router.',
    );
  }
  sections.add(DiagSection(heading: 'Commissioned Matter devices', checks: [matterCheck]));

  return sections;
}

// ── Status colour / icon helpers — kept in widget layer (see diag_widgets.dart)
// The engine deliberately has no Flutter dependency; all colour decisions
// live alongside the widgets that consume them.
