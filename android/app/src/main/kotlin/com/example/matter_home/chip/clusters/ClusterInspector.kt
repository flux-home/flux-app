package com.example.matter_home.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.Descriptor
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.ChipPathId
import com.example.matter_home.chip.ChipClient

private const val TAG = "ClusterInspector"

internal object ClusterInspector {

    /**
     * Reads ALL attributes from ALL clusters on ALL endpoints via wildcard path.
     * Returns a JSON string shaped as:
     *
     * ```json
     * [ { "endpoint": 0, "clusterId": 40,
     *     "deviceTypes": [256],
     *     "attributes": [ { "id": 1, "value": "tado GmbH" }, … ] }, … ]
     * ```
     *
     * `deviceTypes` is only present on Descriptor-cluster entries.
     */
    suspend fun readAllClusters(context: Context, nodeId: Long): String =
        readAttributes(
            context, nodeId,
            ChipAttributePath.newInstance(
                ChipPathId.forWildcard(), ChipPathId.forWildcard(), ChipPathId.forWildcard(),
            ),
            "[]", TAG,
        ) { state -> buildJson(state) }

    private fun buildJson(state: chip.devicecontroller.model.NodeState?): String {
        if (state == null) return "[]"
        val sb = StringBuilder("[")
        var first = true
        try {
            state.getEndpointStates().forEach { (epId, epState) ->
                epState.getClusterStates().forEach { (clusterId, clusterState) ->
                    if (!first) sb.append(",")
                    first = false
                    sb.append("{\"endpoint\":$epId,\"clusterId\":$clusterId")

                    // Embed device-type IDs for Descriptor cluster entries.
                    if (clusterId == Descriptor.ID) {
                        val types = clusterState
                            .getAttributeState(Descriptor.Attribute.DeviceTypeList.id)?.tlv
                            ?.let { DescriptorCluster.parseDeviceTypeList(it) }
                            ?: emptyList()
                        sb.append(",\"deviceTypes\":[${types.joinToString(",")}]")
                    }

                    sb.append(",\"attributes\":[")
                    var firstAttr = true
                    clusterState.getAttributeStates().forEach { (attrId, attrState) ->
                        if (!firstAttr) sb.append(",")
                        firstAttr = false
                        val raw = try {
                            when (val v = attrState.getValue()) {
                                null       -> "null"
                                is Boolean -> v.toString()
                                is Number  -> v.toString()
                                else       -> "\"${jsonEscape(v.toString())}\""
                            }
                        } catch (_: Exception) { "\"?\"" }
                        sb.append("{\"id\":$attrId,\"value\":$raw}")
                    }
                    sb.append("]}")
                }
            }
        } catch (e: Exception) { Log.e(TAG, "buildJson error", e) }
        sb.append("]")
        return sb.toString()
    }
}
