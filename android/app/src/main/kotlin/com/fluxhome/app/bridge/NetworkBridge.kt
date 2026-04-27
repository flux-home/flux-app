package com.fluxhome.app.bridge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.WifiManager
import android.util.Log
import com.fluxhome.app.chip.ThreadBorderRouterScanner
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONArray
import org.json.JSONObject
import kotlin.coroutines.resume

/**
 * Wi-Fi scanning and Thread border-router discovery — both are network-environment
 * utilities used during commissioning setup, neither is a Matter cluster operation.
 */
class NetworkBridge(private val core: BridgeCore) {

    // ── Wi-Fi network scan ────────────────────────────────────────────────────

    /**
     * Triggers a fresh Wi-Fi scan and returns only networks that respond within
     * [WIFI_SCAN_TIMEOUT_MS]. Falls back to the last cached results if the scan
     * is throttled or times out.
     *
     * Each entry is a map with:
     *   - ssid        (String)  — network name
     *   - rssi        (Int)     — signal in dBm (only networks ≥ [WIFI_MIN_RSSI])
     *   - isConnected (Boolean) — true for the currently associated network
     */
    fun scanWifiNetworks(result: MethodChannel.Result) {
        core.scope.launch {
            val networks = doWifiScan()
            core.main.post { result.success(networks) }
        }
    }

    private suspend fun doWifiScan(): List<Map<String, Any?>> {
        val wifiManager =
            core.context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

        // Trigger a fresh scan, wait for the broadcast
        suspendCancellableCoroutine { cont ->
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context, intent: Intent) {
                    try { ctx.unregisterReceiver(this) } catch (_: Exception) {}
                    if (cont.isActive) cont.resume(Unit)
                }
            }
            try {
                core.context.registerReceiver(
                    receiver,
                    IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION),
                )
                @Suppress("DEPRECATION")
                val started = wifiManager.startScan()
                if (!started) {
                    // Throttled by Android — unregister and fall through to cache
                    try { core.context.unregisterReceiver(receiver) } catch (_: Exception) {}
                    Log.d(TAG, "Wi-Fi startScan throttled — using cached results")
                    if (cont.isActive) cont.resume(Unit)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Wi-Fi scan setup failed: ${e.message}")
                if (cont.isActive) cont.resume(Unit)
            }
            cont.invokeOnCancellation {
                try { core.context.unregisterReceiver(receiver) } catch (_: Exception) {}
            }
        }

        // Allow the OS a brief moment to populate results after the broadcast
        delay(WIFI_SCAN_TIMEOUT_MS)
        return buildWifiResults(wifiManager)
    }

    private fun buildWifiResults(wifiManager: WifiManager): List<Map<String, Any?>> {
        val currentSsid = wifiManager.connectionInfo?.ssid
            ?.removeSurrounding("\"")
            ?.takeIf { it.isNotEmpty() && it != "<unknown ssid>" }

        val seen     = mutableSetOf<String>()
        val networks = mutableListOf<Map<String, Any?>>()

        // Connected network always first regardless of RSSI
        if (!currentSsid.isNullOrEmpty()) {
            seen.add(currentSsid)
            networks.add(mapOf(
                "ssid"        to currentSsid,
                "rssi"        to wifiManager.connectionInfo.rssi,
                "isConnected" to true,
            ))
        }

        wifiManager.scanResults
            .filter { sr ->
                sr.SSID.isNotEmpty()         // ignore unnamed (hidden) networks
                && sr.level >= WIFI_MIN_RSSI // only networks with usable signal
            }
            .groupBy { it.SSID }             // one entry per SSID
            .mapValues { (_, aps) -> aps.maxBy { it.level } } // keep strongest AP
            .values
            .sortedByDescending { it.level }
            .filter { it.SSID !in seen }     // drop already-listed connected network
            .forEach { sr ->
                seen.add(sr.SSID)
                networks.add(mapOf(
                    "ssid"        to sr.SSID,
                    "rssi"        to sr.level,
                    "isConnected" to false,
                ))
            }

        return networks
    }

    // ── Thread border-router discovery ────────────────────────────────────────

    fun discoverThreadNetworks(result: MethodChannel.Result) {
        core.scope.launch {
            try {
                val routers = ThreadBorderRouterScanner.scan(core.context)
                val arr = JSONArray()
                for (r in routers) {
                    val txt = JSONObject().apply { r.txt.forEach { (k, v) -> put(k, v) } }
                    arr.put(JSONObject()
                        .put("serviceName", r.serviceName)
                        .put("networkName", r.networkName)
                        .put("extPanId",    r.extPanId)
                        .put("vendorName",  r.vendorName)
                        .put("modelName",   r.modelName)
                        .put("host",        r.host)
                        .put("port",        r.port)
                        .put("txt",         txt))
                }
                core.main.post { result.success(arr.toString()) }
            } catch (e: Exception) {
                Log.e(TAG, "discoverThreadNetworks error", e)
                core.main.post { result.error("THREAD_SCAN_ERROR", e.message, null) }
            }
        }
    }

    companion object {
        private const val TAG                  = "NetworkBridge"
        /** Minimum RSSI to include a network — filters out ghost/stale entries. */
        private const val WIFI_MIN_RSSI        = -85   // dBm
        /** How long to wait after the scan broadcast before reading results. */
        private const val WIFI_SCAN_TIMEOUT_MS = 300L
    }
}
