import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/device_provider.dart';
import 'router.dart';
import 'services/device_store.dart';
import 'services/matter_channel.dart';
import 'services/matter_port.dart';
import 'services/wifi_scan_service.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final store   = await DeviceStore.open();
  final channel = MatterChannel();

  runApp(
    MultiProvider(
      providers: [
        // Sub-interface registrations — each screen depends only on what it uses.
        Provider<MatterSubscriptionPort>.value(value: channel),
        Provider<MatterCommissionPort>.value(value: channel),
        Provider<MatterClusterPort>.value(value: channel),
        Provider<MatterFabricPort>.value(value: channel),
        Provider<WifiScanService>(
          create: (ctx) => WifiScanService(ctx.read<MatterCommissionPort>()),
        ),
        ChangeNotifierProvider(create: (_) => DeviceProvider(store, channel)),
      ],
      child: const MatterHomeApp(),
    ),
  );
}

class MatterHomeApp extends StatelessWidget {
  const MatterHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flux Home',
      debugShowCheckedModeBanner: false,
      theme:      buildAppTheme(brightness: Brightness.light),
      darkTheme:  buildAppTheme(brightness: Brightness.dark),
      themeMode:  ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
