import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'window_service_platform_interface.dart'
    if (dart.library.io) 'window_service_io.dart'
    if (dart.library.js_interop) 'window_service_web.dart';

class WindowService {
  WindowService._() {
    _initNativeCallback();
  }
  static final WindowService instance = WindowService._();

  final WindowServicePlatform _platform = WindowServicePlatform();
  final ValueNotifier<bool> isFullScreenNotifier = ValueNotifier<bool>(false);

  void _initNativeCallback() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      const channel = MethodChannel('com.cajaya.pos/window');
      channel.setMethodCallHandler((call) async {
        if (call.method == 'onFullScreenChanged') {
          if (call.arguments is bool) {
            isFullScreenNotifier.value = call.arguments as bool;
          }
        }
      });
    }
  }

  Future<void> init() async {
    try {
      isFullScreenNotifier.value = await _platform.isFullScreen();
    } catch (_) {}
  }

  Future<bool> toggleFullScreen() async {
    try {
      final newState = await _platform.toggleFullScreen();
      isFullScreenNotifier.value = newState;
      return newState;
    } catch (_) {
      return isFullScreenNotifier.value;
    }
  }

  Future<bool> setFullScreen(bool fullScreen) async {
    try {
      final newState = await _platform.setFullScreen(fullScreen);
      isFullScreenNotifier.value = newState;
      return newState;
    } catch (_) {
      return isFullScreenNotifier.value;
    }
  }

  /// Indica si la plataforma soporta el modo pantalla completa (Windows o Web en PC)
  bool get isSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }
}
