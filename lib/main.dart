import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/router.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/device_store.dart';
import 'package:matter_home/services/fabric_sync_service.dart';
import 'package:matter_home/services/flux_controller_discovery.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/matter_channel.dart';
import 'package:matter_home/services/matter_port.dart';
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

  // ── Boot immediately in standalone mode ──────────────────────────────────
  // Never block runApp() on network I/O — controller discovery (mDNS + DTLS
  // handshake) can take up to 20 s, which would hold the native splash screen.
  // The app starts on the local MatterChannel; background discovery below
  // switches DeviceProvider to hub mode once a controller is found.
  final hubConn  = HubConnection(null);
  final provider = DeviceProvider(store, localChannel);
  // React to any controller service swap (background discovery, Flux Hub "↺",
  // re-adding a controller) without an app restart.
  provider.attachHubConnection(hubConn);

  // On an adopted (controller-owned) fabric the phone holds no CA key, so the
  // native commissioning flow forwards each device CSR here to be signed by the
  // controller via POST /fabric/sign-noc.
  //
  // DEPRECATED — slated for removal once the commission-then-handoff flow lands
  // (see flux-proto/docs/flows.md "commission-then-handoff"). The controller
  // will commission devices onto its own fabric directly, so this CSR-forwarding
  // path (and /fabric/sign-noc) goes away.
  localChannel.deviceNocSigner = (csr, nodeId) async {
    final svc = hubConn.service;
    if (svc == null) {
      debugPrint('deviceNocSigner: NOT connected to a hub — cannot sign device NOC');
      return null;
    }
    final res = await svc.signDeviceNoc(csr: csr, nodeId: nodeId);
    if (res == null) {
      debugPrint('deviceNocSigner: hub /fabric/sign-noc returned no response');
      return null;
    }
    if (!res.success) {
      debugPrint('deviceNocSigner: hub refused to sign — ${res.error}');
      return null;
    }
    return (
      noc:  Uint8List.fromList(res.nocDer),
      icac: res.icacDer.isEmpty ? null : Uint8List.fromList(res.icacDer),
    );
  };

  debugPrint('main: starting in standalone mode, discovering controller in background…');

  runApp(
    MultiProvider(
      providers: [
        // Raw MatterChannel always available for BLE commissioning steps.
        Provider<MatterChannel>.value(value: localChannel),
        // Sub-interface providers keep the localChannel reference.
        // Hub-mode device operations go through DeviceProvider._channel
        // (swapped by adoptHubMode). Commission flows route hub vs. local
        // via CommissioningController.controllerService.
        Provider<MatterSubscriptionPort>.value(value: localChannel),
        Provider<MatterCommissionPort>.value(value: localChannel),
        // HubConnection must come before the ProxyProviders below that depend
        // on it — MultiProvider nests in order (first = outermost ancestor).
        ChangeNotifierProvider<HubConnection>.value(value: hubConn),
        // In hub mode, cluster reads and fabric ops must go through the hub so
        // that controller-managed node IDs resolve correctly.  When no hub is
        // connected, fall back to the local channel.
        ProxyProvider<HubConnection, MatterClusterPort>(
          update: (_, hub, __) => hub.service ?? localChannel,
        ),
        ProxyProvider<HubConnection, MatterFabricPort>(
          update: (_, hub, __) => hub.service ?? localChannel,
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
      debugPrint('main: no controller found — staying in standalone mode');
      return;
    }
    debugPrint('main: controller found at $ep — switching to hub mode');
    final svc = FluxCoapService(ep);

    // Fabric: the controller owns it and the app *enrolls* to join.  Enrollment
    // has side effects (imports an identity + relaunches the process), so it is
    // NEVER auto-run on boot — that would loop if a join can't complete.  It is
    // user-initiated only (Settings → Flux Hub → Join hub).  Here we just log
    // the current state.  See docs/multi-phone-fabric.md.
    final state = await FabricSyncService(localFabric: localChannel, controller: svc)
        .readState();
    debugPrint('main: fabric state — ${state.name}');

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
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _pollTimer?.cancel();
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
