package com.example.matter_home.chip

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.Thermostat
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.WriteAttributesCallback
import chip.devicecontroller.model.AttributeWriteRequest
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.NodeState
import matter.tlv.AnonymousTag
import matter.tlv.TlvWriter
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "ThermostatCluster"

internal object ThermostatCluster {

    /**
     * Reads LocalTemperature, OccupiedHeatingSetpoint, OccupiedCoolingSetpoint,
     * SystemMode and ControlSequenceOfOperation from the Thermostat cluster.
     * All temperatures are in centidegrees (0.01 °C).
     * Returns a map with nullable Int values; 0x8000 (Matter null sentinel) is
     * mapped to null per Matter spec §4.3.9.3.
     */
    suspend fun readThermostat(
        context:  Context,
        nodeId:   Long,
        endpoint: Int = 1,
    ): Map<String, Int?> {
        val ptr   = ChipClient.getConnectedDevicePointer(context, nodeId)
        val paths = listOf(
            attr(endpoint, Thermostat.Attribute.LocalTemperature.id),
            attr(endpoint, Thermostat.Attribute.OccupiedHeatingSetpoint.id),
            attr(endpoint, Thermostat.Attribute.OccupiedCoolingSetpoint.id),
            attr(endpoint, Thermostat.Attribute.SystemMode.id),
            attr(endpoint, Thermostat.Attribute.ControlSequenceOfOperation.id),
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
                        Log.e(TAG, "readThermostat error", ex)
                        if (cont.isActive) cont.resume(emptyMap())
                    }
                    override fun onReport(state: NodeState?) { if (state != null) lastState = state }
                    override fun onDone() {
                        val c = lastState?.getEndpointState(endpoint)?.getClusterState(Thermostat.ID)
                        // 0x8000 = nullable int16 null sentinel per Matter spec
                        fun attr(id: Long): Int? = c?.getAttributeState(id)?.getValue()
                            ?.let { (it as? Number)?.toInt() }
                            ?.takeUnless { it == 0x8000 }
                        val result = mapOf(
                            "localTemp"       to attr(Thermostat.Attribute.LocalTemperature.id),
                            "heatingSetpoint" to attr(Thermostat.Attribute.OccupiedHeatingSetpoint.id),
                            "coolingSetpoint" to attr(Thermostat.Attribute.OccupiedCoolingSetpoint.id),
                            "systemMode"      to attr(Thermostat.Attribute.SystemMode.id),
                            "controlSequence" to attr(Thermostat.Attribute.ControlSequenceOfOperation.id),
                        )
                        Log.d(TAG, "readThermostat → $result")
                        if (cont.isActive) cont.resume(result)
                    }
                },
                ptr, paths, null, false, 0,
            )
        }
    }

    /**
     * Writes [centidegrees] (int16, 0.01 °C) to OccupiedHeatingSetpoint.
     * Example: pass 2100 to set 21.00 °C.
     */
    suspend fun writeHeatingSetpoint(
        context:      Context,
        nodeId:       Long,
        centidegrees: Int,
        endpoint:     Int = 1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter().put(AnonymousTag, centidegrees.toShort()).getEncoded()
        write(ptr, AttributeWriteRequest.newInstance(
            endpoint, Thermostat.ID, Thermostat.Attribute.OccupiedHeatingSetpoint.id, tlv,
        ))
        Log.d(TAG, "writeHeatingSetpoint ${centidegrees / 100.0}°C → nodeId=$nodeId ep=$endpoint")
    }

    /**
     * Writes [mode] (uint8 enum) to SystemMode attribute.
     * Values: 0=Off 1=Auto 3=Cool 4=Heat 5=EmergencyHeat 7=FanOnly
     */
    suspend fun writeSystemMode(
        context:  Context,
        nodeId:   Long,
        mode:     Int,
        endpoint: Int = 1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter().putUnsigned(AnonymousTag, mode).getEncoded()
        write(ptr, AttributeWriteRequest.newInstance(
            endpoint, Thermostat.ID, Thermostat.Attribute.SystemMode.id, tlv,
        ))
        Log.d(TAG, "writeSystemMode mode=$mode → nodeId=$nodeId ep=$endpoint")
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun attr(endpoint: Int, attrId: Long) =
        ChipAttributePath.newInstance(endpoint, Thermostat.ID, attrId)

    private suspend fun write(devicePointer: Long, req: AttributeWriteRequest) =
        suspendCancellableCoroutine<Unit> { cont ->
            ChipClient.getController().write(
                object : WriteAttributesCallback {
                    override fun onError(
                        path: chip.devicecontroller.model.ChipAttributePath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "write error", ex)
                        if (cont.isActive) cont.resumeWithException(ex)
                    }
                    override fun onResponse(
                        path:   chip.devicecontroller.model.ChipAttributePath?,
                        status: chip.devicecontroller.model.Status?,
                    ) {
                        Log.d(TAG, "write response status=$status")
                    }
                    override fun onDone() { if (cont.isActive) cont.resume(Unit) }
                },
                devicePointer, listOf(req), 0, 0,
            )
        }
}
