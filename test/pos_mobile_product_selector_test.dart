import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/ventas/ventas_screen.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';

void main() {
  group('POS Mobile Product Selector & Stepper Tests', () {
    setUp(() {
      ProductoService.setMockProductos([
        Producto(
          idProducto: 1,
          nombre: 'Inca Kola 500ml',
          precioVenta: 3.50,
          stockActual: 24,
          codigo: 'BEB-001',
          nombreCategoria: 'Bebidas',
        ),
        Producto(
          idProducto: 2,
          nombre: 'Galletas Casino Menta',
          precioVenta: 1.20,
          stockActual: 15,
          codigo: 'SNA-002',
          nombreCategoria: 'Snacks',
        ),
      ]);
    });

    testWidgets(
      'Abre selector de productos móvil con categorías, cuadrícula y stepper in-situ',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: VentasScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // 1. Tocar barra de búsqueda para abrir el selector modal
        final searchBar = find.text('Buscar producto o código...');
        expect(searchBar, findsOneWidget);
        await tester.tap(searchBar);
        await tester.pumpAndSettle();

        // 2. Verificar que se renderiza el modal con Propuesta A
        expect(find.text('Catálogo de Productos'), findsOneWidget);
        expect(find.text('Todos'), findsOneWidget);
        expect(find.text('Mostrando 2 productos'), findsOneWidget);
        expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
        expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);

        // 3. Verificar que los productos están en cuadrícula
        expect(find.text('Inca Kola 500ml'), findsWidgets);
        expect(find.text('Galletas Casino Menta'), findsWidgets);

        // 4. Agregar Inca Kola al carrito tocando "Agregar"
        final agregarBotones = find.text('Agregar');
        expect(agregarBotones, findsWidgets);
        await tester.tap(agregarBotones.first);
        await tester.pumpAndSettle();

        // 5. Verificar que aparece el stepper in-situ con cantidad 1
        expect(find.text('1'), findsWidgets);
        expect(
          find.byIcon(Icons.add),
          findsNothing,
        ); // Icon is LucideIcons.plus

        // 6. Verificar que la barra flotante de checkout muestra el total
        expect(find.text('CANASTA • 1 PROD.'), findsOneWidget);
        expect(find.text('S/ 3.50'), findsWidgets);
        expect(find.text('Listo / Cobrar'), findsOneWidget);

        // 7. Cambiar a modo Lista usando el toggle
        await tester.tap(find.byIcon(Icons.view_list_rounded));
        await tester.pumpAndSettle();

        // Verificar que sigue mostrando los productos en lista
        expect(find.text('Inca Kola 500ml'), findsWidgets);
        expect(find.text('Galletas Casino Menta'), findsWidgets);

        // 8. Tocar "Listo / Cobrar" para cerrar el catálogo
        await tester.tap(find.text('Listo / Cobrar'));
        await tester.pumpAndSettle();

        // Debe haber vuelto a la pantalla de ventas con el item en la canasta
        expect(find.text('Catálogo de Productos'), findsNothing);
        expect(find.text('Inca Kola 500ml'), findsWidgets);
      },
    );
  });
}
