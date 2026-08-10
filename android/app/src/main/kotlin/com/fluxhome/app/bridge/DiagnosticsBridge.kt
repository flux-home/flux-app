package com.fluxhome.app.bridge

import com.fluxhome.app.chip.clusters.ClusterInspector
import io.flutter.plugin.common.MethodChannel

class DiagnosticsBridge(private val core: BridgeCore) {


    fun readClusters(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val json = ClusterInspector.readAllClusters(core.context, nodeId)
            core.main.post { result.success(json) }
        }

    companion object {
        private const val TAG = "DiagnosticsBridge"
    }
}
