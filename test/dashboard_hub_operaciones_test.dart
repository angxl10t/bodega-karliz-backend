import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    'DashboardScreen muestra exactamente los accesos rápidos guardados, confirma al añadir/quitar y soporta buscador global',
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

      // Muestra únicamente los 2 favoritos guardados (sin rellenar forzadamente con otros)
      expect(find.text('Accesos rápidos'), findsOneWidget);
      expect(find.text('+ Nuevo Producto'), findsOneWidget);
      expect(find.text('Compras & Lotes'), findsOneWidget);
      expect(find.text('Kardex Auditoría'), findsNothing);
      expect(find.textContaining('Ver todas ('), findsOneWidget);

      // Probar buscador global de módulos
      await tester.enterText(find.byType(TextField).first, 'Kardex');
      await tester.pump();
      expect(find.textContaining('MÓDULOS Y HERRAMIENTAS'), findsOneWidget);
      expect(find.text('Kardex Auditoría'), findsAtLeastNWidgets(1));

      // Limpiar búsqueda con Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.textContaining('MÓDULOS Y HERRAMIENTAS'), findsNothing);

      // Abrir modal Todas las Herramientas y añadir Kardex Auditoría con alerta de confirmación
      await tester.tap(find.textContaining('Ver todas ('));
      await tester.pumpAndSettle();

      expect(find.text('Todas las Herramientas'), findsOneWidget);
      expect(find.text('ALMACÉN'), findsOneWidget);
      expect(find.text('MOSTRADOR'), findsOneWidget);
      expect(find.text('VENTAS & WEB'), findsOneWidget);
      expect(find.text('GESTIÓN & HARDWARE'), findsOneWidget);

      final kardexCard = find.ancestor(
        of: find.text('Kardex Auditoría'),
        matching: find.byType(InkWell),
      );
      await tester.tap(
        find.descendant(
          of: kardexCard.first,
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();

      // Alerta de confirmación para añadir
      expect(find.text('¿Añadir a accesos rápidos?'), findsOneWidget);
      expect(
        find.textContaining('¿Deseas añadir "Kardex Auditoría"'),
        findsOneWidget,
      );
      await tester.tap(find.text('Sí, añadir'));
      await tester.pumpAndSettle();

      // Cerrar modal y verificar que Kardex Auditoría aparece en el inicio
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Kardex Auditoría'), findsOneWidget);

      // Probar long-press para quitar "Compras & Lotes" con alerta de confirmación
      await tester.longPress(find.text('Compras & Lotes'));
      await tester.pumpAndSettle();

      expect(find.text('¿Quitar de accesos rápidos?'), findsOneWidget);
      expect(
        find.textContaining('¿Deseas quitar "Compras & Lotes"'),
        findsOneWidget,
      );
      await tester.tap(find.text('Sí, quitar'));
      await tester.pumpAndSettle();

      expect(find.text('Compras & Lotes'), findsNothing);
      expect(
        find.textContaining(
          'Se quitó "Compras & Lotes" de tus accesos rápidos',
        ),
        findsOneWidget,
      );
    },
  );
}
