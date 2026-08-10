import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matter_home/services/controller_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final psk = Uint8List.fromList(List.generate(16, (i) => i));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('clearController', () {
    test('removes every per-controller key, not just the PSK', () async {
      const id = 'flux-controller-e25311';
      await ControllerSettings.savePsk(id, psk, dtlsIdentity: id);
      await ControllerSettings.saveRendezvousUrl(id, 'https://rzv.example');
      await ControllerSettings.saveStunServer(id, 'stun.example:3478');
      await ControllerSettings.saveTurn(id,
          server: 'turn.example:3478', user: 'u', pass: 'p');

      await ControllerSettings.clearController(id);

      // The regression: clearPsk alone left the DTLS id (and remote config)
      // behind. hasAnyPsk must now be false AND no orphan keys remain.
      expect(await ControllerSettings.hasAnyPsk(), isFalse);
      expect(await ControllerSettings.loadPsk(id), isNull);
      expect(await ControllerSettings.loadRendezvousUrl(id), isNull);
      expect(await ControllerSettings.loadStunServer(id), isNull);
      expect(await ControllerSettings.loadTurn(id), (null, null, null));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.contains(id)), isEmpty);
    });
  });

  group('clearAllControllers', () {
    test('sweeps all ctrl_* keys, including a PSK-less orphan', () async {
      await ControllerSettings.savePsk('ctrl-a', psk, dtlsIdentity: 'ctrl-a');
      await ControllerSettings.savePsk('ctrl-b', psk, dtlsIdentity: 'ctrl-b');
      // Simulate the reported stale state: a DTLS id whose PSK was already
      // (partially) cleared — allControllerIds wouldn't see it, but the sweep
      // must still remove it.
      await ControllerSettings.clearPsk('ctrl-b'); // leaves ctrl_dtls_id_ctrl-b

      await ControllerSettings.clearAllControllers();

      expect(await ControllerSettings.hasAnyPsk(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('ctrl_')), isEmpty);
    });
  });
}
