package com.example.matter_home.chip.clusters

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.BasicInformation
import chip.devicecontroller.model.ChipAttributePath
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

    suspend fun readBasicInfo(context: Context, nodeId: Long): BasicInfo =
        readAttributes(context, nodeId, PATHS, BasicInfo.EMPTY, TAG) { state ->
            val c = state?.getEndpointState(0)?.getClusterState(BasicInformation.ID)
            fun str(id: Long) = c?.getAttributeState(id)?.getValue() as? String
            fun num(id: Long) = c?.getAttributeState(id)?.getValue()?.let { (it as? Number)?.toInt() }
            fun hex(id: Long) = num(id)?.let { "0x%04X".format(it) }
            BasicInfo(
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
            ).also { Log.d(TAG, "readBasicInfo $it") }
        }

    private fun attr(attrId: Long) = ChipAttributePath.newInstance(0, BasicInformation.ID, attrId)

    private val PATHS = listOf(
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
}
