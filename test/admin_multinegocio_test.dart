import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/home/pixel_perfect_navbar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('PixelPerfectNavBar Multinegocio Adaptations', () {
    testWidgets(
      'KarlizPixelPerfectNavBar shows Bodega labels when esGastronomico is false',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: KarlizPixelPerfectNavBar(
                selectedIndex: 0,
                onItemSelected: (_) {},
                isDark: false,
                esGastronomico: false,
              ),
            ),
          ),
        );

        final navBar = tester.widget<KarlizPixelPerfectNavBar>(
          find.byType(KarlizPixelPerfectNavBar),
        );
        expect(navBar.currentItems[3].label, 'Stock');
        expect(navBar.currentItems[4].label, 'Fiados');
        expect(navBar.currentItems[4].icon, LucideIcons.bookUser);
      },
    );

    testWidgets(
      'KarlizPixelPerfectNavBar shows Gastronomía labels when esGastronomico is true',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: KarlizPixelPerfectNavBar(
                selectedIndex: 0,
                onItemSelected: (_) {},
                isDark: false,
                esGastronomico: true,
              ),
            ),
          ),
        );

        final navBar = tester.widget<KarlizPixelPerfectNavBar>(
          find.byType(KarlizPixelPerfectNavBar),
        );
        expect(navBar.currentItems[3].label, 'Carta');
        expect(navBar.currentItems[4].label, 'Clientes');
        expect(navBar.currentItems[4].icon, LucideIcons.users);
      },
    );
  });

  group('Giro de Negocio Gastronómico Detection Tests', () {
    bool isGiroGastronomico(String? giro) {
      final g = (giro ?? '').toUpperCase();
      return g == 'POLLERIA' ||
          g == 'CHIFA' ||
          g == 'FASTFOOD' ||
          g.contains('FAST') ||
          g == 'RESTAURANTE';
    }

    test('Identifies POLLERIA as gastronómico', () {
      expect(isGiroGastronomico('POLLERIA'), isTrue);
      expect(isGiroGastronomico('polleria'), isTrue);
    });

    test('Identifies CHIFA as gastronómico', () {
      expect(isGiroGastronomico('CHIFA'), isTrue);
      expect(isGiroGastronomico('chifa'), isTrue);
    });

    test('Identifies FASTFOOD & RESTAURANTE as gastronómico', () {
      expect(isGiroGastronomico('FASTFOOD'), isTrue);
      expect(isGiroGastronomico('RESTAURANTE'), isTrue);
    });

    test(
      'Identifies BODEGA and MINIMARKET as non-gastronómico (grocery retail)',
      () {
        expect(isGiroGastronomico('BODEGA'), isFalse);
        expect(isGiroGastronomico('bodega'), isFalse);
        expect(isGiroGastronomico('MINIMARKET'), isFalse);
        expect(isGiroGastronomico(null), isFalse);
      },
    );
  });
}
