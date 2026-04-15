package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.AirQuality
import chip.devicecontroller.ClusterIDMapping.BooleanState
import chip.devicecontroller.ClusterIDMapping.CarbonDioxideConcentrationMeasurement
import chip.devicecontroller.ClusterIDMapping.CarbonMonoxideConcentrationMeasurement
import chip.devicecontroller.ClusterIDMapping.ColorControl
import chip.devicecontroller.ClusterIDMapping.FanControl
import chip.devicecontroller.ClusterIDMapping.LevelControl
import chip.devicecontroller.ClusterIDMapping.OccupancySensing
import chip.devicecontroller.ClusterIDMapping.OnOff
import chip.devicecontroller.ClusterIDMapping.Pm25ConcentrationMeasurement
import chip.devicecontroller.ClusterIDMapping.PowerSource
import chip.devicecontroller.ClusterIDMapping.RelativeHumidityMeasurement
import chip.devicecontroller.ClusterIDMapping.SmokeCoAlarm
import chip.devicecontroller.ClusterIDMapping.TemperatureMeasurement
import chip.devicecontroller.ClusterIDMapping.Thermostat
import chip.devicecontroller.ClusterIDMapping.WindowCovering
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.ResubscriptionAttemptCallback
import chip.devicecontroller.SubscriptionEstablishedCallback
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.ChipPathId
import chip.devicecontroller.model.NodeState
import com.fluxhome.app.chip.ChipClient

private const val TAG = "SubscriptionManager"

internal object SubscriptionManager {

    /**
     * Subscribes to all "interesting" attributes on [nodeId].
     *
     * [onUpdate]        — map of changed attribute key→value.
     * [onEstablished]   — subscription is live; initial data report follows.
     * [onResubscribing] — device unreachable; SDK is retrying (nextMs = backoff ms).
     * [onError]         — fatal error (session lost, etc.).
     *
     * Subscribed attribute keys:
     *   onOff, level, localTempCenti, heatingSetptCenti, coolingSetptCenti,
     *   systemMode, controlSequence, humidityCenti, tempMeasureCenti,
     *   batPercentRaw (0–200), batChargeLevel, occupancy, contactState, airQuality,
     *   liftPercent100ths, fanMode, fanPercent, colorTempMireds, smokeState, coState,
     *   pm25 (µg/m³ × 10 as int), co2Ppm (ppm as int), coPpm (ppm × 10 as int).
     */
    fun subscribeDeviceState(
        context:         Context,
        nodeId:          Long,
        onUpdate:        (nodeId: Long, attrs: Map<String, Any?>) -> Unit,
        onEstablished:   (nodeId: Long) -> Unit,
        onResubscribing: (nodeId: Long, nextMs: Long) -> Unit,
        onError:         (nodeId: Long, error: Exception) -> Unit,
    ) {
        ChipClient.getController().getConnectedDevicePointer(
            nodeId,
            object : chip.devicecontroller.GetConnectedDeviceCallbackJni.GetConnectedDeviceCallback {
                override fun onDeviceConnected(devicePointer: Long) {
                    ChipClient.getController().subscribeToPath(
                        SubscriptionEstablishedCallback { _ ->
                            Log.d(TAG, "Subscription established nodeId=$nodeId")
                            onEstablished(nodeId)
                        },
                        ResubscriptionAttemptCallback { terminationCause, nextIntervalMs ->
                            Log.d(TAG, "Resubscribing nodeId=$nodeId cause=$terminationCause nextMs=$nextIntervalMs")
                            onResubscribing(nodeId, nextIntervalMs)
                        },
                        object : ReportCallback {
                            override fun onError(
                                a: chip.devicecontroller.model.ChipAttributePath?,
                                e: chip.devicecontroller.model.ChipEventPath?,
                                ex: Exception,
                            ) {
                                Log.e(TAG, "Subscription error nodeId=$nodeId: ${ex.message}")
                                onError(nodeId, ex)
                            }
                            override fun onReport(state: NodeState?) {
                                if (state == null) return
                                val attrs = extractAttrs(state)
                                if (attrs.isNotEmpty()) onUpdate(nodeId, attrs)
                            }
                        },
                        devicePointer,
                        buildPaths(),
                        null,
                        1,     // minInterval 1 s
                        120,   // maxInterval 120 s
                        false, // keepSubscriptions
                        true,  // autoResubscribe
                        0,
                    )
                }
                override fun onConnectionFailure(nid: Long, error: Exception) {
                    Log.e(TAG, "subscribeDeviceState connection failure nodeId=$nodeId: ${error.message}")
                    onError(nodeId, error)
                }
            }
        )
    }

