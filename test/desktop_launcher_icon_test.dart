import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windows Desktop Launcher Icon & Runner Tests', () {
    test(
      'app_icon.ico existe y contiene los 7 tamaños oficiales de Windows',
      () {
        final icoFile = File('windows/runner/resources/app_icon.ico');
        expect(
          icoFile.existsSync(),
          isTrue,
          reason: 'app_icon.ico debe existir',
        );

        final bytes = icoFile.readAsBytesSync();
        expect(
          bytes.length,
          greaterThan(50000),
          reason: 'app_icon.ico debe contener multi-resolución de alta calidad',
        );

        // Validar cabecera ICONDIR: reserved (0), type (1)
        final reserved = bytes[0] | (bytes[1] << 8);
        final type = bytes[2] | (bytes[3] << 8);
        final count = bytes[4] | (bytes[5] << 8);

        expect(reserved, equals(0));
        expect(type, equals(1)); // 1 = ICO
        expect(
          count,
          equals(7),
          reason: 'Debe contener 7 resoluciones (16, 24, 32, 48, 64, 128, 256)',
        );

        final sizes = <int>[];
        for (var i = 0; i < count; i++) {
          final offset = 6 + i * 16;
          final w = bytes[offset] == 0 ? 256 : bytes[offset];
          sizes.add(w);
        }

        expect(sizes, containsAll([16, 24, 32, 48, 64, 128, 256]));
      },
    );

    test('Runner.rc referencia app_icon.ico y metadatos de CajaYa POS', () {
      final rcFile = File('windows/runner/Runner.rc');
      expect(rcFile.existsSync(), isTrue);

      final content = rcFile.readAsStringSync();
      expect(
        content,
        contains(
          'IDI_APP_ICON            ICON                    "resources\\\\app_icon.ico"',
        ),
      );
      expect(content, contains('VALUE "ProductName", "CajaYa POS"'));
      expect(
        content,
        contains(
          'VALUE "FileDescription", "CajaYa POS - Sistema Punto de Venta"',
        ),
      );
    });

    test('main.cpp inicializa la ventana con el título CajaYa POS', () {
      final mainCpp = File('windows/runner/main.cpp');
      expect(mainCpp.existsSync(), isTrue);

      final content = mainCpp.readAsStringSync();
      expect(content, contains('window.Create(L"CajaYa POS"'));
    });
  });
}
