package com.bodega.bodega_mobile

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Permite capturas de pantalla y grabación en la aplicación
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
