package com.fluxhome.app.bridge

import android.util.Log
import com.fluxhome.app.chip.ChipClient
import com.fluxhome.app.chip.OtaManager
import com.fluxhome.app.chip.clusters.OtaCluster
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class OtaBridge(private val core: BridgeCore) {

    private val otaManager        = OtaManager()
    @Volatile private var queryWatchdogJob: Job? = null

    /**
     * Downloads the OTA image from [otaUrl] to the app cache directory, then
     * registers this controller as an OTA Provider on the fabric and sends
     * AnnounceOTAProvider to [nodeId].
     *
     * Progress is emitted on the device-state event channel as maps with:
     *   type     = "otaProgress"
     *   nodeId   = Int
     *   phase    = "download" | "querying" | "installing" | "applying" | "complete" | "error"
     *   progress = Int (0–100, omitted for non-progress phases)
     *   message  = String (error description, omitted otherwise)
     */
    fun downloadAndFlash(
        nodeId:              Long,
        otaUrl:              String,
        targetVersion:       Long,
        targetVersionString: String,
        dryRun:              Boolean,
        otaEndpoint:         Int,
        result:              MethodChannel.Result,
    ) = core.requireChip(result) {

        // ── Teardown any previous attempt ─────────────────────────────────────
        queryWatchdogJob?.cancel()
        queryWatchdogJob = null
        val destPath = "${core.context.cacheDir.absolutePath}/ota_${nodeId}.bin"
        cleanupOtaSession(destPath)

        // ── Download ──────────────────────────────────────────────────────────
        emitOtaProgress(nodeId, "download", 0, null)
        try {
            downloadOtaFile(otaUrl, destPath) { pct ->
                emitOtaProgress(nodeId, "download", pct, null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "OTA download failed: ${e.message}")
            emitOtaProgress(nodeId, "error", null, "Download failed: ${e.message}")
            core.main.post { result.error("OTA_DOWNLOAD_ERROR", e.message, null) }
            cleanupOtaFile(destPath)
            return@requireChip
        }

        // ── Configure OTA manager callbacks ───────────────────────────────────
        otaManager.configure(destPath, targetVersion, targetVersionString, dryRun)

        otaManager.onBdxProgress = { nid, pct ->
            queryWatchdogJob?.cancel()   // BDX started — watchdog no longer needed
            emitOtaProgress(nid, "installing", pct, null)
        }
        otaManager.onApplyUpdate = { nid ->
            if (dryRun) {
                emitOtaProgress(nid, "dryrun", null, null)
                cleanupOtaSession(destPath)
            } else {
                emitOtaProgress(nid, "applying", null, null)
            }
        }
        otaManager.onUpdateApplied = { nid ->
            queryWatchdogJob?.cancel()
            emitOtaProgress(nid, "complete", 100, null)
            cleanupOtaSession(destPath)
        }
        otaManager.onTransferComplete = { nid, success ->
            queryWatchdogJob?.cancel()
            if (!success) {
                emitOtaProgress(nid, "error", null, "BDX transfer failed")
                cleanupOtaSession(destPath)
            }
        }

        // ── Start OTA provider & announce ─────────────────────────────────────
        ChipClient.getController().startOTAProvider(otaManager)
        val providerNodeId = ChipClient.getController().getControllerNodeId()

        try {
            OtaCluster.announceOtaProvider(core.context, nodeId, providerNodeId, ChipClient.VENDOR_ID, otaEndpoint)
            emitOtaProgress(nodeId, "querying", null, null)
        } catch (e: Exception) {
            // AnnounceOTAProvider is optional — some devices don't support it.
            // Try writing DefaultOTAProviders so the device's background polling picks us up.
            Log.w(TAG, "AnnounceOTAProvider failed (${e.message}), trying DefaultOTAProviders")
            try {
                OtaCluster.writeDefaultOtaProviders(core.context, nodeId, providerNodeId)
                emitOtaProgress(nodeId, "querying", null, null)
            } catch (e2: Exception) {
                Log.e(TAG, "DefaultOTAProviders write also failed: ${e2.message}")
                cleanupOtaSession(destPath)
                emitOtaProgress(nodeId, "error", null,
                    "Could not reach OTA Requestor: ${e2.message}")
            }
        }

        // Watchdog: if the device hasn't started a BDX session within 90 s,
        // clean up and report a timeout rather than hanging indefinitely.
        queryWatchdogJob = core.scope.launch {
            delay(90_000L)
            Log.w(TAG, "OTA query watchdog expired for nodeId=$nodeId")
            cleanupOtaSession(destPath)
            emitOtaProgress(nodeId, "error", null,
                "Device did not initiate an OTA session within 90 s")
        }

        core.main.post { result.success(true) }
    }

    fun cancelOta(result: MethodChannel.Result) = core.requireChip(result) {
        queryWatchdogJob?.cancel()
        queryWatchdogJob = null
        // Graceful cancel: mark NotAvailable so the device gets a clean "no update"
        // response — this lets it reset its backoff state immediately.
        otaManager.markNotAvailable()
        delay(3_000L)
        cleanupOtaSession("${core.context.cacheDir.absolutePath}/ota_*.bin")
        core.main.post { result.success(true) }
    }

    // ── OTA session cleanup ───────────────────────────────────────────────────

    /** Stops the OTA provider, resets the manager, and deletes the image file. */
    private fun cleanupOtaSession(destPath: String) {
        try { ChipClient.getController().finishOTAProvider() } catch (_: Exception) {}
        otaManager.reset()
        cleanupOtaFile(destPath)
    }

    private fun emitOtaProgress(nodeId: Long, phase: String, progress: Int?, message: String?) {
        val map = mutableMapOf<String, Any?>(
            "type"   to "otaProgress",
            "nodeId" to nodeId,
            "phase"  to phase,
        )
        if (progress != null) map["progress"] = progress
        if (message  != null) map["message"]  = message
        core.emitDeviceState(map)
    }

    private suspend fun downloadOtaFile(
        url:        String,
        destPath:   String,
        onProgress: (Int) -> Unit,
    ) = withContext(Dispatchers.IO) {
        val conn = java.net.URL(url).openConnection() as java.net.HttpURLConnection
        try {
            conn.instanceFollowRedirects = true
            conn.connect()
            if (conn.responseCode !in 200..299) {
                throw Exception("HTTP ${conn.responseCode}")
            }
            val total    = conn.contentLengthLong   // -1 if unknown
            var received = 0L
            java.io.FileOutputStream(destPath).use { out ->
                conn.inputStream.use { input ->
                    val buf = ByteArray(32 * 1024)
                    var n: Int
                    while (input.read(buf).also { n = it } != -1) {
                        out.write(buf, 0, n)
                        received += n
                        if (total > 0L) {
                            onProgress(((received.toDouble() / total) * 100).toInt().coerceIn(0, 99))
                        }
                    }
                }
            }
            onProgress(100)
            Log.d(TAG, "OTA download complete: $received bytes → $destPath")
        } finally {
            conn.disconnect()
        }
    }

    private fun cleanupOtaFile(path: String) {
        try { java.io.File(path).delete() } catch (_: Exception) {}
    }

    companion object {
        private const val TAG = "OtaBridge"
    }
}
