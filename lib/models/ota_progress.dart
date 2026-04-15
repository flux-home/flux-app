/// In-progress OTA update state for a single device.
/// Populated from "otaProgress" events on the device-state stream.
class OtaProgressState {

  const OtaProgressState({
    required this.phase,
    this.progress,
    this.message,
  });
  /// Current phase of the update pipeline.
  ///
  /// Possible values emitted by native:
  ///   "download"   — firmware file download in progress
  ///   "querying"   — waiting for device to query the OTA provider
  ///   "installing" — BDX file transfer to device in progress
  ///   "applying"   — device acknowledged, applying the image
  ///   "complete"   — update applied; device will reboot
  ///   "error"      — something failed; see [message]
  final String  phase;

  /// Progress within the current phase, 0–100.  Null when not applicable.
  final int?    progress;

  /// Human-readable error description when [phase] == "error".
  final String? message;

  bool get isTerminal => phase == 'complete' || phase == 'error' || phase == 'dryrun';
}
