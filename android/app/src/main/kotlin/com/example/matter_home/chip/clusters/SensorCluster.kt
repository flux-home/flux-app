package com.example.matter_home.chip.clusters

import com.example.matter_home.chip.ChipClient

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.PowerSource
import chip.devicecontroller.ClusterIDMapping.RelativeHumidityMeasurement
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.ChipPathId
import chip.devicecontroller.model.NodeState
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "SensorCluster"

internal object SensorCluster {

    /**
     * Reads all attributes from the Power Source cluster (0x002F) using a
     * wildcard endpoint.
     *
     * Returns a map with any subset of:
     *   "percent"       → 0–100  (BatPercentRemaining raw 0–200 ÷ 2)
     *   "chargeLevel"   → 0=OK  1=Warning  2=Critical
     *   "voltageMilliV" → mV    (BatVoltage, when present)
     *
     * Returns an empty map when the cluster is absent.
     */
    suspend fun readBattery(context: Context, nodeId: Long): Map<String, Int> {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            ChipPathId.forWildcard(),
            ChipPathId.forId(PowerSource.ID),
            ChipPathId.forWildcard(),
        )
        return suspendCancellableCoroutine { cont ->
            var lastState: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.w(TAG, "readBattery not available: ${ex.message}")
                        if (cont.isActive) cont.resume(emptyMap())
                    }
                    override fun onReport(state: NodeState?) { if (state != null) lastState = state }
                    override fun onDone() {
                        val result = mutableMapOf<String, Int>()
                        lastState?.getEndpointStates()?.values?.forEach { ep ->
                            val c = ep.getClusterState(PowerSource.ID) ?: return@forEach
                            fun int(id: Long) = c.getAttributeState(id)?.getValue()
                                ?.let { (it as? Number)?.toInt() }
                            int(PowerSource.Attribute.BatPercentRemaining.id)
                                ?.takeIf { it in 0..200 }?.let { result["percent"] = it / 2 }
                            int(PowerSource.Attribute.BatChargeLevel.id)
                                ?.takeIf { it in 0..2 }?.let { result["chargeLevel"] = it }
                            int(PowerSource.Attribute.BatVoltage.id)
                                ?.takeIf { it > 0 }?.let { result["voltageMilliV"] = it }
                        }
                        Log.d(TAG, "readBattery → $result")
                        if (cont.isActive) cont.resume(result)
                    }
                },
                ptr, listOf(path), null, false, 0,
            )
        }
    }

    /**
     * Reads MeasuredValue from the Relative Humidity Measurement cluster (0x0405)
     * using a wildcard endpoint.
     *
     * Value is in units of 0.01 % RH (e.g. 5723 = 57.23 %).
     * Returns null when the cluster is absent or reports the null sentinel (0xFFFF).
     */
    suspend fun readHumidity(context: Context, nodeId: Long): Int? {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            ChipPathId.forWildcard(),
            ChipPathId.forId(RelativeHumidityMeasurement.ID),
            ChipPathId.forId(RelativeHumidityMeasurement.Attribute.MeasuredValue.id),
        )
        return suspendCancellableCoroutine { cont ->
            var lastState: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.w(TAG, "readHumidity not available: ${ex.message}")
                        if (cont.isActive) cont.resume(null)
                    }
                    override fun onReport(state: NodeState?) { if (state != null) lastState = state }
                    override fun onDone() {
                        val raw = lastState?.getEndpointStates()?.values
                            ?.mapNotNull { ep ->
                                ep.getClusterState(RelativeHumidityMeasurement.ID)
                                    ?.getAttributeState(RelativeHumidityMeasurement.Attribute.MeasuredValue.id)
                                    ?.getValue()?.let { (it as? Number)?.toInt() }
                            }
                            ?.firstOrNull()
                        val value = if (raw == null || raw == 0xFFFF) null else raw
                        Log.d(TAG, "readHumidity → ${value?.let { "${it / 100.0}%" } ?: "null"}")
                        if (cont.isActive) cont.resume(value)
                    }
                },
                ptr, listOf(path), null, false, 0,
            )
        }
    }
}
