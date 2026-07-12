import 'package:flutter/material.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:provider/provider.dart';

// Pastel accents, matching the category buttons' style (black fill, pastel
// outline + text). Coral = not connected, soft grey = connecting.
const _offlineColor    = Color(0xFFF2A9A0); // coral
const _connectingColor = Color(0xFFBFC4CC); // muted grey

/// A compact status button for the app bar (sits next to the settings action),
/// styled like the category buttons below the title: black fill, pastel outline
/// and text, no icon. Appears only when the hub is unreachable or reconnecting —
/// tapping it retries. Hidden when online or when no hub is paired.
class ControllerStatusChip extends StatelessWidget {
  const ControllerStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final hub    = context.watch<HubConnection>();
    final status = hub.status;

    if (status == ControllerStatus.online || status == ControllerStatus.noHub) {
      return const SizedBox.shrink();
    }

    final connecting = status == ControllerStatus.connecting;
    final color = connecting ? _connectingColor : _offlineColor;
    final label = connecting ? 'Connecting…' : 'Hub not connected';

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
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
