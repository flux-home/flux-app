package com.example.matter_home.chip

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.Identify
import chip.devicecontroller.model.InvokeElement
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvWriter

private const val TAG = "IdentifyCluster"

internal object IdentifyCluster {

    /**
     * Sends the Identify command.
     * [seconds] is the identify duration (0 stops an in-progress identify).
     */
    suspend fun sendIdentify(
        context:  Context,
        nodeId:   Long,
        seconds:  Int = 15,
        endpoint: Int = 1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(0x00), seconds.toUShort())
            .endStructure()
            .getEncoded()
        val element = InvokeElement.newInstance(
            endpoint, Identify.ID, Identify.Command.Identify.id, tlv, null,
        )
        invoke(context, ptr, element)
        Log.d(TAG, "Identify seconds=$seconds → nodeId=$nodeId ep=$endpoint")
    }
}
