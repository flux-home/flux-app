import 'package:flutter/material.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:provider/provider.dart';

/// A compact status pill for the app bar (sits next to the settings action).
/// Appears only when the hub is unreachable or a reconnect is in progress —
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

    final cs         = Theme.of(context).colorScheme;
    final connecting = status == ControllerStatus.connecting;
    final bg = connecting ? cs.surfaceContainerHighest : cs.errorContainer;
    final fg = connecting ? cs.onSurfaceVariant : cs.onErrorContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: connecting ? null : hub.reconnect,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (connecting)
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else
                  Icon(Icons.cloud_off_outlined, size: 15, color: fg),
                const SizedBox(width: 5),
                Text(
                  connecting ? 'Connecting' : 'Offline',
                  style: TextStyle(
                      color: fg, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
