package com.example.matter_home.chip.clusters

import com.example.matter_home.chip.ChipClient

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.Descriptor
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.NodeState
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvReader
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "DescriptorCluster"

internal object DescriptorCluster {

    /**
     * Reads the DeviceTypeList attribute (0x0000) from the Descriptor cluster
     * on [endpoint] and returns all device-type IDs advertised there.
     * Returns an empty list on any error.
     */
    suspend fun readDeviceTypes(
        context:  Context,
        nodeId:   Long,
        endpoint: Int = 0,
    ): List<Int> {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            endpoint, Descriptor.ID, Descriptor.Attribute.DeviceTypeList.id,
        )
        return suspendCancellableCoroutine { cont ->
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "readDeviceTypes error", ex)
                        if (cont.isActive) cont.resume(emptyList())
                    }
                    override fun onReport(state: NodeState?) {
                        val tlv = state
                            ?.getEndpointState(endpoint)
                            ?.getClusterState(Descriptor.ID)
                            ?.getAttributeState(Descriptor.Attribute.DeviceTypeList.id)
                            ?.tlv
                        if (tlv == null) { if (cont.isActive) cont.resume(emptyList()); return }
                        if (cont.isActive) cont.resume(parseDeviceTypeList(tlv))
                    }
                },
                ptr, listOf(path), null, false, 0,
            )
        }
    }

    /**
     * Reads the ServerList attribute (0x0001) from the Descriptor cluster on
     * [endpoint] and returns the server-side cluster IDs present there.
     */
    suspend fun readServerClusterList(
        context:  Context,
        nodeId:   Long,
        endpoint: Int = 0,
    ): List<Long> {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            endpoint, Descriptor.ID, Descriptor.Attribute.ServerList.id,
        )
        return suspendCancellableCoroutine { cont ->
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.w(TAG, "readServerClusterList error: ${ex.message}")
                        if (cont.isActive) cont.resume(emptyList())
                    }
                    override fun onReport(state: NodeState?) {
                        val tlv = state
                            ?.getEndpointState(endpoint)
                            ?.getClusterState(Descriptor.ID)
                            ?.getAttributeState(Descriptor.Attribute.ServerList.id)
                            ?.tlv
                        if (tlv == null) { if (cont.isActive) cont.resume(emptyList()); return }
                        val ids = mutableListOf<Long>()
                        try {
                            val r = TlvReader(tlv)
                            r.enterArray(AnonymousTag)
                            while (!r.isEndOfContainer()) ids.add(r.getULong(AnonymousTag).toLong())
                            r.exitContainer()
                        } catch (ex: Exception) {
                            Log.w(TAG, "readServerClusterList parse error: ${ex.message}")
                        }
                        Log.d(TAG, "ServerList ep=$endpoint: $ids")
                        if (cont.isActive) cont.resume(ids)
                    }
                },
                ptr, listOf(path), null, false, 0,
            )
        }
    }

    /**
     * Reads the PartsList attribute (0x0003) from the Descriptor cluster on EP0
     * and returns the list of non-root endpoint numbers.
     */
    suspend fun readPartsList(context: Context, nodeId: Long): List<Int> {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(0, Descriptor.ID, Descriptor.Attribute.PartsList.id)
        return suspendCancellableCoroutine { cont ->
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.w(TAG, "readPartsList error: ${ex.message}")
                        if (cont.isActive) cont.resume(emptyList())
                    }
                    override fun onReport(state: NodeState?) {
                        val tlv = state?.getEndpointState(0)
                            ?.getClusterState(Descriptor.ID)
                            ?.getAttributeState(Descriptor.Attribute.PartsList.id)
                            ?.tlv
                        if (tlv == null) { if (cont.isActive) cont.resume(emptyList()); return }
                        val eps = mutableListOf<Int>()
                        try {
                            val r = TlvReader(tlv)
                            r.enterArray(AnonymousTag)
                            while (!r.isEndOfContainer()) eps.add(r.getUInt(AnonymousTag).toInt())
                            r.exitContainer()
                        } catch (ex: Exception) {
                            Log.w(TAG, "readPartsList parse error: ${ex.message}")
                        }
                        Log.d(TAG, "PartsList: $eps (nodeId=$nodeId)")
                        if (cont.isActive) cont.resume(eps)
                    }
                },
                ptr, listOf(path), null, false, 0,
            )
        }
    }

    /**
     * Parses a DeviceTypeList TLV (array of DeviceTypeStruct {deviceType:uint32, revision:uint16})
     * and returns the device-type IDs.  Shared with [ClusterInspector].
     */
    internal fun parseDeviceTypeList(tlv: ByteArray): List<Int> {
        val types = mutableListOf<Int>()
        try {
            val r = TlvReader(tlv)
            r.enterArray(AnonymousTag)
            while (!r.isEndOfContainer()) {
                r.enterStructure(AnonymousTag)
                // Must use getULong — device type IDs are uint32; getLong rejects unsigned values
                types.add(r.getULong(ContextSpecificTag(0)).toInt())
                while (!r.isEndOfContainer()) r.skipElement()
                r.exitContainer()
            }
            r.exitContainer()
        } catch (e: Exception) {
            Log.w(TAG, "parseDeviceTypeList error: ${e.message}")
        }
        return types
    }
}
