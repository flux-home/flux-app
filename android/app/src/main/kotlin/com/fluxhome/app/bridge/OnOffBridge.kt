package com.fluxhome.app.bridge

import android.util.Log
import com.fluxhome.app.chip.clusters.LevelControlCluster
import com.fluxhome.app.chip.clusters.OnOffCluster
import io.flutter.plugin.common.MethodChannel

/** OnOff and LevelControl clusters — shared by lights, plugs, and switches. */
class OnOffBridge(private val core: BridgeCore) {

    fun toggleDevice(nodeId: Long, on: Boolean, result: MethodChannel.Result) =
        core.requireChip(result) {
            OnOffCluster.setOnOff(core.context, nodeId, on)
            core.main.post { result.success(true) }
        }

    fun setLevel(nodeId: Long, level: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            LevelControlCluster.moveToLevel(core.context, nodeId, level)
            core.main.post { result.success(true) }
        }

    fun stepLevel(nodeId: Long, stepUp: Boolean, result: MethodChannel.Result) =
        core.requireChip(result) {
            LevelControlCluster.stepWithOnOff(core.context, nodeId, stepUp)
            core.main.post { result.success(true) }
        }

    fun readDeviceState(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            try {
                val on = OnOffCluster.readOnOff(core.context, nodeId)
                core.main.post {
                    result.success(mapOf("isOnline" to true, "isOn" to on, "brightness" to 254))
                }
            } catch (e: Exception) {
                Log.w(TAG, "readDeviceState offline? nodeId=$nodeId: ${e.message}")
                core.main.post { result.success(mapOf("isOnline" to false)) }
            }
        }

    companion object {
        private const val TAG = "OnOffBridge"
    }
}
