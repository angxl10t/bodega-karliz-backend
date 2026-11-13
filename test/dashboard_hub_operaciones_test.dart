import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/features/dashboard/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'test_token',
      'plan_bodega': 'PRO',
      'user_rol': 'ADMIN',
      'nombre_bodega': 'Bodega San José',
    });
    SharedPreferences.setMockInitialValues({
      'cajaya_operaciones_favoritas': ['nuevo_producto', 'compras'],
      'meta_diaria_cajaya': 1200.0,
      'plan_bodega': 'PRO',
    });
  });

  testWidgets(
    'DashboardScreen renderiza Hub de Operaciones por categorías y pestaña Favoritos',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DashboardScreen(onNavigateTab: (_) {})),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Verificar cabecera del hub y selector de favoritos
      expect(find.text('Operaciones & Herramientas'), findsOneWidget);
      expect(find.text('Personalizar ⭐'), findsOneWidget);

      // Verificar las 4 pestañas de categorías tipo píldora
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.text('Almacén'), findsOneWidget);
      expect(find.text('Ventas & Web'), findsOneWidget);
      expect(find.text('Gestión'), findsOneWidget);

      // Por defecto en pestaña Favoritos: muestra los favoritos y la tarjeta para añadir
      expect(find.text('+ Nuevo Producto'), findsOneWidget);
      expect(find.text('Compras & Lotes'), findsOneWidget);
      expect(find.text('+ Añadir Favorito'), findsOneWidget);

      // Cambiar a pestaña Almacén
      await tester.tap(find.text('Almacén'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Control Vencimientos'), findsOneWidget);
      expect(find.text('Registro de Mermas'), findsOneWidget);
      expect(find.text('Kardex Auditoría'), findsOneWidget);

      // Cambiar a pestaña Ventas & Web
      await tester.tap(find.text('Ventas & Web'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Mi Bodega Online'), findsOneWidget);
      expect(find.text('Promociones & Combos'), findsOneWidget);
      expect(find.text('Analítica & Rentabilidad'), findsOneWidget);

      // Cambiar a pestaña Gestión
      await tester.tap(find.text('Gestión'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Impresora Térmica'), findsOneWidget);

      // Abrir modal de personalización de favoritos
      await tester.tap(find.text('Personalizar ⭐'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Personalizar Accesos Favoritos'), findsOneWidget);
      expect(find.text('Restablecer'), findsOneWidget);
    },
  );
}
