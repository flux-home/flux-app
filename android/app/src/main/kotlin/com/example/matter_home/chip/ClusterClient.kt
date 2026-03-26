package com.example.matter_home.chip

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping
import chip.devicecontroller.ClusterIDMapping.AirQuality
import chip.devicecontroller.ClusterIDMapping.BasicInformation
import chip.devicecontroller.ClusterIDMapping.BooleanState
import chip.devicecontroller.ClusterIDMapping.Identify
import chip.devicecontroller.ClusterIDMapping.Descriptor
import chip.devicecontroller.ClusterIDMapping.LevelControl
import chip.devicecontroller.ClusterIDMapping.OccupancySensing
import chip.devicecontroller.ClusterIDMapping.OnOff
import chip.devicecontroller.ClusterIDMapping.PowerSource
import chip.devicecontroller.ClusterIDMapping.RelativeHumidityMeasurement
import chip.devicecontroller.ClusterIDMapping.TemperatureMeasurement
import chip.devicecontroller.ClusterIDMapping.Thermostat
import chip.devicecontroller.ClusterIDMapping.ThreadNetworkDiagnostics
import chip.devicecontroller.InvokeCallback
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.ResubscriptionAttemptCallback
import chip.devicecontroller.SubscriptionEstablishedCallback
import chip.devicecontroller.WriteAttributesCallback
import chip.devicecontroller.model.AttributeWriteRequest
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.ChipPathId
import chip.devicecontroller.model.InvokeElement
import chip.devicecontroller.model.NodeState
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvReader
import matter.tlv.TlvWriter
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * High-level Matter cluster client.
 *
 * Uses the modern invoke / readPath / subscribeToPath API (same as CHIPTool's
 * OnOffClientFragment) rather than the older generated ChipClusters.*  classes.
 * All operations establish a CASE session via [ChipClient.getConnectedDevicePointer].
 */
object ClusterClient {

    private const val TAG         = "ClusterClient"
    private const val ENDPOINT_1  = 1   // standard on/off endpoint for lighting / plugs

    // ── On / Off ─────────────────────────────────────────────────────────────

