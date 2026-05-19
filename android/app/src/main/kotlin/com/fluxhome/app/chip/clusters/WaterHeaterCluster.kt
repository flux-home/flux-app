package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.Thermostat
import chip.devicecontroller.ClusterIDMapping.WaterHeaterManagement
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.InvokeElement
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvWriter

private const val TAG = "WaterHeaterCluster"

/**
 * Reads and controls a Matter Water Heater device (device type 0x050F).
 *
 * Combines two clusters:
 *   - Thermostat (0x0201)            — temperature measurement + setpoint control
 *   - WaterHeaterManagement (0x0094) — boost commands, heat demand, tank state
 */
internal object WaterHeaterCluster {

    /**
     * Reads the full water heater state in a single interaction.
     *
     * Returned map keys (all nullable, Int):
     *   localTemp       — LocalTemperature centidegrees (nullable, 0x8000 mapped to null)
     *   heatingSetpoint — OccupiedHeatingSetpoint centidegrees
     *   minHeatSetpt    — MinHeatSetpointLimit centidegrees (or AbsMin fallback)
     *   maxHeatSetpt    — MaxHeatSetpointLimit centidegrees (or AbsMax fallback)
     *   tankPercentHeat — 0–100 %, or -1 if not reported
     *   heatDemand      — bitmap8 (0 = not heating), or 0 if not reported
     *   boostState      — 0 = Inactive, 1 = Active
     */
    suspend fun readWaterHeater(
        context: Context,
        nodeId: Long,
        endpoint: Int = 1,
    ): Map<String, Int?> = readAttributes(
        context, nodeId, paths(endpoint), emptyMap(), TAG,
    ) { state ->
        val thermo = state?.getEndpointState(endpoint)?.getClusterState(Thermostat.ID)
        val whm    = state?.getEndpointState(endpoint)
                         ?.getClusterState(WaterHeaterManagement.ID)

        fun thermoInt(id: Long) = thermo?.getAttributeState(id)?.getValue()
            ?.let { (it as? Number)?.toInt() }
        fun thermoNullable(id: Long) = thermoInt(id)?.takeUnless { it == 0x8000 }
        fun whmInt(id: Long) = whm?.getAttributeState(id)?.getValue()
            ?.let { (it as? Number)?.toInt() }

        mapOf(
            "localTemp"       to thermoNullable(Thermostat.Attribute.LocalTemperature.id),
            "heatingSetpoint" to thermoInt(Thermostat.Attribute.OccupiedHeatingSetpoint.id),
            // Prefer configurable limits; fall back to absolute limits.
            "minHeatSetpt"    to (thermoInt(Thermostat.Attribute.MinHeatSetpointLimit.id)
                                    ?: thermoInt(Thermostat.Attribute.AbsMinHeatSetpointLimit.id)),
            "maxHeatSetpt"    to (thermoInt(Thermostat.Attribute.MaxHeatSetpointLimit.id)
                                    ?: thermoInt(Thermostat.Attribute.AbsMaxHeatSetpointLimit.id)),
            "tankPercentHeat" to whmInt(WaterHeaterManagement.Attribute.TankPercentage.id),
            "heatDemand"      to whmInt(WaterHeaterManagement.Attribute.HeatDemand.id),
            "boostState"      to whmInt(WaterHeaterManagement.Attribute.BoostState.id),
        ).also { Log.d(TAG, "readWaterHeater → $it") }
    }

    /**
     * Sends the Boost command (spec §9.5.8.1) with [durationSeconds] duration.
     *
     * BoostInfo struct:
     *   Field 0 = Duration (uint32, seconds) — the only required field.
     * All other fields (OneShot, Emergency, TargetPercentage, TargetReheat) are
     * optional and omitted here for a simple one-hour boost.
     */
    suspend fun boost(
        context: Context,
        nodeId: Long,
        durationSeconds: Int = 3600,
        endpoint: Int = 1,
    ) {
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)              // command body
            .startStructure(ContextSpecificTag(        // BoostInfo struct (field 0)
                WaterHeaterManagement.BoostCommandField.BoostInfo.id,
            ))
            .put(ContextSpecificTag(0), durationSeconds.toUInt()) // Duration
            .endStructure()                            // end BoostInfo
            .endStructure()                            // end command body
            .getEncoded()
        invoke(
            context, nodeId,
            InvokeElement.newInstance(
                endpoint,
                WaterHeaterManagement.ID,
                WaterHeaterManagement.Command.Boost.id,
                tlv, null,
            ),
        )
        Log.d(TAG, "Boost durationSeconds=$durationSeconds → nodeId=$nodeId ep=$endpoint")
    }

    /**
     * Sends the CancelBoost command (spec §9.5.8.2).
     * Command body is an empty struct — no fields required.
     */
    suspend fun cancelBoost(
        context: Context,
        nodeId: Long,
        endpoint: Int = 1,
    ) {
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .endStructure()
            .getEncoded()
        invoke(
            context, nodeId,
            InvokeElement.newInstance(
                endpoint,
                WaterHeaterManagement.ID,
                WaterHeaterManagement.Command.CancelBoost.id,
                tlv, null,
            ),
        )
        Log.d(TAG, "CancelBoost → nodeId=$nodeId ep=$endpoint")
    }

    private fun paths(endpoint: Int) = listOf(
        // Thermostat cluster attributes
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.LocalTemperature.id),
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.OccupiedHeatingSetpoint.id),
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.MinHeatSetpointLimit.id),
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.MaxHeatSetpointLimit.id),
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.AbsMinHeatSetpointLimit.id),
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.AbsMaxHeatSetpointLimit.id),
        // Water Heater Management cluster attributes
        ChipAttributePath.newInstance(endpoint, WaterHeaterManagement.ID, WaterHeaterManagement.Attribute.TankPercentage.id),
        ChipAttributePath.newInstance(endpoint, WaterHeaterManagement.ID, WaterHeaterManagement.Attribute.HeatDemand.id),
        ChipAttributePath.newInstance(endpoint, WaterHeaterManagement.ID, WaterHeaterManagement.Attribute.BoostState.id),
    )
}
