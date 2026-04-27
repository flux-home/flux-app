package com.fluxhome.app.bridge

import com.fluxhome.app.chip.clusters.SensorCluster
import io.flutter.plugin.common.MethodChannel

/**
 * Sensor measurement clusters — humidity, battery, and future Matter 1.4
 * sensors (temperature, pressure, flow, occupancy, contact, air quality, etc.).
 */
class SensorBridge(private val core: BridgeCore) {

    fun readHumidity(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val centi = SensorCluster.readHumidity(core.context, nodeId)
            core.main.post { result.success(centi) }
        }

    fun readBattery(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val data = SensorCluster.readBattery(core.context, nodeId)
            // Pass null when cluster was absent (empty map), else the attribute map
            core.main.post { result.success(if (data.isEmpty()) null else data) }
        }
}
