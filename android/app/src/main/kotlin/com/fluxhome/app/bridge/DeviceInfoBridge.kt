package com.fluxhome.app.bridge

import android.util.Log
import com.fluxhome.app.chip.ChipClient
import com.fluxhome.app.chip.MatterCommissionableScanner
import com.fluxhome.app.chip.clusters.BasicInfoCluster
import com.fluxhome.app.chip.clusters.DescriptorCluster
import com.fluxhome.app.chip.clusters.IdentifyCluster
import io.flutter.plugin.common.MethodChannel

private const val TAG = "DeviceInfoBridge"

class DeviceInfoBridge(private val core: BridgeCore) {

    fun readBasicInfo(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val info = BasicInfoCluster.readBasicInfo(core.context, nodeId)
            core.main.post {
                result.success(mapOf(
                    "productName"        to (info.productName       ?: ""),
                    "vendorName"         to (info.vendorName        ?: ""),
                    "vendorId"           to (info.vendorId          ?: ""),
                    "productId"          to (info.productId         ?: ""),
                    "hwVersion"          to (info.hwVersion         ?: ""),
                    "softwareVersion"    to (info.swVersion         ?: ""),
                    "softwareVersionNum" to (info.swVersionNum      ?: -1),
                    "manufacturingDate"  to (info.manufacturingDate ?: ""),
                    "partNumber"         to (info.partNumber        ?: ""),
                    "productUrl"         to (info.productUrl        ?: ""),
                    "serialNumber"       to (info.serialNumber      ?: ""),
                    "uniqueId"           to (info.uniqueId          ?: ""),
                ))
            }
        }

    fun readServerClusterList(nodeId: Long, endpoint: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            val ids = DescriptorCluster.readServerClusterList(core.context, nodeId, endpoint = endpoint)
            core.main.post { result.success(ids.map { it.toInt() }) }
        }

    fun readPartsList(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val ids = DescriptorCluster.readPartsList(core.context, nodeId)
            core.main.post { result.success(ids) }
        }

    fun readDeviceType(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val typeId = readPrimaryDeviceType(core.context, nodeId)
            core.main.post { result.success(typeId) }
        }

    fun identify(nodeId: Long, seconds: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            IdentifyCluster.sendIdentify(core.context, nodeId, seconds)
            core.main.post { result.success(null) }
        }

    fun getFabricId(result: MethodChannel.Result) {
        if (!ChipClient.isAvailable) { result.success("N/A"); return }
        val id = ChipClient.fabricId
        result.success("0x${id.toULong().toString(16).padStart(16, '0').uppercase()}")
    }

    fun getVendorId(result: MethodChannel.Result) {
        result.success(ChipClient.VENDOR_ID)
    }

    /**
     * Discovers commissionable Matter devices on the local network via DNS-SD
     * (_matterc._udp).  Fires the mDNS query, waits [scanMs] milliseconds for
     * responses, then collects all results via [ChipDeviceController.getDiscoveredDevice].
     *
     * Returns a JSON array where each entry is a flat map with:
     *   discriminator, ipAddress, port, deviceType, vendorId, productId,
     *   commissioningMode (enum name), deviceName, instanceName.
     */
    fun discoverCommissionableNodes(result: MethodChannel.Result, scanMs: Long = 5_000L) =
        core.requireChip(result) {
            Log.i(TAG, "discoverCommissionableNodes: scanning via NsdManager…")
            val devices = MatterCommissionableScanner.scan(core.context)
            Log.i(TAG, "discoverCommissionableNodes: found ${devices.size} device(s)")
            val mapped = devices.map { d ->
                mapOf(
                    "discriminator"     to d.discriminator,
                    "ipAddress"         to d.ipAddress,
                    "port"              to d.port,
                    "deviceType"        to d.deviceType,
                    "vendorId"          to d.vendorId,
                    "productId"         to d.productId,
                    "commissioningMode" to d.commissioningMode,
                    "deviceName"        to d.deviceName,
                    "instanceName"      to d.instanceName,
                )
            }
            core.main.post { result.success(mapped) }
        }
}
