import 'package:bodega_mobile/core/theme.dart';
import 'package:bodega_mobile/core/theme_provider.dart';
import 'package:bodega_mobile/features/auth/login_screen.dart';
import 'package:bodega_mobile/features/home/mi_suscripcion_modal.dart';
import 'package:bodega_mobile/features/home/plan_y_personal_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Login Privacy Hint & Dark Mode High Contrast Tests', () {
    test('AppTheme adaptive text helpers return high-contrast light colors in dark mode', () {
      expect(AppTheme.getAdaptiveMutedText(true), const Color(0xFFE2E8F0));
      expect(AppTheme.getAdaptiveMutedText(false), const Color(0xFF334155));
      expect(AppTheme.getAdaptiveHintText(true), const Color(0xFFCBD5E1));
      expect(AppTheme.getAdaptiveHintText(false), const Color(0xFF64748B));
    });

    testWidgets(
      'LoginScreen in dark mode hides admin hint suggestion and uses high-contrast hint/label colors',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(),
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.dark,
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        expect(textFields, hasLength(2));
        expect(textFields[0].decoration?.hintText, 'Ingresa tu usuario');
        expect(textFields[0].decoration?.hintText, isNot('admin'));
        expect(find.text('admin'), findsNothing);
        expect(
          textFields[0].decoration?.hintStyle?.color,
          AppTheme.getAdaptiveHintText(true),
        );

        final rememberLabel = tester.widget<Text>(
          find.text('Recordar dispositivo'),
        );
        expect(rememberLabel.style?.color, AppTheme.getAdaptiveMutedText(true));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PlanYPersonalSheet & MiSuscripcionModal in dark mode avoid low-contrast AppTheme.textMuted on muted labels',
      (tester) async {
        tester.view.physicalSize = const Size(420, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const Scaffold(
              body: PlanYPersonalSheet(
                nombreBodega: 'Bodega Dark Contrast',
                plan: 'BASICO',
                currentUsername: 'owner_test',
                userRol: 'ADMIN',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final subtitleWidget = tester.widget<Text>(
          find.text('Bodega Dark Contrast').first,
        );
        expect(
          subtitleWidget.style?.color,
          AppTheme.getAdaptiveMutedText(true),
        );
        final lowContrastTextsInSheet = tester
            .widgetList<Text>(find.byType(Text))
            .where((t) => t.style?.color == AppTheme.textMuted);
        expect(lowContrastTextsInSheet, isEmpty);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => MiSuscripcionModal.show(
                      ctx,
                      nombreBodega: 'Bodega Dark Contrast',
                      planActual: 'BASICO',
                    ),
                    child: const Text('Abrir Plan Dark'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Plan Dark'));
        await tester.pumpAndSettle();

        expect(find.text('Mi Plan y Suscripción'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
