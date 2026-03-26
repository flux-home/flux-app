import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_type.dart';
import '../../models/matter_device.dart';
import '../../providers/device_provider.dart';
import 'dot_matrix_painter.dart';

// ─── Shared tile style ────────────────────────────────────────────────────────

const _kRadius = 22.0;
const _kCardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(_kRadius)),
  side: BorderSide(color: Colors.white, width: 1.5),
);

// ─── Entry point ─────────────────────────────────────────────────────────────

class DeviceCard extends StatelessWidget {
  final MatterDevice device;
  final VoidCallback onTap;

  const DeviceCard({super.key, required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final live        = context.watch<DeviceProvider>().liveDataFor(device.id);
    final productName = (device.productName?.isNotEmpty ?? false)
        ? device.productName
        : (live?.productName?.isNotEmpty ?? false) ? live!.productName : null;

    if (device.deviceType == DeviceType.thermostat) {
      return _ThermostatTile(device: device, onTap: onTap, productName: productName);
    }
    return _BaseTile(device: device, onTap: onTap, subLabel: productName);
  }
}

// ─── Base tile ───────────────────────────────────────────────────────────────
//
//  ┌──────────────────────────┐
//  │                          │
//  │        [body]            │  ← expanding middle (optional)
//  │                          │
//  │  device name             │  ← footer
//  │  product name (dim)      │
//  └──────────────────────────┘

class _BaseTile extends StatelessWidget {
  final MatterDevice device;
  final VoidCallback onTap;
  final Widget?      body;
  final String?      subLabel;

  const _BaseTile({
    required this.device,
    required this.onTap,
    this.body,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: _kCardShape,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Middle body (expanding) ────────────────────────────────
              if (body != null) ...[
                Expanded(child: body!),
              ] else
                const Spacer(),

              // ── Footer: device name + optional product name ────────────
              Text(
                device.name,
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
                    fontSize: 10,
                    color: Colors.white54,
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

// ─── Thermostat tile ──────────────────────────────────────────────────────────

class _ThermostatTile extends StatelessWidget {
  final MatterDevice device;
  final VoidCallback onTap;
  final String?      productName;

  const _ThermostatTile({
    required this.device,
    required this.onTap,
    this.productName,
  });

  @override
  Widget build(BuildContext context) {
    final temp    = device.localTempCenti;
    final tempStr = temp != null ? (temp / 100.0).toStringAsFixed(1) : '--.-';

    return _BaseTile(
      device:   device,
      onTap:    onTap,
      subLabel: productName,
      body: LayoutBuilder(
        builder: (_, constraints) => Center(
          child: CustomPaint(
            size: Size(constraints.maxWidth * 0.85, constraints.maxHeight * 0.75),
            painter: DotMatrixPainter(text: tempStr, litColor: Colors.white),
          ),
        ),
      ),
    );
  }
}
