import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/ui/widgets/add_controller_sheet.dart';
import 'package:provider/provider.dart';

/// Shows the [AddControllerSheet] (QR scan or manual PSK entry), saves the
/// resulting PSK, and reconnects [HubConnection] — the shared "add a hub"
/// flow used by both the home screen FAB and the Flux Hub settings screen.
///
/// The controller ID always comes from the QR code's `id=` field — never
/// from whatever hub happens to already be connected, since that would
/// silently mis-associate a new PSK with the wrong controller. The manual
/// hex-only PSK entry has no ID of its own, so it only works when
/// [knownControllerId] is supplied: the Settings screen passes the hostname
/// of the (already-discovered-but-unpaired) controller it's currently
/// displaying as a "re-enter the PSK for the box I'm looking at" hint. The
/// home screen FAB (adding a hub for the first time) passes nothing, so
/// manual entry there requires the QR's `id=` and correctly fails otherwise.
///
/// Shows its own snackbar feedback on failure/success. Returns true once a
/// controller was found and connected.
Future<bool> runAddControllerFlow(BuildContext context, {String? knownControllerId}) async {
  final result = await showModalBottomSheet<String>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => const AddControllerSheet(),
  );
  if (result == null || !context.mounted) return false;

  // Parse flux://setup?id=<controllerId>&psk=<hex32>  OR  raw hex
  Uint8List? psk;
  String?    controllerId;
  if (result.startsWith('flux://setup')) {
    final uri = Uri.tryParse(result);
    psk          = _hexToBytes(uri?.queryParameters['psk'] ?? '');
    controllerId = uri?.queryParameters['id'];
  } else {
    psk = _hexToBytes(result.trim());
  }

  if (psk == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invalid PSK — expected 32 hex characters')));
    }
    return false;
  }

  controllerId ??= knownControllerId;

  if (controllerId == null || controllerId.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not determine controller ID — scan the QR code')));
    }
    return false;
  }

  await ControllerSettings.savePsk(controllerId, psk, dtlsIdentity: controllerId);

  final hub = context.read<HubConnection>();
  // Reflect "hub configured" immediately so the UI stops showing "NO HUB YET"
  // even if the controller can't be reached right now.
  await hub.refreshConfiguredState();
  final found = await hub.reconnect();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(found
          ? '🔒 Controller found and connected'
          : 'PSK saved — controller not found yet. Tap ↺ to retry.'),
    ));
  }
  return found;
}

Uint8List? _hexToBytes(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s'), '');
  if (clean.length != 32) return null;
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) return null;
  return Uint8List.fromList(List.generate(
      16, (i) => int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16)));
}
