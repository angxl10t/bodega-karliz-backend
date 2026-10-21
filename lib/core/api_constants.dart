import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  // URL de producción oficial inmutable en la nube (Render)
  static const String defaultBaseUrl = 'https://cajaya-api.onrender.com/api'; 
  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl {
    // SEGURIDAD: En producción (Release), la URL es inmutable para impedir secuestro de credenciales
    if (kReleaseMode) {
      return defaultBaseUrl;
    }
    return _baseUrl;
  }

  static Future<void> init() async {
    if (kReleaseMode) {
      _baseUrl = defaultBaseUrl;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('custom_base_url') ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String newUrl) async {
    if (kReleaseMode) return; // Bloqueado en Release
    _baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_base_url', newUrl);
  }
}
