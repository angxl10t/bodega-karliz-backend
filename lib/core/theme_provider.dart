import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import 'secure_storage_service.dart';
import 'karliz_sound_service.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  static const String _accentColorKey = 'tenant_accent_color';
  static const String _fontScaleKey = 'a11y_font_scale';
  static const String _highContrastKey = 'a11y_high_contrast';
  static const String _assistedIconsKey = 'a11y_assisted_icons';
  static const String _soundEnabledKey = 'a11y_sound_enabled';

  bool _isDarkMode = false;
  Color _accentColor = AppTheme.brandPrimary;
  String _accentColorHex = '#2563EB';

  double _fontScale = 1.0;
  bool _highContrast = false;
  bool _assistedIcons = true;
  bool _soundEnabled = true;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  Color get accentColor => _accentColor;
  String get accentColorHex => _accentColorHex;

  double get fontScale => _fontScale;
  bool get highContrast => _highContrast;
  bool get assistedIcons => _assistedIcons;
  bool get soundEnabled => _soundEnabled;

  ThemeData get lightTheme => AppTheme.buildLightTheme(
    primaryColor: _accentColor,
    highContrast: _highContrast,
  );
  ThemeData get darkTheme => AppTheme.buildDarkTheme(
    primaryColor: _accentColor,
    highContrast: _highContrast,
  );

  ThemeProvider() {
    _cargarTemaGuardado();
  }

  Future<void> _cargarTemaGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    _fontScale = prefs.getDouble(_fontScaleKey) ?? 1.0;
    _highContrast = prefs.getBool(_highContrastKey) ?? false;
    _assistedIcons = prefs.getBool(_assistedIconsKey) ?? true;
    _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    KarlizSoundService.instance.soundEnabled = _soundEnabled;

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
    final finalHex = clean.startsWith('#') && clean.length == 7
        ? clean
        : '#2563EB';
    await setAccentColor(color, hexCode: finalHex);
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, scale);
  }

  Future<void> setHighContrast(bool enabled) async {
    _highContrast = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, enabled);
  }

  Future<void> setAssistedIcons(bool enabled) async {
    _assistedIcons = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_assistedIconsKey, enabled);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    KarlizSoundService.instance.soundEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
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
