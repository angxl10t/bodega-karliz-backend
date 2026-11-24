import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/core/theme_provider.dart';
import 'package:bodega_mobile/core/karliz_sound_service.dart';
import 'package:bodega_mobile/core/widgets/accessibility_panel_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Accessibility & Ergonomics Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ThemeProvider initializes with default accessibility settings', () {
      final provider = ThemeProvider();
      expect(provider.fontScale, 1.0);
      expect(provider.highContrast, isFalse);
      expect(provider.assistedIcons, isTrue);
      expect(provider.soundEnabled, isTrue);
      expect(KarlizSoundService.instance.soundEnabled, isTrue);
    });

    test('ThemeProvider updates font scale dynamically', () async {
      final provider = ThemeProvider();
      await provider.setFontScale(1.15);
      expect(provider.fontScale, 1.15);

      await provider.setFontScale(1.30);
      expect(provider.fontScale, 1.30);
    });

    test(
      'ThemeProvider updates high contrast mode and adapts ThemeData',
      () async {
        final provider = ThemeProvider();
        await provider.setHighContrast(true);
        expect(provider.highContrast, isTrue);

        final darkTheme = provider.darkTheme;
        expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF000000));

        final lightTheme = provider.lightTheme;
        expect(lightTheme.scaffoldBackgroundColor, Colors.white);
      },
    );

    test(
      'ThemeProvider updates soundEnabled and controls KarlizSoundService',
      () async {
        final provider = ThemeProvider();
        await provider.setSoundEnabled(false);
        expect(provider.soundEnabled, isFalse);
        expect(KarlizSoundService.instance.soundEnabled, isFalse);

        await provider.setSoundEnabled(true);
        expect(provider.soundEnabled, isTrue);
        expect(KarlizSoundService.instance.soundEnabled, isTrue);
      },
    );

    testWidgets('AccessibilityPanelModal renders all ergonomic controls', (
      tester,
    ) async {
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: MaterialApp(
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            home: const Scaffold(body: AccessibilityPanelModal()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Encabezado
      expect(find.text('Accesibilidad & Confort'), findsOneWidget);

      // 1. Color de Marca
      expect(find.text('Color de Marca (POS & Web)'), findsOneWidget);
      expect(find.text('Cobalto'), findsOneWidget);
      expect(find.text('Esmeralda'), findsOneWidget);
      expect(find.text('Verde Retail'), findsOneWidget);
      expect(find.text('Violeta'), findsOneWidget);
      expect(find.text('Rubí'), findsOneWidget);

      // 2. Tamaño de texto
      expect(find.text('Tamaño de Texto (Lectura Fácil)'), findsOneWidget);
      expect(find.text('100% Normal'), findsOneWidget);
      expect(find.text('115% Cómodo'), findsOneWidget);
      expect(find.text('130% Grande'), findsOneWidget);

      // 3. Contraste
      expect(find.text('Contraste Extremo (WCAG AAA)'), findsOneWidget);

      // 4. Daltonismo
      expect(find.text('Iconos Asistidos (Daltonismo)'), findsOneWidget);

      // 5. Beeps
      expect(find.text('Beeps Auditivos POS'), findsOneWidget);
      expect(find.text('Probar Beep de Escáner'), findsOneWidget);
    });

    testWidgets('Tapping font scale updates ThemeProvider scale', (
      tester,
    ) async {
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: MaterialApp(
            theme: themeProvider.lightTheme,
            home: const Scaffold(body: AccessibilityPanelModal()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('115% Cómodo'));
      await tester.pumpAndSettle();

      expect(themeProvider.fontScale, 1.15);

      await tester.tap(find.text('130% Grande'));
      await tester.pumpAndSettle();

      expect(themeProvider.fontScale, 1.30);
    });

    testWidgets('Tapping color preset updates ThemeProvider accent color', (
      tester,
    ) async {
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: MaterialApp(
            theme: themeProvider.lightTheme,
            home: const Scaffold(body: AccessibilityPanelModal()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Esmeralda'));
      await tester.pumpAndSettle();

      expect(themeProvider.accentColorHex, '#059669');
      expect(themeProvider.accentColor, const Color(0xFF059669));

      await tester.tap(find.text('Violeta'));
      await tester.pumpAndSettle();

      expect(themeProvider.accentColorHex, '#7C3AED');
      expect(themeProvider.accentColor, const Color(0xFF7C3AED));
    });
  });
}
