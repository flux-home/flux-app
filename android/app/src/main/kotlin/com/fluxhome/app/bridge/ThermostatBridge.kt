package com.fluxhome.app.bridge

import com.fluxhome.app.chip.clusters.ThermostatCluster
import io.flutter.plugin.common.MethodChannel

/** Thermostat cluster — heating, cooling, and HVAC control. */
class ThermostatBridge(private val core: BridgeCore) {

    fun readThermostat(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val data = ThermostatCluster.readThermostat(core.context, nodeId)
            // MethodChannel can't carry Map<String,Int?> with null values reliably;
            // send as individual keys, using sentinel -32768 for "null / not present".
            core.main.post {
                result.success(mapOf(
                    "localTemp"       to (data["localTemp"]       ?: Int.MIN_VALUE),
                    "heatingSetpoint" to (data["heatingSetpoint"] ?: Int.MIN_VALUE),
                    "coolingSetpoint" to (data["coolingSetpoint"] ?: Int.MIN_VALUE),
                    "systemMode"      to (data["systemMode"]      ?: -1),
                    "controlSequence" to (data["controlSequence"] ?: -1),
                    "minHeatSetpt"    to (data["minHeatSetpt"]    ?: Int.MIN_VALUE),
                    "maxHeatSetpt"    to (data["maxHeatSetpt"]    ?: Int.MIN_VALUE),
                    "minCoolSetpt"    to (data["minCoolSetpt"]    ?: Int.MIN_VALUE),
                    "maxCoolSetpt"    to (data["maxCoolSetpt"]    ?: Int.MIN_VALUE),
                    "absMinHeatSetpt" to (data["absMinHeatSetpt"] ?: Int.MIN_VALUE),
                    "absMaxHeatSetpt" to (data["absMaxHeatSetpt"] ?: Int.MIN_VALUE),
                    "absMinCoolSetpt" to (data["absMinCoolSetpt"] ?: Int.MIN_VALUE),
                    "absMaxCoolSetpt" to (data["absMaxCoolSetpt"] ?: Int.MIN_VALUE),
                ))
            }
        }

    fun writeHeatingSetpoint(nodeId: Long, centidegrees: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            ThermostatCluster.writeHeatingSetpoint(core.context, nodeId, centidegrees)
            core.main.post { result.success(true) }
        }

    fun writeSystemMode(nodeId: Long, mode: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            ThermostatCluster.writeSystemMode(core.context, nodeId, mode)
            core.main.post { result.success(true) }
        }
}
