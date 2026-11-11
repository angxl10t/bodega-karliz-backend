import 'dart:async';

import 'package:flutter/foundation.dart';

/// Retrasa la ejecución de una acción hasta que transcurra [delay] sin nuevas llamadas.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 180)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
