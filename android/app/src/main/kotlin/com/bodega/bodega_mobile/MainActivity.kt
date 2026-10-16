package com.bodega.bodega_mobile

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Seguridad POS: Impide capturas de pantalla y oculta datos financieros/clientes en el selector de tareas
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
