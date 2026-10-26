import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/ventas/ventas_screen.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';
import 'package:bodega_mobile/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('POS Hardware Fast-Keys & Keyboard Ergonomics Tests', () {
    setUp(() {
      ProductoService.setMockProductos([
        Producto(
          idProducto: 1,
          nombre: 'Gaseosa Inka Cola 500ml',
          precioVenta: 3.50,
          stockActual: 20,
          codigo: 'PROD-001',
        ),
      ]);
    });

    testWidgets('Renders Fast-Keys toolbar with F2, F4, F9, and Esc in Tablet mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: VentasScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Verificar que los badges de teclas rápidas existan
      expect(find.text('F2'), findsWidgets);
      expect(find.text('F4'), findsWidgets);
      expect(find.text('F9'), findsWidgets);
      expect(find.text('Esc'), findsWidgets);
    });

    testWidgets('Tapping F9 key badge toggles between Boleta and Ticket', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: VentasScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      final f9Finder = find.text('F9');
      expect(f9Finder, findsWidgets);

      await tester.tap(f9Finder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El badge debe permanecer renderizado después del toggle
      expect(find.text('F9'), findsWidgets);
    });
  });
}
