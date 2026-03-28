import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_type.dart';
import '../../models/device_view.dart';
import '../../providers/device_provider.dart';

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
  final String       deviceId;
  final VoidCallback onTap;

  const DeviceCard({super.key, required this.deviceId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final view = context.watch<DeviceProvider>().viewFor(deviceId);
    if (view == null) return const SizedBox.shrink();

    if (view.deviceType == DeviceType.contactSensor) {
      final state = view.contactState;
      final label = state == true  ? 'Closed'
                  : state == false ? 'Open'
                  : '—';
      final color = state == true  ? const Color(0xFF34A853)
                  : state == false ? const Color(0xFFF29900)
                  : Colors.white38;
      return _BaseTile(
        view:     view,
        onTap:    onTap,
        subLabel: view.displayProductName,
        indicator: Text(
          label,
          style: TextStyle(
            fontSize:      22,
            fontWeight:    FontWeight.w700,
            color:         color,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return _BaseTile(view: view, onTap: onTap, subLabel: view.displayProductName);
  }
}

// ─── Base tile ───────────────────────────────────────────────────────────────

class _BaseTile extends StatelessWidget {
  final DeviceView   view;
  final VoidCallback onTap;
  final String?      subLabel;
  final Widget?      indicator;

  const _BaseTile({
    required this.view,
    required this.onTap,
    this.subLabel,
    this.indicator,
  });

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
              // ── Body area ──────────────────────────────────────────────
              if (indicator != null)
                Expanded(child: Center(child: indicator!))
              else
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
