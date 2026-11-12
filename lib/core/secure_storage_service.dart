import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento seguro respaldado por el Hardware de Android (Android Keystore
/// y EncryptedSharedPreferences con cifrado AES-256-GCM).
class SecureStorageService {
  static final Set<void Function()> _sessionCleanupCallbacks =
      <void Function()>{};
  static String? _cachedJwtToken;
  static int _jwtCacheGeneration = 0;
  static int _lastJwtWriteGeneration = 0;
  static int _clearAuthInFlightCount = 0;
  static int _latestClearStartGen = 0;

  /// Limpia únicamente la caché en memoria del JWT (útil en tests).
  @visibleForTesting
  static void clearMemoryCache() {
    _jwtCacheGeneration++;
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
    int? writeGen;
    if (key == 'jwt_token') {
      writeGen = ++_jwtCacheGeneration;
      _lastJwtWriteGeneration = writeGen;
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
    if (key == 'jwt_token' &&
        writeGen != null &&
        _jwtCacheGeneration == writeGen) {
      _cachedJwtToken = value;
    }
  }

  static bool _isClearAuthBlockingRead() =>
      _clearAuthInFlightCount > 0 &&
      _lastJwtWriteGeneration < _latestClearStartGen;

  static bool _isJwtReadStale(int readGen) =>
      _jwtCacheGeneration != readGen || _isClearAuthBlockingRead();

  /// Lee un valor descifrado, con migración transparente y fallback resiliente
  static Future<String?> read(String key) async {
    final bool isJwt = key == 'jwt_token';
    if (isJwt) {
      if (_isClearAuthBlockingRead()) {
        return null;
      }
      if (_cachedJwtToken != null) {
        return _cachedJwtToken;
      }
    }
    final int readGen = _jwtCacheGeneration;
    try {
      String? val = await _storage.read(key: key);
      if (val != null) {
        if (isJwt) {
          if (_isJwtReadStale(readGen)) {
            return _cachedJwtToken;
          }
          _cachedJwtToken = val;
        }
        return val;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(key)) {
        final val = prefs.getString(key);
        if (val != null) {
          if (isJwt && _isJwtReadStale(readGen)) {
            return _cachedJwtToken;
          }
          if (isJwt) {
            _cachedJwtToken = val;
          }
          try {
            await _storage.write(key: key, value: val);
            await prefs.remove(key);
          } catch (_) {}
          if (isJwt && _isJwtReadStale(readGen)) {
            try {
              await _storage.delete(key: key);
            } catch (_) {}
            return _cachedJwtToken;
          }
          return val;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Elimina una clave de ambos almacenamientos de forma segura
  static Future<void> delete(String key) async {
    int? deleteGen;
    if (key == 'jwt_token') {
      deleteGen = ++_jwtCacheGeneration;
      _cachedJwtToken = null;
    }
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
    if (key == 'jwt_token' &&
        deleteGen != null &&
        _lastJwtWriteGeneration < deleteGen) {
      _jwtCacheGeneration++;
      _cachedJwtToken = null;
    }
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
    final int clearStartGen = ++_jwtCacheGeneration;
    _latestClearStartGen = clearStartGen;
    _clearAuthInFlightCount++;
    _cachedJwtToken = null;
    try {
      final currentIdBodega = await read('id_bodega');
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
        // Limpieza de configuración de ticketera, PIN y cachés de terminal
        delete('pos_lock_pin'),
        delete('pos_auto_lock_enabled'),
        delete('pos_inactivity_minutes'),
        delete('cajaya_config_ticket_pos'),
        delete('cajaya_ventas_en_espera_v1'),
        delete('cajaya_mermas_historico_v1'),
        if (currentIdBodega != null && currentIdBodega.isNotEmpty) ...[
          delete('cajaya_config_ticket_pos_$currentIdBodega'),
          delete('cajaya_ventas_en_espera_${currentIdBodega}_v1'),
          delete('cajaya_mermas_historico_${currentIdBodega}_v1'),
        ],
      ]);
    } finally {
      _clearAuthInFlightCount--;
      if (_lastJwtWriteGeneration < clearStartGen) {
        _jwtCacheGeneration++;
        _cachedJwtToken = null;
      }
    }
  }
}
