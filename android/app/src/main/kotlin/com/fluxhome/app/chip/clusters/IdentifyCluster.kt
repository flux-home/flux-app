package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.Identify
import chip.devicecontroller.model.InvokeElement
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvWriter

private const val TAG = "IdentifyCluster"

internal object IdentifyCluster {

    // IdentifyTime field ID in the Identify command (spec §1.2.6.1, field 0)
    private const val FIELD_IDENTIFY_TIME = 0x00

    /**
     * Sends the Identify command. [seconds] is the identify duration
     * (0 stops an in-progress identify).
     */
    suspend fun sendIdentify(context: Context, nodeId: Long, seconds: Int = 15, endpoint: Int = 1) {
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(FIELD_IDENTIFY_TIME), seconds.toUShort())
            .endStructure()
            .getEncoded()
        invoke(context, nodeId, InvokeElement.newInstance(
            endpoint, Identify.ID, Identify.Command.Identify.id, tlv, null,
        ))
        Log.d(TAG, "Identify seconds=$seconds → nodeId=$nodeId ep=$endpoint")
    }
}
