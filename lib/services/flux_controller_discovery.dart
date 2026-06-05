import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/flux_coap_service.dart';

/// Discovers the Flux Controller on the local network.
///
/// PSK lookup key is the **controller ID** — the stable hostname advertised
/// in the mDNS SRV record (`flux-controller-e25311.local` → ID is
/// `flux-controller-e25311`).  This never changes even if the IP changes via
/// DHCP, and it is the same value that appears in the QR code `id=` field.
///
/// Discovery order:
///   1. mDNS `_fluxhub._tcp` → SRV → derive controller ID → load PSK → probe
///   2. Stored manual-IP override (Settings → Flux Hub) — user must also have
///      stored the PSK via the QR-scan / hex-entry flow.
class FluxControllerDiscovery {
  static const _serviceType = '_fluxhub._tcp';
  static const _mdnsTimeout = Duration(seconds: 20); // covers DTLS handshake (~10s) + mDNS (~3s) + margin

  // ── Public ─────────────────────────────────────────────────────────────────

  static Future<FluxControllerEndpoint?> discover() async {
    final fromMdns = await _discoverViaMdns();
    if (fromMdns != null) return fromMdns;

    final manual = await ControllerSettings.loadManualOverride();
    if (manual != null) {
      debugPrint('FluxControllerDiscovery: mDNS failed, trying manual '
          '${manual.host}:${manual.port}');
      // For manual overrides we don't know the controller ID from mDNS.
      // Try loading the PSK by any stored ID (first match) or fall back to
      // the host string as the key.
      return _probeWithPsk(
        host:         manual.host,
        port:         manual.port,
        controllerId: manual.host,  // user must have stored PSK under this key
      );
    }

    return null;
  }

  // ── mDNS ───────────────────────────────────────────────────────────────────

  static Future<FluxControllerEndpoint?> _discoverViaMdns() async {
    final client = MDnsClient();
    try {
      await client.start();
      return await _lookupEndpoint(client)
          .timeout(_mdnsTimeout, onTimeout: () => null);
    } on Exception catch (e) {
      debugPrint('FluxControllerDiscovery: mDNS error: $e');
      return null;
    } finally {
      client.stop();
    }
  }

  static Future<FluxControllerEndpoint?> _lookupEndpoint(
      MDnsClient client) async {
    await for (final ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(_serviceType),
    )) {
      debugPrint('FluxControllerDiscovery: PTR ${ptr.domainName}');

      await for (final srv in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      )) {
        // Derive the stable controller ID from the SRV target hostname.
        // srv.target is e.g. "flux-controller-e25311.local" → strip ".local".
        final controllerId = srv.target
            .replaceAll(RegExp(r'\.local\.?$', caseSensitive: false), '');

        debugPrint('FluxControllerDiscovery: SRV ${srv.target}:${srv.port} '
            '(id: $controllerId)');

        await for (final ip in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        )) {
          final ep = await _probeWithPsk(
            host:         ip.address.address,
            port:         srv.port,
            controllerId: controllerId,
          );
          if (ep != null) return ep;
        }
      }
    }
    return null;
  }

  // ── Probe ──────────────────────────────────────────────────────────────────

  /// Loads the stored PSK for [controllerId] and probes over DTLS.
  /// Returns null if no PSK is stored or the probe fails.
  static Future<FluxControllerEndpoint?> _probeWithPsk({
    required String host,
    required int    port,
    required String controllerId,
  }) async {
    final psk = await ControllerSettings.loadPsk(controllerId);
    if (psk == null) {
      debugPrint('FluxControllerDiscovery: no PSK for "$controllerId" — '
          'scan the QR code on the device label in Settings → Flux Hub');
      return null;
    }
    debugPrint('FluxControllerDiscovery: probing coaps://$host:$port '
        '(id: $controllerId)');
    // controllerId IS the DTLS identity (it's the same hostname).
    return FluxCoapService.probe(host, port,
        psk: psk, dtlsIdentity: controllerId);
  }
}
