import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/models/network_diagnostics.dart';
import 'package:matter_home/services/network_diagnostics_engine.dart';

// ── Minimal fakes ─────────────────────────────────────────────────────────────

BorderRouterDiagnostic _br({
  String serviceName = 'br._meshcop._udp',
  String networkName = 'HomeThread',
  String extPanId    = 'aabbccddeeff0011',
  bool hasIpv4       = true,
  bool hasRoutableIpv6 = true,
  bool? tcpReachable,
  bool? sameSubnet,
  bool? ipv6PrefixMatch,
  StateBitmapInfo? stateBitmap,
}) => BorderRouterDiagnostic(
  serviceName:          serviceName,
  networkName:          networkName,
  extPanId:             extPanId,
  vendorName:           '',
  modelName:            '',
  port:                 8080,
  hostsV4:              hasIpv4 ? ['192.168.1.100'] : [],
  hostsV6Ula:           hasRoutableIpv6 ? ['fd00::1'] : [],
  hostsV6Gua:           [],
  hostsV6LinkLocal:     hasRoutableIpv6 ? [] : ['fe80::1'],
  tcpReachable:         tcpReachable,
  sameSubnetAsPhone:    sameSubnet,
  ipv6PrefixMatchesPhone: ipv6PrefixMatch,
  stateBitmap:          stateBitmap,
);

