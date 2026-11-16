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
      'nombre_bodega': 'Bodega San José Cockpit',
    });
    SharedPreferences.setMockInitialValues({
      'cajaya_operaciones_favoritas': ['nuevo_producto', 'compras'],
      'meta_diaria_cajaya': 1500.0,
      'plan_bodega': 'PRO',
    });
  });

  group('DashboardScreen Responsive Cockpit & Craft Tests', () {
    testWidgets(
      'DashboardScreen en Desktop (1280x800) renderiza cockpit de 2 columnas con resumen financiero y panel lateral',
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

        // Cabecera ejecutiva y métricas
        expect(find.text('Métricas Clave del Negocio'), findsOneWidget);
        expect(find.text('Actualizado hoy (En vivo)'), findsOneWidget);

        // Los 4 pilares financieros
        expect(find.text('Ventas de Hoy'), findsOneWidget);
        expect(find.text('Fiados por Cobrar'), findsOneWidget);
        expect(find.text('Valor en Mercadería'), findsOneWidget);
        expect(find.text('Catálogo & Stock'), findsOneWidget);

        // Flujo de caja y Hub
        expect(find.text('Flujo de Caja en Directo (Hoy)'), findsOneWidget);
        expect(find.text('Operaciones & Herramientas'), findsOneWidget);

        // Columna lateral de control
        expect(find.text('Alertas de Reposición'), findsOneWidget);
      },
    );

    testWidgets(
      'DashboardScreen en Móvil (390x844) renderiza flujo vertical optimizado sin desbordamientos',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
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

        expect(find.text('Métricas Clave del Negocio'), findsOneWidget);
        expect(find.text('Ventas de Hoy'), findsOneWidget);
        expect(find.text('Fiados por Cobrar'), findsOneWidget);
      },
    );
  });
}
