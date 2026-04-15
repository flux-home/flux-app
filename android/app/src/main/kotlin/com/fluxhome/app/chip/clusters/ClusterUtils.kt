package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.InvokeCallback
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.WriteAttributesCallback
import chip.devicecontroller.model.AttributeWriteRequest
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.InvokeElement
import chip.devicecontroller.model.NodeState
import com.fluxhome.app.chip.ChipClient
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

// ── Attribute read — returns fallback on error ────────────────────────────────

/**
 * Suspending Matter attribute read.
 *
 * Establishes a CASE session, sends a read interaction for [paths], accumulates
 * partial reports, then passes the final [NodeState] to [process] in [onDone].
 *
 * Returns [fallback] on any error; never throws.
 *
 * Use [readAttributeOrThrow] when the caller needs to detect connection failures.
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
                override fun onReport(state: NodeState?) { if (state != null) accumulated = state }
                override fun onDone()                    { if (cont.isActive) cont.resume(process(accumulated)) }
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

// ── Attribute read — throws on error ─────────────────────────────────────────

/**
 * Like [readAttributes] but propagates connection errors as exceptions instead
 * of returning a fallback.  Use this when the caller distinguishes between
 * "offline" (throws) and "online but attribute = false" (returns false).
 */
internal suspend fun <T> readAttributeOrThrow(
    context: Context,
    nodeId:  Long,
    path:    ChipAttributePath,
    tag:     String,
    process: (NodeState?) -> T,
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
                    Log.w(tag, "readAttributeOrThrow failed: ${ex.message}")
                    if (cont.isActive) cont.resumeWithException(ex)
                }
                override fun onReport(state: NodeState?) { if (state != null) accumulated = state }
                override fun onDone()                    { if (cont.isActive) cont.resume(process(accumulated)) }
            },
            ptr, listOf(path), null, false, 0,
        )
    }
}

// ── Attribute write ───────────────────────────────────────────────────────────

/**
 * Suspending Matter attribute write (low-level, device pointer variant).
 *
 * The optional [validateResponse] lambda is called for each [onResponse] event.
 * If it throws, the continuation is failed — use this to check IM status codes.
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

/** Convenience overload: resolves the device pointer from [context] + [nodeId]. */
internal suspend fun writeAttribute(
    context:          Context,
    nodeId:           Long,
    req:              AttributeWriteRequest,
    tag:              String,
    validateResponse: ((status: chip.devicecontroller.model.Status?) -> Unit)? = null,
) = writeAttribute(ChipClient.getConnectedDevicePointer(context, nodeId), req, tag, validateResponse)

// ── Cluster invoke ────────────────────────────────────────────────────────────

/**
 * Suspending wrapper around [chip.devicecontroller.ChipDeviceController.invoke]
 * (low-level, device pointer variant).
 */
internal suspend fun invoke(
    devicePointer: Long,
    element: InvokeElement,
) = suspendCancellableCoroutine<Unit> { cont ->
    ChipClient.getController().invoke(
        object : InvokeCallback {
            override fun onError(ex: Exception?) {
                Log.e("ClusterUtils", "invoke error", ex)
                if (cont.isActive) cont.resumeWithException(ex ?: Exception("invoke failed"))
            }
            override fun onResponse(el: InvokeElement?, code: Long) {
                Log.d("ClusterUtils", "invoke success code=$code")
                if (cont.isActive) cont.resume(Unit)
            }
        },
        devicePointer, element, 0, 0,
    )
}

/** Convenience overload: resolves the device pointer from [context] + [nodeId]. */
internal suspend fun invoke(context: Context, nodeId: Long, element: InvokeElement) =
    invoke(ChipClient.getConnectedDevicePointer(context, nodeId), element)

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
