package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.OperationalCredentials
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.InvokeElement
import com.fluxhome.app.chip.ChipClient
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvReader
import matter.tlv.TlvWriter

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

    // RemoveFabric command (0x0A): field 0 = FabricIndex (uint8).
    private const val FIELD_FABRIC_INDEX = 0x00

    /**
     * Removes the fabric at [fabricIndex] from [nodeId] (OperationalCredentials
     * RemoveFabric).  In the multi-admin handoff the phone calls this on its OWN
     * throwaway fabric index once the controller fabric is confirmed present, so
     * the device ends up on the controller fabric only.
     */
    suspend fun removeFabric(context: Context, nodeId: Long, fabricIndex: Int) {
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(FIELD_FABRIC_INDEX), fabricIndex.toUByte())
            .endStructure()
            .getEncoded()
        invoke(context, nodeId, InvokeElement.newInstance(
            0, OperationalCredentials.ID, OperationalCredentials.Command.RemoveFabric.id, tlv, null,
        ))
        Log.i(TAG, "RemoveFabric idx=$fabricIndex → nodeId=0x%016X".format(nodeId))
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
