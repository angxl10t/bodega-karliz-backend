import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/auth/splash_screen.dart';

void main() {
  group('SplashScreen Fluid Animation Tests - Variante 1 Empuje Cinético 1.8s', () {
    testWidgets(
      'Renderiza ícono oficial 3D, texto CajaYa POS empujado y micro-indicador en tiempo fijo de 1.8s',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

        // 1. Verificar presencia de elementos clave de la Variante 1
        expect(find.byType(Image), findsOneWidget);
        expect(find.text('CajaYa'), findsOneWidget);
        expect(find.text('POS'), findsOneWidget);
        expect(find.text('Iniciando terminal...'), findsOneWidget);

        // 2. Avanzar el tiempo para la coreografía de entrada y empuje (600ms)
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(Image), findsOneWidget);
        expect(find.text('CajaYa'), findsOneWidget);

        // 3. Avanzar al estado de fijación estable (1100ms)
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Iniciando terminal...'), findsOneWidget);
        expect(find.text('CajaYa'), findsOneWidget);

        // 4. Completar los 1.8s deterministas
        await tester.pump(const Duration(milliseconds: 700));
      },
    );
  });
}
