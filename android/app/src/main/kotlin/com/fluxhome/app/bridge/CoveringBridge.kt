package com.fluxhome.app.bridge

import com.fluxhome.app.chip.clusters.WindowCoveringCluster
import io.flutter.plugin.common.MethodChannel

/** WindowCovering cluster — blinds, shades, and curtains. */
class CoveringBridge(private val core: BridgeCore) {

    fun coveringUp(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            WindowCoveringCluster.upOrOpen(core.context, nodeId)
            core.main.post { result.success(true) }
        }

    fun coveringDown(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            WindowCoveringCluster.downOrClose(core.context, nodeId)
            core.main.post { result.success(true) }
        }

    fun coveringStop(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            WindowCoveringCluster.stopMotion(core.context, nodeId)
            core.main.post { result.success(true) }
        }

    fun coveringGoToLift(nodeId: Long, percent100ths: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            WindowCoveringCluster.goToLiftPercentage(core.context, nodeId, percent100ths)
            core.main.post { result.success(true) }
        }
}
