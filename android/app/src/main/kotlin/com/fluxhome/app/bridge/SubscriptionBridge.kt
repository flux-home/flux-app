package com.fluxhome.app.bridge

import android.util.Log
import com.fluxhome.app.chip.clusters.SubscriptionManager
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class SubscriptionBridge(private val core: BridgeCore) {

    /** Node IDs for which we should suppress further events (stopped/removed). */
    private val cancelledNodeIds = mutableSetOf<Long>()

    fun startSubscription(nodeId: Long, result: MethodChannel.Result) = core.requireChip(result) {
        startSubscriptionForNode(nodeId)
        core.main.post { result.success(true) }
    }

    fun startSubscriptionForNode(nodeId: Long) {
        cancelledNodeIds.remove(nodeId)
        SubscriptionManager.subscribeDeviceState(
            context = core.context,
            nodeId  = nodeId,
            onUpdate = { nid, attrs ->
                if (nid !in cancelledNodeIds) {
                    val payload = mutableMapOf<String, Any?>(
                        "nodeId" to nid,
                        "type"   to "update",
                    )
                    payload.putAll(attrs)
                    core.emitDeviceState(payload)
                }
            },
            onEstablished = { nid ->
                if (nid !in cancelledNodeIds)
                    core.emitDeviceState(mapOf("nodeId" to nid, "type" to "established"))
            },
            onResubscribing = { nid, nextMs ->
                if (nid !in cancelledNodeIds) {
                    core.emitDeviceState(mapOf("nodeId" to nid, "type" to "resubscribing",
                                               "nextMs" to nextMs))
                    // SDK exponential backoff can grow to minutes — if it exceeds 30 s,
                    // the UDP socket is likely permanently broken. Restart cleanly.
                    if (nextMs > 30_000L) {
                        Log.w(TAG, "Resubscription backoff too large (${nextMs}ms) for " +
                                   "nodeId=$nid — forcing restart")
                        core.scope.launch {
                            delay(2_000L)
                            if (nid !in cancelledNodeIds) startSubscriptionForNode(nid)
                        }
                    }
                }
            },
            onError = { nid, err ->
                if (nid !in cancelledNodeIds) {
                    core.emitDeviceState(mapOf("nodeId" to nid, "type" to "error",
                                               "message" to (err.message ?: "unknown")))
                    // For ICD / sleepy devices the initial connection may time out.
                    // Retry after 60 s — the device will be reachable on next check-in.
                    core.scope.launch {
                        delay(60_000L)
                        if (nid !in cancelledNodeIds) {
                            Log.d(TAG, "Retrying subscription after failure nodeId=$nid")
                            startSubscriptionForNode(nid)
                        }
                    }
                }
            },
        )
    }

    fun stopSubscription(nodeId: Long, result: MethodChannel.Result) {
        cancelledNodeIds.add(nodeId)
        result.success(true)
    }

    companion object {
        private const val TAG = "SubscriptionBridge"
    }
}