    /** Sends an OnOff cluster On or Off command to [nodeId]. */
    suspend fun setOnOff(context: Context, nodeId: Long, on: Boolean, endpoint: Int = ENDPOINT_1) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val cmdId = if (on) OnOff.Command.On.id else OnOff.Command.Off.id
        val element = InvokeElement.newInstance(endpoint, OnOff.ID, cmdId, null, null)
        invoke(context, ptr, element)
        Log.d(TAG, "OnOff ${if (on) "On" else "Off"} → nodeId=$nodeId ep=$endpoint")
    }

    /**
     * Reads the OnOff attribute from [nodeId].
     * Returns `false` if the attribute cannot be read.
     */
    suspend fun readOnOff(
        context: Context,
        nodeId: Long,
        endpoint: Int = ENDPOINT_1,
    ): Boolean {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(endpoint, OnOff.ID, OnOff.Attribute.OnOff.id)
        return suspendCancellableCoroutine { cont ->
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        attributePath: chip.devicecontroller.model.ChipAttributePath?,
                        eventPath: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "readOnOff error", ex)
                        cont.resumeWithException(ex)
                    }

                    override fun onReport(state: NodeState?) {
                        val tlv = state
                            ?.getEndpointState(endpoint)
                            ?.getClusterState(OnOff.ID)
                            ?.getAttributeState(OnOff.Attribute.OnOff.id)
                            ?.tlv
                        val value = tlv?.let { TlvReader(it).getBool(AnonymousTag) } ?: false
                        Log.d(TAG, "readOnOff → $value (nodeId=$nodeId)")
                        if (cont.isActive) cont.resume(value)
                    }
                },
                ptr,
                listOf(path),
                null,
                false,
                0,
            )
        }
    }

    /**
     * Subscribes to the OnOff attribute, calling [onValue] whenever it changes.
     * The subscription lives until the [context] scope is cancelled.
     */
    fun subscribeOnOff(
        context: Context,
        nodeId: Long,
        endpoint: Int = ENDPOINT_1,
        minIntervalSec: Int = 1,
        maxIntervalSec: Int = 10,
        onValue: (Boolean) -> Unit,
        onError: (Exception) -> Unit,
    ) {
        val path = ChipAttributePath.newInstance(endpoint, OnOff.ID, OnOff.Attribute.OnOff.id)
        ChipClient.getController().also { ctrl ->
            ctrl.getConnectedDevicePointer(nodeId,
                object : chip.devicecontroller.GetConnectedDeviceCallbackJni.GetConnectedDeviceCallback {
                    override fun onDeviceConnected(ptr: Long) {
                        ctrl.subscribeToPath(
                            SubscriptionEstablishedCallback { id ->
                                Log.d(TAG, "OnOff subscription established subscriptionId=$id")
                            },
                            ResubscriptionAttemptCallback { cause, next ->
                                Log.d(TAG, "OnOff resubscription: cause=$cause nextMs=$next")
                            },
                            object : ReportCallback {
                                override fun onError(a: chip.devicecontroller.model.ChipAttributePath?, e: chip.devicecontroller.model.ChipEventPath?, ex: Exception) = onError(ex)
                                override fun onReport(state: NodeState?) {
                                    val tlv = state
                                        ?.getEndpointState(endpoint)
                                        ?.getClusterState(OnOff.ID)
                                        ?.getAttributeState(OnOff.Attribute.OnOff.id)?.tlv
                                    tlv?.let { onValue(TlvReader(it).getBool(AnonymousTag)) }
                                }
                            },
                            ptr,
                            listOf(path),
                            null,
                            minIntervalSec,
                            maxIntervalSec,
                            false,  // keepSubscriptions
                            false,  // isFabricFiltered
                            0,      // imTimeoutMs
                        )
                    }
                    override fun onConnectionFailure(nodeId: Long, error: Exception) = onError(error)
                })
        }
    }

    // ── Level Control ─────────────────────────────────────────────────────────

    /**
     * Sends a LevelControl MoveToLevel command.
     * [level] is 0–254 (Matter spec §3.10).
     */
    suspend fun moveToLevel(
        context: Context,
        nodeId: Long,
        level: Int,
        endpoint: Int = ENDPOINT_1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.Level.id), level.toUInt())
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.TransitionTime.id), 0u)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.OptionsMask.id), 0u)
            .put(ContextSpecificTag(LevelControl.MoveToLevelCommandField.OptionsOverride.id), 0u)
            .endStructure()
            .getEncoded()
        val element = InvokeElement.newInstance(
            endpoint, LevelControl.ID, LevelControl.Command.MoveToLevel.id, tlv, null,
        )
        invoke(context, ptr, element)
        Log.d(TAG, "MoveToLevel $level → nodeId=$nodeId ep=$endpoint")
    }

    // ── Identify ──────────────────────────────────────────────────────────────

    /**
     * Sends the Identify command to endpoint 1.
     * [seconds] is the identify time (0 stops an in-progress identify).
     */
    suspend fun sendIdentify(
        context: Context,
        nodeId: Long,
        seconds: Int = 15,
        endpoint: Int = ENDPOINT_1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(0x00), seconds.toUShort())
            .endStructure()
            .getEncoded()
        val element = InvokeElement.newInstance(
            endpoint, Identify.ID, Identify.Command.Identify.id, tlv, null,
        )
        invoke(context, ptr, element)
        Log.d(TAG, "Identify seconds=$seconds → nodeId=$nodeId ep=$endpoint")
    }

    // ── Generic invoke ────────────────────────────────────────────────────────

    private suspend fun invoke(context: Context, devicePointer: Long, element: InvokeElement) =
        suspendCancellableCoroutine<Unit> { cont ->
            ChipClient.getController().invoke(
                object : InvokeCallback {
                    override fun onError(ex: Exception?) {
                        Log.e(TAG, "invoke error", ex)
                        if (cont.isActive) cont.resumeWithException(
                            ex ?: Exception("invoke failed")
                        )
                    }
                    override fun onResponse(el: InvokeElement?, code: Long) {
                        Log.d(TAG, "invoke success code=$code")
                        if (cont.isActive) cont.resume(Unit)
                    }
                },
                devicePointer,
                element,
                0,
                0,
            )
        }

    // ── Descriptor cluster — device type list ─────────────────────────────────

    /**
     * Reads the DeviceTypeList attribute (cluster 0x001D, attribute 0x0000) from
     * endpoint 0 (root) and returns all device-type IDs the device advertises.
     *
     * The TLV is a list of DeviceTypeStruct { deviceType: uint32, revision: uint16 }.
     * Returns an empty list on any error so callers can fall back to a default.
     */
    suspend fun readDeviceTypes(
        context: Context,
        nodeId: Long,
        endpoint: Int = 0,
    ): List<Int> {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            endpoint,
            Descriptor.ID,
            Descriptor.Attribute.DeviceTypeList.id,
        )
        return suspendCancellableCoroutine { cont ->
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        attributePath: chip.devicecontroller.model.ChipAttributePath?,
                        eventPath: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "readDeviceTypes error", ex)
                        if (cont.isActive) cont.resume(emptyList())
                    }

                    override fun onReport(state: NodeState?) {
                        val tlv = state
                            ?.getEndpointState(endpoint)
                            ?.getClusterState(Descriptor.ID)
                            ?.getAttributeState(Descriptor.Attribute.DeviceTypeList.id)
                            ?.tlv

                        if (tlv == null) {
                            if (cont.isActive) cont.resume(emptyList())
                            return
                        }

                        val types = mutableListOf<Int>()
                        Log.d(TAG, "DeviceTypeList TLV bytes (${tlv.size}): " +
                            tlv.take(32).joinToString(" ") { "%02X".format(it) })
                        try {
                            val reader = TlvReader(tlv)
                            // Attribute value is encoded as TLV Array (0x16) with AnonymousTag
                            reader.enterArray(AnonymousTag)
                            while (!reader.isEndOfContainer()) {
                                reader.enterStructure(AnonymousTag)
                                // Field 0 = device_type (uint32), field 1 = revision
                                // Must use getULong — device type IDs are unsigned and getLong
                                // rejects UnsignedIntValue (e.g. 0x0301 = thermostat)
                                val typeId = reader.getULong(ContextSpecificTag(0)).toInt()
                                types.add(typeId)
                                // skip revision (field 1) and any extras
                                while (!reader.isEndOfContainer()) reader.skipElement()
                                reader.exitContainer()
                            }
                            reader.exitContainer()
                        } catch (e: Exception) {
                            Log.w(TAG, "DeviceTypeList TLV parse error: ${e.message}", e)
                        }

                        if (cont.isActive) cont.resume(types)
                    }
                },
                ptr,
                listOf(path),
                null,
                false,
                0,
            )
        }
    }

    // ── Basic Information cluster ─────────────────────────────────────────────

    data class BasicInfo(
        val productName:      String?,
        val vendorName:       String?,
        val vendorId:         String?,   // pre-formatted "0xXXXX"
        val productId:        String?,   // pre-formatted "0xXXXX"
        val hwVersion:        String?,
        val swVersion:        String?,
        val manufacturingDate:String?,
        val partNumber:       String?,
        val productUrl:       String?,
        val serialNumber:     String?,
        val uniqueId:         String?,
    )

    suspend fun readBasicInfo(context: Context, nodeId: Long): BasicInfo {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val paths = listOf(
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.VendorName.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.VendorID.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.ProductName.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.ProductID.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.HardwareVersionString.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.SoftwareVersionString.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.ManufacturingDate.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.PartNumber.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.ProductURL.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.SerialNumber.id),
            ChipAttributePath.newInstance(0, BasicInformation.ID, BasicInformation.Attribute.UniqueID.id),
        )
        return suspendCancellableCoroutine { cont ->
            var lastState: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(a: chip.devicecontroller.model.ChipAttributePath?, e: chip.devicecontroller.model.ChipEventPath?, ex: Exception) {
                        Log.e(TAG, "readBasicInfo error", ex)
                        if (cont.isActive) cont.resume(BasicInfo(null,null,null,null,null,null,null,null,null,null,null))
                    }
                    override fun onReport(state: NodeState?) { if (state != null) lastState = state }
                    override fun onDone() {
                        val cluster = lastState?.getEndpointState(0)?.getClusterState(BasicInformation.ID)
                        fun str(id: Long) = cluster?.getAttributeState(id)?.getValue()?.let { it as? String }
                        fun num(id: Long) = cluster?.getAttributeState(id)?.getValue()?.let { (it as? Number)?.toInt() }
                        fun fmtId(v: Int?) = if (v != null) "0x%04X".format(v) else null
                        val info = BasicInfo(
                            productName       = str(BasicInformation.Attribute.ProductName.id),
                            vendorName        = str(BasicInformation.Attribute.VendorName.id),
                            vendorId          = fmtId(num(BasicInformation.Attribute.VendorID.id)),
                            productId         = fmtId(num(BasicInformation.Attribute.ProductID.id)),
                            hwVersion         = str(BasicInformation.Attribute.HardwareVersionString.id),
                            swVersion         = str(BasicInformation.Attribute.SoftwareVersionString.id),
                            manufacturingDate = str(BasicInformation.Attribute.ManufacturingDate.id),
                            partNumber        = str(BasicInformation.Attribute.PartNumber.id),
                            productUrl        = str(BasicInformation.Attribute.ProductURL.id),
                            serialNumber      = str(BasicInformation.Attribute.SerialNumber.id),
                            uniqueId          = str(BasicInformation.Attribute.UniqueID.id),
                        )
                        Log.d(TAG, "readBasicInfo $info")
                        if (cont.isActive) cont.resume(info)
                    }
                },
                ptr, paths, null, false, 0,
            )
        }
    }

    // ── Thermostat cluster ────────────────────────────────────────────────────

    /**
     * Reads LocalTemperature, OccupiedHeatingSetpoint, OccupiedCoolingSetpoint,
     * SystemMode and ControlSequenceOfOperation from the Thermostat cluster.
     * All temperatures are in centidegrees (0.01 °C units); divide by 100 for °C.
     * Returns a map with nullable Int values for each key.
     */
    suspend fun readThermostat(
        context: Context,
        nodeId: Long,
        endpoint: Int = ENDPOINT_1,
    ): Map<String, Int?> {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val paths = listOf(
            ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.LocalTemperature.id),
            ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.OccupiedHeatingSetpoint.id),
            ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.OccupiedCoolingSetpoint.id),
            ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.SystemMode.id),
            ChipAttributePath.newInstance(endpoint, Thermostat.ID, Thermostat.Attribute.ControlSequenceOfOperation.id),
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
                    override fun onReport(state: NodeState?) {
                        if (state != null) lastState = state
                    }
                    override fun onDone() {
                        val cluster = lastState
                            ?.getEndpointState(endpoint)
                            ?.getClusterState(Thermostat.ID)
                        // Returns Int? — maps 0x8000 (Matter nullable int16 null sentinel) to null
                        fun attr(id: Long): Int? {
                            val v = cluster?.getAttributeState(id)?.getValue()
                                ?.let { (it as? Number)?.toInt() }
                                ?: return null
                            // LocalTemperature null sentinel per Matter spec §4.3.9.3
                            if (v == 0x8000) return null
                            return v
                        }
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
     * Writes [centidegrees] (int16, 0.01 °C units) to OccupiedHeatingSetpoint.
     * E.g. pass 2100 to set 21.00 °C.
     */
    suspend fun writeHeatingSetpoint(
        context: Context,
        nodeId: Long,
        centidegrees: Int,
        endpoint: Int = ENDPOINT_1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        // OccupiedHeatingSetpoint is int16 — encode as signed short TLV
        val tlv = TlvWriter().put(AnonymousTag, centidegrees.toShort()).getEncoded()
        val req = AttributeWriteRequest.newInstance(
            endpoint,
            Thermostat.ID,
            Thermostat.Attribute.OccupiedHeatingSetpoint.id,
            tlv,
        )
        suspendCancellableCoroutine<Unit> { cont ->
            ChipClient.getController().write(
                object : WriteAttributesCallback {
                    override fun onError(path: chip.devicecontroller.model.ChipAttributePath?, ex: Exception) {
                        Log.e(TAG, "writeHeatingSetpoint error", ex)
                        if (cont.isActive) cont.resumeWithException(ex)
                    }
                    override fun onResponse(path: chip.devicecontroller.model.ChipAttributePath?, status: chip.devicecontroller.model.Status?) {
                        Log.d(TAG, "writeHeatingSetpoint response status=$status")
                    }
                    override fun onDone() {
                        if (cont.isActive) cont.resume(Unit)
                    }
                },
                ptr,
                listOf(req),
                0,
                0,
            )
        }
        Log.d(TAG, "writeHeatingSetpoint ${centidegrees / 100.0}°C → nodeId=$nodeId ep=$endpoint")
    }

    /**
     * Writes [mode] (uint8 enum) to SystemMode attribute (0x001C).
     * 0=Off 1=Auto 3=Cool 4=Heat 5=EmergencyHeat 7=FanOnly
     */
    suspend fun writeSystemMode(
        context: Context,
        nodeId: Long,
        mode: Int,
        endpoint: Int = ENDPOINT_1,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        // SystemMode is enum8 (uint8) — use putUnsigned so it encodes as unsigned
        val tlv = TlvWriter().putUnsigned(AnonymousTag, mode).getEncoded()
        val req = AttributeWriteRequest.newInstance(
            endpoint,
            Thermostat.ID,
            Thermostat.Attribute.SystemMode.id,
            tlv,
        )
        suspendCancellableCoroutine<Unit> { cont ->
            ChipClient.getController().write(
                object : WriteAttributesCallback {
                    override fun onError(path: chip.devicecontroller.model.ChipAttributePath?, ex: Exception) {
                        Log.e(TAG, "writeSystemMode error", ex)
                        if (cont.isActive) cont.resumeWithException(ex)
                    }
                    override fun onResponse(path: chip.devicecontroller.model.ChipAttributePath?, status: chip.devicecontroller.model.Status?) {
                        Log.d(TAG, "writeSystemMode response status=$status")
                    }
                    override fun onDone() {
                        if (cont.isActive) cont.resume(Unit)
                    }
                },
                ptr, listOf(req), 0, 0,
            )
        }
        Log.d(TAG, "writeSystemMode mode=$mode → nodeId=$nodeId ep=$endpoint")
    }

    // ── Power Source cluster — battery level ──────────────────────────────────

    /**
     * Reads all attributes from the Power Source cluster (0x002F) using wildcard
     * endpoint and wildcard attribute, so we discover whatever the device exposes.
     *
     * Returns a map with any subset of:
     *   "percent"     → 0–100 (from BatPercentRemaining 0x000C, raw 0–200 ÷ 2)
     *   "chargeLevel" → 0=OK  1=Warning  2=Critical  (from BatChargeLevel 0x000E)
     *   "voltageMilliV" → mV  (from BatVoltage 0x000B)
     *
     * Returns an empty map when the cluster is absent.
     */
    suspend fun readBattery(
        context: Context,
        nodeId: Long,
    ): Map<String, Int> {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            ChipPathId.forWildcard(),                 // any endpoint
            ChipPathId.forId(PowerSource.ID),         // Power Source cluster
            ChipPathId.forWildcard(),                 // all attributes
        )
        return suspendCancellableCoroutine { cont ->
            var lastState: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        attributePath: chip.devicecontroller.model.ChipAttributePath?,
                        eventPath: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.w(TAG, "readBattery not available: ${ex.message}")
                        if (cont.isActive) cont.resume(emptyMap())
                    }

                    override fun onReport(state: NodeState?) {
                        if (state != null) lastState = state
                    }

                    override fun onDone() {
                        val result = mutableMapOf<String, Int>()
                        lastState?.getEndpointStates()?.values?.forEach { ep ->
                            val cluster = ep.getClusterState(PowerSource.ID) ?: return@forEach
                            fun intAttr(id: Long) = cluster.getAttributeState(id)
                                ?.getValue()?.let { (it as? Number)?.toInt() }

                            intAttr(PowerSource.Attribute.BatPercentRemaining.id)
                                ?.takeIf { it in 0..200 }
                                ?.let { result["percent"] = it / 2 }

                            intAttr(PowerSource.Attribute.BatChargeLevel.id)
                                ?.takeIf { it in 0..2 }
                                ?.let { result["chargeLevel"] = it }

                            intAttr(PowerSource.Attribute.BatVoltage.id)
                                ?.takeIf { it > 0 }
                                ?.let { result["voltageMilliV"] = it }
                        }
                        Log.d(TAG, "readBattery → $result")
                        if (cont.isActive) cont.resume(result)
                    }
                },
                ptr,
                listOf(path),
                null,
                false,
                0,
            )
        }
    }

    // ── Relative Humidity Measurement cluster ─────────────────────────────────

    /**
     * Reads MeasuredValue (0x0000) from the Relative Humidity Measurement
     * cluster (0x0405) using a wildcard endpoint, so it works regardless of
     * which endpoint the device places the humidity sensor on.
     *
     * The value is in units of 0.01 % RH (e.g. 5723 = 57.23 %).
     * Returns null when the cluster is absent or reports the null sentinel
     * (0xFFFF per Matter spec §2.6.5).
     */
    suspend fun readHumidity(
        context: Context,
        nodeId: Long,
    ): Int? {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        // Wildcard the endpoint — humidity may live on ep1, ep2, etc.
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
                        attributePath: chip.devicecontroller.model.ChipAttributePath?,
                        eventPath: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.w(TAG, "readHumidity not available: ${ex.message}")
                        if (cont.isActive) cont.resume(null)
                    }

                    override fun onReport(state: NodeState?) {
                        if (state != null) lastState = state
                    }

                    override fun onDone() {
                        val raw = lastState?.getEndpointStates()?.values
                            ?.mapNotNull { ep ->
                                ep.getClusterState(RelativeHumidityMeasurement.ID)
                                    ?.getAttributeState(
                                        RelativeHumidityMeasurement.Attribute.MeasuredValue.id
                                    )
                                    ?.getValue()
                                    ?.let { (it as? Number)?.toInt() }
                            }
                            ?.firstOrNull()
                        val value = if (raw == null || raw == 0xFFFF) null else raw
                        Log.d(TAG, "readHumidity → ${value?.let { "${it / 100.0}%" } ?: "null"}")
                        if (cont.isActive) cont.resume(value)
                    }
                },
                ptr,
                listOf(path),
                null,
                false,
                0,
            )
        }
    }

    // ── Thread Network Diagnostics cluster (0x0035) ───────────────────────────

    /**
     * Reads the Thread Network Diagnostics cluster from endpoint 0.
     *
     * Returns a JSON string shaped as:
     * {
     *   "channel": 15,
     *   "routingRole": 5,
     *   "routingRoleLabel": "Router",
     *   "networkName": "NEST-PAN-26BA",
     *   "panId": 9914,
     *   "extendedPanId": "12f209ab410ad778",
     *   "meshLocalPrefix": "fd12:3456:789a:0001::/64",
     *   "partitionId": 12345,
     *   "weighting": 64,
     *   "leaderRouterId": 0,
     *   "neighbors": [ { extAddress, age, rloc16, lqi, averageRssi, lastRssi,
     *                     frameErrorRate, messageErrorRate, rxOnWhenIdle,
     *                     fullThreadDevice, isChild } ],
     *   "routes":    [ { routerId, rloc16, nextHop, pathCost,
     *                     lqiIn, lqiOut, age, allocated, linkEstablished } ]
     * }
     *
     * Returns `null` if the cluster is absent (Wi-Fi or Ethernet only device).
     */
    suspend fun readThreadNetworkDiagnostics(context: Context, nodeId: Long): String? {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        // Wildcard attributes on endpoint 0 — Thread diag cluster only
        val path = ChipAttributePath.newInstance(
            ChipPathId.forId(0),
            ChipPathId.forId(ThreadNetworkDiagnostics.ID),
            ChipPathId.forWildcard(),
        )
        return suspendCancellableCoroutine { cont ->
            var lastState: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        attributePath: chip.devicecontroller.model.ChipAttributePath?,
                        eventPath:     chip.devicecontroller.model.ChipEventPath?,
                        ex:            Exception,
                    ) {
                        Log.w(TAG, "ThreadNetworkDiagnostics not available: ${ex.message}")
                        if (cont.isActive) cont.resume(null)
                    }
                    override fun onReport(state: NodeState?) {
                        if (state != null) lastState = state
                    }
                    override fun onDone() {
                        val cluster = lastState
                            ?.getEndpointState(0)
                            ?.getClusterState(ThreadNetworkDiagnostics.ID)
                        if (cluster == null) {
                            Log.w(TAG, "ThreadNetworkDiagnostics cluster absent on ep0")
                            if (cont.isActive) cont.resume(null)
                            return
                        }
                        fun intAttr(id: Long): Int? =
                            cluster.getAttributeState(id)?.getValue()
                                ?.let { (it as? Number)?.toInt() }
                        fun longAttr(id: Long): Long? =
                            cluster.getAttributeState(id)?.getValue()
                                ?.let { (it as? Number)?.toLong() }

                        val channel        = intAttr(ThreadNetworkDiagnostics.Attribute.Channel.id)
                        val routingRole    = intAttr(ThreadNetworkDiagnostics.Attribute.RoutingRole.id)
                        val networkName    = cluster.getAttributeState(
                            ThreadNetworkDiagnostics.Attribute.NetworkName.id)?.getValue() as? String
                        val panId          = intAttr(ThreadNetworkDiagnostics.Attribute.PanId.id)
                        val extPanId       = longAttr(ThreadNetworkDiagnostics.Attribute.ExtendedPanId.id)
                            ?.let { "%016x".format(it) }
                        val meshLocalPrefix = cluster.getAttributeState(
                            ThreadNetworkDiagnostics.Attribute.MeshLocalPrefix.id)
                            ?.tlv?.let { parseMeshLocalPrefix(it) }
                        val partitionId    = longAttr(ThreadNetworkDiagnostics.Attribute.PartitionId.id)
                        val weighting      = intAttr(ThreadNetworkDiagnostics.Attribute.Weighting.id)
                        val leaderRouterId = intAttr(ThreadNetworkDiagnostics.Attribute.LeaderRouterId.id)

                        val neighborsTlv = cluster.getAttributeState(
                            ThreadNetworkDiagnostics.Attribute.NeighborTable.id)?.tlv
                        val routesTlv = cluster.getAttributeState(
                            ThreadNetworkDiagnostics.Attribute.RouteTable.id)?.tlv

                        val neighbors = neighborsTlv?.let { parseNeighborTable(it) } ?: emptyList()
                        val routes    = routesTlv?.let    { parseRouteTable(it)    } ?: emptyList()

                        val json = buildThreadDiagJson(
                            channel, routingRole, networkName, panId, extPanId,
                            meshLocalPrefix, partitionId, weighting, leaderRouterId,
                            neighbors, routes,
                        )
                        Log.d(TAG, "ThreadNetworkDiagnostics: $json")
                        if (cont.isActive) cont.resume(json)
                    }
                },
                ptr, listOf(path), null, false, 0,
            )
        }
    }

    // ── Thread diagnostics helpers ────────────────────────────────────────────

    private val routingRoleLabels = mapOf(
        0 to "Unspecified", 1 to "Unassigned",    2 to "Sleepy End Device",
        3 to "End Device",  4 to "REED",           5 to "Router",  6 to "Leader",
    )

    private fun parseMeshLocalPrefix(tlv: ByteArray): String? {
        // MeshLocalPrefix is an octet-string of 8 bytes = IPv6 /64 prefix
        val bytes = try {
            TlvReader(tlv).getByteArray(AnonymousTag)
        } catch (_: Exception) { return null }
        if (bytes.size < 8) return null
        return "%02x%02x:%02x%02x:%02x%02x:%02x%02x::/64".format(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
        )
    }

    /**
     * Parses the NeighborTable list TLV.
     *
     * NeighborTableStruct field tags (Matter spec §11.13.5.1):
     *   0  extAddress       uint64
     *   1  age              uint32   seconds since last communication
     *   2  eid              uint16   (ignored for display)
     *   3  rloc16           uint16   16-bit routing locator
     *   4  linkFrameCounter uint32   (ignored for display)
     *   5  mleFrameCounter  uint32   (ignored for display)
     *   6  lqi              uint8    link quality index 0-255
     *   7  averageRssi      nullable int8   dBm
     *   8  lastRssi         nullable int8   dBm
     *   9  frameErrorRate   uint8    %
     *   10 messageErrorRate uint8    %
     *   11 rxOnWhenIdle     bool
     *   12 fullThreadDevice bool
     *   13 fullNetworkData  bool
     *   14 isChild          bool
     *
     * TlvReader reads sequentially; a failed read (tag mismatch) does NOT advance
     * the reader, so absent optional fields are handled by retrying on the next tag.
     */
    private fun parseNeighborTable(tlv: ByteArray): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        try {
            val r = TlvReader(tlv)
            r.enterArray(AnonymousTag)
            while (!r.isEndOfContainer()) {
                try {
                    r.enterStructure(AnonymousTag)
                    val m = mutableMapOf<String, Any?>()

                    fun ulong(t: Int): Long? = try { r.getULong(ContextSpecificTag(t)).toLong() } catch (_: Exception) { null }
                    fun uint(t: Int): Int?   = try { r.getUInt(ContextSpecificTag(t)).toInt()   } catch (_: Exception) { null }
                    fun bool(t: Int): Boolean? = try { r.getBool(ContextSpecificTag(t)) }         catch (_: Exception) { null }
                    // nullable int8: try as signed byte; if null-type or absent → null
                    fun nullInt8(t: Int): Int? = try { r.getByte(ContextSpecificTag(t)).toInt() } catch (_: Exception) { null }

                    m["extAddress"]       = ulong(0)?.let { "%016x".format(it) }
                    m["age"]              = ulong(1)
                    ulong(2)  // eid — read to advance, not stored
                    m["rloc16"]           = uint(3)
                    ulong(4)  // linkFrameCounter — read to advance
                    ulong(5)  // mleFrameCounter  — read to advance
                    m["lqi"]              = uint(6)
                    m["averageRssi"]      = nullInt8(7)
                    m["lastRssi"]         = nullInt8(8)
                    m["frameErrorRate"]   = uint(9)
                    m["messageErrorRate"] = uint(10)
                    m["rxOnWhenIdle"]     = bool(11)
                    m["fullThreadDevice"] = bool(12)
                    bool(13)  // fullNetworkData — advance only
                    m["isChild"]          = bool(14)

                    while (!r.isEndOfContainer()) r.skipElement()
                    r.exitContainer()
                    result.add(m)
                } catch (e: Exception) {
                    Log.w(TAG, "Skip malformed neighbor entry: ${e.message}")
                    try { while (!r.isEndOfContainer()) r.skipElement(); r.exitContainer() }
                    catch (_: Exception) { break }
                }
            }
            r.exitContainer()
        } catch (e: Exception) {
            Log.w(TAG, "parseNeighborTable error: ${e.message}")
        }
        return result
    }

    /**
     * Parses the RouteTable list TLV.
     *
     * RouteTableStruct field tags (Matter spec §11.13.5.2):
     *   0  extAddress       uint64
     *   1  eid              uint16   (ignored for display)
     *   2  rloc16           uint16
     *   3  routerId         uint8
     *   4  nextHop          uint8    0xFF = no next hop
     *   5  pathCost         uint8
     *   6  LQIIn            uint8
     *   7  LQIOut           uint8
     *   8  age              uint8    seconds (wraps at 255)
     *   9  allocated        bool
     *   10 linkEstablished  bool
     */
    private fun parseRouteTable(tlv: ByteArray): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        try {
            val r = TlvReader(tlv)
            r.enterArray(AnonymousTag)
            while (!r.isEndOfContainer()) {
                try {
                    r.enterStructure(AnonymousTag)
                    val m = mutableMapOf<String, Any?>()

                    fun ulong(t: Int): Long? = try { r.getULong(ContextSpecificTag(t)).toLong() } catch (_: Exception) { null }
                    fun uint(t: Int): Int?   = try { r.getUInt(ContextSpecificTag(t)).toInt()   } catch (_: Exception) { null }
                    fun bool(t: Int): Boolean? = try { r.getBool(ContextSpecificTag(t)) }         catch (_: Exception) { null }

                    ulong(0)  // extAddress — advance only
                    uint(1)   // eid        — advance only
                    m["rloc16"]          = uint(2)
                    m["routerId"]        = uint(3)
                    m["nextHop"]         = uint(4)
                    m["pathCost"]        = uint(5)
                    m["lqiIn"]           = uint(6)
                    m["lqiOut"]          = uint(7)
                    m["age"]             = uint(8)
                    m["allocated"]       = bool(9)
                    m["linkEstablished"] = bool(10)

                    while (!r.isEndOfContainer()) r.skipElement()
                    r.exitContainer()
                    result.add(m)
                } catch (e: Exception) {
                    Log.w(TAG, "Skip malformed route entry: ${e.message}")
                    try { while (!r.isEndOfContainer()) r.skipElement(); r.exitContainer() }
                    catch (_: Exception) { break }
                }
            }
            r.exitContainer()
        } catch (e: Exception) {
            Log.w(TAG, "parseRouteTable error: ${e.message}")
        }
        return result
    }

    private fun buildThreadDiagJson(
        channel:        Int?,
        routingRole:    Int?,
        networkName:    String?,
        panId:          Int?,
        extendedPanId:  String?,
        meshLocalPrefix: String?,
        partitionId:    Long?,
        weighting:      Int?,
        leaderRouterId: Int?,
        neighbors:      List<Map<String, Any?>>,
        routes:         List<Map<String, Any?>>,
    ): String {
        val sb = StringBuilder("{")

        fun optInt(key: String, v: Int?)   { if (v != null) sb.append("\"$key\":$v,") else sb.append("\"$key\":null,") }
        fun optLong(key: String, v: Long?) { if (v != null) sb.append("\"$key\":$v,") else sb.append("\"$key\":null,") }
        fun optStr(key: String, v: String?) {
            if (v != null) sb.append("\"$key\":\"${jsonEscape(v)}\",")
            else sb.append("\"$key\":null,")
        }

        optInt("channel", channel)
        optInt("routingRole", routingRole)
        sb.append("\"routingRoleLabel\":\"${routingRoleLabels[routingRole] ?: "Unknown"}\",")
        optStr("networkName", networkName)
        optInt("panId", panId)
        optStr("extendedPanId", extendedPanId)
        optStr("meshLocalPrefix", meshLocalPrefix)
        optLong("partitionId", partitionId)
        optInt("weighting", weighting)
        optInt("leaderRouterId", leaderRouterId)

        sb.append("\"neighbors\":[")
        neighbors.forEachIndexed { i, n ->
            if (i > 0) sb.append(",")
            sb.append("{")
            fun v(k: String) = n[k]
            fun js(k: String): String = when (val x = v(k)) {
                null    -> "null"
                is Boolean -> x.toString()
                is Number  -> x.toString()
                is String  -> "\"${jsonEscape(x)}\""
                else    -> "null"
            }
            sb.append("\"extAddress\":${js("extAddress")},")
            sb.append("\"age\":${js("age")},")
            sb.append("\"rloc16\":${js("rloc16")},")
            sb.append("\"lqi\":${js("lqi")},")
            sb.append("\"averageRssi\":${js("averageRssi")},")
            sb.append("\"lastRssi\":${js("lastRssi")},")
            sb.append("\"frameErrorRate\":${js("frameErrorRate")},")
            sb.append("\"messageErrorRate\":${js("messageErrorRate")},")
            sb.append("\"rxOnWhenIdle\":${js("rxOnWhenIdle")},")
            sb.append("\"fullThreadDevice\":${js("fullThreadDevice")},")
            sb.append("\"isChild\":${js("isChild")}")
            sb.append("}")
        }
        sb.append("],")

        sb.append("\"routes\":[")
        routes.forEachIndexed { i, r ->
            if (i > 0) sb.append(",")
            sb.append("{")
            fun js(k: String): String = when (val x = r[k]) {
                null       -> "null"
                is Boolean -> x.toString()
                is Number  -> x.toString()
                else       -> "null"
            }
            sb.append("\"rloc16\":${js("rloc16")},")
            sb.append("\"routerId\":${js("routerId")},")
            sb.append("\"nextHop\":${js("nextHop")},")
            sb.append("\"pathCost\":${js("pathCost")},")
            sb.append("\"lqiIn\":${js("lqiIn")},")
            sb.append("\"lqiOut\":${js("lqiOut")},")
            sb.append("\"age\":${js("age")},")
            sb.append("\"allocated\":${js("allocated")},")
            sb.append("\"linkEstablished\":${js("linkEstablished")}")
            sb.append("}")
        }
        sb.append("]}")
        return sb.toString()
    }

    // ── Live subscriptions ────────────────────────────────────────────────────

    /**
     * Subscribes to all "interesting" attributes on [nodeId] and calls back
     * whenever any of them change.
     *
     * [onUpdate]    – map of key→value for changed attributes (see keys below).
     * [onEstablished] – subscription is live; initial data report follows.
     * [onResubscribing] – device unreachable; SDK is retrying (nextMs = backoff).
     * [onError]     – fatal error (session lost, etc.).
     *
     * Subscribed keys: onOff, level, localTempCenti, heatingSetptCenti,
     * coolingSetptCenti, systemMode, controlSequence, humidityCenti,
     * tempMeasureCenti, batPercentRaw (0–200), batChargeLevel, occupancy,
     * contactState.
     */
    fun subscribeDeviceState(
        context: Context,
        nodeId: Long,
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
                                Log.e(TAG, "Subscription report error nodeId=$nodeId: ${ex.message}")
                                onError(nodeId, ex)
                            }
                            override fun onReport(state: NodeState?) {
                                if (state == null) return
                                val attrs = extractSubscribedAttrs(state)
                                if (attrs.isNotEmpty()) onUpdate(nodeId, attrs)
                            }
                        },
                        devicePointer,
                        buildSubscriptionPaths(),
                        null,
                        1,    // minInterval 1 s
                        120,  // maxInterval 120 s
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

    private fun buildSubscriptionPaths(): List<ChipAttributePath> {
        fun wep(clusterId: Long, attrId: Long) = ChipAttributePath.newInstance(
            ChipPathId.forWildcard(), ChipPathId.forId(clusterId), ChipPathId.forId(attrId)
        )
        return listOf(
            wep(OnOff.ID,                        OnOff.Attribute.OnOff.id),
            wep(LevelControl.ID,                 LevelControl.Attribute.CurrentLevel.id),
            wep(Thermostat.ID,                   Thermostat.Attribute.LocalTemperature.id),
            wep(Thermostat.ID,                   Thermostat.Attribute.OccupiedHeatingSetpoint.id),
            wep(Thermostat.ID,                   Thermostat.Attribute.OccupiedCoolingSetpoint.id),
            wep(Thermostat.ID,                   Thermostat.Attribute.SystemMode.id),
            wep(Thermostat.ID,                   Thermostat.Attribute.ControlSequenceOfOperation.id),
            wep(RelativeHumidityMeasurement.ID,  RelativeHumidityMeasurement.Attribute.MeasuredValue.id),
            wep(TemperatureMeasurement.ID,       TemperatureMeasurement.Attribute.MeasuredValue.id),
            wep(PowerSource.ID,                  PowerSource.Attribute.BatPercentRemaining.id),
            wep(PowerSource.ID,                  PowerSource.Attribute.BatChargeLevel.id),
            wep(OccupancySensing.ID,             OccupancySensing.Attribute.Occupancy.id),
            wep(BooleanState.ID,                 BooleanState.Attribute.StateValue.id),
            wep(AirQuality.ID,                   AirQuality.Attribute.AirQuality.id),
        )
    }

    private fun extractSubscribedAttrs(state: NodeState): Map<String, Any?> {
        val r = mutableMapOf<String, Any?>()
        state.getEndpointStates().values.forEach { ep ->
            ep.getClusterState(OnOff.ID)
                ?.getAttributeState(OnOff.Attribute.OnOff.id)
                ?.getValue()?.let { r["onOff"] = it }

            ep.getClusterState(LevelControl.ID)
                ?.getAttributeState(LevelControl.Attribute.CurrentLevel.id)
                ?.getValue()?.let { r["level"] = (it as? Number)?.toInt() }

            ep.getClusterState(Thermostat.ID)?.also { t ->
                fun intAttr(id: Long) = t.getAttributeState(id)?.getValue()
                    ?.let { (it as? Number)?.toInt() }
                intAttr(Thermostat.Attribute.LocalTemperature.id)       ?.let { r["localTempCenti"]    = it }
                intAttr(Thermostat.Attribute.OccupiedHeatingSetpoint.id)?.let { r["heatingSetptCenti"] = it }
                intAttr(Thermostat.Attribute.OccupiedCoolingSetpoint.id)?.let { r["coolingSetptCenti"] = it }
                intAttr(Thermostat.Attribute.SystemMode.id)             ?.let { r["systemMode"]        = it }
                intAttr(Thermostat.Attribute.ControlSequenceOfOperation.id)?.let { r["controlSequence"] = it }
            }

            ep.getClusterState(RelativeHumidityMeasurement.ID)
                ?.getAttributeState(RelativeHumidityMeasurement.Attribute.MeasuredValue.id)
                ?.getValue()?.let { r["humidityCenti"] = (it as? Number)?.toInt() }

            ep.getClusterState(TemperatureMeasurement.ID)
                ?.getAttributeState(TemperatureMeasurement.Attribute.MeasuredValue.id)
                ?.getValue()?.let { r["tempMeasureCenti"] = (it as? Number)?.toInt() }

            ep.getClusterState(PowerSource.ID)?.also { ps ->
                ps.getAttributeState(PowerSource.Attribute.BatPercentRemaining.id)
                    ?.getValue()?.let { r["batPercentRaw"] = (it as? Number)?.toInt() }
                ps.getAttributeState(PowerSource.Attribute.BatChargeLevel.id)
                    ?.getValue()?.let { r["batChargeLevel"] = (it as? Number)?.toInt() }
            }

            ep.getClusterState(OccupancySensing.ID)
                ?.getAttributeState(OccupancySensing.Attribute.Occupancy.id)
                ?.getValue()?.let { r["occupancy"] = (it as? Number)?.toInt() }

            ep.getClusterState(BooleanState.ID)
                ?.getAttributeState(BooleanState.Attribute.StateValue.id)
                ?.getValue()?.let { r["contactState"] = it }

            ep.getClusterState(AirQuality.ID)
                ?.getAttributeState(AirQuality.Attribute.AirQuality.id)
                ?.getValue()?.let { r["airQuality"] = (it as? Number)?.toInt() }
        }
        return r
    }

    // ── Wildcard cluster/attribute read (for Cluster Inspector) ──────────────

    /**
     * Reads ALL attributes from ALL clusters on ALL endpoints using a wildcard
     * path. Returns a JSON string shaped as:
     *   [ { "endpoint": 0,
     *       "clusterId": 40,
     *       "attributes": [ { "id": 1, "value": "tado GmbH" }, … ] }, … ]
     *
     * onReport may be called multiple times with partial data; onDone signals
     * the complete interaction so we resume there.
     */
    suspend fun readAllClusters(context: Context, nodeId: Long): String {
        val ptr  = ChipClient.getConnectedDevicePointer(context, nodeId)
        val path = ChipAttributePath.newInstance(
            ChipPathId.forWildcard(),
            ChipPathId.forWildcard(),
            ChipPathId.forWildcard(),
        )
        return suspendCancellableCoroutine { cont ->
            var accumulated: NodeState? = null
            ChipClient.getController().readPath(
                object : ReportCallback {
                    override fun onError(
                        a: chip.devicecontroller.model.ChipAttributePath?,
                        e: chip.devicecontroller.model.ChipEventPath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "readAllClusters error", ex)
                        if (cont.isActive) cont.resume("[]")
                    }

                    override fun onReport(state: NodeState?) {
                        if (state != null) accumulated = state
                    }

                    override fun onDone() {
                        val json = buildClustersJson(accumulated)
                        if (cont.isActive) cont.resume(json)
                    }
                },
                ptr,
                listOf(path),
                null,
                false,
                0,
            )
        }
    }

    private fun buildClustersJson(state: NodeState?): String {
        if (state == null) return "[]"
        val sb = StringBuilder("[")
        var firstCluster = true
        try {
            state.getEndpointStates().forEach { (epId, epState) ->
                epState.getClusterStates().forEach { (clusterId, clusterState) ->
                    if (!firstCluster) sb.append(",")
                    firstCluster = false
                    sb.append("{\"endpoint\":$epId,\"clusterId\":$clusterId")

                    // For the Descriptor cluster, parse and embed the device type list
                    // so the UI can show human-readable type names per endpoint.
                    if (clusterId == Descriptor.ID) {
                        val dtlTlv = clusterState
                            .getAttributeState(Descriptor.Attribute.DeviceTypeList.id)?.tlv
                        val types = dtlTlv?.let { parseDeviceTypeListTlv(it) } ?: emptyList()
                        sb.append(",\"deviceTypes\":[${types.joinToString(",")}]")
                    }

                    sb.append(",\"attributes\":[")
                    var firstAttr = true
                    clusterState.getAttributeStates().forEach { (attrId, attrState) ->
                        if (!firstAttr) sb.append(",")
                        firstAttr = false
                        val raw = try {
                            val v = attrState.getValue()
                            when (v) {
                                null       -> "null"
                                is Boolean -> v.toString()
                                is Number  -> v.toString()
                                else       -> "\"${jsonEscape(v.toString())}\""
                            }
                        } catch (_: Exception) { "\"?\"" }
                        sb.append("{\"id\":$attrId,\"value\":$raw}")
                    }
                    sb.append("]}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "buildClustersJson error", e)
        }
        sb.append("]")
        return sb.toString()
    }

    /**
     * Parses a DeviceTypeList TLV (array of DeviceTypeStruct { deviceType: uint32, revision: uint16 })
     * and returns the list of device type IDs.
     */
    private fun parseDeviceTypeListTlv(tlv: ByteArray): List<Int> {
        val types = mutableListOf<Int>()
        try {
            val reader = TlvReader(tlv)
            reader.enterArray(AnonymousTag)
            while (!reader.isEndOfContainer()) {
                reader.enterStructure(AnonymousTag)
                val typeId = reader.getULong(ContextSpecificTag(0)).toInt()
                types.add(typeId)
                while (!reader.isEndOfContainer()) reader.skipElement()
                reader.exitContainer()
            }
            reader.exitContainer()
        } catch (e: Exception) {
            Log.w(TAG, "parseDeviceTypeListTlv error: ${e.message}")
        }
        return types
    }

    /** Properly escapes a string for embedding in a JSON double-quoted value. */
    private fun jsonEscape(s: String): String = buildString(s.length + 8) {
        for (c in s) {
            when (c) {
                '\\'     -> append("\\\\")
                '"'      -> append("\\\"")
                '\n'     -> append("\\n")
                '\r'     -> append("\\r")
                '\t'     -> append("\\t")
                '\b'     -> append("\\b")
                '\u000C' -> append("\\f")
                else     -> if (c.code < 0x20) append("\\u%04x".format(c.code)) else append(c)
            }
        }
    }
}
