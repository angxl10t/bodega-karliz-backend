package com.cajaya.pos

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var bluetoothPrinterChannel: BluetoothThermalPrinterChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Permite capturas de pantalla y grabación en la aplicación
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        bluetoothPrinterChannel = BluetoothThermalPrinterChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (bluetoothPrinterChannel?.onRequestPermissionsResult(requestCode, grantResults) == true) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        bluetoothPrinterChannel?.dispose()
        bluetoothPrinterChannel = null
        super.onDestroy()
    }
}
