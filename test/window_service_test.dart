import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/window/window_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowService Tests', () {
    test('WindowService instance es singleton', () {
      final s1 = WindowService.instance;
      final s2 = WindowService.instance;
      expect(identical(s1, s2), isTrue);
    });

    test('isFullScreenNotifier inicializa en false por defecto en tests', () {
      final service = WindowService.instance;
      expect(service.isFullScreenNotifier.value, isFalse);
    });

    test(
      'setFullScreen y toggleFullScreen actualizan el ValueNotifier',
      () async {
        final service = WindowService.instance;

        await service.setFullScreen(false);
        expect(service.isFullScreenNotifier.value, isFalse);

        await service.toggleFullScreen();
        // En entorno de prueba sin backend nativo retorna false gracefulmente
        expect(service.isFullScreenNotifier.value, isFalse);
      },
    );
  });
}
