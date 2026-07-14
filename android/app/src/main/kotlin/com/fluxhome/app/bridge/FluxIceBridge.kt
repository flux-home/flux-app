package com.fluxhome.app.bridge

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

/**
 * MethodChannel/EventChannel handler for the flux-ice remote-access tunnel,
 * mirroring [MatterBridge]. Kotlin stays thin: it drives [FluxIceNative] and
 * polls the ICE state onto the event sink (native worker thread is never
 * attached to the JVM).
 */
class FluxIceBridge {

    companion object { private const val TAG = "FluxIceBridge" }

    private val main = Handler(Looper.getMainLooper())
    private var stateSink: EventChannel.EventSink? = null
    private var poller: Thread? = null
    @Volatile private var polling = false

    // ── MethodChannel ───────────────────────────────────────────────────────

    /** start(stunHost?, stunPort, turn…) → { "handle": Long, "offer": String } (null on failure). */
    fun start(stunHost: String?, stunPort: Int,
              turnHost: String?, turnPort: Int, turnUser: String?, turnPass: String?,
              result: MethodChannel.Result) {
        thread(name = "flux_ice_start") {   // nativeStart blocks (~3 s gather)
            val handle = try {
                FluxIceNative.nativeStart(stunHost, stunPort, turnHost, turnPort, turnUser, turnPass)
            } catch (t: Throwable) {
                Log.e(TAG, "nativeStart failed", t); 0L
            }
            main.post {
                if (handle == 0L) {
                    result.error("start_failed", "flux_ice_mobile_start returned null", null)
                } else {
                    result.success(mapOf(
                        "handle" to handle,
                        "offer"  to FluxIceNative.nativeOffer(handle),
                    ))
                }
            }
        }
    }

    fun setAnswer(handle: Long, answer: String, result: MethodChannel.Result) {
        result.success(FluxIceNative.nativeSetAnswer(handle, answer))
    }

    fun localPort(handle: Long, result: MethodChannel.Result) {
        result.success(FluxIceNative.nativeLocalPort(handle))
    }

    fun stop(handle: Long, result: MethodChannel.Result) {
        stopPolling()
        FluxIceNative.nativeStop(handle)
        result.success(null)
    }

    // ── EventChannel: ICE state stream (polled) ───────────────────────────────

    fun setStateSink(sink: EventChannel.EventSink?, handle: Long) {
        stateSink = sink
        if (sink == null || handle == 0L) { stopPolling(); return }
        polling = true
        poller = thread(name = "flux_ice_state") {
            var last = -1
            while (polling) {
                val st = FluxIceNative.nativeState(handle)
                if (st != last) {
                    last = st
                    main.post { stateSink?.success(st) }
                }
                if (st == 4 /*FAILED*/ || st == 5 /*CLOSED*/) break
                try { Thread.sleep(200) } catch (_: InterruptedException) { break }
            }
        }
    }

    private fun stopPolling() {
        polling = false
        poller?.interrupt()
        poller = null
    }
}
