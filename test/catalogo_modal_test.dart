import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bodega_mobile/features/catalogo/catalogo_publico_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Test clicking product card, adding to cart, retroceder seleccion, and cart modal',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        final data = {
          'esPro': true,
          'mensaje': null,
          'bodega': {
            'idBodega': 3,
            'nombreComercial': 'Bodega Karliz',
            'telefono': '987654321',
            'direccion': 'Av. Principal 123',
            'lemaComercial': 'Tu bodega amiga',
            'plan': 'PRO',
            'esPro': true,
          },
          'categorias': ['Gaseosas y Bebidas'],
          'productos': [
            {
              'idProducto': 25,
              'codigo': 'SNK-0009',
              'nombre': 'Piqueo Snax Familiar 200g',
              'marca': 'Frito-Lay',
              'precioVenta': 7.50,
              'stockActual': 20.0,
              'categoria': 'Gaseosas y Bebidas',
              'imagenUrl': 'packshots/piqueo_snax.png',
              'disponible': true,
            },
          ],
        };
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CatalogoPublicoScreen(
            tiendaSlug: 'bodega-karliz',
            httpClient: mockClient,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Piqueo Snax Familiar 200g'), findsOneWidget);

      // 1. Tap the product card to open the detail modal
      await tester.tap(find.text('Piqueo Snax Familiar 200g'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify modal is shown with "Volver" and "Agregar al Pedido"
      expect(find.text('Disponible en tienda'), findsOneWidget);
      expect(find.text('Volver'), findsOneWidget);
      expect(find.text('Agregar al Pedido'), findsOneWidget);

      // 2. Tap "Agregar al Pedido" inside the modal
      await tester.tap(find.text('Agregar al Pedido'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal stays open and gives clear feedback and "Quitar" option to retroceder
      expect(find.textContaining('En tu pedido'), findsOneWidget);
      expect(find.text('Quitar'), findsOneWidget);
      expect(find.textContaining('Ver Pedido'), findsWidgets);
      expect(find.text('Seguir Comprando en el Catálogo'), findsOneWidget);

      // 3. Test "Quitar" to retroceder la selección directly inside the modal
      await tester.tap(find.text('Quitar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Selection was undone ("retrocedida")
      expect(find.text('Agregar al Pedido'), findsOneWidget);

      // 4. Re-add and tap "Seguir Comprando en el Catálogo"
      await tester.tap(find.text('Agregar al Pedido'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Seguir Comprando en el Catálogo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify floating bar shows 1 producto
      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text('Ver Pedido'), findsOneWidget);
      expect(find.textContaining('WhatsApp'), findsWidgets);

      // 5. Tap "Ver Pedido" on the floating bar to open the shopping cart modal
      await tester.tap(find.text('Ver Pedido'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Cart modal is open with details
      expect(find.text('Mi Pedido'), findsOneWidget);
      expect(find.text('Vaciar'), findsOneWidget);
      expect(find.text('TOTAL ESTIMADO:'), findsOneWidget);

      // 6. Test Vaciar Pedido
      await tester.tap(find.text('Vaciar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tu pedido está vacío'), findsOneWidget);

      // 7. Tap "Volver al Catálogo" to return
      await tester.tap(find.text('Volver al Catálogo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Floating bar is gone because cart is empty
      expect(find.text('Mi Pedido'), findsNothing);
      expect(find.text('Piqueo Snax Familiar 200g'), findsOneWidget);
    },
  );
}
