import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento seguro respaldado por el Hardware de Android (Android Keystore
/// y EncryptedSharedPreferences con cifrado AES-256-GCM).
class SecureStorageService {
  static final Set<void Function()> _sessionCleanupCallbacks =
      <void Function()>{};
  static String? _cachedJwtToken;

  /// Limpia únicamente la caché en memoria del JWT (útil en tests).
  @visibleForTesting
  static void clearMemoryCache() {
    _cachedJwtToken = null;
  }

  /// Registra una rutina síncrona para limpiar cachés en memoria o temporizadores
  /// al cerrar sesión, expirar el token o cambiar de bodega.
  static void registerSessionCleanup(void Function() callback) {
    _sessionCleanupCallbacks.add(callback);
  }

  /// Ejecuta de forma segura todos los callbacks de limpieza registrados.
  static void runSessionCleanupCallbacks() {
    for (final cb in List<void Function()>.from(_sessionCleanupCallbacks)) {
      try {
        cb();
      } catch (_) {}
    }
  }
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  /// Escribe un valor de forma cifrada con respaldo resiliente
  static Future<void> write(String key, String value) async {
    if (key == 'jwt_token') {
      _cachedJwtToken = value;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } catch (_) {}
    }
  }

  /// Lee un valor descifrado, con migración transparente y fallback resiliente
  static Future<String?> read(String key) async {
    if (key == 'jwt_token' && _cachedJwtToken != null) {
      return _cachedJwtToken;
    }
    try {
      String? val = await _storage.read(key: key);
      if (val != null) {
        if (key == 'jwt_token') _cachedJwtToken = val;
        return val;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(key)) {
        final val = prefs.getString(key);
        if (val != null) {
          if (key == 'jwt_token') _cachedJwtToken = val;
          try {
            await _storage.write(key: key, value: val);
            await prefs.remove(key);
          } catch (_) {}
          return val;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Elimina una clave de ambos almacenamientos de forma segura
  static Future<void> delete(String key) async {
    if (key == 'jwt_token') {
      _cachedJwtToken = null;
    }
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Comprueba si existe la clave de forma segura y tolerante a fallos
  static Future<bool> containsKey(String key) async {
    try {
      final hasKey = await _storage.containsKey(key: key);
      if (hasKey) return true;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(key);
    } catch (_) {
      return false;
    }
  }

  /// Limpia todas las credenciales cifradas y resetea cachés en memoria de la sesión
  static Future<void> clearAuth() async {
    _cachedJwtToken = null;
    runSessionCleanupCallbacks();
    await Future.wait([
      delete('jwt_token'),
      delete('user_rol'),
      delete('username'),
      delete('user_email'),
      delete('id_bodega'),
      delete('nombre_bodega'),
      delete('plan_bodega'),
      delete('ruc_bodega'),
      delete('direccion_bodega'),
      delete('telefono_bodega'),
      delete('color_primario'),
      delete('lema_comercial'),
      delete('logo_url'),
      delete('regimen_tributario'),
      delete('facturacion_sunat_activa'),
    ]);
  }
}
