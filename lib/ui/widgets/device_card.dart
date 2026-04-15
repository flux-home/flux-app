import 'package:flutter/material.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:provider/provider.dart';

// ─── Shared tile style ────────────────────────────────────────────────────────

const _kRadius = 22.0;
const _kCardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(_kRadius)),
  side: BorderSide(color: Colors.white, width: 1.5),
);

// ─── Entry point ─────────────────────────────────────────────────────────────

/// Home-screen tile for a single device.
///
/// Watches [DeviceProvider] directly (by device ID) so it rebuilds on every
/// subscription notification without depending on parent sliver delegate
/// propagation.
class DeviceCard extends StatelessWidget {

  const DeviceCard({required this.deviceId, required this.onTap, super.key});
  final String       deviceId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final view = context.watch<DeviceProvider>().viewFor(deviceId);
    if (view == null) return const SizedBox.shrink();

    return _BaseTile(view: view, onTap: onTap, subLabel: view.displayProductName);
  }
}

// ─── Base tile ───────────────────────────────────────────────────────────────

class _BaseTile extends StatelessWidget {

  const _BaseTile({
    required this.view,
    required this.onTap,
    this.subLabel,
  });
  final DeviceView   view;
  final VoidCallback onTap;
  final String?      subLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color:     Colors.transparent,
      elevation: 0,
      shape:     _kCardShape,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // ── Footer: device name + optional sub-label ───────────────
              Text(
                view.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  subLabel!,
                  style: const TextStyle(
                    fontSize:      10,
                    color:         Colors.white54,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
