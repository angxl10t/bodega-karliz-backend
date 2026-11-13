import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import 'secure_storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  static const String _accentColorKey = 'tenant_accent_color';

  bool _isDarkMode = false;
  Color _accentColor = AppTheme.brandPrimary;
  String _accentColorHex = '#2563EB';

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  Color get accentColor => _accentColor;
  String get accentColorHex => _accentColorHex;

  ThemeData get lightTheme =>
      AppTheme.buildLightTheme(primaryColor: _accentColor);
  ThemeData get darkTheme =>
      AppTheme.buildDarkTheme(primaryColor: _accentColor);

  ThemeProvider() {
    _cargarTemaGuardado();
  }

  Future<void> _cargarTemaGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    String? colorHex = prefs.getString(_accentColorKey);
    if (colorHex == null || colorHex.isEmpty) {
      colorHex = await SecureStorageService.read('color_primario');
    }
    if (colorHex != null && colorHex.isNotEmpty) {
      _accentColorHex = colorHex;
      _accentColor = _parseColor(colorHex);
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }

  Future<void> setAccentColor(Color color, {String? hexCode}) async {
    _accentColor = color;
    final hex =
        hexCode ??
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    _accentColorHex = hex;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentColorKey, hex);
    await SecureStorageService.write('color_primario', hex);
  }

  Future<void> setAccentColorFromHex(String hexCode) async {
    String clean = hexCode.trim();
    if (!clean.startsWith('#') && clean.length == 6) {
      clean = '#$clean';
    }
    clean = clean.toUpperCase();
    final color = _parseColor(clean);
    final finalHex = clean.startsWith('#') && clean.length == 7 ? clean : '#2563EB';
    await setAccentColor(color, hexCode: finalHex);
  }

  Color _parseColor(String hex) {
    try {
      String clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
      return AppTheme.brandPrimary;
    } catch (_) {
      return AppTheme.brandPrimary;
    }
  }
}
