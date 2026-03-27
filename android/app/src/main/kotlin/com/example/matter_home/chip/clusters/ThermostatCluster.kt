package com.example.matter_home.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.Thermostat
import chip.devicecontroller.model.AttributeWriteRequest
import chip.devicecontroller.model.ChipAttributePath
import com.example.matter_home.chip.ChipClient
import matter.tlv.AnonymousTag
import matter.tlv.TlvWriter

private const val TAG = "ThermostatCluster"

internal object ThermostatCluster {

    /**
     * Reads LocalTemperature, OccupiedHeatingSetpoint, OccupiedCoolingSetpoint,
     * SystemMode and ControlSequenceOfOperation from the Thermostat cluster.
     * All temperatures are in centidegrees (0.01 °C).
     * 0x8000 (Matter nullable int16 null sentinel per spec §4.3.9.3) → mapped to null.
     */
    suspend fun readThermostat(context: Context, nodeId: Long, endpoint: Int = 1): Map<String, Int?> =
        readAttributes(context, nodeId, paths(endpoint), emptyMap(), TAG) { state ->
            val c = state?.getEndpointState(endpoint)?.getClusterState(Thermostat.ID)
            fun attr(id: Long) = c?.getAttributeState(id)?.getValue()
                ?.let { (it as? Number)?.toInt() }
                ?.takeUnless { it == 0x8000 }
            mapOf(
                "localTemp"       to attr(Thermostat.Attribute.LocalTemperature.id),
                "heatingSetpoint" to attr(Thermostat.Attribute.OccupiedHeatingSetpoint.id),
                "coolingSetpoint" to attr(Thermostat.Attribute.OccupiedCoolingSetpoint.id),
                "systemMode"      to attr(Thermostat.Attribute.SystemMode.id),
                "controlSequence" to attr(Thermostat.Attribute.ControlSequenceOfOperation.id),
            ).also { Log.d(TAG, "readThermostat → $it") }
        }

    /**
     * Writes [centidegrees] (int16, 0.01 °C) to OccupiedHeatingSetpoint.
     * Example: pass 2100 to set 21.00 °C.
     */
    suspend fun writeHeatingSetpoint(context: Context, nodeId: Long, centidegrees: Int, endpoint: Int = 1) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter().put(AnonymousTag, centidegrees.toShort()).getEncoded()
        writeAttribute(ptr, AttributeWriteRequest.newInstance(
            endpoint, Thermostat.ID, Thermostat.Attribute.OccupiedHeatingSetpoint.id, tlv,
        ), TAG)
        Log.d(TAG, "writeHeatingSetpoint ${centidegrees / 100.0}°C → nodeId=$nodeId ep=$endpoint")
    }

    /**
     * Writes [mode] (uint8 enum) to SystemMode attribute.
     * Values: 0=Off 1=Auto 3=Cool 4=Heat 5=EmergencyHeat 7=FanOnly
     */
    suspend fun writeSystemMode(context: Context, nodeId: Long, mode: Int, endpoint: Int = 1) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter().putUnsigned(AnonymousTag, mode).getEncoded()
        writeAttribute(ptr, AttributeWriteRequest.newInstance(
            endpoint, Thermostat.ID, Thermostat.Attribute.SystemMode.id, tlv,
        ), TAG)
        Log.d(TAG, "writeSystemMode mode=$mode → nodeId=$nodeId ep=$endpoint")
    }

    private fun paths(endpoint: Int) = listOf(
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.LocalTemperature.id),
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.OccupiedHeatingSetpoint.id),
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.OccupiedCoolingSetpoint.id),
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.SystemMode.id),
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.ControlSequenceOfOperation.id),
    )
}