StateBitmapInfo _bitmap({int threadInterface = 2, bool externalConnectivity = true}) =>
    StateBitmapInfo(
      raw:                   0,
      connectionMode:        externalConnectivity ? 1 : 0,
      connectionModeLabel:   externalConnectivity ? 'WiFi' : 'None',
      threadInterfaceStatus: threadInterface,
      threadInterfaceLabel:  '',
      availability:          1,
      bbrActive:             false,
      bbrIsPrimary:          false,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('extractExtPanId', () {
    test('returns null for empty string', () {
      expect(extractExtPanId(''), isNull);
    });

    test('parses ext PAN ID (type 0x02) from TLV hex', () {
      // TLV: type=0x02, len=0x08, value=aabbccddeeff0011
      const tlv = '0208aabbccddeeff0011';
      expect(extractExtPanId(tlv), equals('aabbccddeeff0011'));
    });

    test('returns null when type 0x02 absent', () {
      // TLV: type=0x03, len=0x04, value=74657374 ("test")
      const tlv = '030474657374';
      expect(extractExtPanId(tlv), isNull);
    });
  });

  group('worstStatus', () {
    test('returns ok when all checks ok', () {
      final checks = [
        const DiagCheckResult(status: DiagStatus.ok, title: 'a'),
        const DiagCheckResult(status: DiagStatus.ok, title: 'b'),
      ];
      expect(worstStatus(checks), equals(DiagStatus.ok));
    });

    test('returns warning when one warning present', () {
      final checks = [
        const DiagCheckResult(status: DiagStatus.ok, title: 'a'),
        const DiagCheckResult(status: DiagStatus.warning, title: 'b'),
      ];
      expect(worstStatus(checks), equals(DiagStatus.warning));
    });

    test('fail dominates warning', () {
      final checks = [
        const DiagCheckResult(status: DiagStatus.warning, title: 'a'),
        const DiagCheckResult(status: DiagStatus.fail, title: 'b'),
      ];
      expect(worstStatus(checks), equals(DiagStatus.fail));
    });
  });

  group('borderRouterChecks — IPv6', () {
    test('ok when routable IPv6 present', () {
      final checks = borderRouterChecks(_br(hasRoutableIpv6: true), null);
      final ipv6 = checks.firstWhere((c) => c.title.contains('IPv6 routable'));
      expect(ipv6.status, equals(DiagStatus.ok));
    });

    test('warning when only link-local IPv6', () {
      final br = _br(hasRoutableIpv6: false);
      final checks = borderRouterChecks(br, null);
      final ipv6 = checks.firstWhere(
          (c) => c.title.contains('link-local'), orElse: () => checks[1]);
      expect(ipv6.status, equals(DiagStatus.warning));
    });

    test('fail when no IPv6 at all', () {
      final br = BorderRouterDiagnostic(
        serviceName: 'br', networkName: 'net', extPanId: 'aa',
        vendorName: '', modelName: '',
        port: 0,
        hostsV4: ['192.168.1.1'], hostsV6Ula: [], hostsV6Gua: [],
        hostsV6LinkLocal: [],
        tcpReachable: null, sameSubnetAsPhone: null,
        ipv6PrefixMatchesPhone: null, stateBitmap: null,
      );
      final checks = borderRouterChecks(br, null);
      final ipv6Check = checks[1]; // second check is IPv6
      expect(ipv6Check.status, equals(DiagStatus.fail));
    });
  });

  group('borderRouterChecks — state bitmap', () {
    test('ok when thread interface active (status=2)', () {
      final br = _br(stateBitmap: _bitmap(threadInterface: 2));
      final checks = borderRouterChecks(br, null);
      final bitmapCheck = checks.firstWhere((c) => c.title.contains('Thread interface'));
      expect(bitmapCheck.status, equals(DiagStatus.ok));
    });

    test('fail when thread interface not initialised (status=0)', () {
      final br = _br(stateBitmap: _bitmap(threadInterface: 0));
      final checks = borderRouterChecks(br, null);
      final bitmapCheck = checks.firstWhere((c) => c.title.contains('Thread interface'));
      expect(bitmapCheck.status, equals(DiagStatus.fail));
    });

    test('fail when no external connectivity', () {
      final br = _br(stateBitmap: _bitmap(externalConnectivity: false));
      final checks = borderRouterChecks(br, null);
      final conn = checks.firstWhere((c) => c.title.contains('connectivity'));
      expect(conn.status, equals(DiagStatus.fail));
    });
  });

  group('borderRouterChecks — dataset match', () {
    test('ok when ext PAN ID matches saved', () {
      final br = _br(extPanId: 'aabb');
      final checks = borderRouterChecks(br, 'aabb');
      final match = checks.firstWhere((c) => c.title.contains('Dataset'));
      expect(match.status, equals(DiagStatus.ok));
    });

    test('fail when ext PAN ID mismatches saved', () {
      final br = _br(extPanId: 'aabb');
      final checks = borderRouterChecks(br, 'ccdd');
      final match = checks.firstWhere((c) => c.title.contains('Dataset'));
      expect(match.status, equals(DiagStatus.fail));
    });

    test('no dataset check when savedExtPanId is null', () {
      final br = _br();
      final checks = borderRouterChecks(br, null);
      final match = checks.where((c) => c.title.contains('Dataset'));
      expect(match, isEmpty);
    });
  });

  group('brLabel', () {
    test('returns vendor+model when both present', () {
      final br = BorderRouterDiagnostic(
        serviceName: 'svc', networkName: 'n', extPanId: 'e',
        vendorName: 'Apple', modelName: 'HomePod',
        port: 0,
        hostsV4: [], hostsV6Ula: [], hostsV6Gua: [], hostsV6LinkLocal: [],
        tcpReachable: null, sameSubnetAsPhone: null,
        ipv6PrefixMatchesPhone: null, stateBitmap: null,
      );
      expect(brLabel(br), equals('Apple HomePod'));
    });

    test('falls back to serviceName when vendor/model absent', () {
      final br = BorderRouterDiagnostic(
        serviceName: 'my-br', networkName: 'n', extPanId: 'e',
        vendorName: '', modelName: '',
        port: 0,
        hostsV4: [], hostsV6Ula: [], hostsV6Gua: [], hostsV6LinkLocal: [],
        tcpReachable: null, sameSubnetAsPhone: null,
        ipv6PrefixMatchesPhone: null, stateBitmap: null,
      );
      expect(brLabel(br), equals('my-br'));
    });
  });
}
