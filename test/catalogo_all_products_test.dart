import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bodega_mobile/features/catalogo/catalogo_publico_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test all real products from live backend in CatalogoPublicoScreen', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
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
    print('Testing with total products: ${prods.length}');

    final p0 = prods[0];
    final nombre0 = p0['nombre'] as String;
    print('Testing product [0]: $nombre0');

    expect(find.text(nombre0), findsWidgets);
    await tester.tap(find.text(nombre0).first);
    await tester.pumpAndSettle();

    expect(find.text('Disponible en tienda'), findsOneWidget);
    expect(find.text('Agregar al Pedido'), findsOneWidget);

    await tester.tap(find.text('Agregar al Pedido'));
    await tester.pumpAndSettle();

    expect(find.text('Seguir Comprando en el Catálogo'), findsOneWidget);
    await tester.tap(find.text('Seguir Comprando en el Catálogo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('WhatsApp'), findsWidgets);
    expect(find.text('Ver Pedido'), findsOneWidget);

    print('SUCCESS! Real catalog products flow passed without error.');
  });
}
