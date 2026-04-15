package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.FanControl
import chip.devicecontroller.model.AttributeWriteRequest
import chip.devicecontroller.model.ChipAttributePath
import matter.tlv.AnonymousTag
import matter.tlv.TlvWriter

private const val TAG = "FanControlCluster"

/**
 * FanMode enum (Matter spec §4.4.5.2):
 *   0 = Off, 1 = Low, 2 = Med, 3 = High, 4 = On, 5 = Auto, 6 = Smart
 */
internal object FanControlCluster {

    data class FanState(
        val fanMode: Int?,         // 0–6
        val percentCurrent: Int?,  // 0–100
    )

    suspend fun readFanState(
        context: Context, nodeId: Long, endpoint: Int = 1,
    ): FanState = readAttributes(
        context, nodeId,
        listOf(
            ChipAttributePath.newInstance(endpoint, FanControl.ID, FanControl.Attribute.FanMode.id),
            ChipAttributePath.newInstance(endpoint, FanControl.ID, FanControl.Attribute.PercentCurrent.id),
        ),
        FanState(null, null), TAG,
    ) { state ->
        val c = state?.getEndpointState(endpoint)?.getClusterState(FanControl.ID)
        fun intAttr(id: Long) = c?.getAttributeState(id)?.getValue()?.let { (it as? Number)?.toInt() }
        FanState(
            fanMode        = intAttr(FanControl.Attribute.FanMode.id),
            percentCurrent = intAttr(FanControl.Attribute.PercentCurrent.id),
        )
    }.also { Log.d(TAG, "fanState=$it nodeId=$nodeId") }

    suspend fun writeFanMode(
        context: Context, nodeId: Long, mode: Int, endpoint: Int = 1,
    ) {
        val tlv = TlvWriter().put(AnonymousTag, mode.toUByte()).getEncoded()
        writeAttribute(context, nodeId, AttributeWriteRequest.newInstance(
            endpoint, FanControl.ID, FanControl.Attribute.FanMode.id, tlv,
        ), TAG)
        Log.d(TAG, "writeFanMode mode=$mode nodeId=$nodeId")
    }

    suspend fun writePercentSetting(
        context: Context, nodeId: Long, percent: Int, endpoint: Int = 1,
    ) {
        val tlv = TlvWriter().put(AnonymousTag, percent.coerceIn(0, 100).toUByte()).getEncoded()
        writeAttribute(context, nodeId, AttributeWriteRequest.newInstance(
            endpoint, FanControl.ID, FanControl.Attribute.PercentSetting.id, tlv,
        ), TAG)
        Log.d(TAG, "writePercentSetting percent=$percent nodeId=$nodeId")
    }
}
