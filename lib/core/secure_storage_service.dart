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

  /// Escribe un valor de forma cifrada
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Lee un valor descifrado, con migración transparente si existía en SharedPreferences
  static Future<String?> read(String key) async {
    String? val = await _storage.read(key: key);
    if (val == null) {
      // Migración desde SharedPreferences legado si existe
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(key)) {
        val = prefs.getString(key);
        if (val != null) {
          await _storage.write(key: key, value: val);
          await prefs.remove(key); // Eliminar del archivo plano no cifrado
        }
      }
    }
    return val;
  }

  /// Elimina una clave de ambos almacenamientos
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Comprueba si existe la clave de forma segura
  static Future<bool> containsKey(String key) async {
    final hasKey = await _storage.containsKey(key: key);
    if (hasKey) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
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
