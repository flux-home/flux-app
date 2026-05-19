package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.DoorLock
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.InvokeElement
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvReader
import matter.tlv.TlvWriter

private const val TAG = "DoorLockCluster"

/**
 * LockStateEnum (spec §5.2.6.19):
 *   0 = NotFullyLocked  — bolt is moving or intermediate state
 *   1 = Locked          — fully secured
 *   2 = Unlocked        — fully open
 *   3 = Unlatched       — unlocked + latch retracted (optional)
 *
 * DoorStateEnum (spec §5.2.6.11, feature DPS):
 *   0 = DoorOpen   1 = DoorClosed   2 = DoorJammed
 *   3 = DoorForcedOpen   4 = DoorUnspecifiedError   5 = DoorAjar
 */
internal object DoorLockCluster {

    data class LockState(
        /** nullable — null when state is unknown/transitioning per spec */
        val lockState: Int?,
        /** null when device does not support the DPS (door-position-sensor) feature */
        val doorState: Int?,
    )

    // ── Attribute read ────────────────────────────────────────────────────────

    /**
     * Reads LockState (0x0000) and DoorState (0x0003) in a single interaction.
     * Uses [readAttributeOrThrow] so callers can distinguish offline (throws)
     * from "online, state = unknown" (returns null lockState).
     */
    suspend fun readLockState(
        context: Context,
        nodeId: Long,
        endpoint: Int = 1,
    ): LockState = readAttributeOrThrow(
        context, nodeId,
        listOf(
            ChipAttributePath.newInstance(endpoint, DoorLock.ID, DoorLock.Attribute.LockState.id),
            ChipAttributePath.newInstance(endpoint, DoorLock.ID, DoorLock.Attribute.DoorState.id),
        ),
        TAG,
    ) { state ->
        val c = state?.getEndpointState(endpoint)?.getClusterState(DoorLock.ID)
        fun intAttr(id: Long) = c?.getAttributeState(id)?.getValue()
            ?.let { (it as? Number)?.toInt() }
        LockState(
            lockState = intAttr(DoorLock.Attribute.LockState.id),
            doorState = intAttr(DoorLock.Attribute.DoorState.id),
        ).also { Log.d(TAG, "readLockState $it nodeId=$nodeId") }
    }

    // ── Commands ──────────────────────────────────────────────────────────────

    /**
     * Sends the LockDoor command (spec §5.2.10.1).
     *
     * A timed interaction (10 s timeout) is mandatory per the Matter spec for
     * all Door Lock commands — the device returns NEEDS_TIMED_INTERACTION
     * (0xC6) if the request arrives without one.
     */
    suspend fun lockDoor(
        context: Context,
        nodeId: Long,
        pin: String? = null,
        endpoint: Int = 1,
    ) {
        val tlv = buildLockCommandTlv(pin)
        invoke(
            context, nodeId,
            InvokeElement.newInstance(endpoint, DoorLock.ID, DoorLock.Command.LockDoor.id, tlv, null),
            timedRequestTimeoutMs = 10_000,
        )
        Log.d(TAG, "LockDoor pin=${pin != null} → nodeId=$nodeId ep=$endpoint")
    }

    /**
     * Sends the UnlockDoor command (spec §5.2.10.2).
     *
     * Same timed-interaction requirement as [lockDoor].
     */
    suspend fun unlockDoor(
        context: Context,
        nodeId: Long,
        pin: String? = null,
        endpoint: Int = 1,
    ) {
        val tlv = buildLockCommandTlv(pin)
        invoke(
            context, nodeId,
            InvokeElement.newInstance(endpoint, DoorLock.ID, DoorLock.Command.UnlockDoor.id, tlv, null),
            timedRequestTimeoutMs = 10_000,
        )
        Log.d(TAG, "UnlockDoor pin=${pin != null} → nodeId=$nodeId ep=$endpoint")
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Builds the TLV body for LockDoor / UnlockDoor.
     *
     * Both commands share the same field layout (spec §5.2.10.1 / §5.2.10.2):
     *   Field 0 = PINCode (octstr, optional — present only when PIN is provided)
     *
     * Without PIN → empty struct (all fields are optional per spec).
     * With PIN    → struct with field 0 set to the UTF-8 PIN bytes.
     */
    private fun buildLockCommandTlv(pin: String?): ByteArray {
        val writer = TlvWriter().startStructure(AnonymousTag)
        if (pin != null) {
            writer.put(
                ContextSpecificTag(DoorLock.LockDoorCommandField.PINCode.id.toInt()),
                pin.toByteArray(Charsets.UTF_8),
            )
        }
        return writer.endStructure().getEncoded()
    }
}

// ── Multi-path readAttributeOrThrow overload ──────────────────────────────────
// ClusterUtils provides single-path and single-path-list variants; add a
// list overload here so DoorLockCluster can batch two paths into one read.
private suspend fun <T> readAttributeOrThrow(
    context: Context,
    nodeId: Long,
    paths: List<ChipAttributePath>,
    tag: String,
    process: (chip.devicecontroller.model.NodeState?) -> T,
): T {
    val ptr = com.fluxhome.app.chip.ChipClient.getConnectedDevicePointer(context, nodeId)
    return kotlinx.coroutines.suspendCancellableCoroutine { cont ->
        var accumulated: chip.devicecontroller.model.NodeState? = null
        com.fluxhome.app.chip.ChipClient.getController().readPath(
            object : chip.devicecontroller.ReportCallback {
                override fun onError(
                    a: chip.devicecontroller.model.ChipAttributePath?,
                    e: chip.devicecontroller.model.ChipEventPath?,
                    ex: Exception,
                ) {
                    Log.w(tag, "readAttributeOrThrow(list) failed: ${ex.message}")
                    if (cont.isActive) cont.resumeWith(Result.failure(ex))
                }
                override fun onReport(state: chip.devicecontroller.model.NodeState?) {
                    if (state != null) accumulated = state
                }
                override fun onDone() {
                    if (cont.isActive) cont.resumeWith(Result.success(process(accumulated)))
                }
            },
            ptr, paths, null, false, 0,
        )
    }
}
