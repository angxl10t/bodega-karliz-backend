import 'dart:io';
import 'package:flutter/foundation.dart';

/// Guardia de seguridad para verificación de integridad de entorno
class SecurityGuard {
  /// Verifica si el dispositivo presenta indicios de Root o modificación de sistema
  static bool isDeviceRooted() {
    if (kIsWeb || !Platform.isAndroid) return false;

    // Rutas conocidas de binarios de escalación de privilegios y paquetes SuperUser/Magisk
    const paths = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/system/xbin/daemonsu',
    ];

    for (final path in paths) {
      try {
        if (File(path).existsSync()) {
          return true;
        }
      } catch (_) {
        // En Android con sandbox estricto, la excepción de permiso denegado es esperada
      }
    }
    return false;
  }
}
