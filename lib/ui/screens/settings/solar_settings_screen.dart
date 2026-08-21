import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/proto/flux.pb.dart' as $proto;

/// The site model behind the production forecast: where the roof is, which way
/// it faces, and how big it is.
///
/// The controller does the forecasting itself — it fetches irradiance and runs
/// the plane-of-array model on-device — so these values are not cosmetic. Get the
/// azimuth wrong by 90° and the curve peaks two hours out.
///
/// Writes are LAN-only on the controller (flux-proto ADR-0012), so the save
/// button is disabled over a remote tunnel rather than failing after the fact.
class SolarSettingsScreen extends StatefulWidget {
  const SolarSettingsScreen({super.key});

  @override
  State<SolarSettingsScreen> createState() => _SolarSettingsScreenState();
}

class _SolarSettingsScreenState extends State<SolarSettingsScreen> {
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _tilt = TextEditingController();
  final _azimuth = TextEditingController();
  final _kwp = TextEditingController();
  final _acLimit = TextEditingController();
  final _loss = TextEditingController();

  bool _enabled = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cfg = await context.read<DeviceProvider>().fetchSolarConfig();
      if (!mounted || cfg == null) return;
      _fill(cfg);
    });
  }

  void _fill($proto.SolarConfig c) {
    final plane = c.planes.isNotEmpty ? c.planes.first : $proto.SolarPlane();
    setState(() {
      _enabled = c.enabled;
      _lat.text = (c.latitudeUdeg / 1e6).toStringAsFixed(6);
      _lon.text = (c.longitudeUdeg / 1e6).toStringAsFixed(6);
      _tilt.text = plane.tiltDeg.toString();
      _azimuth.text = plane.azimuthDeg.toString();
      _kwp.text = (plane.kwpW / 1000.0).toStringAsFixed(1);
      _acLimit.text = c.inverterAcW == 0
          ? ''
          : (c.inverterAcW / 1000.0).toStringAsFixed(1);
      _loss.text = c.systemLossPct == 0 ? '' : c.systemLossPct.toString();
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_lat, _lon, _tilt, _azimuth, _kwp, _acLimit, _loss]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final lat = _num(_lat), lon = _num(_lon);
    final tilt = _num(_tilt), azi = _num(_azimuth), kwp = _num(_kwp);
    if (lat == null || lon == null || tilt == null || azi == null || kwp == null) {
      _snack('Fill in location, tilt, azimuth and size');
      return;
    }
    if (lat.abs() > 90 || lon.abs() > 180) {
      _snack('Latitude is −90…90, longitude −180…180');
      return;
    }
    if (tilt < 0 || tilt > 90) { _snack('Tilt is 0…90°'); return; }
    if (azi < 0 || azi > 359) { _snack('Azimuth is 0…359°'); return; }
    if (kwp <= 0) { _snack('Array size must be more than zero'); return; }

    // Start from the stored config so fields this screen does not show — albedo,
    // the temperature coefficient, the provider — survive a save here.
    final provider = context.read<DeviceProvider>();
    final cfg = provider.solarConfig?.deepCopy() ?? $proto.SolarConfig();
    cfg
      ..enabled = _enabled
      ..latitudeUdeg = (lat * 1e6).round()
      ..longitudeUdeg = (lon * 1e6).round()
      ..inverterAcW = ((_num(_acLimit) ?? 0) * 1000).round()
      ..systemLossPct = (_num(_loss) ?? 0).round();
    if (cfg.provider.isEmpty) cfg.provider = 'openmeteo';
    cfg.planes
      ..clear()
      ..add($proto.SolarPlane(
        tiltDeg: tilt.round(),
        azimuthDeg: azi.round(),
        kwpW: (kwp * 1000).round(),
      ));

    setState(() => _saving = true);
    final ok = await provider.updateSolarConfig(cfg);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(ok ? 'Solar settings saved' : "Couldn't save — on the local network?");
    if (ok) Navigator.of(context).pop();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hub = context.watch<HubConnection>();
    final canWrite = hub.connectionKind == ConnectionKind.local;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solar forecast',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'The controller forecasts your production itself: it fetches the sky '
            'and models your roof. These are the numbers that model uses.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: _loaded ? (v) => setState(() => _enabled = v) : null,
            title: const Text('Forecast production'),
            subtitle: Text(
                'Off means no outbound weather requests at all.',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          const Divider(height: 24),

          _label(context, 'LOCATION'),
          Row(children: [
            Expanded(child: _field(_lat, 'Latitude', '49.477491', '°',
                decimal: true, signed: true)),
            const SizedBox(width: 12),
            Expanded(child: _field(_lon, 'Longitude', '11.077298', '°',
                decimal: true, signed: true)),
          ]),
          const SizedBox(height: 8),
          Text('Decimal degrees, north and east positive. A few hundred metres '
              'is close enough — this sets the sun\'s position, not the weather '
              'station.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),

          _label(context, 'THE ARRAY'),
          _field(_tilt, 'Tilt', '30', '°', helper: '0 = flat, 90 = vertical'),
          const SizedBox(height: 14),
          _field(_azimuth, 'Azimuth', '180', '°',
              helper: 'Compass bearing the panels FACE: 180 = south, '
                  '90 = east, 270 = west'),
          const SizedBox(height: 14),
          _field(_kwp, 'Array size', '18.0', 'kWp', decimal: true,
              helper: 'DC peak capacity, as on the panels'),
          const SizedBox(height: 20),

          _label(context, 'INVERTER'),
          _field(_acLimit, 'AC limit', 'e.g. 12.0', 'kW', decimal: true,
              helper: 'Blank = no clipping. An array oversized against its '
                  'inverter over-predicts sunny middays by ~15% without this.'),
          const SizedBox(height: 14),
          _field(_loss, 'System losses', '13', '%',
              helper: 'Soiling, mismatch, wiring. Blank = 13%.'),
          const SizedBox(height: 24),

          if (!canWrite)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                hub.isOnline
                    ? 'Connected remotely — these can only be changed on your '
                      'home network.'
                    : 'Controller unreachable.',
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ),
          FilledButton(
            onPressed: (_saving || !canWrite || !_loaded) ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: TextStyle(
            fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _field(TextEditingController c, String label, String hint, String unit,
      {String? helper, bool decimal = false, bool signed = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(
          decimal: decimal, signed: signed),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            RegExp(signed ? r'[0-9.,\-]' : (decimal ? r'[0-9.,]' : r'[0-9]'))),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        suffixText: unit,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
