package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.LevelControl
import chip.devicecontroller.model.InvokeElement
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvWriter

private const val TAG = "LevelControlCluster"

internal object LevelControlCluster {

    /** Sends a MoveToLevel command. [level] is 0–254 (Matter spec §3.10). */
    suspend fun moveToLevel(context: Context, nodeId: Long, level: Int, endpoint: Int = 1) {
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.Level.id),           level.toUInt())
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.TransitionTime.id),  0u)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.OptionsMask.id),     0u)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.OptionsOverride.id), 0u)
            .endStructure()
            .getEncoded()
        invoke(context, nodeId, InvokeElement.newInstance(
            endpoint, LevelControl.ID, LevelControl.Command.MoveToLevel.id, tlv, null,
        ))
        Log.d(TAG, "MoveToLevel $level → nodeId=$nodeId ep=$endpoint")
    }

    /**
     * Sends a StepWithOnOff command.
     *
     * [stepUp] true = step up (increase brightness), false = step down.
     * [stepSize] 0–254; 25 ≈ 10 % of full range.
     * Turns the device on when stepping up from off.
     */
    suspend fun stepWithOnOff(
        context: Context,
        nodeId: Long,
        stepUp: Boolean,
        stepSize: Int = 25,
        endpoint: Int = 1,
    ) {
        val mode: UInt = if (stepUp) 0u else 1u
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(LevelControl.StepWithOnOffCommandField.StepMode.id),        mode)
            .put(ContextSpecificTag(LevelControl.StepWithOnOffCommandField.StepSize.id),        stepSize.toUInt())
            .put(ContextSpecificTag(LevelControl.StepWithOnOffCommandField.TransitionTime.id),  0u)
            .put(ContextSpecificTag(LevelControl.StepWithOnOffCommandField.OptionsMask.id),     0u)
            .put(ContextSpecificTag(LevelControl.StepWithOnOffCommandField.OptionsOverride.id), 0u)
            .endStructure()
            .getEncoded()
        invoke(context, nodeId, InvokeElement.newInstance(
            endpoint, LevelControl.ID, LevelControl.Command.StepWithOnOff.id, tlv, null,
        ))
        Log.d(TAG, "StepWithOnOff ${if (stepUp) "UP" else "DOWN"} $stepSize → nodeId=$nodeId ep=$endpoint")
    }
}
