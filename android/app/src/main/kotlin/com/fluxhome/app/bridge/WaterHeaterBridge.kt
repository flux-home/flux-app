package com.fluxhome.app.bridge

import com.fluxhome.app.chip.clusters.WaterHeaterCluster
import io.flutter.plugin.common.MethodChannel

/** Water Heater Management cluster — temperature, boost control, tank state. */
class WaterHeaterBridge(private val core: BridgeCore) {

    /**
     * Reads the full water heater state (Thermostat + WaterHeaterManagement clusters).
     *
     * Null values are encoded as sentinel integers so MethodChannel can transmit them
     * in a Map<String,Int>:
     *   - Temperature centidegrees use Int.MIN_VALUE (-2147483648) for "not present".
     *   - tankPercentHeat uses -1 for "not reported".
     *   - heatDemand / boostState use 0 as the safe default (not heating / inactive).
     */
    fun readWaterHeater(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val data = WaterHeaterCluster.readWaterHeater(core.context, nodeId)
            core.main.post {
                result.success(mapOf(
                    "localTemp"       to (data["localTemp"]       ?: Int.MIN_VALUE),
                    "heatingSetpoint" to (data["heatingSetpoint"] ?: Int.MIN_VALUE),
                    "minHeatSetpt"    to (data["minHeatSetpt"]    ?: Int.MIN_VALUE),
                    "maxHeatSetpt"    to (data["maxHeatSetpt"]    ?: Int.MIN_VALUE),
                    "tankPercentHeat" to (data["tankPercentHeat"] ?: -1),
                    "heatDemand"      to (data["heatDemand"]      ?: 0),
                    "boostState"      to (data["boostState"]      ?: 0),
                ))
            }
        }

    /**
     * Toggles the boost mode.
     * [enable] = true  → sends Boost command with [durationSeconds] (default 3600 = 1 h).
     * [enable] = false → sends CancelBoost.
     */
    fun setBoost(
        nodeId: Long,
        enable: Boolean,
        durationSeconds: Int,
        result: MethodChannel.Result,
    ) = core.requireChip(result) {
        if (enable) {
            WaterHeaterCluster.boost(core.context, nodeId, durationSeconds)
        } else {
            WaterHeaterCluster.cancelBoost(core.context, nodeId)
        }
        core.main.post { result.success(true) }
    }
}
