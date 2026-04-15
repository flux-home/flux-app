package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.ColorControl
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.InvokeElement
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvWriter

private const val TAG = "ColorControlCluster"

internal object ColorControlCluster {

    data class ColorState(
        val colorTempMireds: Int?,    // 153 (6500 K) – 500 (2000 K)
        val colorTempMinMireds: Int?,
        val colorTempMaxMireds: Int?,
    )

    suspend fun readColorState(
        context: Context, nodeId: Long, endpoint: Int = 1,
    ): ColorState = readAttributes(
        context, nodeId,
        listOf(
            ChipAttributePath.newInstance(endpoint, ColorControl.ID,
                ColorControl.Attribute.ColorTemperatureMireds.id),
            ChipAttributePath.newInstance(endpoint, ColorControl.ID,
                ColorControl.Attribute.ColorTempPhysicalMinMireds.id),
            ChipAttributePath.newInstance(endpoint, ColorControl.ID,
                ColorControl.Attribute.ColorTempPhysicalMaxMireds.id),
        ),
        ColorState(null, null, null), TAG,
    ) { state ->
        val c = state?.getEndpointState(endpoint)?.getClusterState(ColorControl.ID)
        fun intAttr(id: Long) = c?.getAttributeState(id)?.getValue()?.let { (it as? Number)?.toInt() }
        ColorState(
            colorTempMireds    = intAttr(ColorControl.Attribute.ColorTemperatureMireds.id),
            colorTempMinMireds = intAttr(ColorControl.Attribute.ColorTempPhysicalMinMireds.id),
            colorTempMaxMireds = intAttr(ColorControl.Attribute.ColorTempPhysicalMaxMireds.id),
        )
    }.also { Log.d(TAG, "colorState=$it nodeId=$nodeId") }

    /**
     * Sends MoveToColorTemperature. [mireds] is 153 (6500 K cool) – 500 (2000 K warm).
     * [transitionTime] is in tenths of a second (0 = immediate).
     */
    suspend fun moveToColorTemperature(
        context: Context,
        nodeId: Long,
        mireds: Int,
        transitionTime: Int = 0,
        endpoint: Int = 1,
    ) {
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(ColorControl.MoveToColorTemperatureCommandField.ColorTemperatureMireds.id),
                mireds.toUShort())
            .put(ContextSpecificTag(ColorControl.MoveToColorTemperatureCommandField.TransitionTime.id),
                transitionTime.toUShort())
            .put(ContextSpecificTag(ColorControl.MoveToColorTemperatureCommandField.OptionsMask.id), 0u)
            .put(ContextSpecificTag(ColorControl.MoveToColorTemperatureCommandField.OptionsOverride.id), 0u)
            .endStructure()
            .getEncoded()
        invoke(context, nodeId, InvokeElement.newInstance(
            endpoint, ColorControl.ID,
            ColorControl.Command.MoveToColorTemperature.id, tlv, null,
        ))
        Log.d(TAG, "MoveToColorTemperature mireds=$mireds nodeId=$nodeId ep=$endpoint")
    }
}
