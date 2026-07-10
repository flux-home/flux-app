import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/router.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:matter_home/services/flux_controller_discovery.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/matter_channel.dart';
import 'package:matter_home/services/matter_port.dart';
import 'package:matter_home/services/null_matter_port.dart';
import 'package:matter_home/services/thread_sync_service.dart';
import 'package:matter_home/services/wifi_scan_service.dart';
import 'package:matter_home/ui/theme.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final store        = await DeviceStore.open();
  final localChannel = MatterChannel();

  // ── Bootstrap PSK (debug only) ────────────────────────────────────────────
  // Dev convenience: seeds the known dev-hub PSK so DTLS works across reinstalls
  // without re-scanning the QR. Gated to debug builds so it never ships — the
  // QR-scan setup flow is the only PSK source in release builds.
  if (kDebugMode) {
    const hubPskHex = 'a089ebcce62353bf5f84e4fb4855f7f0';
    const hubDtlsId = 'flux-controller-e25311'; // stable controller ID from QR
    final existingPsk = await ControllerSettings.loadPsk(hubDtlsId);
    if (existingPsk == null) {
      final pskBytes = Uint8List.fromList(List.generate(
          16, (i) => int.parse(
              hubPskHex.substring(i * 2, i * 2 + 2), radix: 16)));
      await ControllerSettings.savePsk(hubDtlsId, pskBytes,
          dtlsIdentity: hubDtlsId);
      debugPrint('main: bootstrapped dev-hub PSK for $hubDtlsId');
    }
  }

  // ── Boot with no controller yet ──────────────────────────────────────────
  // Never block runApp() on network I/O — controller discovery (mDNS + DTLS
  // handshake) can take up to 20 s, which would hold the native splash screen.
  // Device control is controller-proxied only (docs/controller-only-control.md)
  // — there is no local-CHIP control fallback — so DeviceProvider starts on
  // the inert NullMatterPort and background discovery below swaps it onto the
  // real FluxCoapService once a controller is found.
  final hubConn      = HubConnection(null);
  final nullChannel  = NullMatterPort();
  final provider     = DeviceProvider(store, nullChannel);
  // React to any controller service swap (background discovery, Flux Hub "↺",
  // re-adding a controller) without an app restart.
  provider.attachHubConnection(hubConn);

  debugPrint('main: starting with no controller, discovering in background…');

  runApp(
    MultiProvider(
      providers: [
        // Raw MatterChannel always available for BLE commissioning steps.
        Provider<MatterChannel>.value(value: localChannel),
        // Sub-interface providers keep the localChannel reference — BLE
        // commissioning runs on local CHIP regardless of hub connection.
        Provider<MatterSubscriptionPort>.value(value: localChannel),
        Provider<MatterCommissionPort>.value(value: localChannel),
        // HubConnection must come before the ProxyProviders below that depend
        // on it — MultiProvider nests in order (first = outermost ancestor).
        ChangeNotifierProvider<HubConnection>.value(value: hubConn),
        // Device control/reads are controller-proxied only — when no hub is
        // connected, these resolve to the inert NullMatterPort, never local
        // CHIP, so cluster screens simply show "no control" instead of
        // silently operating on the wrong fabric.
        ProxyProvider<HubConnection, MatterClusterPort>(
          update: (_, hub, __) => hub.service ?? nullChannel,
        ),
        ProxyProvider<HubConnection, MatterFabricPort>(
          update: (_, hub, __) => hub.service ?? nullChannel,
        ),
        Provider<WifiScanService>(
          create: (ctx) => WifiScanService(ctx.read<MatterCommissionPort>()),
        ),
        ChangeNotifierProvider<DeviceProvider>.value(value: provider),
      ],
      child: const MatterHomeApp(),
    ),
  );

  // ── Background controller discovery ──────────────────────────────────────
  // Runs concurrently with the first frame. On success, DeviceProvider and
  // HubConnection are both updated so the UI sees hub mode seamlessly.
  unawaited(FluxControllerDiscovery.discover().then((ep) async {
    if (ep == null) {
      debugPrint('main: no controller found — no device control until one connects');
      return;
    }
    debugPrint('main: controller found at $ep — switching to hub mode');
    final svc = FluxCoapService(ep);

    // Put both on one Thread network, controller as source of truth: adopt the
    // controller's network if it has one, otherwise seed it with the app's.
    final thread = await ThreadSyncService(svc)
        .ensureInSync(log: (m) => debugPrint('main: thread sync — $m'));
    debugPrint('main: thread sync result — ${thread.status.name}'
        '${thread.message != null ? ' (${thread.message})' : ''}');

    // setService notifies HubConnection listeners; DeviceProvider (attached
    // above) adopts hub mode in response — no separate adoptHubMode call needed.
    hubConn.setService(svc);
  }));
}

class MatterHomeApp extends StatefulWidget {
  const MatterHomeApp({super.key});

  @override
  State<MatterHomeApp> createState() => _MatterHomeAppState();
}

class _MatterHomeAppState extends State<MatterHomeApp>
    with WidgetsBindingObserver {
  /// How often to re-fetch the controller's device list while the app is in
  /// the foreground.  Keeps controller-side changes (devices added/removed on
  /// another phone, reachability flips) visible without a manual refresh.
  static const _pollInterval = Duration(seconds: 45);
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _sync());
  }

  void _sync() {
    if (!mounted) return;
    unawaited(context.read<DeviceProvider>().syncWithController());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Catch anything that changed while backgrounded, then resume polling.
        _sync();
        _startPolling();
        context.read<HubConnection>().startHealthMonitoring();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _pollTimer?.cancel();
        context.read<HubConnection>().pauseHealthMonitoring();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flux Home',
      debugShowCheckedModeBanner: false,
      theme:      buildAppTheme(),
      darkTheme:  buildAppTheme(brightness: Brightness.dark),
      themeMode:  ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
