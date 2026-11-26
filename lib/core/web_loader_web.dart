// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

void dismissWebLoadingScreen() {
  try {
    final loader = html.document.getElementById('loading-container');
    if (loader != null) {
      loader.classes.add('loaded');
      Timer(const Duration(milliseconds: 380), () {
        try {
          loader.remove();
        } catch (_) {}
      });
    }
  } catch (_) {}
}
