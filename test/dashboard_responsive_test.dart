import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bodega_mobile/features/dashboard/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'fake_desktop_token',
      'plan_bodega': 'PRO',
      'user_rol': 'ADMIN',
      'username': 'admin',
      'nombre_bodega': 'Bodega San José Cockpit',
    });
    SharedPreferences.setMockInitialValues({
      'cajaya_operaciones_favoritas': ['bodega_online', 'compras'],
      'meta_diaria_cajaya': 1500.0,
      'plan_bodega': 'PRO',
    });
  });

  group('DashboardScreen Responsive V1 + Global Search Tests', () {
    testWidgets(
      'DashboardScreen en Desktop (1280x800) renderiza cabecera unificada, hero 3-en-1, 3 KPIs y panel de atención sin overflows',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: DashboardScreen(onNavigateTab: (_) {})),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Cabecera unificada
        expect(find.text('Hola, admin'), findsOneWidget);
        expect(find.text('Nueva Venta'), findsOneWidget);

        // Hero Financiero 3-en-1
        expect(find.text('Ventas de Hoy'), findsOneWidget);
        expect(find.text('En vivo'), findsOneWidget);
        expect(find.text('Efectivo'), findsOneWidget);
        expect(find.text('Yape'), findsOneWidget);
        expect(find.text('Plin'), findsOneWidget);
        expect(find.text('Tarjeta'), findsOneWidget);
        expect(find.text('Ver arqueo'), findsOneWidget);

        // 3 KPIs secundarios
        expect(find.text('Fiados por Cobrar'), findsOneWidget);
        expect(find.text('Catálogo & Stock'), findsOneWidget);
        expect(find.text('Valor en Mercadería'), findsOneWidget);

        // Zona inferior: Accesos rápidos + Requiere atención (Stock / Vencen)
        expect(find.text('Accesos rápidos'), findsOneWidget);
        expect(find.text('Requiere atención'), findsOneWidget);
        expect(find.text('Stock (0)'), findsOneWidget);
        expect(find.text('Vencen (0)'), findsOneWidget);

        // Cambiar pestaña a Vencen
        await tester.tap(find.text('Vencen (0)'));
        await tester.pump();
        expect(find.text('Sin lotes próximos a vencer'), findsOneWidget);
      },
    );

    testWidgets(
      'DashboardScreen en Móvil (390x844) y Compacto (360x640) renderiza sin desbordamientos',
      (tester) async {
        for (final size in [const Size(390, 844), const Size(360, 640)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: DashboardScreen(onNavigateTab: (_) {})),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('Hola, admin'), findsOneWidget);
          expect(find.text('Ventas de Hoy'), findsOneWidget);
          expect(find.text('Fiados por Cobrar'), findsOneWidget);
          expect(find.text('Accesos rápidos'), findsOneWidget);
        }
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      },
    );
  });
}
