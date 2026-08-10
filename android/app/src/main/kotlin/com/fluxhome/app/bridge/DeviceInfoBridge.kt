package com.fluxhome.app.bridge

import android.util.Log
import com.fluxhome.app.chip.ChipClient
import com.fluxhome.app.chip.clusters.BasicInfoCluster
import com.fluxhome.app.chip.clusters.DescriptorCluster
import com.fluxhome.app.chip.clusters.IdentifyCluster
import com.fluxhome.app.chip.clusters.OperationalCredentialsCluster
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

    fun readFabrics(nodeId: Long, result: MethodChannel.Result) =
        core.requireChip(result) {
            val fabrics = OperationalCredentialsCluster.readFabrics(core.context, nodeId)
            core.main.post {
                result.success(fabrics.map { f ->
                    mapOf(
                        "fabricIndex" to f.fabricIndex,
                        "fabricId"    to "0x%016X".format(f.fabricId),
                        "nodeId"      to "0x%016X".format(f.nodeId),
                        "vendorId"    to "0x%04X".format(f.vendorId),
                        "label"       to f.label,
                    )
                })
            }
        }

    fun removeFabric(nodeId: Long, fabricIndex: Int, result: MethodChannel.Result) =
        core.requireChip(result) {
            OperationalCredentialsCluster.removeFabric(core.context, nodeId, fabricIndex)
            core.main.post { result.success(true) }
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

}
