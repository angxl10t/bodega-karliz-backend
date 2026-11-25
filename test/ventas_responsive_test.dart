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

        // Verificar las 6 acciones visibles del turno en barra unificada
        expect(find.text('Garantía Botellas'), findsAtLeastNWidgets(1));
        expect(find.text('En Espera'), findsAtLeastNWidgets(1));
        expect(find.text('Pedidos Web'), findsAtLeastNWidgets(1));
        expect(find.text('Egreso Caja'), findsAtLeastNWidgets(1));
        expect(find.text('Cierre Caja'), findsAtLeastNWidgets(1));
        expect(find.text('Abrir Gaveta'), findsAtLeastNWidgets(1));
        expect(find.text('Más opciones'), findsOneWidget);

        // Abrir el menú agrupado "Más opciones" y verificar utilidades secundarias
        await tester.tap(find.text('Más opciones'));
        await tester.pumpAndSettle();

        expect(find.text('Hardware POS'), findsOneWidget);
        expect(find.text('Ticket'), findsOneWidget);
        expect(find.text('Tips Turno'), findsOneWidget);
        expect(find.text('Sincronizar'), findsOneWidget);
      },
    );

    testWidgets(
      'VentasScreen en tablet vertical (680x1024, 768x1024, 768x600) muestra total de cobro sin overflow ni superposición',
      (tester) async {
        for (final size in [
          const Size(680, 1024),
          const Size(768, 1024),
          const Size(768, 600),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('ventas_portrait_$size'),
              home: const Scaffold(body: VentasScreen()),
            ),
          );
          await tester.pumpAndSettle();

          // Agrega producto al carrito desde la grilla tablet
          await tester.tap(find.text('Inca Kola 1.5L Vidrio Retornable').first);
          await tester.pumpAndSettle();

          // Verifica que el total/monto de cobro aparece y no se sobrepone sobre cabecera ni sale de la pantalla
          expect(find.textContaining('5.50'), findsAtLeastNWidgets(1));
          final totalLabelRect = tester.getRect(find.text('TOTAL A COBRAR'));
          final ticketHeaderRect = tester.getRect(
            find.text('TICKET POS • CAJA 1'),
          );
          expect(totalLabelRect.overlaps(ticketHeaderRect), isFalse);
          expect(totalLabelRect.top >= ticketHeaderRect.bottom, isTrue);
          expect(totalLabelRect.bottom <= size.height, isTrue);
        }

        // Simula tablet vertical (768x1024) con teclado en pantalla abierto
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.viewInsets = const FakeViewPadding(bottom: 340);
        addTearDown(tester.view.resetViewInsets);

        await tester.pumpWidget(
          const MaterialApp(
            key: ValueKey('ventas_portrait_keyboard'),
            home: Scaffold(body: VentasScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Inca Kola 1.5L Vidrio Retornable').first);
        await tester.pumpAndSettle();

        final totalKbRect = tester.getRect(find.text('TOTAL A COBRAR'));
        final headerKbRect = tester.getRect(find.text('TICKET POS • CAJA 1'));
        expect(totalKbRect.overlaps(headerKbRect), isFalse);
        expect(totalKbRect.bottom <= 1024 - 340, isTrue);
      },
    );
  });
}
