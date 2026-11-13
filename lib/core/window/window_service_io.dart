import 'dart:io';

import 'package:flutter/services.dart';

class WindowServicePlatform {
  static const MethodChannel _channel = MethodChannel('com.cajaya.pos/window');

  Future<bool> isFullScreen() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return false;
    }
    try {
      final res = await _channel.invokeMethod<bool>('isFullScreen');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleFullScreen() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return false;
    }
    try {
      final res = await _channel.invokeMethod<bool>('toggleFullScreen');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setFullScreen(bool fullScreen) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return false;
    }
    try {
      final res = await _channel.invokeMethod<bool>(
        'setFullScreen',
        fullScreen,
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
