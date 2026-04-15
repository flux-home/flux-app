import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/commission_models.dart';
import '../../models/wifi_network.dart';
import '../../providers/commissioning_controller.dart';
import '../../providers/device_provider.dart';
import '../../services/matter_port.dart';
import '../../services/qr_payload_service.dart';
import '../../services/thread_settings_service.dart';
import '../../services/wifi_scan_service.dart';
import '../widgets/dot_matrix_painter.dart';
import '../widgets/section_label.dart';
import 'qr_payload_detail_screen.dart';
import 'qr_scanner_screen.dart';

class CommissionScreen extends StatefulWidget {
  /// When provided the screen skips the form and starts commissioning immediately.
  final String? initialPayload;
  const CommissionScreen({super.key, this.initialPayload});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  // ── UI-only state ─────────────────────────────────────────────────────────
  bool _expertMode = false;

  // Form state — method / network type are initialised from the parsed payload
  // but can be overridden by the user in expert mode.
  CommissionMethod _method  = CommissionMethod.ble;
  int              _netType = 0; // 0 = Thread, 1 = Wi-Fi, 2 = None

  bool _showThreadDataset = false;
  bool _showPassword      = false;

  // ── Form controllers ───────────────────────────────────────────────────────
  final _threadCtrl = TextEditingController();
  final _ssidCtrl   = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _ipCtrl     = TextEditingController();
  final _discCtrl   = TextEditingController();
  final _pinCtrl    = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  // ── Log scroll controller ─────────────────────────────────────────────────
  final _rawLogScrollCtrl = ScrollController();

  // ── Commissioning controller ──────────────────────────────────────────────
  late CommissioningController _ctrl;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _ctrl = CommissioningController(
      port:                 context.read<MatterCommissionPort>(),
      provider:             context.read<DeviceProvider>(),
      requestBlePermissions: _requestBlePermissions,
      onNeedsCredentials:   _credentialCallback,
      threadDataset:        () => _threadCtrl.text,
    );
    _ctrl.addListener(_onControllerChanged);

    // Pre-fill Thread dataset from stored settings.
    ThreadSettingsService.load().then((ds) {
      if (mounted) _threadCtrl.text = ds;
    });

