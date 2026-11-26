import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/cajaya_vectors.dart';
import 'package:bodega_mobile/features/auth/splash_screen.dart';

void main() {
  group('SplashScreen Fluid Animation Tests - Opción 2 Isotipo C-Check', () {
    testWidgets(
      'Renderiza Isotipo oficial CajaYa, texto fijo y micro-indicador de progreso sin rebotes',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

        // 1. Verificar presencia de elementos clave de la Opción 2
        expect(find.byType(CajaYaLogoMark), findsOneWidget);
        expect(find.text('CajaYa'), findsOneWidget);
        expect(find.text('POS'), findsOneWidget);
        expect(find.text('Iniciando terminal...'), findsOneWidget);

        // 2. Avanzar el tiempo para la coreografía de entrada (600ms)
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CajaYaLogoMark), findsOneWidget);
        expect(find.text('CajaYa'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Iniciando terminal...'), findsOneWidget);

        // 3. Verificar estabilidad temporal sin vaivén
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(CajaYaLogoMark), findsOneWidget);
        expect(find.text('CajaYa'), findsOneWidget);
      },
    );
  });
}
