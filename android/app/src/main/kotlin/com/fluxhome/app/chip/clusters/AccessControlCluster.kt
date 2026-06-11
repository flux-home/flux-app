package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.model.AttributeWriteRequest
import chip.devicecontroller.model.ChipAttributePath
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.NullValue
import matter.tlv.TlvReader
import matter.tlv.TlvWriter

internal object AccessControlCluster {
    private const val TAG        = "AccessControlCluster"
    private const val CLUSTER_ID = 0x001FL
    private const val ATTR_ACL   = 0x0000L

    private val ACL_PATH = ChipAttributePath.newInstance(0, CLUSTER_ID, ATTR_ACL)

    // Grants all fabric members (subjects=null) Administer access via CASE on all
    // endpoints (targets=null).  With a single-controller fabric this is equivalent
    // to explicitly granting Node 0x0002, and is simpler to encode.
    suspend fun grantControllerAccess(context: Context, nodeId: Long) {
        val tlv = buildAclTlv()
        val req = AttributeWriteRequest.newInstance(0, CLUSTER_ID, ATTR_ACL, tlv)
        writeAttribute(context, nodeId, req, TAG)
        Log.i(TAG, "ACL written for nodeId=0x%016X".format(nodeId))
    }

    /** Reads and returns all ACL entries as a human-readable string, also logged at INFO. */
    suspend fun readAcl(context: Context, nodeId: Long): String =
        readAttributes(context, nodeId, ACL_PATH, "[]", TAG) { state ->
            val tlv = state
                ?.getEndpointState(0)
                ?.getClusterState(CLUSTER_ID)
                ?.getAttributeState(ATTR_ACL)
                ?.tlv ?: return@readAttributes "[]"
            parseAclEntries(tlv).also {
                Log.i(TAG, "ACL for nodeId=0x%016X: $it".format(nodeId))
            }
        }

    private fun parseAclEntries(tlv: ByteArray): String {
        val entries = mutableListOf<String>()
        try {
            val r = TlvReader(tlv)
            r.enterArray(AnonymousTag)
            while (!r.isEndOfContainer()) {
                r.enterStructure(AnonymousTag)
                var privilege    = -1
                var authMode     = -1
                val subjects     = mutableListOf<Long>()
                var subjectsNull = false
                var targetsNull  = false
                var fabricIndex  = -1

                while (!r.isEndOfContainer()) {
                    when (val tag = r.peekElement().tag) {
                        ContextSpecificTag(1)    -> privilege   = r.getUInt(tag).toInt()
                        ContextSpecificTag(2)    -> authMode    = r.getUInt(tag).toInt()
                        ContextSpecificTag(3)    -> {
                            if (r.peekElement().value is NullValue) {
                                r.skipElement(); subjectsNull = true
                            } else {
                                r.enterArray(tag)
                                while (!r.isEndOfContainer()) subjects += r.getULong(AnonymousTag).toLong()
                                r.exitContainer()
                            }
                        }
                        ContextSpecificTag(4)    -> {
                            if (r.peekElement().value is NullValue) {
                                r.skipElement(); targetsNull = true
                            } else {
                                r.enterArray(tag)
                                while (!r.isEndOfContainer()) r.skipElement()
                                r.exitContainer()
                                targetsNull = false
                            }
                        }
                        ContextSpecificTag(0xFE) -> fabricIndex = r.getUInt(tag).toInt()
                        else                     -> r.skipElement()
                    }
                }
                r.exitContainer()

                val privLabel = when (privilege) {
                    1 -> "View"; 2 -> "ProxyView"; 3 -> "Operate"
                    4 -> "Manage"; 5 -> "Administer"; else -> "priv=$privilege"
                }
                val authLabel = when (authMode) {
                    1 -> "PASE"; 2 -> "CASE"; 3 -> "Group"; else -> "auth=$authMode"
                }
                val subjLabel = if (subjectsNull) "all" else subjects.map { "0x%016X".format(it) }.toString()
                val tgtLabel  = if (targetsNull)  "all" else "..."
                entries += "{fabric=$fabricIndex, $privLabel/$authLabel, subjects=$subjLabel, targets=$tgtLabel}"
            }
            r.exitContainer()
        } catch (ex: Exception) {
            Log.w(TAG, "parseAclEntries error: ${ex.message}")
        }
        return entries.toString()
    }

    private fun buildAclTlv(): ByteArray {
        val w = TlvWriter()
        w.startArray(AnonymousTag)
        w.startStructure(AnonymousTag)
        w.put(ContextSpecificTag(1), 5u)   // privilege = Administer
        w.put(ContextSpecificTag(2), 2u)   // authMode = CASE
        w.putNull(ContextSpecificTag(3))   // subjects = null → all fabric members
        w.putNull(ContextSpecificTag(4))   // targets  = null → all endpoints
        w.endStructure()
        w.endArray()
        return w.getEncoded()
    }
}