    if (widget.initialPayload != null) {
      // Opened from the camera — start immediately, no form shown.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setPayload(widget.initialPayload!, autoStart: true);
      });
    } else {
      // Restore the last scanned payload so the user doesn't have to re-scan.
      QrPayloadService.load().then((saved) {
        if (saved != null && mounted) _setPayload(saved, autoStart: false);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChanged);
    _ctrl.dispose();
    _threadCtrl.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _ipCtrl.dispose();
    _discCtrl.dispose();
    _pinCtrl.dispose();
    _rawLogScrollCtrl.dispose();
    super.dispose();
  }

  // ── Controller listener ────────────────────────────────────────────────────

  void _onControllerChanged() {
    // Auto-scroll expert log to bottom on every new raw entry.
    if (_expertMode && _rawLogScrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_rawLogScrollCtrl.hasClients) {
          _rawLogScrollCtrl.animateTo(
            _rawLogScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      });
    }
    setState(() {});
  }

  // ── Credential callback (injected into controller) ────────────────────────

  Future<CommissionCredentials?> _credentialCallback() async {
    final confirmed = await _collectWifiCredentials();
    if (confirmed) {
      return CommissionCredentials.wifi(_ssidCtrl.text.trim(), _passCtrl.text);
    }
    final threadHex = _threadCtrl.text.trim();
    if (threadHex.isNotEmpty) {
      return CommissionCredentials.thread(threadHex);
    }
    return null;
  }

  // ── Payload handling ───────────────────────────────────────────────────────

  Future<void> _setPayload(String raw, {bool autoStart = false}) async {
    await _ctrl.setPayload(raw, autoStart: autoStart);
    if (!mounted) return;

    // Handle navigation when autoStart commissioning completes successfully.
    if (_ctrl.phase == CommissionPhase.done && _ctrl.result != null) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) context.pushReplacement('/device/${_ctrl.result!.id}');
      return;
    }

    // Pre-fill form fields from the parsed payload.
    final p = _ctrl.parsed;
    if (p != null) {
      setState(() {
        _method  = CommissioningController.suggestMethod(p);
        _netType = CommissioningController.suggestNetType(p, threadDataset: _threadCtrl.text);

        if (!p.hasShortDiscriminator && p.discriminator > 0) {
          _discCtrl.text = p.discriminator.toString();
        } else {
          _discCtrl.clear();
        }
        if (p.setupPinCode > 0) _pinCtrl.text = p.setupPinCode.toString();
      });
    }
  }

  // ── QR scan ───────────────────────────────────────────────────────────────

  Future<void> _scanQr() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Camera permission required to scan QR codes'),
      ));
      return;
    }
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (raw != null && mounted) await _setPayload(raw);
  }

  // ── BLE permission ────────────────────────────────────────────────────────

  Future<bool> _requestBlePermissions() async {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final denied    = results.values.any((s) => s.isDenied || s.isPermanentlyDenied);
    final permanent = results.values.any((s) => s.isPermanentlyDenied);

    if (denied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(permanent
            ? 'Bluetooth permissions permanently denied — open Settings.'
            : 'Bluetooth permissions are required for BLE commissioning.'),
        action: permanent
            ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
            : null,
      ));
      return false;
    }
    return true;
  }

  // ── Reset and re-scan ─────────────────────────────────────────────────────

  Future<void> _resetAndScan() async {
    _ctrl.reset();
    await _scanQr();
  }

  // ── WiFi credential collection ────────────────────────────────────────────

  Future<bool> _collectWifiCredentials() async {
    if (!mounted) return false;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.grey.shade900.withAlpha(240),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _WifiCredentialPanel(
        ssidCtrl: _ssidCtrl,
        passCtrl: _passCtrl,
        onConfirm: () => Navigator.pop(sheetCtx, true),
      ),
    );
    return confirmed == true;
  }

  // ── Commission ─────────────────────────────────────────────────────────────

  Future<void> _commission() async {
    // When retrying, the form widget may not be in the tree — skip validation.
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) return;
    if (_ctrl.rawPayload == null) return;

    await _ctrl.start(CommissionConfig(
      method:           _method,
      netType:          _netType,
      threadDatasetHex: _threadCtrl.text.trim(),
      wifiSsid:         _ssidCtrl.text.trim(),
      wifiPassword:     _passCtrl.text,
      ipAddress:        _ipCtrl.text.trim(),
      discriminator:    int.tryParse(_discCtrl.text) ?? 3840,
      setupPinCode:     int.tryParse(_pinCtrl.text) ?? 20202021,
    ));

    if (!mounted) return;
    if (_ctrl.phase == CommissionPhase.done && _ctrl.result != null) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) context.pushReplacement('/device/${_ctrl.result!.id}');
    }
  }

  // ── Mode toggle button ────────────────────────────────────────────────────

  Widget _modeToggleButton() => IconButton(
    icon: Icon(
      _expertMode ? Icons.close : Icons.bug_report_outlined,
      size: 18,
      color: _ctrl.phase == CommissionPhase.failed && !_expertMode
          ? const Color(0xFFE53935)
          : _expertMode
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurface.withAlpha(80),
    ),
    tooltip: _expertMode ? 'Hide debug log' : 'Show debug log',
    onPressed: () => setState(() => _expertMode = !_expertMode),
  );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inProgress = _ctrl.phase == CommissionPhase.running
        || _ctrl.phase == CommissionPhase.done
        || _ctrl.phase == CommissionPhase.failed;

    if (inProgress) return _buildProgressScreen(context);
    return _expertMode
        ? _buildExpertFormScreen(context)
        : _buildSimpleFormScreen(context);
  }

  // ── Simple form screen ────────────────────────────────────────────────────

  Widget _buildSimpleFormScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Matter Device')),
      body: Center(
        child: _ctrl.parsing
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: FilledButton.icon(
                  onPressed: _scanQr,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Open camera'),
                ),
              ),
      ),
    );
  }

  // ── Progress screen ────────────────────────────────────────────────────────

  Widget _buildProgressScreen(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bool done   = _ctrl.phase == CommissionPhase.done;
    final bool failed = _ctrl.phase == CommissionPhase.failed;
    final bool busy   = _ctrl.phase == CommissionPhase.running;

    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final cancel = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cancel commissioning?'),
            content: const Text(
                'The device will not be added and any partial state will be reverted.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep going')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Cancel')),
            ],
          ),
        );
        if ((cancel ?? false) && mounted) _ctrl.reset();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: const Text('Adding Device'),
          automaticallyImplyLeading: false,
          leading: failed
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _ctrl.reset,
                )
              : null,
          actions: [_modeToggleButton()],
        ),
        body: _expertMode
            ? _buildRawLogScreen(context, cs, busy)
            : Column(children: [
                Expanded(
                  child: _buildProgressTrack(
                    context, cs, busy,
                    _ctrl.humanLog.isEmpty ? -1 : _ctrl.humanLog.length - 1,
                  ),
                ),
                if (done) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(children: [
                      Icon(Icons.check_circle_rounded,
                          size: 48, color: const Color(0xFF34A853)),
                      const SizedBox(height: 10),
                      Text('Device added',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF34A853),
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ] else if (failed) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: GestureDetector(
                      onTap: _resetAndScan,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color:        Colors.white.withAlpha(230),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: const Center(
                          child: Text('Scan again',
                              style: TextStyle(
                                  color:      Colors.black87,
                                  fontSize:   15,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
      ),
    );
  }

  // ── Progress track ────────────────────────────────────────────────────────

  static const double _kActiveWordH = 44.0;
  static const double _kOtherWordH  = 32.0;

  static double _slotH(String text, {required bool active}) {
    final words = text.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final n = words.isEmpty ? 1 : words.length;
    return n * (active ? _kActiveWordH : _kOtherWordH);
  }

  Widget _buildProgressTrack(
    BuildContext context,
    ColorScheme cs,
    bool busy,
    int lastHumanIdx,
  ) {
    final humanLog = _ctrl.humanLog;
    final slots    = <int, ({String text, Color? color})>{};

    for (int i = 0; i < humanLog.length; i++) {
      final d = lastHumanIdx - i;
      slots[d] = (text: humanLog[i].text, color: humanLog[i].color);
    }

    if (busy) {
      final nextIdx  = _ctrl.stageIdx + 1;
      int futureDist = 1;
      for (int s = nextIdx; s < kCommissionStages.length; s++) {
        final human = kCommissionStageHuman[kCommissionStages[s]]
            ?? kCommissionStages[s].toUpperCase();
        slots.putIfAbsent(-futureDist, () => (text: human, color: null));
        futureDist++;
      }
      slots.putIfAbsent(0, () => (text: '', color: null));
    }

    if (slots.isEmpty) return const Center(child: SizedBox.shrink());

    final dists = slots.keys.toList()..sort((a, b) => b.compareTo(a));
    final items = [for (final d in dists) (text: slots[d]!.text, color: slots[d]!.color, dist: d)];

    final activeIdx = items.indexWhere((it) => it.dist == 0);
    if (activeIdx < 0) return const Center(child: SizedBox.shrink());

    double yBeforeActive = 0;
    for (int i = 0; i < activeIdx; i++) {
      yBeforeActive += _slotH(items[i].text, active: false);
    }
    final activeH   = _slotH(items[activeIdx].text, active: true);
    final activeMid = yBeforeActive + activeH / 2;

    final column = OverflowBox(
      alignment: Alignment.topLeft,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            _GlyphLogLine(
              text:           item.text,
              distFromActive: item.dist,
              overrideColor:  item.color,
            ),
        ],
      ),
    );

    return LayoutBuilder(builder: (_, constraints) {
      final screenH  = constraints.maxHeight;
      final offsetY  = screenH / 2 - activeMid;
      final fadeSize = screenH * 0.28;

      return ClipRect(
        child: Stack(children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: offsetY),
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeOutCubic,
            child: column,
            builder: (_, animY, child) => Transform.translate(
              offset: Offset(0, animY),
              child: child,
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, height: fadeSize,
            child: IgnorePointer(child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [cs.surface, cs.surface.withAlpha(0)],
              )),
            )),
          ),
          Positioned(bottom: 0, left: 0, right: 0, height: fadeSize,
            child: IgnorePointer(child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [cs.surface, cs.surface.withAlpha(0)],
              )),
            )),
          ),
        ]),
      );
    });
  }

  // ── Expert raw log ─────────────────────────────────────────────────────────

  Widget _buildRawLogScreen(BuildContext context, ColorScheme cs, bool busy) {
    return ListView.builder(
      controller:  _rawLogScrollCtrl,
      padding:     const EdgeInsets.fromLTRB(16, 20, 16, 20),
      itemCount:   _ctrl.rawLog.length,
      itemBuilder: (_, i) {
        final entry    = _ctrl.rawLog[i];
        final isSuccess = entry.level == LogLevel.success;
        final isError   = entry.level == LogLevel.error;

        final Color msgColor = switch (entry.level) {
          LogLevel.success => cs.onSurfaceVariant,
          LogLevel.error   => cs.onSurfaceVariant,
          LogLevel.step    => cs.onSurface,
          LogLevel.info    => cs.onSurfaceVariant,
        };

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize:   11,
                height:     1.5,
                color:      msgColor,
              ),
              children: [
                TextSpan(text: entry.message),
                if (isSuccess)
                  const TextSpan(
                    text:  ' — success',
                    style: TextStyle(color: Color(0xFF34A853)),
                  ),
                if (isError)
                  TextSpan(
                    text:  ' — failed',
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Expert form screen ────────────────────────────────────────────────────

  Widget _buildExpertFormScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Matter Device'),
        actions: [_modeToggleButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Step 1: Scan / Enter code ─────────────────────────────
              _PayloadEntry(
                onScan:        _scanQr,
                onCodeEntered: _setPayload,
                parsed:        _ctrl.parsed,
                rawPayload:    _ctrl.rawPayload,
                parsing:       _ctrl.parsing,
                parseError:    _ctrl.parseError,
                onViewDetails: _ctrl.rawPayload != null && _ctrl.parsed != null
                    ? () => context.push('/qr-detail',
                          extra: QrPayloadDetailArgs(
                            rawPayload: _ctrl.rawPayload!,
                            parsed:     _ctrl.parsed!,
                          ))
                    : null,
              ),

              // ── Method toggle ─────────────────────────────────────────
              if (_ctrl.parsed != null &&
                  _ctrl.parsed!.canUseBle && _ctrl.parsed!.canUseIp) ...[
                const SizedBox(height: 16),
                SegmentedButton<CommissionMethod>(
                  segments: const [
                    ButtonSegment(
                      value: CommissionMethod.ble,
                      icon:  Icon(Icons.bluetooth, size: 16),
                      label: Text('BLE'),
                    ),
                    ButtonSegment(
                      value: CommissionMethod.ip,
                      icon:  Icon(Icons.lan_outlined, size: 16),
                      label: Text('IP'),
                    ),
                  ],
                  selected: {_method},
                  onSelectionChanged: (s) => setState(() => _method = s.first),
                ),
              ],

              // ── Step 2: Network credentials (BLE only) ────────────────
              if (_ctrl.parsed != null && _method == CommissionMethod.ble) ...[
                const SizedBox(height: 20),
                const SectionLabel('Network', style: SectionLabelStyle.prominent),
                const SizedBox(height: 10),
                _NetworkSection(
                  netType:               _netType,
                  threadCtrl:            _threadCtrl,
                  ssidCtrl:              _ssidCtrl,
                  passCtrl:              _passCtrl,
                  showThreadDataset:     _showThreadDataset,
                  showPassword:          _showPassword,
                  onNetTypeChanged:      (v) => setState(() => _netType = v),
                  onShowDatasetChanged:  (v) => setState(() => _showThreadDataset = v),
                  onShowPasswordChanged: (v) => setState(() => _showPassword = v),
                ),
              ],

              // ── IP fields ─────────────────────────────────────────────
              if (_ctrl.parsed != null && _method == CommissionMethod.ip) ...[
                const SizedBox(height: 20),
                const SectionLabel('IP commissioning', style: SectionLabelStyle.prominent),
                const SizedBox(height: 10),
                TextField(
                  controller: _ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IP address',
                    prefixIcon: Icon(Icons.lan_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _discCtrl,
                    decoration: InputDecoration(
                      labelText: 'Discriminator',
                      hintText: _ctrl.parsed?.hasShortDiscriminator == true
                          ? 'Unknown — manual codes only carry 4 bits'
                          : '${_ctrl.parsed?.discriminator ?? 3840}',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                    controller: _pinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Setup PIN',
                      hintText: '20202021',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  )),
                ]),
              ],

              // ── Commission button ──────────────────────────────────────
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _ctrl.rawPayload != null && _ctrl.parsed != null && !_ctrl.parsing
                    ? _commission
                    : null,
                icon: const Icon(Icons.add_link),
                label: Text(_method == CommissionMethod.ble
                    ? 'Commission via BLE'
                    : 'Commission via IP'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payload entry widget  (QR scan tab  +  manual pairing-code tab)
// ─────────────────────────────────────────────────────────────────────────────

enum _EntryMode { qr, manual }

class _PayloadEntry extends StatefulWidget {
  final VoidCallback                        onScan;
  final Future<void> Function(String)       onCodeEntered;
  final ParsedPayload?                      parsed;
  final String?                             rawPayload;
  final bool                                parsing;
  final String?                             parseError;
  final VoidCallback?                       onViewDetails;

  const _PayloadEntry({
    required this.onScan,
    required this.onCodeEntered,
    required this.parsed,
    required this.rawPayload,
    required this.parsing,
    required this.parseError,
    this.onViewDetails,
  });

  @override
  State<_PayloadEntry> createState() => _PayloadEntryState();
}

class _PayloadEntryState extends State<_PayloadEntry> {
  _EntryMode _mode = _EntryMode.qr;

  final _qrCtrl     = TextEditingController();
  final _manualCtrl = TextEditingController();

  @override
  void dispose() {
    _qrCtrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  void _submitManual() {
    final d = _digits(_manualCtrl.text);
    if (d.length == 11) widget.onCodeEntered(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_EntryMode>(
          segments: const [
            ButtonSegment(
              value: _EntryMode.qr,
              icon:  Icon(Icons.qr_code_scanner, size: 16),
              label: Text('QR Code'),
            ),
            ButtonSegment(
              value: _EntryMode.manual,
              icon:  Icon(Icons.dialpad_outlined, size: 16),
              label: Text('Manual Code'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 16),
        if (_mode == _EntryMode.qr)     _buildQrTab(context, cs),
        if (_mode == _EntryMode.manual) _buildManualTab(context, cs),
      ],
    );
  }

  Widget _buildQrTab(BuildContext context, ColorScheme cs) {
    final scanned   = widget.parsed != null;
    final scanColor = scanned ? const Color(0xFF34A853) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: widget.onScan,
          icon: widget.parsing
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  scanned ? Icons.check_circle_outline : Icons.qr_code_scanner,
                  color: scanColor),
          label: Text(scanned ? 'QR scanned ✓' : 'Scan QR code',
              style: TextStyle(color: scanColor)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: scanned ? const Color(0xFF34A853) : Colors.white54),
          ),
        ),

        if (scanned && widget.rawPayload != null) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: QrImageView(
                  data: widget.rawPayload!,
                  version: QrVersions.auto,
                  size: 88,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black),
                ),
              ),
              const SizedBox(width: 14),
              if (widget.onViewDetails != null)
                OutlinedButton.icon(
                  onPressed: widget.onViewDetails,
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('View details'),
                  style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
            ],
          ),
        ],

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('or paste payload', style: TextStyle(fontSize: 12)),
            ),
            Expanded(child: Divider()),
          ]),
        ),

        TextField(
          controller: _qrCtrl,
          decoration: InputDecoration(
            labelText:  'Setup payload string',
            hintText:   'MT:Y.K9042C00KA0648G00',
            prefixIcon: const Icon(Icons.content_paste_outlined),
            border:     const OutlineInputBorder(),
            errorText:  widget.parseError,
            suffixIcon: _qrCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _qrCtrl.clear();
                      setState(() {});
                    })
                : null,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onCodeEntered(v.trim());
          },
          onChanged: (v) => setState(() {}),
        ),
        if (_qrCtrl.text.trim().isNotEmpty &&
            widget.parsed == null &&
            !widget.parsing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonal(
              onPressed: () => widget.onCodeEntered(_qrCtrl.text.trim()),
              child: const Text('Parse payload'),
            ),
          ),
      ],
    );
  }

  Widget _buildManualTab(BuildContext context, ColorScheme cs) {
    final digits   = _digits(_manualCtrl.text);
    final ready    = digits.length == 11;
    final hasError = widget.parseError != null && !widget.parsing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the 11-digit code printed on the device or its packaging.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _manualCtrl,
          decoration: InputDecoration(
            labelText:   'Pairing code',
            hintText:    '12345-678901',
            prefixIcon:  const Icon(Icons.dialpad_outlined),
            border:      const OutlineInputBorder(),
            errorText:   hasError ? widget.parseError : null,
            counterText: '${digits.length}/11',
            suffixIcon: _manualCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _manualCtrl.clear();
                      setState(() {});
                    })
                : null,
          ),
          keyboardType:     TextInputType.number,
          inputFormatters:  [_ManualCodeFormatter()],
          style: const TextStyle(
            fontFamily:    'monospace',
            fontSize:      22,
            fontWeight:    FontWeight.w600,
            letterSpacing: 4,
          ),
          textAlign: TextAlign.center,
          onChanged: (v) {
            setState(() {});
            if (_digits(v).length == 11) _submitManual();
          },
          onSubmitted: (_) => _submitManual(),
        ),
        const SizedBox(height: 12),
        if (widget.parsing)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (widget.parsed != null) ...[
          Row(children: [
            Icon(Icons.check_circle_outline,
                size: 18, color: const Color(0xFF34A853)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Code recognised — ${widget.parsed!.suggestedName}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF34A853)),
              ),
            ),
          ]),
        ] else if (ready && !widget.parsing) ...[
          FilledButton.tonal(
            onPressed: _submitManual,
            child: const Text('Verify code'),
          ),
        ],
      ],
    );
  }
}

