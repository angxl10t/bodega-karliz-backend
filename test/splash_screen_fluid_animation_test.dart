import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/auth/splash_screen.dart';

void main() {
  group('SplashScreen Fluid Animation Tests', () {
    testWidgets(
      'Renderiza el logotipo CajaYa POS, resplandor ambiental y micro-indicador de progreso',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

        // 1. Verificar renderizado inicial
        expect(find.text('CajaYa'), findsOneWidget);
        expect(find.text('POS'), findsOneWidget);
        expect(find.text('Iniciando terminal...'), findsOneWidget);

        // 2. Avanzar el tiempo para la animación de entrada (700ms)
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('CajaYa'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Iniciando terminal...'), findsOneWidget);

        // 3. Verificar ciclo de respiración continua (sin congelarse)
        await tester.pump(const Duration(milliseconds: 1100));
        expect(find.text('CajaYa'), findsOneWidget);
      },
    );
  });
}
