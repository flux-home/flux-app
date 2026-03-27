package com.example.matter_home.chip.clusters

import com.example.matter_home.chip.ChipClient

import android.content.Context

/**
 * Facade that exposes all Matter cluster operations to [MatterBridge].
 *
 * Each method delegates to a focused single-cluster module:
 *
 *  Cluster / concern          Module file
 *  ─────────────────────────  ──────────────────────────
 *  On/Off                     OnOffCluster.kt
 *  Level Control              LevelControlCluster.kt
 *  Identify                   IdentifyCluster.kt
 *  Descriptor                 DescriptorCluster.kt
 *  Basic Information          BasicInfoCluster.kt
 *  Thermostat                 ThermostatCluster.kt
 *  Battery / Humidity         SensorCluster.kt
 *  Thread diagnostics         ThreadDiagCluster.kt
 *  OTA update (requestor)     OtaCluster.kt
 *  Live subscriptions         SubscriptionManager.kt
 *  Wildcard cluster inspector ClusterInspector.kt
 *  Shared coroutine helpers   ClusterUtils.kt
 */
object ClusterClient {

    // ── On/Off ────────────────────────────────────────────────────────────────
    suspend fun setOnOff(context: Context, nodeId: Long, on: Boolean, endpoint: Int = 1) =
        OnOffCluster.setOnOff(context, nodeId, on, endpoint)

    suspend fun readOnOff(context: Context, nodeId: Long, endpoint: Int = 1) =
        OnOffCluster.readOnOff(context, nodeId, endpoint)

    // ── Level Control ─────────────────────────────────────────────────────────
    suspend fun moveToLevel(context: Context, nodeId: Long, level: Int, endpoint: Int = 1) =
        LevelControlCluster.moveToLevel(context, nodeId, level, endpoint)

    // ── Identify ──────────────────────────────────────────────────────────────
    suspend fun sendIdentify(context: Context, nodeId: Long, seconds: Int = 15, endpoint: Int = 1) =
        IdentifyCluster.sendIdentify(context, nodeId, seconds, endpoint)

    // ── Descriptor ────────────────────────────────────────────────────────────
    suspend fun readDeviceTypes(context: Context, nodeId: Long, endpoint: Int = 0) =
        DescriptorCluster.readDeviceTypes(context, nodeId, endpoint)

    suspend fun readServerClusterList(context: Context, nodeId: Long, endpoint: Int = 0) =
        DescriptorCluster.readServerClusterList(context, nodeId, endpoint)

    suspend fun readPartsList(context: Context, nodeId: Long) =
        DescriptorCluster.readPartsList(context, nodeId)

    // ── Basic Information ─────────────────────────────────────────────────────
    suspend fun readBasicInfo(context: Context, nodeId: Long) =
        BasicInfoCluster.readBasicInfo(context, nodeId)

    // ── Thermostat ────────────────────────────────────────────────────────────
    suspend fun readThermostat(context: Context, nodeId: Long, endpoint: Int = 1) =
        ThermostatCluster.readThermostat(context, nodeId, endpoint)

    suspend fun writeHeatingSetpoint(context: Context, nodeId: Long, centidegrees: Int, endpoint: Int = 1) =
        ThermostatCluster.writeHeatingSetpoint(context, nodeId, centidegrees, endpoint)

    suspend fun writeSystemMode(context: Context, nodeId: Long, mode: Int, endpoint: Int = 1) =
        ThermostatCluster.writeSystemMode(context, nodeId, mode, endpoint)

    // ── Battery / Humidity sensors ────────────────────────────────────────────
    suspend fun readBattery(context: Context, nodeId: Long) =
        SensorCluster.readBattery(context, nodeId)

    suspend fun readHumidity(context: Context, nodeId: Long) =
        SensorCluster.readHumidity(context, nodeId)

    // ── Thread Network Diagnostics ────────────────────────────────────────────
    suspend fun readThreadNetworkDiagnostics(context: Context, nodeId: Long) =
        ThreadDiagCluster.readThreadNetworkDiagnostics(context, nodeId)

    // ── OTA ───────────────────────────────────────────────────────────────────
    suspend fun announceOtaProvider(
        context: Context, nodeId: Long, providerNodeId: Long,
        vendorId: Int, requestorEndpoint: Int = 0,
    ) = OtaCluster.announceOtaProvider(context, nodeId, providerNodeId, vendorId, requestorEndpoint)

    suspend fun writeDefaultOtaProviders(context: Context, nodeId: Long, providerNodeId: Long) =
        OtaCluster.writeDefaultOtaProviders(context, nodeId, providerNodeId)

    // ── Live subscriptions ────────────────────────────────────────────────────
    fun subscribeDeviceState(
        context:         Context,
        nodeId:          Long,
        onUpdate:        (nodeId: Long, attrs: Map<String, Any?>) -> Unit,
        onEstablished:   (nodeId: Long) -> Unit,
        onResubscribing: (nodeId: Long, nextMs: Long) -> Unit,
        onError:         (nodeId: Long, error: Exception) -> Unit,
    ) = SubscriptionManager.subscribeDeviceState(
        context, nodeId, onUpdate, onEstablished, onResubscribing, onError,
    )

    // ── Cluster inspector (wildcard read) ─────────────────────────────────────
    suspend fun readAllClusters(context: Context, nodeId: Long) =
        ClusterInspector.readAllClusters(context, nodeId)
}
