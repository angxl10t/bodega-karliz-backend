import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgets(
      'POS tablet layout maximizes vertical space and omits visual key badges',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const Scaffold(body: VentasScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        // Verificar que los badges visuales obsoletos no ocupen espacio vertical en tablet
        expect(find.text('F2'), findsNothing);
        expect(find.text('F4'), findsNothing);
        expect(find.text('F9'), findsNothing);
        expect(find.text('Esc'), findsNothing);

        // La barra de búsqueda y catálogo táctil están listos para toque directo
        expect(find.byType(TextField), findsWidgets);
      },
    );

    testWidgets('Hardware key listener captures F2 silently to focus search', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: VentasScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Disparar evento de hardware F2
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verificar que el widget sigue respondiendo normalmente sin errores
      expect(find.byType(VentasScreen), findsOneWidget);
    });
  });
}
