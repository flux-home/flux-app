import 'dart:async';
import 'dart:typed_data';

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

  // ── Bootstrap PSK (one-time) ──────────────────────────────────────────────
  // Ensures the known hub PSK is always stored so DTLS works across reinstalls.
  // Remove once the QR-scan setup flow is the primary path.
  const _hubPskHex  = 'a089ebcce62353bf5f84e4fb4855f7f0';
  const _hubDtlsId  = 'flux-controller-e25311'; // stable controller ID from QR
  final existingPsk = await ControllerSettings.loadPsk(_hubDtlsId);
  if (existingPsk == null) {
    final pskBytes = Uint8List.fromList(List.generate(
        16, (i) => int.parse(
            _hubPskHex.substring(i * 2, i * 2 + 2), radix: 16)));
    await ControllerSettings.savePsk(_hubDtlsId, pskBytes,
        dtlsIdentity: _hubDtlsId);
    debugPrint('main: bootstrapped PSK for controller $_hubDtlsId');
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

    // Check whether the controller needs fabric provisioning.
    // fabric_id == 0 means the controller has no operational identity yet.
    // The app must call POST /fabric/provision before the controller can open
    // CASE sessions or register nodes.
    final info = await svc.getInfo();
    if (info != null && info.fabricId.toInt() == 0) {
      final hostname = ep.dtlsIdentity ?? ep.host;
      final alreadyProvisioned = await ControllerSettings.isProvisioned(hostname);
      if (!alreadyProvisioned) {
        debugPrint('main: controller not provisioned — running fabric provision flow');
        final creds = await localChannel.exportFabricForController();
        if (creds != null) {
          final result = await svc.provisionFabric(
            fabricId:  creds.fabricId,
            nodeId:    0x0002,
            rootCaTlv: creds.rootCaTlv,
            nocTlv:    creds.nocTlv,
            opPrivKey: creds.opPrivKey,
            ipk:       creds.ipk,
            vendorId:  0xFFF1,
          );
          if (result != null && result.success) {
            await ControllerSettings.saveProvisionedFlag(hostname);
            debugPrint('main: controller provisioned — '
                'fabricIndex=${result.fabricIndex} '
                'compressedFabricId=0x${result.compressedFabricId.toHexString()}');
          } else {
            debugPrint('main: provisioning failed — ${result?.error ?? 'no response'}');
          }
        } else {
          debugPrint('main: exportFabricForController returned null — CHIP SDK unavailable?');
        }
      }
    }

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
