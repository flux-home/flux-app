package com.fluxhome.app.bridge

import com.fluxhome.app.chip.clusters.FanControlCluster
import io.flutter.plugin.common.MethodChannel

/** FanControl cluster — fans and fan-capable air treatment devices. */
class FanBridge(private val core: BridgeCore) {

    fun setFanMode(nodeId: Long, mode: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            FanControlCluster.writeFanMode(core.context, nodeId, mode)
            core.main.post { result.success(true) }
        }

    fun setFanPercent(nodeId: Long, percent: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            FanControlCluster.writePercentSetting(core.context, nodeId, percent)
            core.main.post { result.success(true) }
        }
}
