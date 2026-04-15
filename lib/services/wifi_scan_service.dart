import 'package:permission_handler/permission_handler.dart';

import '../models/wifi_network.dart';
import 'matter_port.dart';

// ── Result ────────────────────────────────────────────────────────────────────

class WifiScanResult {
  final List<WifiNetwork> networks;

  /// First network where [WifiNetwork.isConnected] is true, or null if none.
  final WifiNetwork? autoSelected;

  final bool permissionDenied;
  final bool permanentlyDenied;

  const WifiScanResult({
    required this.networks,
    this.autoSelected,
    this.permissionDenied  = false,
    this.permanentlyDenied = false,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Centralises Wi-Fi network scanning: requests location permission, calls the
/// port, and applies the connected-first auto-selection policy.
///
/// Callers receive a [WifiScanResult] and handle SnackBar presentation
/// themselves; this service never touches [BuildContext].
class WifiScanService {
  const WifiScanService(this._port);

  final MatterCommissionPort _port;

  Future<WifiScanResult> scan() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      return WifiScanResult(
        networks:          const [],
        permissionDenied:  true,
        permanentlyDenied: status.isPermanentlyDenied,
      );
    }

    final nets      = await _port.scanWifiNetworks();
    final connected = nets.where((n) => n.isConnected).firstOrNull;

    return WifiScanResult(
      networks:     nets,
      autoSelected: connected,
    );
  }
}
