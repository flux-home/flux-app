// ─────────────────────────────────────────────────────────────────────────────
// Typed events emitted by the Android subscription layer.
//
// The platform channel must carry a Map<String, dynamic> — that constraint
// belongs to Flutter, not to this app.  MatterChannel decodes the raw map here,
// at the channel boundary, so every consumer above it speaks typed Dart.
//
// The attrs payload inside SubscriptionUpdateEvent deliberately stays as
// Map<String, dynamic>: the Kotlin side emits an open-ended set of attribute
// keys (one per subscribed cluster attribute) and DeviceLiveData.merge() is
// designed to accept any key without code changes.  The encoding contract
// (key names) lives in SubscriptionManager.kt; DeviceLiveData's typed getters
// are the stable Dart-side API over it.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:matter_home/models/matter_device.dart' show DeviceKind;

sealed class DeviceStateEvent {
  const DeviceStateEvent(this.nodeId,
      {this.kind = DeviceKind.matter, this.endpoint = 0});
  final int nodeId;

  /// Which device ON that node the event belongs to. 0 = the node itself.
  ///
  /// A subscription is per node and its wildcard covers every endpoint, so a
  /// bridge delivers its children's reports over one session. Without this, all
  /// of them merge into the bridge's cache entry and the last endpoint to report
  /// wins per attribute — five Hue devices sharing one `onOff`.
  ///
  /// Only attribute updates carry a meaningful endpoint; connectivity events are
  /// node-level and keep 0.
  final int endpoint;

  /// With [nodeId], identifies the device the event belongs to. Events for a
  /// Modbus device and a Matter node can share a nodeId, so matching on nodeId
  /// alone would deliver one device's readings to the other.
  final DeviceKind kind;
}

/// Subscription successfully established on [nodeId]; an initial data report
/// will follow immediately as a [SubscriptionUpdateEvent].
class SubscriptionEstablishedEvent extends DeviceStateEvent {
  const SubscriptionEstablishedEvent(super.nodeId, {super.kind});
}

/// One or more attribute values changed on [nodeId].
///
/// [attrs] contains only the attributes that changed in this report.
/// Keys are the camelCase strings defined in SubscriptionManager.kt
/// (e.g. `'onOff'`, `'localTempCenti'`, `'co2Ppm'`).
class SubscriptionUpdateEvent extends DeviceStateEvent {
  const SubscriptionUpdateEvent(super.nodeId, this.attrs,
      {super.kind, super.endpoint});
  final Map<String, dynamic> attrs;
}

/// Subscription session dropped; the CHIP SDK is retrying automatically.
///
/// [nextIntervalMs] is the SDK's back-off delay before the next attempt.
class SubscriptionResubscribingEvent extends DeviceStateEvent {
  const SubscriptionResubscribingEvent(super.nodeId, this.nextIntervalMs, {super.kind});
  final int nextIntervalMs;
}

/// Subscription permanently failed on [nodeId]; a manual restart is needed.
class SubscriptionErrorEvent extends DeviceStateEvent {
  const SubscriptionErrorEvent(super.nodeId, this.message, {super.kind});
  final String message;
}


