package com.fluxhome.app.bridge

import android.util.Log
import com.fluxhome.app.chip.clusters.DoorLockCluster
import io.flutter.plugin.common.MethodChannel

/**
 * Door Lock cluster (0x0101) — lock, unlock, and read bolt state.
 *
 * Commands are sent without a PIN by default.  If the device has
 * RequirePINForRemoteOperation = true and rejects the command, the error
 * propagates to Flutter as a CHIP_ERROR result.
 */
class DoorLockBridge(private val core: BridgeCore) {

    fun lockDoor(nodeId: Long, pin: String?, result: MethodChannel.Result) =
        core.requireChip(result) {
            DoorLockCluster.lockDoor(core.context, nodeId, pin)
            core.main.post { result.success(true) }
        }

    fun unlockDoor(nodeId: Long, pin: String?, result: MethodChannel.Result) =
        core.requireChip(result) {
            DoorLockCluster.unlockDoor(core.context, nodeId, pin)
            core.main.post { result.success(true) }
        }

    fun readLockState(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            try {
                val state = DoorLockCluster.readLockState(core.context, nodeId)
                core.main.post {
                    result.success(mapOf(
                        "isOnline"  to true,
                        "lockState" to state.lockState,
                        "doorState" to state.doorState,
                    ))
                }
            } catch (e: Exception) {
                Log.w(TAG, "readLockState offline? nodeId=$nodeId: ${e.message}")
                core.main.post { result.success(mapOf("isOnline" to false)) }
            }
        }

    companion object {
        private const val TAG = "DoorLockBridge"
    }
}
