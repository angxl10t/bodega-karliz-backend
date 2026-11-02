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
    testWidgets('Test mobile screen ${size.width}x${size.height} opening product modal and adding to cart', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final rawJson = File('test/real_catalog_data.json').readAsStringSync(encoding: utf8);
      final Map<String, dynamic> data = jsonDecode(rawJson);

      final mockClient = MockClient((request) async {
        return http.Response(rawJson, 200, headers: {'content-type': 'application/json; charset=utf-8'});
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

      // Verify we can tap "Quitar" to roll back selection
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Agregar al Pedido'), findsOneWidget);
    });
  }
}
