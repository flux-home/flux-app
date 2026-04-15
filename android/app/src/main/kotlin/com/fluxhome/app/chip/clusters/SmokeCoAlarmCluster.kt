package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.SmokeCoAlarm
import chip.devicecontroller.model.ChipAttributePath

private const val TAG = "SmokeCoAlarmCluster"

/**
 * Read-only access to the Smoke CO Alarm cluster (0x005C).
 *
 * AlarmStateEnum (shared by SmokeState, COState, BatteryAlert):
 *   0 = Normal, 1 = Warning, 2 = Critical
 */
internal object SmokeCoAlarmCluster {

    data class SmokeCoState(
        val smokeState:   Int?,  // 0=Normal 1=Warning 2=Critical
        val coState:      Int?,
        val batteryAlert: Int?,
    )

    suspend fun readState(
        context: Context, nodeId: Long, endpoint: Int = 1,
    ): SmokeCoState = readAttributes(
        context, nodeId,
        listOf(
            ChipAttributePath.newInstance(endpoint, SmokeCoAlarm.ID, SmokeCoAlarm.Attribute.SmokeState.id),
            ChipAttributePath.newInstance(endpoint, SmokeCoAlarm.ID, SmokeCoAlarm.Attribute.COState.id),
            ChipAttributePath.newInstance(endpoint, SmokeCoAlarm.ID, SmokeCoAlarm.Attribute.BatteryAlert.id),
        ),
        SmokeCoState(null, null, null), TAG,
    ) { state ->
        val c = state?.getEndpointState(endpoint)?.getClusterState(SmokeCoAlarm.ID)
        fun intAttr(id: Long) = c?.getAttributeState(id)?.getValue()?.let { (it as? Number)?.toInt() }
        SmokeCoState(
            smokeState   = intAttr(SmokeCoAlarm.Attribute.SmokeState.id),
            coState      = intAttr(SmokeCoAlarm.Attribute.COState.id),
            batteryAlert = intAttr(SmokeCoAlarm.Attribute.BatteryAlert.id),
        )
    }.also { Log.d(TAG, "smokeCoState=$it nodeId=$nodeId") }
}
