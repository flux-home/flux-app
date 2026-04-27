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

sealed class DeviceStateEvent {
  const DeviceStateEvent(this.nodeId);
  final int nodeId;
}

/// Subscription successfully established on [nodeId]; an initial data report
/// will follow immediately as a [SubscriptionUpdateEvent].
class SubscriptionEstablishedEvent extends DeviceStateEvent {
  const SubscriptionEstablishedEvent(super.nodeId);
}

/// One or more attribute values changed on [nodeId].
///
/// [attrs] contains only the attributes that changed in this report.
/// Keys are the camelCase strings defined in SubscriptionManager.kt
/// (e.g. `'onOff'`, `'localTempCenti'`, `'co2Ppm'`).
class SubscriptionUpdateEvent extends DeviceStateEvent {
  const SubscriptionUpdateEvent(super.nodeId, this.attrs);
  final Map<String, dynamic> attrs;
}

/// Subscription session dropped; the CHIP SDK is retrying automatically.
///
/// [nextIntervalMs] is the SDK's back-off delay before the next attempt.
class SubscriptionResubscribingEvent extends DeviceStateEvent {
  const SubscriptionResubscribingEvent(super.nodeId, this.nextIntervalMs);
  final int nextIntervalMs;
}

/// Subscription permanently failed on [nodeId]; a manual restart is needed.
class SubscriptionErrorEvent extends DeviceStateEvent {
  const SubscriptionErrorEvent(super.nodeId, this.message);
  final String message;
}

/// OTA firmware update progress for [nodeId].
///
/// [phase] is one of: `download` | `querying` | `installing` | `applying` |
///   `dryrun` | `complete` | `error`.
/// [progress] is a 0–100 percentage, present during `download` / `installing`.
/// [message] carries an error description when [phase] is `error`.
class OtaProgressEvent extends DeviceStateEvent {
  const OtaProgressEvent(
    super.nodeId, {
    required this.phase,
    this.progress,
    this.message,
  });
  final String phase;
  final int? progress;
  final String? message;
}
