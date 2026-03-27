package com.example.matter_home.chip.clusters

import com.example.matter_home.chip.ChipClient

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.BasicInformation
import chip.devicecontroller.ReportCallback
import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.NodeState
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "BasicInfoCluster"

data class BasicInfo(
    val productName:       String?,
    val vendorName:        String?,
    val vendorId:          String?,    // pre-formatted "0xXXXX"
    val productId:         String?,    // pre-formatted "0xXXXX"
    val hwVersion:         String?,
    val swVersion:         String?,
    val swVersionNum:      Int?,       // uint32 SoftwareVersion (for DCL comparison)
    val manufacturingDate: String?,
    val partNumber:        String?,
    val productUrl:        String?,
    val serialNumber:      String?,
    val uniqueId:          String?,
) {
    companion object {
        val EMPTY = BasicInfo(null,null,null,null,null,null,null,null,null,null,null,null)
    }
}

internal object BasicInfoCluster {

    suspend fun readBasicInfo(context: Context, nodeId: Long): BasicInfo {
        val ptr   = ChipClient.getConnectedDevicePointer(context, nodeId)
        val paths = listOf(
            attr(BasicInformation.Attribute.VendorName.id),
            attr(BasicInformation.Attribute.VendorID.id),
            attr(BasicInformation.Attribute.ProductName.id),
            attr(BasicInformation.Attribute.ProductID.id),
            attr(BasicInformation.Attribute.HardwareVersionString.id),
            attr(BasicInformation.Attribute.SoftwareVersion.id),
            attr(BasicInformation.Attribute.SoftwareVersionString.id),
            attr(BasicInformation.Attribute.ManufacturingDate.id),
            attr(BasicInformation.Attribute.PartNumber.id),
            attr(BasicInformation.Attribute.ProductURL.id),
            attr(BasicInformation.Attribute.SerialNumber.id),
            attr(BasicInformation.Attribute.UniqueID.id),
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
                        Log.e(TAG, "readBasicInfo error", ex)
                        if (cont.isActive) cont.resume(BasicInfo.EMPTY)
                    }
                    override fun onReport(state: NodeState?) { if (state != null) lastState = state }
                    override fun onDone() {
                        val c = lastState?.getEndpointState(0)?.getClusterState(BasicInformation.ID)
                        fun str(id: Long) = c?.getAttributeState(id)?.getValue() as? String
                        fun num(id: Long) = c?.getAttributeState(id)?.getValue()
                            ?.let { (it as? Number)?.toInt() }
                        fun hex(id: Long) = num(id)?.let { "0x%04X".format(it) }
                        val info = BasicInfo(
                            productName       = str(BasicInformation.Attribute.ProductName.id),
                            vendorName        = str(BasicInformation.Attribute.VendorName.id),
                            vendorId          = hex(BasicInformation.Attribute.VendorID.id),
                            productId         = hex(BasicInformation.Attribute.ProductID.id),
                            hwVersion         = str(BasicInformation.Attribute.HardwareVersionString.id),
                            swVersion         = str(BasicInformation.Attribute.SoftwareVersionString.id),
                            swVersionNum      = num(BasicInformation.Attribute.SoftwareVersion.id),
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

    private fun attr(attrId: Long) =
        ChipAttributePath.newInstance(0, BasicInformation.ID, attrId)
}
