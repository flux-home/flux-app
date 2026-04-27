package com.fluxhome.app.bridge

import android.util.Log
import com.fluxhome.app.chip.NetworkDiagnosticsRunner
import com.fluxhome.app.chip.clusters.ClusterInspector
import com.fluxhome.app.chip.clusters.ThreadDiagCluster
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

class DiagnosticsBridge(private val core: BridgeCore) {

    fun runNetworkDiagnostics(result: MethodChannel.Result) {
        core.scope.launch {
            try {
                val report = NetworkDiagnosticsRunner.run(core.context)
                val json   = buildDiagnosticsJson(report)
                core.main.post { result.success(json) }
            } catch (e: Exception) {
                Log.e(TAG, "runNetworkDiagnostics error", e)
                core.main.post { result.error("DIAGNOSTICS_ERROR", e.message, null) }
            }
        }
    }

    fun readThreadNetworkDiagnostics(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val json = ThreadDiagCluster.readThreadNetworkDiagnostics(core.context, nodeId)
            core.main.post {
                if (json != null) result.success(json)
                else result.error("CLUSTER_ABSENT",
                    "ThreadNetworkDiagnostics cluster not found on this device", null)
            }
        }

    fun readClusters(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val json = ClusterInspector.readAllClusters(core.context, nodeId)
            core.main.post { result.success(json) }
        }

    private fun buildDiagnosticsJson(r: NetworkDiagnosticsRunner.DiagnosticsReport): String {
        val borderRouters = JSONArray()
        for (br in r.borderRouters) {
            val brObj = JSONObject()
                .put("serviceName",  br.serviceName)
                .put("networkName",  br.networkName)
                .put("extPanId",     br.extPanId)
                .put("vendorName",   br.vendorName)
                .put("modelName",    br.modelName)
                .put("port",         br.port)
                .put("hostsV4",            JSONArray(br.hostsV4))
                .put("hostsV6LinkLocal",   JSONArray(br.hostsV6LinkLocal))
                .put("hostsV6Ula",         JSONArray(br.hostsV6Ula))
                .put("hostsV6Gua",         JSONArray(br.hostsV6Gua))
                .put("tcpReachable",           br.tcpReachable)
                .put("sameSubnetAsPhone",      br.sameSubnetAsPhone)
                .put("ipv6PrefixMatchesPhone", br.ipv6PrefixMatchesPhone)
            if (br.stateBitmap != null) {
                val bm = br.stateBitmap
                brObj.put("stateBitmap", JSONObject()
                    .put("raw",                    bm.raw)
                    .put("connectionMode",         bm.connectionMode)
                    .put("connectionModeLabel",    bm.connectionModeLabel)
                    .put("threadInterfaceStatus",  bm.threadInterfaceStatus)
                    .put("threadInterfaceLabel",   bm.threadInterfaceLabel)
                    .put("threadInterfaceActive",  bm.threadInterfaceActive)
                    .put("availability",           bm.availability)
                    .put("bbrActive",              bm.bbrActive)
                    .put("bbrIsPrimary",           bm.bbrIsPrimary))
            } else {
                brObj.put("stateBitmap", JSONObject.NULL)
            }
            borderRouters.put(brObj)
        }

        return JSONObject()
            .put("phoneIpv6", JSONObject()
                .put("hasRoutableIpv6",    r.phoneIpv6.hasRoutableIpv6)
                .put("guaAddresses",       JSONArray(r.phoneIpv6.guaAddresses))
                .put("ulaAddresses",       JSONArray(r.phoneIpv6.ulaAddresses))
                .put("linkLocalAddresses", JSONArray(r.phoneIpv6.linkLocalAddresses)))
            .put("multicastLockAcquired", r.multicastLockAcquired)
            .put("wifi", JSONObject()
                .put("frequencyMhz", r.wifi.frequencyMhz)
                .put("band",         r.wifi.band)
                .put("ssid",         r.wifi.ssid)
                .put("hasBandSuffix", r.wifi.hasBandSuffix))
            .put("vpn", JSONObject()
                .put("isActive", r.vpn.isActive))
            .put("borderRouters",     borderRouters)
            .put("matterTcpServices", JSONArray(r.matterTcpServices))
            .toString()
    }

    companion object {
        private const val TAG = "DiagnosticsBridge"
    }
}
