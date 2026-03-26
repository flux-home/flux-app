import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last scanned / manually entered Matter setup payload string
/// so the commission screen can restore it across app restarts.
class QrPayloadService {
  static const _key = 'last_matter_qr_payload';

  /// Returns the last saved payload, or null if none saved yet.
  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// Saves [payload] (the raw MT:… string or manual pairing code).
  static Future<void> save(String payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, payload.trim());
  }

  /// Removes the saved payload (e.g. after successful commissioning).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
