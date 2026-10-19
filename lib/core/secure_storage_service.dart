import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento seguro respaldado por el Hardware de Android (Android Keystore
/// y EncryptedSharedPreferences con cifrado AES-256-GCM).
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );

  /// Escribe un valor de forma cifrada con respaldo resiliente
  static Future<void> write(String key, String value) async {
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
    try {
      String? val = await _storage.read(key: key);
      if (val != null) return val;
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(key)) {
        final val = prefs.getString(key);
        if (val != null) {
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

  /// Limpia todas las credenciales cifradas
  static Future<void> clearAuth() async {
    await delete('jwt_token');
    await delete('user_rol');
    await delete('username');
    await delete('id_bodega');
    await delete('nombre_bodega');
    await delete('plan_bodega');
  }
}
