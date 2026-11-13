import 'package:web/web.dart' as web;

class WindowServicePlatform {
  Future<bool> isFullScreen() async {
    try {
      return web.document.fullscreenElement != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleFullScreen() async {
    try {
      final doc = web.document;
      if (doc.fullscreenElement != null) {
        doc.exitFullscreen();
        return false;
      } else {
        doc.documentElement?.requestFullscreen();
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> setFullScreen(bool fullScreen) async {
    try {
      final doc = web.document;
      if (fullScreen) {
        if (doc.fullscreenElement == null) {
          doc.documentElement?.requestFullscreen();
        }
        return true;
      } else {
        if (doc.fullscreenElement != null) {
          doc.exitFullscreen();
        }
        return false;
      }
    } catch (_) {
      return false;
    }
  }
}
