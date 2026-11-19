import 'package:bodega_mobile/core/theme.dart';
import 'package:bodega_mobile/core/theme_provider.dart';
import 'package:bodega_mobile/features/auth/login_screen.dart';
import 'package:bodega_mobile/features/auth/registro_bodega_sheet.dart';
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

  group('Multinegocio Onboarding & Cajero PIN Tests', () {
    testWidgets(
      'RegistroBodegaSheet muestra selector de giros comerciales (Bodega, Pollería, Chifa, Fast Food)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(),
            child: const MaterialApp(
              home: Scaffold(body: RegistroBodegaSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica que aparezca el selector de giro
        expect(find.text('Giro de tu Negocio *'), findsOneWidget);
        expect(find.text('Bodega & Minimarket'), findsOneWidget);
        expect(find.text('Pollería & Brasas'), findsOneWidget);
        expect(find.text('Chifa & Oriental'), findsOneWidget);
        expect(find.text('Fast Food & Sanguchería'), findsOneWidget);

        // Verifica régimen tributario
        await tester.ensureVisible(
          find.text('Régimen Tributario SUNAT (Opcional)'),
        );
        expect(
          find.text('Régimen Tributario SUNAT (Opcional)'),
          findsOneWidget,
        );
        expect(find.text('Nuevo RUS (Tickets)'), findsOneWidget);
        expect(find.text('MYPE (Facturas)'), findsOneWidget);

        // Cambiar giro a Pollería
        await tester.ensureVisible(find.text('Pollería & Brasas'));
        await tester.tap(find.text('Pollería & Brasas'), warnIfMissed: false);
        await tester.pumpAndSettle();

        // Debe sugerir catálogo de pollería en el banner
        expect(
          find.textContaining('Tu pollería se creará con categorías de Brasas'),
          findsOneWidget,
        );

        // Cambiar giro a Chifa
        await tester.ensureVisible(find.text('Chifa & Oriental'));
        await tester.tap(find.text('Chifa & Oriental'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Tu chifa se creará con categorías de Arroces Chaufas',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LoginScreen conmuta entre modo Dueño/Admin y modo Cajero (PIN) con teclado ergonómico',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // En modo Dueño por defecto: se ven los textfields de usuario y password
        expect(find.text('Dueño / Admin'), findsOneWidget);
        expect(find.text('Cajero (PIN)'), findsOneWidget);
        expect(find.text('USUARIO / OPERADOR'), findsOneWidget);
        expect(find.text('CONTRASEÑA'), findsOneWidget);
        expect(find.text('INGRESAR AL SISTEMA'), findsOneWidget);

        // Cambiar a Modo Cajero (PIN)
        await tester.tap(find.text('Cajero (PIN)'));
        await tester.pumpAndSettle();

        // Ya no deben verse los inputs tradicionales de usuario/clave
        expect(find.text('USUARIO / OPERADOR'), findsNothing);
        expect(find.text('CONTRASEÑA'), findsNothing);

        // Deben verse la vinculación o badge de terminal y el teclado numérico
        expect(find.text('Vincular Terminal'), findsOneWidget);
        expect(find.text('Ingresa tu PIN de 4 dígitos'), findsOneWidget);

        // Teclado 0-9 y botón C
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        expect(find.text('C'), findsOneWidget);

        // Pulsar dígitos en el teclado numérico
        await tester.tap(find.text('1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('3'));
        await tester.pumpAndSettle();

        // Pulsar C para limpiar
        await tester.tap(find.text('C'));
        await tester.pumpAndSettle();

        // Regresar a Modo Dueño
        await tester.tap(find.text('Dueño / Admin'));
        await tester.pumpAndSettle();

        expect(find.text('USUARIO / OPERADOR'), findsOneWidget);
        expect(find.text('CONTRASEÑA'), findsOneWidget);
      },
    );
  });
}
