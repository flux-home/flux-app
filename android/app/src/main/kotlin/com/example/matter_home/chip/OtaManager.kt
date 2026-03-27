package com.example.matter_home.chip

import android.util.Log
import chip.devicecontroller.OTAProviderDelegate
import java.io.File
import java.io.RandomAccessFile

/**
 * Implements [OTAProviderDelegate] to serve a locally-downloaded OTA image
 * to a Matter device via the BDX (Bulk Data Exchange) protocol.
 *
 * Lifecycle:
 *   1. Call [configure] with the local firmware path and target version info.
 *   2. Register progress callbacks.
 *   3. The CHIP SDK calls [handleQueryImage], [handleBDXTransferSessionBegin],
 *      [handleBDXQuery] (repeatedly), [handleBDXTransferSessionEnd],
 *      [handleApplyUpdateRequest], and finally [handleNotifyUpdateApplied].
 *   4. Call [reset] after the update completes or is cancelled.
 */
class OtaManager : OTAProviderDelegate {

    private companion object { const val TAG = "OtaManager" }

    @Volatile private var filePath:             String  = ""
    @Volatile private var targetVersion:        Long    = 0L
    @Volatile private var targetVersionString:  String  = ""
    @Volatile private var fileSize:             Long    = 0L
    @Volatile private var dryRun:               Boolean = false
    @Volatile private var notAvailable:         Boolean = false

    private var raf: RandomAccessFile? = null

    // ── Callbacks set by MatterBridge ────────────────────────────────────────

    var onBdxProgress:       ((nodeId: Long, percent: Int) -> Unit)? = null
    var onTransferComplete:  ((nodeId: Long, success: Boolean) -> Unit)? = null
    var onApplyUpdate:       ((nodeId: Long) -> Unit)? = null
    var onUpdateApplied:     ((nodeId: Long) -> Unit)? = null

    // ── Configuration ─────────────────────────────────────────────────────────

    fun configure(path: String, version: Long, versionString: String, dryRun: Boolean = false) {
        this.filePath            = path
        this.targetVersion       = version
        this.targetVersionString = versionString
        this.fileSize            = File(path).length()
        this.dryRun              = dryRun
        this.notAvailable        = false   // reset for a fresh attempt
        Log.d(TAG, "configured path=$path version=$version fileSize=$fileSize dryRun=$dryRun")
    }

    /**
     * Signals that the next [handleQueryImage] call should return NotAvailable.
     * Call this before [reset] on a graceful cancel so the device receives a
     * clean "nothing to update" response instead of a network error, allowing
     * it to reset its backoff state immediately.
     */
    fun markNotAvailable() {
        notAvailable = true
        Log.d(TAG, "marked NotAvailable — next QueryImage will return NotAvailable")
    }

    fun reset() {
        raf?.close()
        raf      = null
        filePath = ""
        fileSize = 0L
    }

    // ── OTAProviderDelegate ───────────────────────────────────────────────────

    override fun handleQueryImage(
        vendorId: Int, productId: Int, softwareVersion: Long,
        hardwareVersion: Int?, location: String?,
        requestorCanConsent: Boolean?, metadataForProvider: ByteArray?,
    ): OTAProviderDelegate.QueryImageResponse {
        if (notAvailable || filePath.isEmpty() || !File(filePath).exists()) {
            Log.d(TAG, "handleQueryImage → NotAvailable (notAvailable=$notAvailable filePath='$filePath')")
            return OTAProviderDelegate.QueryImageResponse(
                OTAProviderDelegate.QueryImageResponseStatusEnum.NotAvailable, false)
        }
        Log.d(TAG, "handleQueryImage vid=$vendorId pid=$productId " +
                   "currentVer=$softwareVersion → providing v$targetVersion ($targetVersionString)")
        return OTAProviderDelegate.QueryImageResponse(
            targetVersion, targetVersionString, filePath, /* userConsentNeeded= */ false)
    }

    override fun handleOTAQueryFailure(error: Int) {
        Log.e(TAG, "OTA query failure: errorCode=$error")
    }

    override fun handleBDXTransferSessionBegin(nodeId: Long, fileDesignator: String?, length: Long) {
        Log.d(TAG, "BDX session begin nodeId=$nodeId length=$length")
        try {
            raf = RandomAccessFile(filePath, "r")
            if (fileSize == 0L && length > 0L) fileSize = length
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open OTA file for BDX", e)
        }
    }

    override fun handleBDXQuery(
        nodeId: Long, blockSize: Int, blockIndex: Long, bytesToSkip: Long,
    ): OTAProviderDelegate.BDXData {
        val file = raf ?: run {
            Log.e(TAG, "handleBDXQuery: no file open")
            return OTAProviderDelegate.BDXData(ByteArray(0), true)
        }
        return try {
            val offset = blockIndex * blockSize + bytesToSkip
            file.seek(offset)
            val buf  = ByteArray(blockSize)
            val read = file.read(buf)
            if (read <= 0) return OTAProviderDelegate.BDXData(ByteArray(0), true)
            val data  = if (read < blockSize) buf.copyOf(read) else buf
            val isEof = (offset + read) >= fileSize
            if (fileSize > 0L) {
                val pct = ((offset + read).toDouble() / fileSize * 100).toInt().coerceIn(0, 100)
                onBdxProgress?.invoke(nodeId, pct)
            }
            OTAProviderDelegate.BDXData(data, isEof)
        } catch (e: Exception) {
            Log.e(TAG, "handleBDXQuery error at blockIndex=$blockIndex", e)
            OTAProviderDelegate.BDXData(ByteArray(0), true)
        }
    }

    override fun handleBDXTransferSessionEnd(errorCode: Long, nodeId: Long) {
        Log.d(TAG, "BDX session end nodeId=$nodeId errorCode=$errorCode")
        raf?.close(); raf = null
        onTransferComplete?.invoke(nodeId, errorCode == 0L)
    }

    override fun handleApplyUpdateRequest(
        nodeId: Long, newVersion: Long,
    ): OTAProviderDelegate.ApplyUpdateResponse {
        return if (dryRun) {
            Log.d(TAG, "ApplyUpdateRequest nodeId=$nodeId newVersion=$newVersion → Discontinue (dry run)")
            onApplyUpdate?.invoke(nodeId)
            OTAProviderDelegate.ApplyUpdateResponse(
                OTAProviderDelegate.ApplyUpdateActionEnum.Discontinue, 0L)
        } else {
            Log.d(TAG, "ApplyUpdateRequest nodeId=$nodeId newVersion=$newVersion → Proceed")
            onApplyUpdate?.invoke(nodeId)
            OTAProviderDelegate.ApplyUpdateResponse(
                OTAProviderDelegate.ApplyUpdateActionEnum.Proceed, 0L)
        }
    }

    override fun handleNotifyUpdateApplied(nodeId: Long) {
        Log.d(TAG, "NotifyUpdateApplied nodeId=$nodeId")
        onUpdateApplied?.invoke(nodeId)
    }
}
