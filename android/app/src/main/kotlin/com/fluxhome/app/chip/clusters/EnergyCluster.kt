package com.fluxhome.app.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.ElectricalEnergyMeasurement
import chip.devicecontroller.model.ChipAttributePath

private const val TAG = "EnergyCluster"

/**
 * One-shot reads of Electrical Energy Measurement (0x0091) attributes.
 *
 * Used for periodic polling when the device does not push these values
 * via subscription (which is common — many devices only push EPM/ActivePower
 * on the subscription stream and serve EEM data only on direct reads).
 */
internal object EnergyCluster {

    data class CumulativeEnergy(
        /** Imported cumulative energy in milliwatt-hours, or null if unavailable. */
        val importedMwh: Long?,
        /** Exported cumulative energy in milliwatt-hours, or null if unavailable. */
        val exportedMwh: Long?,
    )

    /**
     * Reads CumulativeEnergyImported and CumulativeEnergyExported in a single
     * interaction.  Uses [readAttributes] (fallback on error) so a failed read
     * returns an empty result rather than throwing.
     */
    suspend fun readCumulativeEnergy(
        context: Context,
        nodeId: Long,
        endpoint: Int = 1,
    ): CumulativeEnergy = readAttributes(
        context, nodeId,
        listOf(
            ChipAttributePath.newInstance(endpoint, ElectricalEnergyMeasurement.ID,
                ElectricalEnergyMeasurement.Attribute.CumulativeEnergyImported.id),
            ChipAttributePath.newInstance(endpoint, ElectricalEnergyMeasurement.ID,
                ElectricalEnergyMeasurement.Attribute.CumulativeEnergyExported.id),
        ),
        fallback = CumulativeEnergy(null, null),
        TAG,
    ) { state ->
        val c = state?.getEndpointState(endpoint)?.getClusterState(ElectricalEnergyMeasurement.ID)
        fun mwh(attrId: Long) = c?.getAttributeState(attrId)?.getValue()
            ?.let { extractEnergyMwh(it) }
        CumulativeEnergy(
            importedMwh = mwh(ElectricalEnergyMeasurement.Attribute.CumulativeEnergyImported.id),
            exportedMwh = mwh(ElectricalEnergyMeasurement.Attribute.CumulativeEnergyExported.id),
        ).also { Log.d(TAG, "readCumulativeEnergy $it nodeId=$nodeId ep=$endpoint") }
    }
}
