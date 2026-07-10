import 'package:flutter/foundation.dart';

import 'package:matter_home/services/controller_transport/controller_transport.dart';
import 'package:matter_home/services/controller_transport/in_process_transport.dart';
import 'package:matter_home/services/controller_transport/isolate_transport.dart';

/// Set to `false` to force the in-process (UI-isolate) client everywhere — the
/// escape hatch if the isolate transport ever misbehaves.
const bool kUseIsolateTransport = true;

/// The transport used by [FluxCoapService] unless one is injected. Runs the
/// CoAP/DTLS client on a background isolate on mobile/desktop (keeps the DTLS
/// handshake off the UI thread); falls back to in-process on web / when disabled.
ControllerTransport defaultControllerTransport(FluxControllerEndpoint endpoint) =>
    (kUseIsolateTransport && !kIsWeb)
        ? IsolateTransport(endpoint)
        : InProcessTransport(endpoint);
