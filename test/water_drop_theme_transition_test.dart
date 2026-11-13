import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/widgets/water_drop_theme_transition.dart';

void main() {
  testWidgets(
    'WaterDropThemeButton renderiza icono y ejecuta transición de tema',
    (WidgetTester tester) async {
      bool isDark = false;
      bool toggleCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return WaterDropThemeButton(
                    isDark: isDark,
                    onToggle: () async {
                      toggleCalled = true;
                      setState(() {
                        isDark = !isDark;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Inicialmente modo claro (muestra icono de luna)
      expect(find.byType(WaterDropThemeButton), findsOneWidget);
      expect(toggleCalled, isFalse);

      // Tap en el botón
      await tester.tap(find.byType(WaterDropThemeButton));
      await tester.pump();

      // Avanzar animación
      await tester.pump(const Duration(milliseconds: 550));
      expect(toggleCalled, isTrue);

      // Dejar que termine toda la animación
      await tester.pumpAndSettle();
    },
  );
}