    private fun buildPaths(): List<ChipAttributePath> {
        fun wep(clusterId: Long, attrId: Long) = ChipAttributePath.newInstance(
            ChipPathId.forWildcard(), ChipPathId.forId(clusterId), ChipPathId.forId(attrId),
        )
        return listOf(
            wep(OnOff.ID,                       OnOff.Attribute.OnOff.id),
            wep(LevelControl.ID,                LevelControl.Attribute.CurrentLevel.id),
            wep(Thermostat.ID,                  Thermostat.Attribute.LocalTemperature.id),
            wep(Thermostat.ID,                  Thermostat.Attribute.OccupiedHeatingSetpoint.id),
            wep(Thermostat.ID,                  Thermostat.Attribute.OccupiedCoolingSetpoint.id),
            wep(Thermostat.ID,                  Thermostat.Attribute.SystemMode.id),
            wep(Thermostat.ID,                  Thermostat.Attribute.ControlSequenceOfOperation.id),
            wep(RelativeHumidityMeasurement.ID, RelativeHumidityMeasurement.Attribute.MeasuredValue.id),
            wep(TemperatureMeasurement.ID,      TemperatureMeasurement.Attribute.MeasuredValue.id),
            wep(PowerSource.ID,                 PowerSource.Attribute.BatPercentRemaining.id),
            wep(PowerSource.ID,                 PowerSource.Attribute.BatChargeLevel.id),
            wep(OccupancySensing.ID,            OccupancySensing.Attribute.Occupancy.id),
            wep(BooleanState.ID,                BooleanState.Attribute.StateValue.id),
            wep(AirQuality.ID,                  AirQuality.Attribute.AirQuality.id),
            wep(Pm25ConcentrationMeasurement.ID,              Pm25ConcentrationMeasurement.Attribute.MeasuredValue.id),
            wep(CarbonDioxideConcentrationMeasurement.ID,     CarbonDioxideConcentrationMeasurement.Attribute.MeasuredValue.id),
            wep(CarbonMonoxideConcentrationMeasurement.ID,    CarbonMonoxideConcentrationMeasurement.Attribute.MeasuredValue.id),
        )
    }

    private fun extractAttrs(state: NodeState): Map<String, Any?> {
        val r = mutableMapOf<String, Any?>()
        state.getEndpointStates().values.forEach { ep ->
            fun <T> get(clusterId: Long, attrId: Long, cast: (Any) -> T?): T? =
                ep.getClusterState(clusterId)?.getAttributeState(attrId)
                    ?.getValue()?.let { cast(it) }
            fun intOf(clusterId: Long, attrId: Long) =
                get(clusterId, attrId) { (it as? Number)?.toInt() }

            get(OnOff.ID, OnOff.Attribute.OnOff.id)                                    { it as? Boolean }?.let { r["onOff"] = it }
            intOf(LevelControl.ID, LevelControl.Attribute.CurrentLevel.id)             ?.let { r["level"]             = it }
            intOf(Thermostat.ID,   Thermostat.Attribute.LocalTemperature.id)           ?.let { r["localTempCenti"]    = it }
            intOf(Thermostat.ID,   Thermostat.Attribute.OccupiedHeatingSetpoint.id)    ?.let { r["heatingSetptCenti"] = it }
            intOf(Thermostat.ID,   Thermostat.Attribute.OccupiedCoolingSetpoint.id)    ?.let { r["coolingSetptCenti"] = it }
            intOf(Thermostat.ID,   Thermostat.Attribute.SystemMode.id)                 ?.let { r["systemMode"]        = it }
            intOf(Thermostat.ID,   Thermostat.Attribute.ControlSequenceOfOperation.id) ?.let { r["controlSequence"]   = it }
            intOf(RelativeHumidityMeasurement.ID, RelativeHumidityMeasurement.Attribute.MeasuredValue.id)
                                                                                        ?.let { r["humidityCenti"]    = it }
            intOf(TemperatureMeasurement.ID, TemperatureMeasurement.Attribute.MeasuredValue.id)
                                                                                        ?.let { r["tempMeasureCenti"] = it }
            intOf(PowerSource.ID,  PowerSource.Attribute.BatPercentRemaining.id)       ?.let { r["batPercentRaw"]     = it }
            intOf(PowerSource.ID,  PowerSource.Attribute.BatChargeLevel.id)            ?.let { r["batChargeLevel"]    = it }
            intOf(OccupancySensing.ID, OccupancySensing.Attribute.Occupancy.id)        ?.let { r["occupancy"]         = it }
            get(BooleanState.ID,   BooleanState.Attribute.StateValue.id)               { it as? Boolean }?.let { r["contactState"] = it }
            intOf(AirQuality.ID,   AirQuality.Attribute.AirQuality.id)                ?.let { r["airQuality"]        = it }

            // Concentration measurement clusters report nullable floats.
            // Store as scaled integers: PM2.5 and CO as ×10 (1 decimal), CO2 as direct ppm.
            fun floatOf(clusterId: Long, attrId: Long): Double? =
                get(clusterId, attrId) { (it as? Number)?.toDouble() }

            floatOf(Pm25ConcentrationMeasurement.ID,           Pm25ConcentrationMeasurement.Attribute.MeasuredValue.id)
                ?.let { r["pm25"]   = (it * 10).toInt() }
            floatOf(CarbonDioxideConcentrationMeasurement.ID,  CarbonDioxideConcentrationMeasurement.Attribute.MeasuredValue.id)
                ?.let { r["co2Ppm"] = it.toInt() }
            floatOf(CarbonMonoxideConcentrationMeasurement.ID, CarbonMonoxideConcentrationMeasurement.Attribute.MeasuredValue.id)
                ?.let { r["coPpm"]  = (it * 10).toInt() }
            intOf(WindowCovering.ID, WindowCovering.Attribute.CurrentPositionLiftPercent100ths.id)
                                                                                        ?.let { r["liftPercent100ths"] = it }
            intOf(FanControl.ID,   FanControl.Attribute.FanMode.id)                    ?.let { r["fanMode"]           = it }
            intOf(FanControl.ID,   FanControl.Attribute.PercentCurrent.id)             ?.let { r["fanPercent"]        = it }
            intOf(ColorControl.ID, ColorControl.Attribute.ColorTemperatureMireds.id)   ?.let { r["colorTempMireds"]   = it }
            intOf(SmokeCoAlarm.ID, SmokeCoAlarm.Attribute.SmokeState.id)               ?.let { r["smokeState"]        = it }
            intOf(SmokeCoAlarm.ID, SmokeCoAlarm.Attribute.COState.id)                  ?.let { r["coState"]           = it }
        }
        return r
    }
}
