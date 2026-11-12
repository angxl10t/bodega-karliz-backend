package com.cajaya.pos

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Puente nativo MethodChannel para impresión térmica ESC/POS directa vía Bluetooth SPP (RFCOMM)
 * en Android sin depender de aplicaciones intermediarias externas.
 */
class BluetoothThermalPrinterChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.cajaya.pos/bluetooth_printer"
        private const val REQUEST_BT_CONNECT = 4102
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingCall: MethodCall? = null
    private var pendingResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
        pendingCall = null
        pendingResult = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> {
                result.success(getBluetoothAdapter() != null)
            }
            "getBondedDevices" -> {
                runWithBluetoothPermission(call, result) {
                    listBondedDevices(result)
                }
            }
            "printBytes" -> {
                runWithBluetoothPermission(call, result) {
                    handlePrintBytes(call, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_BT_CONNECT) {
            return false
        }
        val call = pendingCall
        val result = pendingResult
        pendingCall = null
        pendingResult = null

        if (call == null || result == null) {
            return true
        }

        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            result.error(
                "BT_PERMISSION_DENIED",
                "Permiso de Dispositivos Cercanos / Bluetooth denegado. Actívalo en Ajustes de la app para imprimir directamente.",
                null
            )
            return true
        }

        when (call.method) {
            "getBondedDevices" -> listBondedDevices(result)
            "printBytes" -> handlePrintBytes(call, result)
            else -> result.notImplemented()
        }
        return true
    }

    private fun runWithBluetoothPermission(
        call: MethodCall,
        result: MethodChannel.Result,
        action: () -> Unit,
    ) {
        if (hasBluetoothConnectPermission()) {
            action()
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (pendingResult != null) {
                result.error(
                    "BT_BUSY",
                    "Ya hay una solicitud de permiso Bluetooth en curso.",
                    null
                )
                return
            }
            pendingCall = call
            pendingResult = result
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.BLUETOOTH_CONNECT),
                REQUEST_BT_CONNECT
            )
            return
        }

        result.error(
            "BT_PERMISSION_DENIED",
            "Permiso Bluetooth requerido en Android.",
            null
        )
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.BLUETOOTH
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun getBluetoothAdapter(): BluetoothAdapter? {
        val manager = activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }

    @SuppressLint("MissingPermission")
    private fun listBondedDevices(result: MethodChannel.Result) {
        val adapter = getBluetoothAdapter()
        if (adapter == null) {
            result.error("BT_UNAVAILABLE", "Este dispositivo no cuenta con adaptador Bluetooth.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error(
                "BT_DISABLED",
                "El Bluetooth está apagado. Enciéndelo y empareja tu ticketera desde Ajustes.",
                null
            )
            return
        }

        try {
            val bonded: Set<BluetoothDevice> = adapter.bondedDevices ?: emptySet()
            val mapped = bonded
                .map { device ->
                    mapOf(
                        "name" to (device.name ?: "Impresora Bluetooth"),
                        "address" to (device.address ?: "")
                    )
                }
                .filter { (it["address"] ?: "").isNotEmpty() }
                .sortedBy { (it["name"] ?: "").lowercase() }
            result.success(mapped)
        } catch (e: SecurityException) {
            result.error("BT_PERMISSION_DENIED", "Falta permiso BLUETOOTH_CONNECT.", e.localizedMessage)
        }
    }

    @SuppressLint("MissingPermission")
    private fun handlePrintBytes(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address")?.trim().orEmpty()
        val bytes = call.argument<ByteArray>("bytes")

        if (address.isEmpty() || !BluetoothAdapter.checkBluetoothAddress(address)) {
            result.error(
                "BT_INVALID_ADDRESS",
                "Dirección MAC de impresora Bluetooth inválida o vacía.",
                null
            )
            return
        }
        if (bytes == null || bytes.isEmpty()) {
            result.error("BT_EMPTY_PAYLOAD", "No hay comandos ESC/POS para imprimir.", null)
            return
        }

        val adapter = getBluetoothAdapter()
        if (adapter == null) {
            result.error("BT_UNAVAILABLE", "Este dispositivo no cuenta con adaptador Bluetooth.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error(
                "BT_DISABLED",
                "El Bluetooth está apagado. Actívalo antes de imprimir.",
                null
            )
            return
        }

        executor.execute {
            var socket: BluetoothSocket? = null
            try {
                val device = adapter.getRemoteDevice(address)
                val canCancelDiscovery = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                    ContextCompat.checkSelfPermission(
                        activity,
                        Manifest.permission.BLUETOOTH_SCAN
                    ) == PackageManager.PERMISSION_GRANTED
                if (canCancelDiscovery) {
                    try {
                        adapter.cancelDiscovery()
                    } catch (_: SecurityException) {
                    }
                }

                socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()

                val out = socket.outputStream
                var offset = 0
                val chunkSize = 1024
                while (offset < bytes.size) {
                    val length = minOf(chunkSize, bytes.size - offset)
                    out.write(bytes, offset, length)
                    offset += length
                }
                out.flush()
                // Pausa breve para asegurar vaciado completo hacia el buffer térmico antes de cerrar RFCOMM
                Thread.sleep(150)

                mainHandler.post { result.success(true) }
            } catch (e: SecurityException) {
                mainHandler.post {
                    result.error(
                        "BT_PERMISSION_DENIED",
                        "Falta permiso Bluetooth para conectar con la ticketera.",
                        e.localizedMessage
                    )
                }
            } catch (e: IOException) {
                mainHandler.post {
                    result.error(
                        "BT_IO_ERROR",
                        "No se pudo conectar o enviar el ticket a la ticketera ($address). Verifica que esté encendida y vinculada.",
                        e.localizedMessage
                    )
                }
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
                mainHandler.post {
                    result.error("BT_INTERRUPTED", "Impresión interrumpida.", e.localizedMessage)
                }
            } finally {
                try {
                    socket?.close()
                } catch (_: IOException) {
                }
            }
        }
    }
}
