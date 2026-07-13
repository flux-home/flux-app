import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:provider/provider.dart';

/// Lets the user enter the fixed parts of their electricity tariff — the net
/// per-kWh fees/levies/taxes added on top of the wholesale spot price, and VAT
/// — so the energy price view shows the real consumer price they pay:
///   gross = (spot + fees) × (1 + VAT).
/// Stored on the controller (PricingConfig markup_ueur_per_kwh + vat_percent).
class TariffSettingsScreen extends StatefulWidget {
  const TariffSettingsScreen({super.key});

  @override
  State<TariffSettingsScreen> createState() => _TariffSettingsScreenState();
}

class _TariffSettingsScreenState extends State<TariffSettingsScreen> {
  final _fees = TextEditingController();
  final _vat = TextEditingController();
  final _feedIn = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<DeviceProvider>();
      await provider.fetchEnergyPrices(); // also loads the pricing config
      if (!mounted) return;
      _prefill();
    });
  }

  void _prefill() {
    final cfg = context.read<DeviceProvider>().pricingConfig;
    if (cfg != null && !_loaded) {
      _fees.text = (cfg.markupUeurPerKwh / 10000.0).toStringAsFixed(2);
      _vat.text = cfg.vatPercent.toString();
      _feedIn.text = (cfg.feedInUeurPerKwh / 10000.0).toStringAsFixed(1);
      setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    _fees.dispose();
    _vat.dispose();
    _feedIn.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final feesCt = double.tryParse(_fees.text.replaceAll(',', '.'));
    final vat = int.tryParse(_vat.text.trim());
    final feedInCt = double.tryParse(_feedIn.text.replaceAll(',', '.')) ?? 0;
    if (feesCt == null || vat == null) {
      _snack('Enter valid numbers');
      return;
    }
    setState(() => _saving = true);
    final ok = await context.read<DeviceProvider>().updateTariff(
          markupUeurPerKwh: (feesCt * 10000).round(),
          vatPercent: vat,
          feedInUeurPerKwh: (feedInCt * 10000).round(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(ok ? 'Tariff saved' : 'Couldn\'t save — hub unreachable?');
    if (ok) Navigator.of(context).pop();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Prefill once the config arrives.
    context.watch<DeviceProvider>();
    _prefill();
    final online = context.watch<HubConnection>().isOnline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Electricity tariff',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Your bill adds fixed grid fees, levies and taxes on top of the '
            'wholesale spot price, then VAT. Enter them so the price view shows '
            'what you actually pay.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _fees,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Grid fees, levies & taxes',
              helperText: 'Net ct/kWh added on top of spot (e.g. 11.04)',
              suffixText: 'ct/kWh',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _vat,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'VAT',
              helperText: 'e.g. 19',
              suffixText: '%',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _feedIn,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Feed-in tariff (Einspeisevergütung)',
              helperText: 'Paid per kWh exported to the grid (e.g. 6.7)',
              suffixText: 'ct/kWh',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Gross price = (spot + fees) × (1 + VAT). Feed-in credits exported '
            'energy. A fixed monthly base fee (if any) isn\'t part of the '
            'per-kWh price.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_saving || !online) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(online ? 'Save' : 'Hub offline'),
          ),
        ],
      ),
    );
  }
}
