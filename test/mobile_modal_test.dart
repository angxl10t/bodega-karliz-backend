import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bodega_mobile/features/catalogo/catalogo_publico_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final screenSizes = [
    const Size(360, 640), // Android compact (Moto, Galaxy A)
    const Size(375, 667), // iPhone SE
    const Size(390, 844), // iPhone 12/13/14
    const Size(412, 915), // Pixel / Galaxy S
  ];

  for (final size in screenSizes) {
    testWidgets(
      'Test mobile screen ${size.width}x${size.height} opening product modal and adding to cart',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final rawJson = File('test/real_catalog_data.json')
            .readAsStringSync(encoding: utf8);
        final Map<String, dynamic> data = jsonDecode(rawJson);

        final mockClient = MockClient((request) async {
          return http.Response(
            rawJson,
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

        await tester.pumpAndSettle();

        final prods = data['productos'] as List;

        // Find first visible product
        final p0 = prods[0];
        final nombre0 = p0['nombre'] as String;

        // Scroll down so product cards are comfortably in view on compact screens
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
        await tester.pumpAndSettle();

        expect(find.text(nombre0), findsWidgets);
        await tester.tap(find.text(nombre0).first);
        await tester.pumpAndSettle();

        // Check if modal has any overflow or layout errors
        expect(tester.takeException(), isNull);

        // Now tap "Agregar al Pedido"
        final agregarBtn = find.text('Agregar al Pedido');
        expect(agregarBtn, findsOneWidget);
        await tester.tap(agregarBtn);
        await tester.pumpAndSettle();

        // Check if adding to cart has any overflow or layout errors
        expect(tester.takeException(), isNull);

        // Verify that the product is now in the cart and stepper is visible
        expect(find.text('En tu pedido (1 unidad)'), findsOneWidget);
        expect(find.text('Quitar'), findsOneWidget);

        // Now tap "Ver Pedido (1)" inside the product modal
        final verPedidoBtn = find.text('Ver Pedido (1)');
        expect(verPedidoBtn, findsOneWidget);
        await tester.tap(verPedidoBtn);
        await tester.pumpAndSettle();

        // We should now be in the Cart modal ("Mi Pedido")
        expect(find.text('Mi Pedido'), findsOneWidget);

        // In Cart modal, tap the Seguir button
        final seguirBtn = find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('Seguir') ?? false),
        );
        expect(seguirBtn, findsWidgets);
        await tester.tap(seguirBtn.last);
        await tester.pumpAndSettle();

        // Cart modal should now be closed
        expect(find.text('Mi Pedido'), findsNothing);

        // Verify that the catalog scroll view has FULL height and is active
        final scrollFinder = find.byType(CustomScrollView);
        expect(scrollFinder, findsOneWidget);
        final scrollRect = tester.getRect(scrollFinder);
        expect(
          scrollRect.height,
          greaterThan(400.0),
          reason: 'CustomScrollView must have full height and not collapse',
        );

        // Now tap the product card again or tap another product
        expect(find.text(nombre0), findsWidgets);
        await tester.tap(find.text(nombre0).first);
        await tester.pumpAndSettle();

        // Product modal opens
        expect(find.text('Seguir Comprando en el Catálogo'), findsOneWidget);

        // Tap "Seguir Comprando en el Catálogo"
        await tester.tap(find.text('Seguir Comprando en el Catálogo'));
        await tester.pumpAndSettle();

        // Product modal closes cleanly and is NOT left as a residual view
        expect(find.text('Disponible en tienda'), findsNothing);
        expect(find.text('Seguir Comprando en el Catálogo'), findsNothing);
      },
    );
  }
}
