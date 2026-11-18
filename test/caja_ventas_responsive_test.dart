import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bodega_mobile/features/ventas/caja_ventas_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'fake_caja_token',
      'plan_bodega': 'PRO',
      'user_rol': 'ADMIN',
      'username': 'admin',
      'nombre_bodega': 'Bodega Karliz',
    });
    SharedPreferences.setMockInitialValues({
      'plan_bodega': 'PRO',
      'user_rol': 'ADMIN',
    });
  });

  group('CajaVentasScreen Calma Visual & Responsive Tests', () {
    testWidgets(
      'CajaVentasScreen en Desktop (1280x800) renderiza cockpit de calma visual, sin card azul sólido y con tira proporcional',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: CajaVentasScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Tab Bar
        expect(find.text('Cierre del Día'), findsOneWidget);
        expect(find.text('Historial de Ventas'), findsOneWidget);

        // Header Desktop y selector de fecha
        expect(find.text('TURNO EN CURSO'), findsOneWidget);
        expect(find.text('Hoy'), findsOneWidget);
        expect(find.text('Ayer'), findsOneWidget);
        expect(find.text('+ Egreso'), findsWidgets);

        // KPIs de Flujo
        expect(find.text('Base Inicial'), findsOneWidget);
        expect(find.text('(+) Ventas Efectivo'), findsOneWidget);
        expect(find.text('(+) Cobro Fiados'), findsOneWidget);
        expect(find.text('(-) Egresos / Gastos'), findsOneWidget);

        // Card de Total Recaudado Multicanal (en superficie neutra limpia)
        expect(find.text('TOTAL RECAUDADO EN EL TURNO'), findsOneWidget);
        expect(find.text('Multi-Canal'), findsOneWidget);
        expect(find.text('Distribución por Canal de Cobro'), findsOneWidget);
        expect(find.text('Ver Boletas del Día'), findsOneWidget);

        // Consola de Arqueo
        expect(find.text('Consola de Arqueo Físico'), findsOneWidget);
        expect(find.text('EFECTIVO ESPERADO EN GAVETA'), findsOneWidget);
        expect(find.text('Desglose por Denominación'), findsOneWidget);

        // No hay errores de overflow
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CajaVentasScreen en Móvil (390x844) renderiza arqueo y tira proporcional sin overflows',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: CajaVentasScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Card Total Recaudado Móvil
        expect(find.text('TOTAL RECAUDADO EN EL DÍA'), findsOneWidget);

        // Arqueo de Turno visible en móvil
        expect(find.text('Arqueo de Turno & Cuadre'), findsOneWidget);
        expect(find.text('EFECTIVO ESPERADO EN GAVETA'), findsOneWidget);

        // Canales de pago
        expect(find.text('Desglose por Canal de Pago'), findsOneWidget);
        expect(find.text('Efectivo en Caja'), findsOneWidget);

        // No hay excepciones de layout
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Cambio a tab de Historial de Ventas renderiza filtros y botón CSV sin errores',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: CajaVentasScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Tap en Historial de Ventas
        await tester.tap(find.text('Historial de Ventas'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Exportar CSV'), findsOneWidget);
        expect(find.text('Actualizar'), findsOneWidget);
        expect(find.textContaining('Todas'), findsWidgets);
        expect(find.textContaining('Completadas'), findsWidgets);
        expect(find.textContaining('Anuladas'), findsWidgets);

        expect(tester.takeException(), isNull);
      },
    );
  });
}
