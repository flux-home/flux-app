package com.fluxhome.app.bridge

import android.content.Context
import android.util.Log
import com.fluxhome.app.chip.clusters.DescriptorCluster

/**
 * Matter infrastructure device-type IDs that should be skipped when looking
 * for the primary application device type on an endpoint.
 */
internal val infraTypes = setOf(
    0x000E, // Aggregator
    0x0011, // Root Node
    0x0012, // OTA Requestor
    0x0013, // Bridged Node
    0x0014, // OTA Provider
    0x0016, // Secondary Network Interface
    0x0017, // Power Source (utility node type)
    // Note: 0x000F is Generic Switch — an APPLICATION type, NOT infra
)

/**
 * Reads the primary application device-type from the Descriptor cluster.
 *
 * Strategy per Matter spec:
 *  - Endpoint 0  = Root Node (infrastructure types: 0x0011, 0x0016, …)
 *  - Endpoint 1  = Primary application endpoint (thermostat, light, …)
 *
 * Tries endpoints 1–5; falls back to OnOff Light (0x0100) if none yield a
 * non-infrastructure type.
 */
internal suspend fun readPrimaryDeviceType(context: Context, nodeId: Long): Int {
    for (ep in 1..5) {
        try {
            val types = DescriptorCluster.readDeviceTypes(context, nodeId, ep)
            if (types.isEmpty()) continue
            Log.d(TAG, "Descriptor ep=$ep types=${types.map { "0x%04X".format(it) }}")
            val appType = types.firstOrNull { it !in infraTypes }
            if (appType != null) {
                Log.i(TAG, "Primary device type 0x%04X from ep=$ep".format(appType))
                return appType
            }
        } catch (e: Exception) {
            Log.w(TAG, "readDeviceTypes ep=$ep failed: ${e.message}")
        }
    }
    Log.w(TAG, "No application device type found for nodeId=$nodeId, defaulting to OnOff Light")
    return 0x0100
}

private const val TAG = "DeviceTypeHelper"
