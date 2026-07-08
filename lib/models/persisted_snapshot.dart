import 'package:matter_home/models/device_live_data.dart';
import 'package:matter_home/models/matter_device.dart' show MatterDevice;
import 'package:matter_home/providers/device_provider.dart' show DeviceProvider;

/// Thin snapshot of last-known live state persisted alongside [MatterDevice].
///
/// Stores two things:
///   - [productName]  — from BasicInformation cluster; separate because it is
///     never overwritten by subscription events.
///   - [state]        — a merge-compatible attribute map whose keys are exactly
///     the same string keys that [DeviceLiveData.merge] understands.  This makes
///     the snapshot forward-compatible: new clusters just appear in the map
///     without any changes to this class.
///
/// Written at explicit checkpoints only:
///   - On the first `established` subscription event per session (captures the
///     fresh device state immediately after the SDK confirms the subscription).
///   - After a successful user command (toggle, setBrightness, …).
///   - After a successful [DeviceProvider.refreshDevice].
///
/// Read once at app startup to seed [DeviceLiveData] before any subscription
/// arrives, so tiles show the last-known state immediately.
class PersistedSnapshot {

  const PersistedSnapshot({
    required this.deviceId,
    this.productName,
    this.state = const {},
    this.clusterJson,
  });

  // ── Capture ───────────────────────────────────────────────────────────────

  /// Builds a snapshot from the current [DeviceLiveData] for [deviceId].
  /// Only non-null fields are stored so the JSON stays compact. [clusterJson] is
  /// not part of live state, so callers pass the previously-cached value to
  /// preserve it across captures.
  factory PersistedSnapshot.capture(String deviceId, DeviceLiveData live,
          {String? clusterJson}) =>
      PersistedSnapshot(
        deviceId:    deviceId,
        productName: live.productName,
        state:       live.attrs,
        clusterJson: clusterJson,
      );

  /// Returns a copy with [clusterJson] set, preserving everything else.
  PersistedSnapshot withClusterJson(String json) => PersistedSnapshot(
        deviceId:    deviceId,
        productName: productName,
        state:       state,
        clusterJson: json,
      );

  factory PersistedSnapshot.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> state;

    if (json.containsKey('state')) {
      // New format — nested state map.
      state = (json['state'] as Map).cast<String, dynamic>();
    } else {
      // Backwards-compatibility: old flat format.
      state = {};
      if (json['isOn']           != null) state['onOff']          = json['isOn'];
      if (json['levelRaw']       != null) state['level']          = json['levelRaw'];
      if (json['localTempCenti'] != null) state['localTempCenti'] = json['localTempCenti'];
    }

    return PersistedSnapshot(
      deviceId:    json['deviceId']    as String,
      productName: json['productName'] as String?,
      state:       state,
      clusterJson: json['clusterJson'] as String?,
    );
  }
  final String              deviceId;
  final String?             productName;

  /// Last successful targeted cluster dump (BasicInfo + Descriptor + OnOff) as
  /// JSON. Static metadata, so it's cached here to avoid re-reading it from the
  /// controller every time the device view opens.
  final String?             clusterJson;

  /// Merge-compatible attribute map — pass directly to [DeviceLiveData.merge].
  /// Keys match the subscription event keys (e.g. 'onOff', 'level',
  /// 'contactState', 'fanMode', …).
  final Map<String, dynamic> state;

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'deviceId':    deviceId,
    if (productName != null) 'productName': productName,
    'state':       state,
    if (clusterJson != null) 'clusterJson': clusterJson,
  };
}
