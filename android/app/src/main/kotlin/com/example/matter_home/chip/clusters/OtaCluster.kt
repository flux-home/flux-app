package com.example.matter_home.chip.clusters

import com.example.matter_home.chip.ChipClient

import android.content.Context
import android.util.Log
import chip.devicecontroller.ClusterIDMapping.OtaSoftwareUpdateRequestor
import chip.devicecontroller.WriteAttributesCallback
import chip.devicecontroller.model.AttributeWriteRequest
import chip.devicecontroller.model.InvokeElement
import matter.tlv.AnonymousTag
import matter.tlv.ContextSpecificTag
import matter.tlv.TlvWriter
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "OtaCluster"

internal object OtaCluster {

    /**
     * Sends AnnounceOTAProvider (cluster 0x002A, command 0x00) to [requestorEndpoint]
     * of [nodeId], telling the device to query [providerNodeId] for a firmware update.
     *
     * AnnouncementReason 1 = UpdateAvailable (highest priority).
     *
     * TLV field types per Matter spec §11.19.7.6.1:
     *   0  ProviderNodeID     — uint64 (node-id)
     *   1  VendorID           — uint16
     *   2  AnnouncementReason — enum8 = uint8
     *   3  MetadataForNode    — optional, omitted
     *   4  Endpoint           — uint16 (endpoint on the provider node)
     */
    suspend fun announceOtaProvider(
        context:            Context,
        nodeId:             Long,
        providerNodeId:     Long,
        vendorId:           Int,
        requestorEndpoint:  Int = 0,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter()
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(0), providerNodeId.toULong()) // ProviderNodeID — uint64
            .put(ContextSpecificTag(1), vendorId.toUShort())      // VendorID        — uint16
            .put(ContextSpecificTag(2), 1.toUByte())              // AnnouncementReason — enum8
            // Field 3 (MetadataForNode) omitted — optional
            .put(ContextSpecificTag(4), 0.toUShort())             // Endpoint on provider — uint16
            .endStructure()
            .getEncoded()
        val element = InvokeElement.newInstance(
            requestorEndpoint,
            OtaSoftwareUpdateRequestor.ID,
            OtaSoftwareUpdateRequestor.Command.AnnounceOTAProvider.id,
            tlv, null,
        )
        invoke(context, ptr, element)
        Log.d(TAG, "AnnounceOTAProvider → nodeId=$nodeId ep=$requestorEndpoint providerNodeId=$providerNodeId")
    }

    /**
     * Writes the DefaultOTAProviders attribute (0x0000) on the OTA Requestor
     * cluster (EP0), registering [providerNodeId] as the sole provider.
     *
     * Used as a fallback when [announceOtaProvider] returns UNSUPPORTED_COMMAND.
     * The device's background OTA polling will then contact our provider.
     *
     * ProviderLocationStruct TLV fields:
     *   0   providerNodeID — uint64
     *   1   endpoint       — uint16  (0 = provider lives on EP0)
     *   254 fabricIndex    — uint8   (omitted; device fills from request fabric)
     */
    suspend fun writeDefaultOtaProviders(
        context:        Context,
        nodeId:         Long,
        providerNodeId: Long,
    ) {
        val ptr = ChipClient.getConnectedDevicePointer(context, nodeId)
        val tlv = TlvWriter()
            .startArray(AnonymousTag)
            .startStructure(AnonymousTag)
            .put(ContextSpecificTag(0), providerNodeId)
            .put(ContextSpecificTag(1), 0.toUInt())
            .endStructure()
            .endArray()
            .getEncoded()
        val req = AttributeWriteRequest.newInstance(
            0,
            OtaSoftwareUpdateRequestor.ID,
            OtaSoftwareUpdateRequestor.Attribute.DefaultOTAProviders.id,
            tlv,
        )
        suspendCancellableCoroutine<Unit> { cont ->
            ChipClient.getController().write(
                object : WriteAttributesCallback {
                    override fun onError(
                        path: chip.devicecontroller.model.ChipAttributePath?,
                        ex: Exception,
                    ) {
                        Log.e(TAG, "writeDefaultOtaProviders onError", ex)
                        if (cont.isActive) cont.resumeWithException(ex)
                    }
                    override fun onResponse(
                        path:   chip.devicecontroller.model.ChipAttributePath?,
                        status: chip.devicecontroller.model.Status?,
                    ) {
                        val ok = status == null ||
                                 status.toString().contains("Success", ignoreCase = true)
                        if (!ok && cont.isActive)
                            cont.resumeWithException(Exception("Write rejected: $status"))
                    }
                    override fun onDone() { if (cont.isActive) cont.resume(Unit) }
                },
                ptr, listOf(req), 0, 0,
            )
        }
        Log.d(TAG, "DefaultOTAProviders written → nodeId=$nodeId providerNodeId=$providerNodeId")
    }
}
