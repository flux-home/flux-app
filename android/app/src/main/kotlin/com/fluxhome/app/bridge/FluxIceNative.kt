package com.fluxhome.app.bridge

/**
 * JNI surface over flux_ice_mobile (libflux_ice_jni.so). Thin control plane
 * only — the packet data plane stays entirely in native code (app ADR-0001).
 *
 * `nativeStart` blocks ~3 s (gathering); call it off the main thread.
 */
object FluxIceNative {
    init {
        System.loadLibrary("flux_ice_jni")
    }

    /** Opens a CONTROLLING session + gathers. Returns a native handle (0 = failure). */
    external fun nativeStart(stunHost: String?, stunPort: Int): Long

    /** The local offer SDP captured at start. */
    external fun nativeOffer(handle: Long): String

    /** Feed the controller's answer SDP. Returns 0 on success. */
    external fun nativeSetAnswer(handle: Long, answer: String): Int

    /** Loopback UDP port for the app's CoAP client (coaps://127.0.0.1:<port>). */
    external fun nativeLocalPort(handle: Long): Int

    /** 0 NEW, 1 GATHERING, 2 CHECKING, 3 CONNECTED, 4 FAILED, 5 CLOSED. */
    external fun nativeState(handle: Long): Int

    /** Tear down + free. */
    external fun nativeStop(handle: Long)
}
