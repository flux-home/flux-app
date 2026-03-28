package com.example.matter_home.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.Descriptor
import chip.devicecontroller.model.ChipAttributePath
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvReader

private const val TAG = "DescriptorCluster"

internal object DescriptorCluster {

    /** Reads all device-type IDs from the DeviceTypeList attribute on [endpoint]. */
    suspend fun readDeviceTypes(context: Context, nodeId: Long, endpoint: Int = 0): List<Int> =
        readAttributes(
            context, nodeId,
            ChipAttributePath.newInstance(endpoint, Descriptor.ID, Descriptor.Attribute.DeviceTypeList.id),
            emptyList(), TAG,
        ) { state ->
            state?.getEndpointState(endpoint)
                ?.getClusterState(Descriptor.ID)
                ?.getAttributeState(Descriptor.Attribute.DeviceTypeList.id)
                ?.tlv?.let { parseDeviceTypeList(it) }
                ?: emptyList()
        }

    /** Reads the ServerList (server-side cluster IDs) from the Descriptor cluster on [endpoint]. */
    suspend fun readServerClusterList(context: Context, nodeId: Long, endpoint: Int = 0): List<Long> =
        readAttributes(
            context, nodeId,
            ChipAttributePath.newInstance(endpoint, Descriptor.ID, Descriptor.Attribute.ServerList.id),
            emptyList(), TAG,
        ) { state ->
            val tlv = state?.getEndpointState(endpoint)
                ?.getClusterState(Descriptor.ID)
                ?.getAttributeState(Descriptor.Attribute.ServerList.id)?.tlv
                ?: return@readAttributes emptyList()
            mutableListOf<Long>().also { ids ->
                try {
                    val r = TlvReader(tlv)
                    r.enterArray(AnonymousTag)
                    while (!r.isEndOfContainer()) ids.add(r.getULong(AnonymousTag).toLong())
                    r.exitContainer()
                } catch (ex: Exception) { Log.w(TAG, "ServerList parse error: ${ex.message}") }
                Log.d(TAG, "ServerList ep=$endpoint: $ids")
            }
        }

    /** Reads the PartsList from EP0 — the list of non-root endpoint numbers. */
    suspend fun readPartsList(context: Context, nodeId: Long): List<Int> =
        readAttributes(
            context, nodeId,
            ChipAttributePath.newInstance(0, Descriptor.ID, Descriptor.Attribute.PartsList.id),
            emptyList(), TAG,
        ) { state ->
            val tlv = state?.getEndpointState(0)
                ?.getClusterState(Descriptor.ID)
                ?.getAttributeState(Descriptor.Attribute.PartsList.id)?.tlv
                ?: return@readAttributes emptyList()
            mutableListOf<Int>().also { eps ->
                try {
                    val r = TlvReader(tlv)
                    r.enterArray(AnonymousTag)
                    while (!r.isEndOfContainer()) eps.add(r.getUInt(AnonymousTag).toInt())
                    r.exitContainer()
                } catch (ex: Exception) { Log.w(TAG, "PartsList parse error: ${ex.message}") }
                Log.d(TAG, "PartsList: $eps (nodeId=$nodeId)")
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
        } catch (e: Exception) { Log.w(TAG, "parseDeviceTypeList error: ${e.message}") }
        return types
    }
}
