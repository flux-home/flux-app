package com.example.matter_home.chip.clusters

import com.example.matter_home.chip.ChipClient

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.Descriptor
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.ChipPathId
import chip.devicecontroller.model.NodeState
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "ClusterInspector"

internal object ClusterInspector {

    /**
     * Reads ALL attributes from ALL clusters on ALL endpoints using a wildcard
     * path.  Returns a JSON string shaped as:
     *
     * ```json
     * [ { "endpoint": 0, "clusterId": 40,
     *     "deviceTypes": [256],
     *     "attributes": [ { "id": 1, "value": "tado GmbH" }, … ] }, … ]
     * ```
     *
     * The `deviceTypes` field is only present on Descriptor-cluster entries.
     * [onReport] may be called multiple times with partial data; [onDone] signals
     * completion.
     */
    suspend fun readAllClusters(context: Context, nodeId: Long): String {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            ChipPathId.forWildcard(),
            ChipPathId.forWildcard(),
            ChipPathId.forWildcard(),
        )
        return suspendCancellableCoroutine { cont ->
            var accumulated: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "readAllClusters error", ex)
                        if (cont.isActive) cont.resume("[]")
                    }
                    override fun onReport(state: NodeState?) { if (state != null) accumulated = state }
                    override fun onDone() {
                        if (cont.isActive) cont.resume(buildJson(accumulated))
                    }
                },
                ptr, listOf(path), null, false, 0,
            )
        }
    }

    private fun buildJson(state: NodeState?): String {
        if (state == null) return "[]"
        val sb = StringBuilder("[")
        var firstCluster = true
        try {
            state.getEndpointStates().forEach { (epId, epState) ->
                epState.getClusterStates().forEach { (clusterId, clusterState) ->
                    if (!firstCluster) sb.append(",")
                    firstCluster = false
                    sb.append("{\"endpoint\":$epId,\"clusterId\":$clusterId")

                    // Embed device type list for Descriptor cluster entries.
                    if (clusterId == Descriptor.ID) {
                        val types = clusterState
                            .getAttributeState(Descriptor.Attribute.DeviceTypeList.id)
                            ?.tlv
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
        } catch (e: Exception) {
            Log.e(TAG, "buildJson error", e)
        }
        sb.append("]")
        return sb.toString()
    }
}
