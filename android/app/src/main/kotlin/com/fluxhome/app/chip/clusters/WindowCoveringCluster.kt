package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.WindowCovering
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.InvokeElement
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvWriter

private const val TAG = "WindowCoveringCluster"

internal object WindowCoveringCluster {

    // ── Commands ─────────────────────────────────────────────────────────────

    suspend fun upOrOpen(context: Context, nodeId: Long, endpoint: Int = 1) =
        invoke(context, nodeId,
            InvokeElement.newInstance(endpoint, WindowCovering.ID,
                WindowCovering.Command.UpOrOpen.id, null, null))

    suspend fun downOrClose(context: Context, nodeId: Long, endpoint: Int = 1) =
        invoke(context, nodeId,
            InvokeElement.newInstance(endpoint, WindowCovering.ID,
                WindowCovering.Command.DownOrClose.id, null, null))

    suspend fun stopMotion(context: Context, nodeId: Long, endpoint: Int = 1) =
        invoke(context, nodeId,
            InvokeElement.newInstance(endpoint, WindowCovering.ID,
                WindowCovering.Command.StopMotion.id, null, null))

    /**
     * GoToLiftPercentage command. [percent100ths] is 0 (open) – 10 000 (closed).
     */
    suspend fun goToLiftPercentage(
        context: Context,
        nodeId: Long,
        percent100ths: Int,
        endpoint: Int = 1,
    ) {
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(
                WindowCovering.GoToLiftPercentageCommandField.LiftPercent100thsValue.id),
                percent100ths.coerceIn(0, 10_000).toUInt())
            .endStructure()
            .getEncoded()
        invoke(context, nodeId, InvokeElement.newInstance(
            endpoint, WindowCovering.ID,
            WindowCovering.Command.GoToLiftPercentage.id, tlv, null,
        ))
        Log.d(TAG, "GoToLiftPercentage $percent100ths → nodeId=$nodeId ep=$endpoint")
    }

    // ── Read ─────────────────────────────────────────────────────────────────

    /** Returns CurrentPositionLiftPercent100ths (0–10 000) or null. */
    suspend fun readLiftPercent100ths(
        context: Context, nodeId: Long, endpoint: Int = 1,
    ): Int? = readAttributes(
        context, nodeId,
        ChipAttributePath.newInstance(endpoint, WindowCovering.ID,
            WindowCovering.Attribute.CurrentPositionLiftPercent100ths.id),
        null, TAG,
    ) { state ->
        state?.getEndpointState(endpoint)
            ?.getClusterState(WindowCovering.ID)
            ?.getAttributeState(
                WindowCovering.Attribute.CurrentPositionLiftPercent100ths.id)
            ?.getValue()
            ?.let { (it as? Number)?.toInt() }
    }.also { Log.d(TAG, "liftPercent100ths=$it nodeId=$nodeId") }
}
