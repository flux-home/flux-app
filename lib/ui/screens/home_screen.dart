import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../providers/device_provider.dart';
import '../widgets/device_card.dart';
import 'qr_scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nothing else Matters',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final status = await Permission.camera.request();
          if (!status.isGranted || !context.mounted) return;
          final payload = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const QrScannerScreen()),
          );
          if (payload != null && context.mounted) {
            context.push('/commission', extra: payload);
          }
        },
        backgroundColor: const Color(0xFF6DC9A2),
        foregroundColor: const Color(0xFF1A4A38),
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          if (provider.state == DeviceProviderState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final views = provider.deviceViews;
          if (views.isEmpty) {
            return const SizedBox.shrink();
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing:    12,
                    crossAxisSpacing:   12,
                    childAspectRatio:   1.0,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => DeviceCard(
                      deviceId: views[i].id,
                      onTap:    () => context.push('/device/${views[i].id}'),
                    ),
                    childCount: views.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
            ],
          );
        },
      ),
    );
  }
}
