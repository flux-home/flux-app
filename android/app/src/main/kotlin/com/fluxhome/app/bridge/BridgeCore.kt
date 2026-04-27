package com.fluxhome.app.bridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.fluxhome.app.chip.ChipClient
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Shared infrastructure injected into every sub-bridge.
 *
 * Holds the coroutine scope, main-thread handler, event sinks, and the
 * [requireChip] guard so no sub-bridge duplicates any of this boilerplate.
 */
class BridgeCore(val context: Context) {

    val main  = Handler(Looper.getMainLooper())
    val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // ── EventChannel sinks ────────────────────────────────────────────────────
    @Volatile var commissionEventSink: EventChannel.EventSink? = null
    @Volatile var deviceStateSink:     EventChannel.EventSink? = null

    fun emitEvent(msg: String) {
        main.post { commissionEventSink?.success(msg) }
    }

    fun emitDeviceState(payload: Map<String, Any?>) {
        main.post { deviceStateSink?.success(payload) }
    }

    // ── Guard: require real CHIP SDK ──────────────────────────────────────────
    fun requireChip(result: MethodChannel.Result, block: suspend () -> Unit) {
        if (!ChipClient.isAvailable) {
            result.error(
                "CHIP_SDK_UNAVAILABLE",
                "The CHIP SDK is not loaded. Place CHIPController.aar in android/app/libs/ and rebuild.",
                null,
            )
            return
        }
        scope.launch {
            try { block() } catch (e: Exception) {
                Log.e(TAG, "CHIP call failed", e)
                main.post { result.error("CHIP_ERROR", e.message, null) }
            }
        }
    }

    companion object {
        private const val TAG = "BridgeCore"
    }
}
