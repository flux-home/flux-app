package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.OnOff
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.InvokeElement
import matter.tlv.AnonymousTag
import matter.tlv.TlvReader
import matter.tlv.TlvWriter

private const val TAG = "OnOffCluster"

internal object OnOffCluster {

    /**
     * Sends an On or Off command to [nodeId] on [endpoint].
     * On/Off commands carry no fields; an empty TLV struct is sent to satisfy
     * the SDK requirement for a non-null body.
     */
    suspend fun setOnOff(context: Context, nodeId: Long, on: Boolean, endpoint: Int = 1) {
        val cmdId       = if (on) OnOff.Command.On.id else OnOff.Command.Off.id
        val emptyStruct = TlvWriter().startStructure(AnonymousTag).endStructure().getEncoded()
        invoke(context, nodeId, InvokeElement.newInstance(endpoint, OnOff.ID, cmdId, emptyStruct, null))
        Log.d(TAG, "OnOff ${if (on) "On" else "Off"} → nodeId=$nodeId ep=$endpoint")
    }

    /**
     * Reads the OnOff attribute from [nodeId].
     * Throws on connection failure so callers can distinguish offline from off.
     */
    suspend fun readOnOff(context: Context, nodeId: Long, endpoint: Int = 1): Boolean =
        readAttributeOrThrow(
            context, nodeId,
            ChipAttributePath.newInstance(endpoint, OnOff.ID, OnOff.Attribute.OnOff.id),
            TAG,
        ) { state ->
            state?.getEndpointState(endpoint)
                ?.getClusterState(OnOff.ID)
                ?.getAttributeState(OnOff.Attribute.OnOff.id)
                ?.tlv?.let { TlvReader(it).getBool(AnonymousTag) }
                ?: false
        }
}
