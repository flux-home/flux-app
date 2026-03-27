package com.example.matter_home.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.PowerSource
import chip.devicecontroller.ClusterIDMapping.RelativeHumidityMeasurement
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.ChipPathId
import com.example.matter_home.chip.ChipClient
private const val TAG = "SensorCluster"

internal object SensorCluster {

    /**
     * Reads all attributes from the Power Source cluster (0x002F) via wildcard endpoint.
     *
     * Returns a map with any subset of:
     *   "percent"       → 0–100  (BatPercentRemaining raw 0–200 ÷ 2)
     *   "chargeLevel"   → 0=OK  1=Warning  2=Critical
     *   "voltageMilliV" → mV    (BatVoltage, when present)
     *
     * Returns an empty map when the cluster is absent.
     */
    suspend fun readBattery(context: Context, nodeId: Long): Map<String, Int> =
        readAttributes(
            context, nodeId,
            ChipAttributePath.newInstance(
                ChipPathId.forWildcard(), ChipPathId.forId(PowerSource.ID), ChipPathId.forWildcard(),
            ),
            emptyMap(), TAG,
        ) { state ->
            mutableMapOf<String, Int>().also { result ->
                state?.getEndpointStates()?.values?.forEach { ep ->
                    val c = ep.getClusterState(PowerSource.ID) ?: return@forEach
                    fun int(id: Long) = c.getAttributeState(id)?.getValue()?.let { (it as? Number)?.toInt() }
                    int(PowerSource.Attribute.BatPercentRemaining.id)
                        ?.takeIf { it in 0..200 }?.let { result["percent"] = it / 2 }
                    int(PowerSource.Attribute.BatChargeLevel.id)
                        ?.takeIf { it in 0..2 }?.let { result["chargeLevel"] = it }
                    int(PowerSource.Attribute.BatVoltage.id)
                        ?.takeIf { it > 0 }?.let { result["voltageMilliV"] = it }
                }
                Log.d(TAG, "readBattery → $result")
            }
        }

    /**
     * Reads MeasuredValue from the Relative Humidity Measurement cluster (0x0405)
     * via wildcard endpoint.
     *
     * Value is in units of 0.01 % RH (e.g. 5723 = 57.23 %).
     * Returns null when the cluster is absent or reports the null sentinel (0xFFFF).
     */
    suspend fun readHumidity(context: Context, nodeId: Long): Int? =
        readAttributes(
            context, nodeId,
            ChipAttributePath.newInstance(
                ChipPathId.forWildcard(),
                ChipPathId.forId(RelativeHumidityMeasurement.ID),
                ChipPathId.forId(RelativeHumidityMeasurement.Attribute.MeasuredValue.id),
            ),
            null, TAG,
        ) { state ->
            state?.getEndpointStates()?.values
                ?.mapNotNull { ep ->
                    ep.getClusterState(RelativeHumidityMeasurement.ID)
                        ?.getAttributeState(RelativeHumidityMeasurement.Attribute.MeasuredValue.id)
                        ?.getValue()?.let { (it as? Number)?.toInt() }
                }
                ?.firstOrNull()
                ?.takeUnless { it == 0xFFFF }
                .also { Log.d(TAG, "readHumidity → ${it?.let { v -> "${v / 100.0}%" } ?: "null"}") }
        }
}
