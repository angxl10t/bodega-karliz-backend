import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/core/responsive_layout.dart';
import 'package:bodega_mobile/features/ventas/ventas_screen.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';

void main() {
  group('ResponsiveLayout Breakpoint & Builder Tests', () {
    testWidgets(
      'ResponsiveBuilder renders mobile layout on small width (< 650dp)',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResponsiveBuilder(
                mobile: (ctx, constraints) => const Text('VISTA_MOVIL'),
                tablet: (ctx, constraints) => const Text('VISTA_TABLET'),
              ),
            ),
          ),
        );

        expect(find.text('VISTA_MOVIL'), findsOneWidget);
        expect(find.text('VISTA_TABLET'), findsNothing);
      },
    );

    testWidgets(
      'ResponsiveBuilder renders tablet layout on wider width (>= 650dp)',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResponsiveBuilder(
                mobile: (ctx, constraints) => const Text('VISTA_MOVIL'),
                tablet: (ctx, constraints) => const Text('VISTA_TABLET'),
              ),
            ),
          ),
        );

        expect(find.text('VISTA_TABLET'), findsOneWidget);
        expect(find.text('VISTA_MOVIL'), findsNothing);
      },
    );

    testWidgets(
      'ResponsiveLayout detects physical tablet (shortestSide >= 600) and landscape',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        late bool isTabletDetected;
        late bool isLandscapeDetected;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) {
                isTabletDetected = ResponsiveLayout.isPhysicalTablet(ctx);
                isLandscapeDetected = ResponsiveLayout.isLandscape(ctx);
                return Container();
              },
            ),
          ),
        );

        expect(isTabletDetected, isTrue);
        expect(isLandscapeDetected, isTrue);
      },
    );

    testWidgets(
      'ResponsiveLayout detects smartphone (shortestSide < 600) in portrait',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        late bool isTabletDetected;
        late bool isLandscapeDetected;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) {
                isTabletDetected = ResponsiveLayout.isPhysicalTablet(ctx);
                isLandscapeDetected = ResponsiveLayout.isLandscape(ctx);
                return Container();
              },
            ),
          ),
        );

        expect(isTabletDetected, isFalse);
        expect(isLandscapeDetected, isFalse);
      },
    );
  });

  group('VentasScreen Tablet / Desktop Visibility Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ProductoService.setMockProductos([
        Producto(
          idProducto: 1,
          nombre: 'Inca Kola 1.5L Vidrio Retornable',
          precioVenta: 5.50,
          stockActual: 10.0,
          codigo: 'IK1500',
          nombreCategoria: 'Bebidas',
        ),
      ]);
    });

    testWidgets(
      'VentasScreen en resolución Tablet/Desktop (1024x768) muestra Garantía Botellas y todas las acciones de caja',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: VentasScreen())),
        );
        await tester.pumpAndSettle();

        // Verificar que en vista de tablet/ordenador aparezca el chip de Garantía Botellas
        expect(find.text('Garantía Botellas'), findsAtLeastNWidgets(1));

        // Verificar que las demás acciones críticas de caja estén visibles
        expect(find.text('En Espera'), findsAtLeastNWidgets(1));
        expect(find.text('Pedidos Web'), findsAtLeastNWidgets(1));
        expect(find.text('Egreso Caja'), findsAtLeastNWidgets(1));
        expect(find.text('Cierre Caja'), findsAtLeastNWidgets(1));
        expect(find.text('Tips Turno'), findsAtLeastNWidgets(1));
        expect(find.text('Ticket'), findsAtLeastNWidgets(1));
      },
    );
  });
}
