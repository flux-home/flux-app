package com.fluxhome.app.bridge

import com.fluxhome.app.chip.clusters.ColorControlCluster
import io.flutter.plugin.common.MethodChannel

/** ColorControl cluster — color temperature, hue, and saturation. */
class ColorBridge(private val core: BridgeCore) {

    fun setColorTemperature(nodeId: Long, mireds: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            ColorControlCluster.moveToColorTemperature(core.context, nodeId, mireds)
            core.main.post { result.success(true) }
        }
}
