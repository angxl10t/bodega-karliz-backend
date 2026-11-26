import 'web_loader_stub.dart' if (dart.library.html) 'web_loader_web.dart';

/// Oculta y remueve el contenedor de carga HTML inicial (`#loading-container`)
/// en cuanto Flutter toma el control del lienzo web.
void dismissWebLoader() {
  dismissWebLoadingScreen();
}
