package com.example.matter_home.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.InvokeCallback
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.WriteAttributesCallback
import chip.devicecontroller.model.AttributeWriteRequest
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.InvokeElement
import chip.devicecontroller.model.NodeState
import com.example.matter_home.chip.ChipClient
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

// ── Attribute read ────────────────────────────────────────────────────────────

/**
 * Suspending Matter attribute read.
 *
 * Establishes a CASE session, sends a read interaction for [paths], accumulates
 * reports across multiple [onReport] calls, then passes the final [NodeState]
 * to [process] in [onDone].
 *
 * Returns [fallback] on any error; never throws.
 */
internal suspend fun <T> readAttributes(
    context:  Context,
    nodeId:   Long,
    paths:    List<ChipAttributePath>,
    fallback: T,
    tag:      String,
    process:  (NodeState?) -> T,
): T {
    val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
    return suspendCancellableCoroutine { cont ->
        var accumulated: NodeState? = null
        ChipClient.getController().readPath(
            object : ReportCallback {
                override fun onError(
                    a: chip.devicecontroller.model.ChipAttributePath?,
                    e: chip.devicecontroller.model.ChipEventPath?,
                    ex: Exception,
                ) {
                    Log.w(tag, "readAttributes failed: ${ex.message}")
                    if (cont.isActive) cont.resume(fallback)
                }
                override fun onReport(state: NodeState?) {
                    if (state != null) accumulated = state
                }
                override fun onDone() {
                    if (cont.isActive) cont.resume(process(accumulated))
                }
            },
            ptr, paths, null, false, 0,
        )
    }
}

/** Single-path convenience overload. */
internal suspend fun <T> readAttributes(
    context:  Context,
    nodeId:   Long,
    path:     ChipAttributePath,
    fallback: T,
    tag:      String,
    process:  (NodeState?) -> T,
) = readAttributes(context, nodeId, listOf(path), fallback, tag, process)

// ── Attribute write ───────────────────────────────────────────────────────────

/**
 * Suspending Matter attribute write.
 *
 * The optional [validateResponse] lambda is called for each [onResponse] event.
 * If it throws, the continuation is failed with that exception, which is useful
 * for checking IM status codes (e.g. OTA DefaultOTAProviders write).
 */
internal suspend fun writeAttribute(
    devicePointer:    Long,
    req:              AttributeWriteRequest,
    tag:              String,
    validateResponse: ((status: chip.devicecontroller.model.Status?) -> Unit)? = null,
) = suspendCancellableCoroutine<Unit> { cont ->
    ChipClient.getController().write(
        object : WriteAttributesCallback {
            override fun onError(
                path: chip.devicecontroller.model.ChipAttributePath?,
                ex: Exception,
            ) {
                Log.e(tag, "writeAttribute error", ex)
                if (cont.isActive) cont.resumeWithException(ex)
            }
            override fun onResponse(
                path:   chip.devicecontroller.model.ChipAttributePath?,
                status: chip.devicecontroller.model.Status?,
            ) {
                Log.d(tag, "writeAttribute response: $status")
                try { validateResponse?.invoke(status) }
                catch (ex: Exception) { if (cont.isActive) cont.resumeWithException(ex) }
            }
            override fun onDone() { if (cont.isActive) cont.resume(Unit) }
        },
        devicePointer, listOf(req), 0, 0,
    )
}

// ── Cluster invoke ────────────────────────────────────────────────────────────

/**
 * Suspending wrapper around [chip.devicecontroller.ChipDeviceController.invoke].
 * Resumes normally on success, or throws on error.
 */
internal suspend fun invoke(
    @Suppress("UNUSED_PARAMETER") context: Context,
    devicePointer: Long,
    element: InvokeElement,
) = suspendCancellableCoroutine<Unit> { cont ->
    ChipClient.getController().invoke(
        object : InvokeCallback {
            override fun onError(ex: Exception?) {
                Log.e("ClusterUtils", "invoke error", ex)
                if (cont.isActive) cont.resumeWithException(
                    ex ?: Exception("invoke failed")
                )
            }
            override fun onResponse(el: InvokeElement?, code: Long) {
                Log.d("ClusterUtils", "invoke success code=$code")
                if (cont.isActive) cont.resume(Unit)
            }
        },
        devicePointer,
        element,
        0,
        0,
    )
}

// ── JSON escaping ─────────────────────────────────────────────────────────────

/** Properly escapes a string for embedding in a JSON double-quoted value. */
internal fun jsonEscape(s: String): String = buildString(s.length + 8) {
    for (c in s) when (c) {
        '\\'     -> append("\\\\")
        '"'      -> append("\\\"")
        '\n'     -> append("\\n")
        '\r'     -> append("\\r")
        '\t'     -> append("\\t")
        '\b'     -> append("\\b")
        '\u000C' -> append("\\f")
        else     -> if (c.code < 0x20) append("\\u%04x".format(c.code)) else append(c)
    }
}
