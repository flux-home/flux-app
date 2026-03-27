part of '../device_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// On/Off card
// ─────────────────────────────────────────────────────────────────────────────

class _OnOffCard extends StatelessWidget {
  final MatterDevice device;
  const _OnOffCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final provider = context.watch<DeviceProvider>();
    final live     = provider.liveDataFor(device.id);
    final isStale  = live?.isStale ?? false;
    final isOn     = live?.isOn ?? device.isOn;

    final label    = isStale ? '--' : (isOn ? 'ON' : 'OFF');
    final litColor = isStale
        ? Colors.white24
        : isOn
            ? Colors.white
            : Colors.white38;

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header row ─────────────────────────────────────────────
            Row(children: [
              Icon(Icons.power_settings_new_outlined,
                  size: 18,
                  color: isStale
                      ? cs.onSurfaceVariant.withAlpha(80)
                      : isOn
                          ? cs.onSurface
                          : cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Power',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Switch(
                value:     isOn,
                onChanged: isStale ? null : (_) => provider.toggle(device.id),
              ),
            ]),
            const SizedBox(height: 12),
            // ── Dot-matrix reading ─────────────────────────────────────
            SizedBox(
              height: 52,
              child: CustomPaint(
                painter: DotMatrixPainter(
                  text:     label,
                  litColor: litColor,
                  dimColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brightness card
// ─────────────────────────────────────────────────────────────────────────────

class _BrightnessCard extends StatelessWidget {
  final double brightness;
  final ValueChanged<double> onChanged;
  const _BrightnessCard({required this.brightness, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.brightness_6_outlined, size: 18),
            const SizedBox(width: 8),
            Text('Brightness', style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${(brightness * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
          Slider(value: brightness, onChangeEnd: onChanged, onChanged: (_) {},
                 min: 0.01, max: 1.0),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sensor readings section
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingsSection extends StatelessWidget {
  final List<_Reading>? readings;
  final bool loading;
  final VoidCallback onRefresh;

  const _ReadingsSection({
    required this.readings,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (readings == null || readings!.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        mainAxisSpacing:  10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount:   readings!.length,
      itemBuilder: (_, i) => _ReadingCard(reading: readings![i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual reading tile  — home-screen card style + dot-matrix value
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingCard extends StatelessWidget {
  final _Reading reading;
  const _ReadingCard({required this.reading});

  /// True when the displayValue is a plain number (usable as dot-matrix input).
  bool get _isNumeric => double.tryParse(reading.displayValue) != null;

  @override
  Widget build(BuildContext context) {
    final isNum   = _isNumeric;
    final hasUnit = reading.unit.isNotEmpty;

    return Card(
      color: Colors.white.withAlpha(18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: Colors.white, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top-left: icon + label + quality dot ──────────────────────
            Row(children: [
              Icon(reading.icon, size: 14, color: reading.iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(reading.label,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11,
                        fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (reading.quality != null)
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: _qualityColor(reading.quality!),
                    shape: BoxShape.circle,
                  ),
                ),
            ]),

            // ── Centre: value ──────────────────────────────────────────────
            Expanded(
              child: Center(
                child: SizedBox(
                  height: 38,
                  width: double.infinity,
                  child: isNum
                      ? CustomPaint(
                          painter: DotMatrixPainter(
                            text:     reading.displayValue,
                            litColor: Colors.white,
                            dimColor: Colors.white.withAlpha(28),
                          ),
                        )
                      : Center(
                          child: Text(
                            reading.displayValue,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
              ),
            ),

            // ── Bottom-right: unit ─────────────────────────────────────────
            if (hasUnit || reading.subtitle != null)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  reading.subtitle != null && !hasUnit
                      ? reading.subtitle!
                      : reading.unit,
                  style: TextStyle(
                    color: reading.quality != null
                        ? _qualityColor(reading.quality!)
                        : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

