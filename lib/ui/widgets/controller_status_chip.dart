import 'package:flutter/material.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:provider/provider.dart';

// Pastel accents, matching the category buttons' style (black fill, pastel
// outline + text).
const _offlineColor    = Color(0xFFF2A9A0); // coral   — not connected
const _connectingColor = Color(0xFFBFC4CC); // grey    — reconnecting
const _localColor      = Color(0xFF9FD8A8); // green   — on the local network
const _remoteColor     = Color(0xFFA9C7F2); // blue    — via remote tunnel

/// Compact connection-status button for the app bar (next to the settings
/// action), styled like the category buttons: black fill, pastel outline + a
/// small status dot and label. Reflects how the hub is reached:
///   • Local  — direct LAN connection (green)
///   • Remote — off-LAN via the ICE tunnel (blue)
///   • Connecting… (grey) / Controller not connected (coral)
/// Hidden only when no hub is paired. Tapping (re)connects, except while a
/// connection attempt is already in progress.
class ControllerStatusChip extends StatelessWidget {
  const ControllerStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final hub    = context.watch<HubConnection>();
    final status = hub.status;

    if (status == ControllerStatus.noHub) return const SizedBox.shrink();

    final (Color color, String label) = switch (status) {
      ControllerStatus.online => switch (hub.connectionKind) {
          ConnectionKind.remote => (_remoteColor, 'Remote'),
          _                     => (_localColor,  'Local'),
        },
      ControllerStatus.connecting => (_connectingColor, 'Connecting…'),
      _                           => (_offlineColor,    'Controller not connected'),
    };
    final connecting = status == ControllerStatus.connecting;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Material(
        color: Colors.black,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color, width: 1.5),
        ),
        child: InkWell(
          onTap: connecting ? null : hub.reconnect,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
