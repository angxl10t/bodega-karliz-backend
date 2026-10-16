import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  static const String _accentColorKey = 'tenant_accent_color';

  bool _isDarkMode = false;
  Color _accentColor = AppTheme.brandPrimary;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  Color get accentColor => _accentColor;

  ThemeData get lightTheme => AppTheme.buildLightTheme(primaryColor: _accentColor);
  ThemeData get darkTheme => AppTheme.buildDarkTheme(primaryColor: _accentColor);

  ThemeProvider() {
    _cargarTemaGuardado();
  }

  Future<void> _cargarTemaGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    final colorHex = prefs.getString(_accentColorKey);
    if (colorHex != null && colorHex.isNotEmpty) {
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
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final hex = hexCode ?? '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    await prefs.setString(_accentColorKey, hex);
  }

  Future<void> setAccentColorFromHex(String hexCode) async {
    final color = _parseColor(hexCode);
    await setAccentColor(color, hexCode: hexCode);
  }

  Color _parseColor(String hex) {
    try {
      String clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return AppTheme.brandPrimary;
    }
  }
}
