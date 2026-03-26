package com.example.matter_home.chip

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import chip.platform.BleCallback
import java.util.UUID
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Manages BLE scanning and GATT connection for Matter device commissioning.
 *
 * Key design notes:
 *  - [addConnection] is called only after the GATT is fully ready (post-MTU),
 *    not immediately after [BluetoothDevice.connectGatt]. Calling it too early
 *    means a stale registration in the CHIP C++ connection table.
 *  - [close] manually injects a STATE_DISCONNECTED event into the CHIP
 *    platform's own BluetoothGattCallback *before* calling [BluetoothGatt.close].
 *    This is necessary because [BluetoothGatt.close] deregisters all Android
 *    callbacks, so the real STATE_DISCONNECTED will never fire — leaving the
 *    CHIP C++ layer thinking the connection is still open ("already in use").
 */
@OptIn(ExperimentalCoroutinesApi::class)
class BleConnectionManager : BleCallback {

    companion object {
        private const val TAG = "BleConnectionManager"
        private const val MATTER_BLE_UUID = "0000FFF6-0000-1000-8000-00805F9B34FB"
        private const val BLE_SCAN_TIMEOUT_MS = 10_000L
    }

    private val adapter: BluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
    @Volatile private var bleGatt: BluetoothGatt? = null

    /** Connection ID assigned by [chip.platform.AndroidBleManager.addConnection].
     *  0 means no connection is registered with the CHIP platform yet. */
    @Volatile var connectionId: Int = 0
        private set

    // ── BleCallback (called by CHIP platform on BLE lifecycle events) ─────────

    override fun onCloseBleComplete(connId: Int) {
        Log.d(TAG, "onCloseBleComplete connId=$connId")
        connectionId = 0
    }

    override fun onNotifyChipConnectionClosed(connId: Int) {
        Log.d(TAG, "onNotifyChipConnectionClosed connId=$connId")
        try { bleGatt?.close() } catch (e: Exception) { Log.w(TAG, "close in onNotifyChipConnectionClosed: ${e.message}") }
        bleGatt      = null
        connectionId = 0
    }

    // ── Explicit cleanup ──────────────────────────────────────────────────────

    /**
     * Tears down any active GATT connection and notifies the CHIP C++ layer.
     *
     * Safe to call in any state, including before a connection was established.
     *
     * Why we inject STATE_DISCONNECTED manually:
     * Android's [BluetoothGatt.close] immediately deregisters our callback,
     * so the real STATE_DISCONNECTED event will never arrive.  Without the
     * manual injection the CHIP C++ layer keeps the connection in its table,
     * and the next [pairDeviceThroughBLE] call fails with
     * "bluetooth connection already in use".
     */
    fun close() {
        val gatt = bleGatt ?: run {
            Log.d(TAG, "close() — nothing to close")
            return
        }
        Log.i(TAG, "close() connId=$connectionId addr=${gatt.device?.address}")

        // 1. Notify the CHIP C++ layer that this connection is gone, BEFORE
        //    calling gatt.close() which would suppress any further callbacks.
        if (connectionId != 0) {
            try {
                ChipClient.getPlatform().bleManager.callback.onConnectionStateChange(
                    gatt,
                    BluetoothGatt.GATT_SUCCESS,
                    BluetoothProfile.STATE_DISCONNECTED,
                )
                Log.d(TAG, "Injected STATE_DISCONNECTED into CHIP platform for connId=$connectionId")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to inject disconnect into CHIP layer: ${e.message}")
            }
        }

        // 2. Cleanly close the Android GATT.
        try { gatt.disconnect() } catch (e: Exception) { Log.w(TAG, "GATT disconnect: ${e.message}") }
        try { gatt.close()     } catch (e: Exception) { Log.w(TAG, "GATT close: ${e.message}") }

        bleGatt      = null
        connectionId = 0
    }

    // ── BLE scan ─────────────────────────────────────────────────────────────

    suspend fun findDevice(
        context: Context,
        discriminator: Int,
        isShortDiscriminator: Boolean = false,
        timeoutMs: Long = BLE_SCAN_TIMEOUT_MS,
    ): BluetoothDevice? {
        if (!adapter.isEnabled) {
            @Suppress("DEPRECATION")
            adapter.enable()
        }
        val scanner = adapter.bluetoothLeScanner ?: run {
            Log.e(TAG, "BLE scanner unavailable")
            return null
        }
        return withTimeoutOrNull(timeoutMs) {
            callbackFlow {
                val scanCb = object : ScanCallback() {
                    override fun onScanResult(callbackType: Int, result: ScanResult) {
                        trySend(result.device)
                    }
                    override fun onScanFailed(errorCode: Int) {
                        Log.e(TAG, "BLE scan failed: $errorCode")
                    }
                }
                val serviceUuid = ParcelUuid(UUID.fromString(MATTER_BLE_UUID))
                val filter = ScanFilter.Builder()
                    .setServiceData(serviceUuid,
                        matterServiceData(discriminator),
                        matterServiceDataMask(isShortDiscriminator))
                    .build()
                val settings = ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .build()
                Log.i(TAG, "BLE scan started – discriminator=$discriminator")
                scanner.startScan(listOf(filter), settings, scanCb)
                awaitClose { scanner.stopScan(scanCb) }
            }.first()
        }
    }

