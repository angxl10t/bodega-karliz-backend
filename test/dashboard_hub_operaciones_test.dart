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
      'jwt_token': 'test_token',
      'plan_bodega': 'PRO',
      'user_rol': 'ADMIN',
      'username': 'admin',
      'nombre_bodega': 'Bodega San José',
    });
    SharedPreferences.setMockInitialValues({
      'cajaya_operaciones_favoritas': ['nuevo_producto', 'compras'],
      'meta_diaria_cajaya': 1200.0,
      'plan_bodega': 'PRO',
    });
  });

  testWidgets(
    'DashboardScreen renderiza Accesos rápidos, modal Todas las Herramientas y buscador global',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DashboardScreen(onNavigateTab: (_) {})),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Cabecera unificada con saludo y buscador global
      expect(find.text('Hola, admin'), findsOneWidget);
      expect(find.text('Nueva Venta'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.hintText?.contains('Buscar producto') ?? false),
        ),
        findsOneWidget,
      );

      // Sección de Accesos rápidos con favoritos guardados + defaults
      expect(find.text('Accesos rápidos'), findsOneWidget);
      expect(find.text('+ Nuevo Producto'), findsOneWidget);
      expect(find.text('Compras & Lotes'), findsOneWidget);
      expect(find.textContaining('Ver todas ('), findsOneWidget);

      // Probar buscador global de módulos
      await tester.enterText(find.byType(TextField).first, 'Kardex');
      await tester.pump();
      expect(find.textContaining('MÓDULOS Y HERRAMIENTAS'), findsOneWidget);
      expect(find.text('Kardex Auditoría'), findsAtLeastNWidgets(1));

      // Limpiar búsqueda
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      // Abrir modal de Todas las Herramientas
      await tester.tap(find.textContaining('Ver todas ('));
      await tester.pumpAndSettle();

      expect(find.text('Todas las Herramientas'), findsOneWidget);
      expect(find.text('ALMACÉN'), findsOneWidget);
      expect(find.text('VENTAS & WEB'), findsOneWidget);
      expect(find.text('GESTIÓN & HARDWARE'), findsOneWidget);
      expect(find.text('Control Vencimientos'), findsOneWidget);
      expect(find.text('Mi Bodega Online'), findsAtLeastNWidgets(1));
      expect(find.text('Impresora Térmica'), findsAtLeastNWidgets(1));

      // Cerrar modal y probar long-press en favorito
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Compras & Lotes'));
      await tester.pump();
      expect(
        find.textContaining(
          'Se quitó "Compras & Lotes" de tus accesos rápidos',
        ),
        findsOneWidget,
      );
    },
  );
}
