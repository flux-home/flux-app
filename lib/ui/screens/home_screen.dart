import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/room.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/services/add_controller_flow.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/screens/qr_scanner_screen.dart';
import 'package:matter_home/ui/screens/home/today_plan_card.dart';
import 'package:matter_home/ui/widgets/category_bar.dart';
import 'package:matter_home/ui/widgets/controller_status_chip.dart';
import 'package:matter_home/ui/widgets/dot_matrix_empty_hint.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Commissioning requires a hub (see CommissioningController), so the FAB
    // surfaces whichever action is actually possible: pair a hub first, then
    // add devices once one is connected.
    final hub    = context.watch<HubConnection>();
    final status = hub.status;
    final online = status == ControllerStatus.online;
    final noHub  = status == ControllerStatus.noHub;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flux Home', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          const ControllerStatusChip(),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // Pair a hub when none is set up; add a device only when the hub is
        // reachable; otherwise the action would silently fail, so surface why.
        onPressed: noHub
            ? () => _addHub(context)
            : online
                ? () => _addDevice(context)
                : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Can't reach your controller — check it's powered "
                        'and on your network.'))),
        elevation: 2,
        shape: const CircleBorder(),
        backgroundColor: (!noHub && !online) ? Theme.of(context).disabledColor : null,
        tooltip: noHub ? 'Add controller' : 'Add device',
        child: Icon(noHub ? Icons.router_outlined : Icons.add, size: 28),
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          if (provider.state == DeviceProviderState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Every device now lives in a category — Other takes whatever the
          // first three do not claim. The home screen is no longer a list of
          // leftovers: this app is about energy, so the first thing it shows is
          // what the house is doing with it.
          final anyDevices = provider.deviceViews.isNotEmpty;

          return RefreshIndicator(
            // Pull down to re-fetch the controller's device list. When a hub is
            // configured but currently offline, also retry the connection.
            onRefresh: () async {
              final hub = context.read<HubConnection>();
              if (!hub.isOnline && hub.hasConfiguredHub) {
                await hub.connect();
              }
              await provider.syncWithController();
            },
            child: !anyDevices
                ? CustomScrollView(
                    // AlwaysScrollable so the pull gesture works even when the
                    // (otherwise non-scrolling) empty hint is shown.
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: DotMatrixEmptyHint(
                          headline: !online
                              ? (noHub ? 'NO CONTROLLER' : 'CONTROLLER OFFLINE')
                              : 'NO DEVICES',
                          subline: !online
                              ? (noHub ? 'TAP + TO PAIR' : 'PULL TO RECONNECT')
                              : 'TAP + TO ADD',
                        ),
                      ),
                    ],
                  )
                : _buildHome(context),
          );
        },
      ),
    );
  }

  Future<void> _addDevice(BuildContext context) async {
    // Let flutter_zxing trigger the native camera permission dialog
    // on first use — no explicit pre-check needed on iOS.
    final payload = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    if (payload != null && context.mounted) {
      unawaited(context.push('/commission', extra: payload));
    }
  }

  Future<void> _addHub(BuildContext context) => runAddControllerFlow(context);

  /// Categories, then what the house is doing with its energy.
  ///
  /// The device grid that used to be here has moved into Other. A home screen
  /// that opens with "here are the things I could not classify" says nothing
  /// about the house; the energy card says what is happening in it.
  Widget _buildHome(BuildContext context) => const CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: CategoryBar()),
          SliverToBoxAdapter(child: TodayPlanCard()),
          SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      );
}
