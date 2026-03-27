package com.example.matter_home.chip.clusters

import com.example.matter_home.chip.ChipClient

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.ThreadNetworkDiagnostics
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.ChipPathId
import chip.devicecontroller.model.NodeState
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvReader
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "ThreadDiagCluster"

internal object ThreadDiagCluster {

    private val ROUTING_ROLE_LABELS = mapOf(
        0 to "Unspecified", 1 to "Unassigned", 2 to "Sleepy End Device",
        3 to "End Device",  4 to "REED",        5 to "Router", 6 to "Leader",
    )

    /**
     * Reads the Thread Network Diagnostics cluster (0x0035) from endpoint 0.
     *
     * Returns a JSON string with channel, routingRole, networkName, panId,
     * extendedPanId, meshLocalPrefix, partitionId, weighting, leaderRouterId,
     * and the neighbor / route tables.
     *
     * Returns `null` when the cluster is absent (Wi-Fi / Ethernet device).
     */
    suspend fun readThreadNetworkDiagnostics(context: Context, nodeId: Long): String? {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            ChipPathId.forId(0),
            ChipPathId.forId(ThreadNetworkDiagnostics.ID),
            ChipPathId.forWildcard(),
        )
        return suspendCancellableCoroutine { cont ->
            var lastState: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.w(TAG, "ThreadNetworkDiagnostics not available: ${ex.message}")
                        if (cont.isActive) cont.resume(null)
                    }
                    override fun onReport(state: NodeState?) { if (state != null) lastState = state }
                    override fun onDone() {
                        val cluster = lastState?.getEndpointState(0)
                            ?.getClusterState(ThreadNetworkDiagnostics.ID)
                        if (cluster == null) {
                            Log.w(TAG, "ThreadNetworkDiagnostics cluster absent on ep0")
                            if (cont.isActive) cont.resume(null)
                            return
                        }
                        fun int(id: Long)  = cluster.getAttributeState(id)?.getValue()
                            ?.let { (it as? Number)?.toInt() }
                        fun long(id: Long) = cluster.getAttributeState(id)?.getValue()
                            ?.let { (it as? Number)?.toLong() }

                        val json = buildJson(
                            channel         = int(ThreadNetworkDiagnostics.Attribute.Channel.id),
                            routingRole     = int(ThreadNetworkDiagnostics.Attribute.RoutingRole.id),
                            networkName     = cluster.getAttributeState(
                                ThreadNetworkDiagnostics.Attribute.NetworkName.id)?.getValue() as? String,
                            panId           = int(ThreadNetworkDiagnostics.Attribute.PanId.id),
                            extendedPanId   = long(ThreadNetworkDiagnostics.Attribute.ExtendedPanId.id)
                                ?.let { "%016x".format(it) },
                            meshLocalPrefix = cluster.getAttributeState(
                                ThreadNetworkDiagnostics.Attribute.MeshLocalPrefix.id)
                                ?.tlv?.let { parseMeshLocalPrefix(it) },
                            partitionId     = long(ThreadNetworkDiagnostics.Attribute.PartitionId.id),
                            weighting       = int(ThreadNetworkDiagnostics.Attribute.Weighting.id),
                            leaderRouterId  = int(ThreadNetworkDiagnostics.Attribute.LeaderRouterId.id),
                            neighbors       = cluster.getAttributeState(
                                ThreadNetworkDiagnostics.Attribute.NeighborTable.id)
                                ?.tlv?.let { parseNeighborTable(it) } ?: emptyList(),
                            routes          = cluster.getAttributeState(
                                ThreadNetworkDiagnostics.Attribute.RouteTable.id)
                                ?.tlv?.let { parseRouteTable(it) } ?: emptyList(),
                        )
                        Log.d(TAG, "ThreadNetworkDiagnostics OK")
                        if (cont.isActive) cont.resume(json)
                    }
                },
                ptr, listOf(path), null, false, 0,
            )
        }
    }

    // ── TLV parsers ───────────────────────────────────────────────────────────

    private fun parseMeshLocalPrefix(tlv: ByteArray): String? {
        val bytes = try { TlvReader(tlv).getByteArray(AnonymousTag) } catch (_: Exception) { return null }
        if (bytes.size < 8) return null
        return "%02x%02x:%02x%02x:%02x%02x:%02x%02x::/64".format(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
        )
    }

    /**
     * Parses the NeighborTable list TLV.
     * NeighborTableStruct field tags (Matter spec §11.13.5.1):
     *   0=extAddress(uint64) 1=age(uint32) 2=eid 3=rloc16 4=linkFrameCounter
     *   5=mleFrameCounter 6=lqi(uint8) 7=averageRssi(nullable int8)
     *   8=lastRssi(nullable int8) 9=frameErrorRate 10=messageErrorRate
     *   11=rxOnWhenIdle 12=fullThreadDevice 13=fullNetworkData 14=isChild
     */
    private fun parseNeighborTable(tlv: ByteArray): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        try {
            val r = TlvReader(tlv)
            r.enterArray(AnonymousTag)
            while (!r.isEndOfContainer()) {
                try {
                    r.enterStructure(AnonymousTag)
                    val m = mutableMapOf<String, Any?>()
                    fun ulong(t: Int)  = try { r.getULong(ContextSpecificTag(t)).toLong() } catch (_: Exception) { null }
                    fun uint(t: Int)   = try { r.getUInt(ContextSpecificTag(t)).toInt()   } catch (_: Exception) { null }
                    fun bool(t: Int)   = try { r.getBool(ContextSpecificTag(t))            } catch (_: Exception) { null }
                    fun int8(t: Int)   = try { r.getByte(ContextSpecificTag(t)).toInt()    } catch (_: Exception) { null }

                    m["extAddress"]       = ulong(0)?.let { "%016x".format(it) }
                    m["age"]              = ulong(1)
                    ulong(2)                                 // eid — advance only
                    m["rloc16"]           = uint(3)
                    ulong(4); ulong(5)                       // frame/mle counters — advance only
                    m["lqi"]              = uint(6)
                    m["averageRssi"]      = int8(7)
                    m["lastRssi"]         = int8(8)
                    m["frameErrorRate"]   = uint(9)
                    m["messageErrorRate"] = uint(10)
                    m["rxOnWhenIdle"]     = bool(11)
                    m["fullThreadDevice"] = bool(12)
                    bool(13)                                 // fullNetworkData — advance only
                    m["isChild"]          = bool(14)

                    while (!r.isEndOfContainer()) r.skipElement()
                    r.exitContainer()
                    result.add(m)
                } catch (e: Exception) {
                    Log.w(TAG, "Skip malformed neighbor entry: ${e.message}")
                    try { while (!r.isEndOfContainer()) r.skipElement(); r.exitContainer() }
                    catch (_: Exception) { break }
                }
            }
            r.exitContainer()
        } catch (e: Exception) {
            Log.w(TAG, "parseNeighborTable error: ${e.message}")
        }
        return result
    }

    /**
     * Parses the RouteTable list TLV.
     * RouteTableStruct field tags (Matter spec §11.13.5.2):
     *   0=extAddress(uint64) 1=eid 2=rloc16 3=routerId 4=nextHop
     *   5=pathCost 6=LQIIn 7=LQIOut 8=age 9=allocated 10=linkEstablished
     */
    private fun parseRouteTable(tlv: ByteArray): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        try {
            val r = TlvReader(tlv)
            r.enterArray(AnonymousTag)
            while (!r.isEndOfContainer()) {
                try {
                    r.enterStructure(AnonymousTag)
                    val m = mutableMapOf<String, Any?>()
                    fun ulong(t: Int) = try { r.getULong(ContextSpecificTag(t)).toLong() } catch (_: Exception) { null }
                    fun uint(t: Int)  = try { r.getUInt(ContextSpecificTag(t)).toInt()   } catch (_: Exception) { null }
                    fun bool(t: Int)  = try { r.getBool(ContextSpecificTag(t))            } catch (_: Exception) { null }

                    ulong(0); uint(1)              // extAddress, eid — advance only
                    m["rloc16"]          = uint(2)
                    m["routerId"]        = uint(3)
                    m["nextHop"]         = uint(4)
                    m["pathCost"]        = uint(5)
                    m["lqiIn"]           = uint(6)
                    m["lqiOut"]          = uint(7)
                    m["age"]             = uint(8)
                    m["allocated"]       = bool(9)
                    m["linkEstablished"] = bool(10)

                    while (!r.isEndOfContainer()) r.skipElement()
                    r.exitContainer()
                    result.add(m)
                } catch (e: Exception) {
                    Log.w(TAG, "Skip malformed route entry: ${e.message}")
                    try { while (!r.isEndOfContainer()) r.skipElement(); r.exitContainer() }
                    catch (_: Exception) { break }
                }
            }
            r.exitContainer()
        } catch (e: Exception) {
            Log.w(TAG, "parseRouteTable error: ${e.message}")
        }
        return result
    }

    // ── JSON builder ──────────────────────────────────────────────────────────

    private fun buildJson(
        channel:         Int?,
        routingRole:     Int?,
        networkName:     String?,
        panId:           Int?,
        extendedPanId:   String?,
        meshLocalPrefix: String?,
        partitionId:     Long?,
        weighting:       Int?,
        leaderRouterId:  Int?,
        neighbors:       List<Map<String, Any?>>,
        routes:          List<Map<String, Any?>>,
    ): String {
        val sb = StringBuilder("{")
        fun opt(k: String, v: Any?)  { sb.append("\"$k\":${toJsonValue(v)},") }
        fun str(k: String, v: String?) { sb.append("\"$k\":${if (v != null) "\"${jsonEscape(v)}\"" else "null"},") }

        opt("channel", channel)
        opt("routingRole", routingRole)
        sb.append("\"routingRoleLabel\":\"${ROUTING_ROLE_LABELS[routingRole] ?: "Unknown"}\",")
        str("networkName", networkName)
        opt("panId", panId)
        str("extendedPanId", extendedPanId)
        str("meshLocalPrefix", meshLocalPrefix)
        opt("partitionId", partitionId)
        opt("weighting", weighting)
        opt("leaderRouterId", leaderRouterId)

        sb.append("\"neighbors\":[")
        neighbors.forEachIndexed { i, n ->
            if (i > 0) sb.append(",")
            sb.append("{")
            val keys = listOf("extAddress","age","rloc16","lqi","averageRssi","lastRssi",
                              "frameErrorRate","messageErrorRate","rxOnWhenIdle",
                              "fullThreadDevice","isChild")
            keys.forEachIndexed { j, k ->
                if (j > 0) sb.append(",")
                sb.append("\"$k\":${toJsonValue(n[k])}")
            }
            sb.append("}")
        }
        sb.append("],\"routes\":[")
        routes.forEachIndexed { i, r ->
            if (i > 0) sb.append(",")
            sb.append("{")
            val keys = listOf("rloc16","routerId","nextHop","pathCost",
                              "lqiIn","lqiOut","age","allocated","linkEstablished")
            keys.forEachIndexed { j, k ->
                if (j > 0) sb.append(",")
                sb.append("\"$k\":${toJsonValue(r[k])}")
            }
            sb.append("}")
        }
        sb.append("]}")
        return sb.toString()
    }

    private fun toJsonValue(v: Any?): String = when (v) {
        null       -> "null"
        is Boolean -> v.toString()
        is Number  -> v.toString()
        is String  -> "\"${jsonEscape(v)}\""
        else       -> "null"
    }
}
