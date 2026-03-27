package com.example.matter_home.chip.clusters

import com.example.matter_home.chip.ChipClient

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.OnOff
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.InvokeElement
import chip.devicecontroller.model.NodeState
import matter.tlv.AnonymousTag
import matter.tlv.TlvReader
import matter.tlv.TlvWriter
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "OnOffCluster"

internal object OnOffCluster {

    /** Sends an On or Off command to [nodeId] on [endpoint]. */
    suspend fun setOnOff(
        context:  Context,
        nodeId:   Long,
        on:       Boolean,
        endpoint: Int = 1,
    ) {
        val ptr   = ChipClient.getConnectedDevicePointer(context, nodeId)
        val cmdId = if (on) OnOff.Command.On.id else OnOff.Command.Off.id
        // On/Off commands carry no fields but the SDK requires a non-null TLV body.
        val emptyStruct = TlvWriter().startStructure(AnonymousTag).endStructure().getEncoded()
        val element = InvokeElement.newInstance(endpoint, OnOff.ID, cmdId, emptyStruct, null)
        invoke(context, ptr, element)
        Log.d(TAG, "OnOff ${if (on) "On" else "Off"} → nodeId=$nodeId ep=$endpoint")
    }

    /** Reads the OnOff attribute from [nodeId]. Returns `false` on any error. */
    suspend fun readOnOff(
        context:  Context,
        nodeId:   Long,
        endpoint: Int = 1,
    ): Boolean {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(endpoint, OnOff.ID, OnOff.Attribute.OnOff.id)
        return suspendCancellableCoroutine { cont ->
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "readOnOff error", ex)
                        cont.resumeWithException(ex)
                    }
                    override fun onReport(state: NodeState?) {
                        val tlv = state
                            ?.getEndpointState(endpoint)
                            ?.getClusterState(OnOff.ID)
                            ?.getAttributeState(OnOff.Attribute.OnOff.id)
                            ?.tlv
                        val value = tlv?.let { TlvReader(it).getBool(AnonymousTag) } ?: false
                        Log.d(TAG, "readOnOff → $value (nodeId=$nodeId)")
                        if (cont.isActive) cont.resume(value)
                    }
                },
                ptr, listOf(path), null, false, 0,
            )
        }
    }
}
