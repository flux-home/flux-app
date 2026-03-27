package com.example.matter_home.chip

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.LevelControl
import chip.devicecontroller.model.InvokeElement
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvWriter

private const val TAG = "LevelControlCluster"

internal object LevelControlCluster {

    /**
     * Sends a MoveToLevel command.  [level] is 0–254 (Matter spec §3.10).
     */
    suspend fun moveToLevel(
        context:  Context,
        nodeId:   Long,
        level:    Int,
        endpoint: Int = 1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.Level.id),           level.toUInt())
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.TransitionTime.id),  0u)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.OptionsMask.id),     0u)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.OptionsOverride.id), 0u)
            .endStructure()
            .getEncoded()
        val element = InvokeElement.newInstance(
            endpoint, LevelControl.ID, LevelControl.Command.MoveToLevel.id, tlv, null,
        )
        invoke(context, ptr, element)
        Log.d(TAG, "MoveToLevel $level → nodeId=$nodeId ep=$endpoint")
    }
}