// ── TextInputFormatter for XXXXX-XXXXXX manual codes ─────────────────────────

class _ManualCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, newValue.text.replaceAll(RegExp(r'[^0-9]'), '').length
            .clamp(0, 11));
    if (digits.isEmpty) return TextEditingValue.empty;
    final formatted = digits.length > 5
        ? '${digits.substring(0, 5)}-${digits.substring(5)}'
        : digits;
    return TextEditingValue(
      text:      formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Network credentials section
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkSection extends StatefulWidget {
  final int netType;
  final TextEditingController threadCtrl;
  final TextEditingController ssidCtrl;
  final TextEditingController passCtrl;
  final bool showThreadDataset;
  final bool showPassword;
  final ValueChanged<int>  onNetTypeChanged;
  final ValueChanged<bool> onShowDatasetChanged;
  final ValueChanged<bool> onShowPasswordChanged;

  const _NetworkSection({
    required this.netType,
    required this.threadCtrl,
    required this.ssidCtrl,
    required this.passCtrl,
    required this.showThreadDataset,
    required this.showPassword,
    required this.onNetTypeChanged,
    required this.onShowDatasetChanged,
    required this.onShowPasswordChanged,
  });

  @override
  State<_NetworkSection> createState() => _NetworkSectionState();
}

class _NetworkSectionState extends State<_NetworkSection> {
  List<WifiNetwork> _networks       = [];
  bool              _loadingNetworks = false;
  WifiNetwork?      _selected;

  @override
  void initState() {
    super.initState();
    if (widget.netType == 1) _loadNetworks();
  }

  @override
  void didUpdateWidget(_NetworkSection old) {
    super.didUpdateWidget(old);
    if (widget.netType == 1 && old.netType != 1 && _networks.isEmpty) {
      _loadNetworks();
    }
  }

  Future<void> _loadNetworks() async {
    if (_loadingNetworks) return;
    setState(() => _loadingNetworks = true);

    final result = await context.read<WifiScanService>().scan();
    if (!mounted) return;

    if (result.permissionDenied) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.permanentlyDenied
            ? 'Location permission permanently denied — open Settings to enable Wi-Fi scanning.'
            : 'Location permission is required to scan for Wi-Fi networks.'),
        action: result.permanentlyDenied
            ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
            : null,
      ));
      setState(() => _loadingNetworks = false);
      return;
    }

    setState(() {
      _networks        = result.networks;
      _loadingNetworks = false;
      if (_selected == null && widget.ssidCtrl.text.isEmpty && result.autoSelected != null) {
        _pickNetwork(result.autoSelected!);
      }
    });
  }

  void _pickNetwork(WifiNetwork net) {
    setState(() => _selected = net);
    widget.ssidCtrl.text = net.ssid;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Type selector ──────────────────────────────────────────
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, icon: Icon(Icons.memory_outlined, size: 16), label: Text('Thread')),
                ButtonSegment(value: 1, icon: Icon(Icons.wifi_outlined, size: 16),   label: Text('Wi-Fi')),
                ButtonSegment(value: 2, icon: Icon(Icons.lan_outlined, size: 16),    label: Text('None')),
              ],
              selected: {widget.netType},
              onSelectionChanged: (s) => widget.onNetTypeChanged(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 14),

            // ── Thread ─────────────────────────────────────────────────
            if (widget.netType == 0) ...[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.onShowDatasetChanged(!widget.showThreadDataset),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.memory_outlined, size: 16, color: cs.secondary),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEST-PAN-26BA  •  Ch 15  •  PAN 0x26BA',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600,
                                           color: cs.secondary)),
                        Text('Ext PAN: 12f209ab410ad778',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontFamily: 'monospace',
                                           color: cs.onSurfaceVariant)),
                      ],
                    )),
                    Icon(widget.showThreadDataset
                        ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: cs.onSurfaceVariant),
                  ]),
                ),
              ),
              if (widget.showThreadDataset) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: widget.threadCtrl,
                  decoration: InputDecoration(
                    labelText: 'Active Operational Dataset (hex TLV)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.restart_alt_outlined),
                      tooltip: 'Restore default',
                      onPressed: () async =>
                          widget.threadCtrl.text = await ThreadSettingsService.load(),
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  maxLines: 3, minLines: 2,
                ),
              ],
            ],

            // ── Wi-Fi ──────────────────────────────────────────────────
            if (widget.netType == 1) ...[
              DropdownButtonFormField<String>(
                value: _selected?.ssid,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi network',
                  prefixIcon: _loadingNetworks
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.wifi_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh_outlined, size: 20),
                    tooltip: 'Rescan',
                    onPressed: _loadingNetworks ? null : _loadNetworks,
                  ),
                ),
                hint: Text(_loadingNetworks ? 'Scanning…' : 'Select a network'),
                items: _networks.map((net) => DropdownMenuItem(
                  value: net.ssid,
                  child: Row(children: [
                    _WifiSignalIcon(bars: net.bars, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(child: Text(net.ssid,
                        overflow: TextOverflow.ellipsis)),
                    if (net.isConnected) ...[
                      const SizedBox(width: 6),
                      Text('connected',
                          style: TextStyle(fontSize: 11, color: cs.primary)),
                    ],
                  ]),
                )).toList(),
                onChanged: (ssid) {
                  if (ssid == null) return;
                  final net = _networks.firstWhere((n) => n.ssid == ssid);
                  _pickNetwork(net);
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Select a network' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: widget.passCtrl,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(widget.showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => widget.onShowPasswordChanged(!widget.showPassword),
                  ),
                ),
                obscureText: !widget.showPassword,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Password is required' : null,
              ),
            ],

            // ── None ───────────────────────────────────────────────────
            if (widget.netType == 2)
              Text('No network credentials — for Ethernet-only devices.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Wi-Fi signal icon ─────────────────────────────────────────────────────────

class _WifiSignalIcon extends StatelessWidget {
  final int   bars;
  final Color color;
  const _WifiSignalIcon({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = switch (bars) {
      4 || 3 => Icons.wifi,
      2      => Icons.wifi_2_bar,
      1      => Icons.wifi_1_bar,
      _      => Icons.wifi_off_outlined,
    };
    final opacity = bars >= 3 ? 1.0 : bars == 2 ? 0.75 : 0.5;
    return Icon(icon, size: 18, color: color.withOpacity(opacity));
  }
}

// ── Glyph log line ────────────────────────────────────────────────────────────

class _GlyphLogLine extends StatelessWidget {
  final String    text;
  final LogLevel? level;
  final Color?    overrideColor;
  final int       distFromActive;

  const _GlyphLogLine({
    required this.text,
    required this.distFromActive,
    this.level,
    this.overrideColor,
    super.key,
  });

  static const double _activeWordH = 44.0;
  static const double _otherWordH  = 32.0;
  static const double _activeTextH = 32.0;
  static const double _otherTextH  = 22.0;

  bool   get _isActive => distFromActive == 0;
  double get _wordH    => _isActive ? _activeWordH : _otherWordH;
  double get _textH    => _isActive ? _activeTextH : _otherTextH;

  List<String> get _words {
    final ws = text.trim().split(' ').where((w) => w.isNotEmpty).toList();
    return ws.isEmpty ? [''] : ws;
  }

  double get _opacity {
    final d = distFromActive.abs();
    return switch (d) {
      0 => 1.00,
      1 => 0.45,
      2 => 0.18,
      3 => 0.07,
      _ => 0.03,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color baseColor = overrideColor ?? (level == null
        ? cs.onSurface
        : switch (level!) {
            LogLevel.success => const Color(0xFF34A853),
            LogLevel.error   => cs.error,
            LogLevel.step    => cs.onSurface,
            LogLevel.info    => cs.onSurfaceVariant,
          });

    final Color litColor = baseColor.withOpacity(_opacity);
    final Color dimColor = litColor.withAlpha(12);
    final words = _words;

    return SizedBox(
      height: words.length * _wordH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final word in words)
              SizedBox(
                height: _wordH,
                child: Center(
                  child: SizedBox(
                    height: _textH,
                    width: double.infinity,
                    child: word.isEmpty
                        ? null
                        : CustomPaint(
                            painter: DotMatrixPainter(
                              text:     word,
                              litColor: litColor,
                              dimColor: dimColor,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── WiFi credential panel ─────────────────────────────────────────────────────

class _WifiCredentialPanel extends StatefulWidget {
  final TextEditingController ssidCtrl;
  final TextEditingController passCtrl;
  final VoidCallback          onConfirm;

  const _WifiCredentialPanel({
    required this.ssidCtrl,
    required this.passCtrl,
    required this.onConfirm,
  });

  @override
  State<_WifiCredentialPanel> createState() => _WifiCredentialPanelState();
}

class _WifiCredentialPanelState extends State<_WifiCredentialPanel> {
  bool              _showPassword    = false;
  bool              _loadingNetworks = true;
  List<WifiNetwork> _networks        = [];

  @override
  void initState() {
    super.initState();
    _scanNetworks();
  }

  Future<void> _scanNetworks() async {
    final result = await context.read<WifiScanService>().scan();
    if (!mounted) return;
    setState(() {
      _networks        = result.networks;
      _loadingNetworks = false;
      if (widget.ssidCtrl.text.isEmpty && result.autoSelected != null) {
        widget.ssidCtrl.text = result.autoSelected!.ssid;
      }
    });
  }

  static InputDecoration _fieldDeco(String hint, {Widget? suffix}) => InputDecoration(
    hintText:  hint,
    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
    filled:    true,
    fillColor: Colors.white10,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide:   const BorderSide(color: Colors.white24, width: 1.5)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide:   const BorderSide(color: Colors.white24, width: 1.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide:   const BorderSide(color: Colors.white60, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    suffixIcon: suffix,
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      decoration: BoxDecoration(
        color:        Colors.grey.shade900.withAlpha(240),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow:    [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 20)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),

        // ── SSID ──────────────────────────────────────────────────────────
        if (_loadingNetworks)
          Container(
            height: 52,
            decoration: BoxDecoration(
              color:        Colors.white10,
              borderRadius: BorderRadius.circular(22),
              border:       Border.all(color: Colors.white24, width: 1.5),
            ),
            child: const Center(
              child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.white38)),
            ),
          )
        else if (_networks.isEmpty)
          TextField(
            controller:      widget.ssidCtrl,
            autofocus:       true,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration:      _fieldDeco('Network name (SSID)'),
            textInputAction: TextInputAction.next,
          )
        else
          DropdownButtonFormField<String>(
            value: _networks.any((n) => n.ssid == widget.ssidCtrl.text)
                ? widget.ssidCtrl.text
                : null,
            hint: const Text('Select network',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
            dropdownColor: Colors.grey.shade900,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            icon: const Icon(Icons.expand_more, color: Colors.white38),
            decoration: _fieldDeco(''),
            isExpanded: true,
            items: _networks.map((n) => DropdownMenuItem(
              value: n.ssid,
              child: Row(children: [
                Icon(
                  n.rssi > -60 ? Icons.wifi : n.rssi > -75 ? Icons.wifi_2_bar : Icons.wifi_1_bar,
                  size: 16, color: n.isConnected ? Colors.white70 : Colors.white38,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(n.ssid,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: n.isConnected ? Colors.white : Colors.white70))),
                if (n.isConnected)
                  const Text(' ✓',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            )).toList(),
            onChanged: (v) {
              if (v != null) {
                widget.ssidCtrl.text = v;
                setState(() {});
              }
            },
          ),

        const SizedBox(height: 10),

        // ── Password ───────────────────────────────────────────────────────
        TextField(
          controller:    widget.passCtrl,
          obscureText:   !_showPassword,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _fieldDeco('Password', suffix: IconButton(
            icon: Icon(
              _showPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white38, size: 20),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          )),
          textInputAction: TextInputAction.done,
          onSubmitted:     (_) => widget.onConfirm(),
        ),

        const SizedBox(height: 16),

        // ── Connect ────────────────────────────────────────────────────────
        GestureDetector(
          onTap: widget.onConfirm,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color:        Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Center(
              child: Text('Connect',
                  style: TextStyle(
                      color:      Colors.black87,
                      fontSize:   15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
}
