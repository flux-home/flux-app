import 'dart:convert';

import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Result model
// ─────────────────────────────────────────────────────────────────────────────

class DclUpdateResult {
  /// True if a newer valid version exists for this device on the DCL.
  final bool    isUpdateAvailable;

  /// The highest available version integer (uint32), or null when up-to-date.
  final int?    latestVersion;

  /// Human-readable version string from the DCL record, e.g. "1.3.0".
  final String? latestVersionString;

  /// Direct OTA image URL from the DCL, empty string if not provided.
  final String  otaUrl;

  /// Release notes URL from the DCL, empty string if not provided.
  final String  releaseNotesUrl;

  const DclUpdateResult({
    required this.isUpdateAvailable,
    this.latestVersion,
    this.latestVersionString,
    this.otaUrl          = '',
    this.releaseNotesUrl = '',
  });

  static const DclUpdateResult upToDate =
      DclUpdateResult(isUpdateAvailable: false);
}

// ─────────────────────────────────────────────────────────────────────────────
// Typed errors
// ─────────────────────────────────────────────────────────────────────────────

/// Device (VID/PID) not found in the DCL.
class DclNotFoundError implements Exception {
  final String message;
  const DclNotFoundError(this.message);
  @override
  String toString() => message;
}

/// Network or HTTP error while contacting the DCL.
class DclNetworkError implements Exception {
  final String message;
  const DclNetworkError(this.message);
  @override
  String toString() => message;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class DclService {
  static const _base = 'https://on.dcl.csa-iot.org';

  final http.Client _client;
  DclService({http.Client? client}) : _client = client ?? http.Client();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Checks the CSA Distributed Compliance Ledger for an available software
  /// update for the device identified by [vid] + [pid] + [currentVersion].
  ///
  /// [vid]            – vendor ID (decimal integer, e.g. 5264)
  /// [pid]            – product ID (decimal integer, e.g. 1)
  /// [currentVersion] – uint32 SoftwareVersion from BasicInformation cluster
  ///
  /// Returns a [DclUpdateResult] describing whether an update is available.
  /// Throws [DclNotFoundError] if the device is not in the DCL, or
  /// [DclNetworkError] on connectivity problems.
  Future<DclUpdateResult> checkForUpdate({
    required int vid,
    required int pid,
    required int currentVersion,
  }) async {
    // 1 ── Fetch the list of all known software versions for this device.
    final versions = await _fetchVersionList(vid, pid);
    if (versions.isEmpty) return DclUpdateResult.upToDate;

    // 2 ── Keep only versions newer than the current one.
    final candidates = versions.where((v) => v > currentVersion).toList()
      ..sort();

    if (candidates.isEmpty) return DclUpdateResult.upToDate;

    // 3 ── Walk candidates from highest down; find the first valid one that
    //      applies to the current version (min ≤ current ≤ max).
    for (final candidate in candidates.reversed) {
      final detail = await _fetchVersionDetail(vid, pid, candidate);
      if (detail == null) continue;

      final valid = detail['softwareVersionValid'] as bool? ?? false;
      final min   = detail['minApplicableSoftwareVersion'] as int? ?? 0;
      final max   = detail['maxApplicableSoftwareVersion'] as int? ?? 0xFFFFFFFF;

      if (!valid) continue;
      if (currentVersion < min || currentVersion > max) continue;

      return DclUpdateResult(
        isUpdateAvailable:   true,
        latestVersion:       candidate,
        latestVersionString: detail['softwareVersionString'] as String?,
        otaUrl:              (detail['otaUrl']         as String?) ?? '',
        releaseNotesUrl:     (detail['releaseNotesUrl'] as String?) ?? '',
      );
    }

    return DclUpdateResult.upToDate;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<List<int>> _fetchVersionList(int vid, int pid) async {
    final uri = Uri.parse('$_base/dcl/model/versions/$vid/$pid');
    final response = await _get(uri);
    final body     = json.decode(response) as Map<String, dynamic>;
    final versions = body['modelVersions']?['softwareVersions'] as List<dynamic>?;
    return versions?.map((e) => (e as num).toInt()).toList() ?? [];
  }

  Future<Map<String, dynamic>?> _fetchVersionDetail(
      int vid, int pid, int version) async {
    final uri = Uri.parse('$_base/dcl/model/versions/$vid/$pid/$version');
    try {
      final response = await _get(uri);
      final body     = json.decode(response) as Map<String, dynamic>;
      return body['modelVersion'] as Map<String, dynamic>?;
    } on DclNotFoundError {
      return null; // skip unknown version entries
    }
  }

  /// Executes a GET request and returns the body string.
  /// Throws [DclNotFoundError] on 404, [DclNetworkError] on other failures.
  Future<String> _get(Uri uri) async {
    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw DclNetworkError('DCL request timed out'),
      );
      if (response.statusCode == 404) {
        throw DclNotFoundError('Not found on DCL: $uri');
      }
      if (response.statusCode != 200) {
        throw DclNetworkError(
            'DCL returned HTTP ${response.statusCode} for $uri');
      }
      return response.body;
    } on DclNotFoundError {
      rethrow;
    } on DclNetworkError {
      rethrow;
    } catch (e) {
      throw DclNetworkError('DCL request failed: $e');
    }
  }
}
