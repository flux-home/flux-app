package com.example.matter_home.chip

import android.content.Context
import android.util.Log
import chip.devicecontroller.InvokeCallback
import chip.devicecontroller.model.InvokeElement
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "ClusterUtils"

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
                Log.e(TAG, "invoke error", ex)
                if (cont.isActive) cont.resumeWithException(
                    ex ?: Exception("invoke failed")
                )
            }
            override fun onResponse(el: InvokeElement?, code: Long) {
                Log.d(TAG, "invoke success code=$code")
                if (cont.isActive) cont.resume(Unit)
            }
        },
        devicePointer,
        element,
        0,
        0,
    )
}

/** Properly escapes a string for embedding in a JSON double-quoted value. */
internal fun jsonEscape(s: String): String = buildString(s.length + 8) {
    for (c in s) {
        when (c) {
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
}
