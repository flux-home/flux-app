import 'device_live_data.dart';

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
  final String              deviceId;
  final String?             productName;

  /// Merge-compatible attribute map — pass directly to [DeviceLiveData.merge].
  /// Keys match the subscription event keys (e.g. 'onOff', 'level',
  /// 'contactState', 'fanMode', …).
  final Map<String, dynamic> state;

  const PersistedSnapshot({
    required this.deviceId,
    this.productName,
    this.state = const {},
  });

  // ── Capture ───────────────────────────────────────────────────────────────

  /// Builds a snapshot from the current [DeviceLiveData] for [deviceId].
  /// Only non-null fields are stored so the JSON stays compact.
  factory PersistedSnapshot.capture(String deviceId, DeviceLiveData live) =>
      PersistedSnapshot(
        deviceId:    deviceId,
        productName: live.productName,
        state:       live.attrs,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'deviceId':    deviceId,
    if (productName != null) 'productName': productName,
    'state':       state,
  };

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
    );
  }
}