    // ── GATT connection ───────────────────────────────────────────────────────

    /**
     * Connects to [device], discovers services, negotiates MTU, then registers
     * the GATT connection with the CHIP platform.
     *
     * [addConnection] is intentionally called inside [onMtuChanged] — only
     * once the GATT is fully ready — not immediately after [connectGatt].
     * Registering too early leaves the platform holding a half-open connection
     * if setup fails, which triggers "already in use" on the next attempt.
     */
    suspend fun connect(context: Context, device: BluetoothDevice): BluetoothGatt? =
        suspendCancellableCoroutine { cont ->
            Log.i(TAG, "GATT connecting to ${device.address}")
            bleGatt = device.connectGatt(
                context, false,
                buildGattCallback(cont),
                BluetoothDevice.TRANSPORT_LE,
            )
            cont.invokeOnCancellation { close() }
        }

    // ── GATT callback ─────────────────────────────────────────────────────────

    private enum class GattState { INIT, DISCOVER_SERVICES, REQUEST_MTU }

    private fun buildGattCallback(
        cont: CancellableContinuation<BluetoothGatt?>,
    ): BluetoothGattCallback {
        return object : BluetoothGattCallback() {
            private val chipCb: BluetoothGattCallback
                get() = ChipClient.getPlatform().bleManager.callback

            private var state = GattState.INIT

            override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                chipCb.onConnectionStateChange(gatt, status, newState)
                when {
                    newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS -> {
                        Log.i(TAG, "GATT connected – discovering services")
                        state = GattState.DISCOVER_SERVICES
                        gatt?.discoverServices()
                    }
                    newState == BluetoothProfile.STATE_DISCONNECTED -> {
                        Log.w(TAG, "GATT disconnected status=$status")
                        if (cont.isActive) cont.resume(null)
                    }
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                chipCb.onServicesDiscovered(gatt, status)
                if (state != GattState.DISCOVER_SERVICES) return
                Log.i(TAG, "GATT services discovered – requesting MTU 247")
                state = GattState.REQUEST_MTU
                gatt?.requestMtu(247)
            }

            override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
                chipCb.onMtuChanged(gatt, mtu, status)
                if (state != GattState.REQUEST_MTU) return
                // GATT is fully ready — register with the CHIP platform NOW.
                // Doing this here (not in connectGatt) means the CHIP C++ layer
                // only ever sees one live connection at a time.
                val platform  = ChipClient.getPlatform()
                connectionId  = platform.bleManager.addConnection(gatt)
                platform.bleManager.setBleCallback(this@BleConnectionManager)
                Log.i(TAG, "GATT ready — connectionId=$connectionId MTU=$mtu")
                if (cont.isActive) cont.resume(gatt)
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt, char: android.bluetooth.BluetoothGattCharacteristic,
            ) = chipCb.onCharacteristicChanged(gatt, char)

            override fun onCharacteristicRead(
                gatt: BluetoothGatt, char: android.bluetooth.BluetoothGattCharacteristic, status: Int,
            ) = chipCb.onCharacteristicRead(gatt, char, status)

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt, char: android.bluetooth.BluetoothGattCharacteristic, status: Int,
            ) = chipCb.onCharacteristicWrite(gatt, char, status)

            override fun onDescriptorWrite(
                gatt: BluetoothGatt, desc: android.bluetooth.BluetoothGattDescriptor, status: Int,
            ) = chipCb.onDescriptorWrite(gatt, desc, status)

            override fun onDescriptorRead(
                gatt: BluetoothGatt, desc: android.bluetooth.BluetoothGattDescriptor, status: Int,
            ) = chipCb.onDescriptorRead(gatt, desc, status)

            override fun onReadRemoteRssi(gatt: BluetoothGatt, rssi: Int, status: Int) =
                chipCb.onReadRemoteRssi(gatt, rssi, status)

            override fun onReliableWriteCompleted(gatt: BluetoothGatt, status: Int) =
                chipCb.onReliableWriteCompleted(gatt, status)
        }
    }

    // ── BLE service-data encoding ─────────────────────────────────────────────

    private fun matterServiceData(discriminator: Int): ByteArray {
        val version = 0
        val vDisc   = ((version and 0xf) shl 12) or (discriminator and 0xfff)
        return byteArrayOf(0, (vDisc and 0xff).toByte(), (vDisc shr 8).toByte())
    }

    private fun matterServiceDataMask(isShort: Boolean): ByteArray {
        val discMask = if (isShort) 0x00.toByte() else 0xff.toByte()
        return byteArrayOf(0xff.toByte(), discMask, 0xff.toByte())
    }
}
