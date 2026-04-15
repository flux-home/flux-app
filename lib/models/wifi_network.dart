import 'package:matter_home/services/matter_channel.dart' show MatterChannel;

/// A nearby Wi-Fi network returned by [MatterChannel.scanWifiNetworks].
class WifiNetwork {

  const WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.isConnected,
  });

  factory WifiNetwork.fromMap(Map<Object?, Object?> m) => WifiNetwork(
        ssid:        m['ssid']!        as String,
        rssi:        (m['rssi']!       as num).toInt(),
        isConnected: m['isConnected']! as bool,
      );
  final String ssid;
  final int    rssi;
  final bool   isConnected;

  /// Maps RSSI (dBm) to a 0–4 signal bar count.
  int get bars {
    if (rssi >= -55) return 4;
    if (rssi >= -66) return 3;
    if (rssi >= -77) return 2;
    if (rssi >= -88) return 1;
    return 0;
  }
}
