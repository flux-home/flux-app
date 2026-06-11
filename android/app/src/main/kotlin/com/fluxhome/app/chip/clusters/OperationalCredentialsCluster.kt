package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.OperationalCredentials
import chip.devicecontroller.model.ChipAttributePath
import com.fluxhome.app.chip.ChipClient
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvReader

private const val TAG = "OpCredCluster"

data class FabricDescriptor(
    val fabricIndex: Int,
    val fabricId:    Long,   // hex-formatted on display
    val nodeId:      Long,
    val vendorId:    Int,
    val label:       String,
)

internal object OperationalCredentialsCluster {

    // Endpoint 0, cluster 0x003E, attribute 0x0001 (Fabrics)
    private val FABRICS_PATH = ChipAttributePath.newInstance(
        0, OperationalCredentials.ID, OperationalCredentials.Attribute.Fabrics.id,
    )

    /**
     * Reads the Fabrics attribute with fabricFiltered=false so all commissioned
     * fabrics are returned (not just the one for our CASE session).
     */
    suspend fun readFabrics(context: Context, nodeId: Long): List<FabricDescriptor> =
        readAttributes(context, nodeId, FABRICS_PATH, emptyList(), TAG) { state ->
            parseFabrics(state)
        }

    private fun parseFabrics(state: chip.devicecontroller.model.NodeState?): List<FabricDescriptor> {
        val tlv = state
            ?.getEndpointState(0)
            ?.getClusterState(OperationalCredentials.ID)
            ?.getAttributeState(OperationalCredentials.Attribute.Fabrics.id)
            ?.tlv ?: return emptyList()

        val result = mutableListOf<FabricDescriptor>()
        try {
            val r = TlvReader(tlv)
            r.enterArray(AnonymousTag)
            while (!r.isEndOfContainer()) {
                r.enterStructure(AnonymousTag)
                var rootPublicKeyRead = false
                var vendorId    = 0
                var fabricId    = 0L
                var nodeId      = 0L
                var label       = ""
                var fabricIndex = 0

                while (!r.isEndOfContainer()) {
                    val tag = r.peekElement().tag
                    when {
                        tag == ContextSpecificTag(1) -> {
                            r.getByteArray(tag) // rootPublicKey — skip
                            rootPublicKeyRead = true
                        }
                        tag == ContextSpecificTag(2) -> vendorId    = r.getUInt(tag).toInt()
                        tag == ContextSpecificTag(3) -> fabricId    = r.getULong(tag).toLong()
                        tag == ContextSpecificTag(4) -> nodeId      = r.getULong(tag).toLong()
                        tag == ContextSpecificTag(5) -> label       = r.getString(tag)
                        tag == ContextSpecificTag(0xFE) -> fabricIndex = r.getUInt(tag).toInt()
                        else -> r.skipElement()
                    }
                }
                r.exitContainer()
                result += FabricDescriptor(fabricIndex, fabricId, nodeId, vendorId, label)
            }
            r.exitContainer()
        } catch (ex: Exception) {
            Log.w(TAG, "parseFabrics error: ${ex.message}")
        }
        Log.d(TAG, "readFabrics → $result")
        return result
    }
}
