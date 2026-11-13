import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bodega_mobile/features/catalogo/catalogo_publico_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CatalogoPublicoScreen renders store catalog and products when Bodega has Plan PRO',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
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
            'idBodega': 1,
            'nombreComercial': 'Bodega Karliz',
            'telefono': '987654321',
            'direccion': 'Av. Principal 123',
            'lemaComercial': 'Tu bodega de confianza',
            'plan': 'PRO',
            'esPro': true,
          },
          'categorias': ['Bebidas', 'Abarrotes'],
          'productos': [
            {
              'idProducto': 101,
              'codigo': '7750106001',
              'nombre': 'Inca Kola 500ml',
              'marca': 'Inca Kola',
              'precioVenta': 3.50,
              'stockActual': 10.0,
              'categoria': 'Bebidas',
              'imagenUrl': '',
              'disponible': true,
            },
            {
              'idProducto': 102,
              'codigo': '7750106002',
              'nombre': 'Arroz Costeño 1kg',
              'marca': 'Costeño',
              'precioVenta': 4.80,
              'stockActual': 25.0,
              'categoria': 'Abarrotes',
              'imagenUrl': '',
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

      expect(find.text('Bodega Karliz'), findsWidgets);
      expect(find.text('Inca Kola 500ml'), findsOneWidget);
      expect(find.text('Arroz Costeño 1kg'), findsOneWidget);
      expect(find.text('S/ 3.50'), findsOneWidget);
      expect(find.text('S/ 4.80'), findsOneWidget);
      expect(find.text('PRO ONLINE'), findsOneWidget);

      // Tap "Agregar" on first item
      final agregarBtn = find.text('Agregar').first;
      await tester.tap(agregarBtn);
      await tester.pump();

      // Floating bar appears with 1 product and WhatsApp button
      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text('S/ 3.50'), findsWidgets);
      expect(find.text('Pedir por WhatsApp'), findsOneWidget);
    },
  );

  testWidgets(
    'CatalogoPublicoScreen renders PRO required lock screen when Bodega is not PRO',
    (tester) async {
      final mockClient = MockClient((request) async {
        final data = {
          'esPro': false,
          'mensaje': 'El catálogo online está disponible exclusivamente para tiendas con Suscripción PRO.',
          'bodega': {
            'idBodega': 2,
            'nombreComercial': 'Bodega Don Pepe',
            'telefono': '911222333',
            'direccion': 'Jr. Los Álamos 456',
            'plan': 'BASICO',
            'esPro': false,
          },
          'categorias': [],
          'productos': [],
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
            tiendaSlug: 'bodega-don-pepe',
            httpClient: mockClient,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Bodega Don Pepe'), findsWidgets);
      expect(find.text('SUSCRIPCIÓN PRO REQUERIDA'), findsOneWidget);
      expect(find.text('Inca Kola 500ml'), findsNothing);
    },
  );

  testWidgets(
    'CatalogoPublicoScreen adapts properly for Tablet Portrait (800x1280)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
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
            'idBodega': 1,
            'nombreComercial': 'Bodega Karliz',
            'telefono': '987654321',
            'plan': 'PRO',
            'esPro': true,
          },
          'categorias': ['Bebidas'],
          'productos': [
            {
              'idProducto': 101,
              'nombre': 'Inca Kola 500ml',
              'precioVenta': 3.50,
              'categoria': 'Bebidas',
              'imagenUrl': '',
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

      expect(find.text('Inca Kola 500ml'), findsOneWidget);
      expect(find.text('S/ 3.50'), findsOneWidget);
    },
  );

  testWidgets(
    'CatalogoPublicoScreen adapts properly for Tablet Landscape (1280x800)',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
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
            'idBodega': 1,
            'nombreComercial': 'Bodega Karliz',
            'telefono': '987654321',
            'plan': 'PRO',
            'esPro': true,
          },
          'categorias': ['Bebidas'],
          'productos': [
            {
              'idProducto': 101,
              'nombre': 'Inca Kola 500ml',
              'precioVenta': 3.50,
              'categoria': 'Bebidas',
              'imagenUrl': '',
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

      expect(find.text('Inca Kola 500ml'), findsOneWidget);
      expect(find.text('S/ 3.50'), findsOneWidget);
    },
  );

  testWidgets(
    'CatalogoPublicoScreen adapts properly for Mobile Landscape (844x390)',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
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
            'idBodega': 1,
            'nombreComercial': 'Bodega Karliz',
            'telefono': '987654321',
            'plan': 'PRO',
            'esPro': true,
          },
          'categorias': ['Bebidas'],
          'productos': [
            {
              'idProducto': 101,
              'nombre': 'Inca Kola 500ml',
              'precioVenta': 3.50,
              'categoria': 'Bebidas',
              'imagenUrl': '',
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

      expect(find.text('Inca Kola 500ml'), findsOneWidget);
      expect(find.text('S/ 3.50'), findsOneWidget);
    },
  );

  group('Secondary Promotional Color Tests', () {
    test(
      'Cobalt brand produces warm coral/orange secondary promotional color',
      () {
        const primary = Color(0xFF2563EB); // Cobalto FinTech
        final promoColor =
            CatalogoPublicoScreen.generarColorSecundarioPromocion(primary);
        expect(promoColor, equals(const Color(0xFFEA580C)));
      },
    );

    test('Green & Emerald brands produce vibrant Ruby/Crimson secondary promotional color (never green-on-green)', () {
      const verdeRetail = Color(0xFF059669);
      const esmeralda = Color(0xFF0D9488);
      expect(
        CatalogoPublicoScreen.generarColorSecundarioPromocion(verdeRetail),
        equals(const Color(0xFFE11D48)),
      );
      expect(
        CatalogoPublicoScreen.generarColorSecundarioPromocion(esmeralda),
        equals(const Color(0xFFE11D48)),
      );
    });

    test('Ruby brand produces warm Golden Amber secondary promotional color (avoids green clash)', () {
      const rubi = Color(0xFFE11D48);
      expect(
        CatalogoPublicoScreen.generarColorSecundarioPromocion(rubi),
        equals(const Color(0xFFD97706)),
      );
    });

    test(
      'Violet brand produces warm electric Amber secondary promotional color',
      () {
        const violeta = Color(0xFF7C3AED);
        expect(
          CatalogoPublicoScreen.generarColorSecundarioPromocion(violeta),
          equals(const Color(0xFFF59E0B)),
        );
      },
    );

    test(
      'Custom green hue via HSV fallback never outputs green for promotions',
      () {
        const customGreen = Color(0xFF22C55E); // Green 500
        final promoColor =
            CatalogoPublicoScreen.generarColorSecundarioPromocion(customGreen);
        expect(promoColor, equals(const Color(0xFFE11D48)));
      },
    );

    testWidgets(
      'Promotional pricing hierarchy renders base price with strikethrough and promo hero price with savings badge',
      (tester) async {
        final mockClient = MockClient((request) async {
          final data = {
            'esPro': true,
            'mensaje': null,
            'bodega': {
              'idBodega': 99,
              'nombreComercial': 'Bodega Ofertas',
              'telefono': '999888777',
              'plan': 'PRO',
              'esPro': true,
              'colorMarca': '#2563EB',
            },
            'categorias': ['Bebidas'],
            'productos': [
              {
                'idProducto': 901,
                'nombre': 'Six Pack Cerveza Pilsen',
                'precioVenta': 25.00,
                'precioPromocional': 20.00,
                'tienePromocion': true,
                'tituloPromocion': 'Promo Fin de Semana',
                'badgePromocion': '🔥 20% OFF',
                'categoria': 'Bebidas',
                'imagenUrl': '',
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
              tiendaSlug: 'bodega-ofertas',
              httpClient: mockClient,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verifies the promotional hero price is shown
        expect(find.text('S/ 20.00'), findsOneWidget);
        // Verifies the crossed out regular base price is shown
        expect(find.text('S/ 25.00'), findsOneWidget);
        // Verifies the discount percentage pill (-20%) is rendered
        expect(find.text('-20%'), findsOneWidget);
      },
    );
  });
}
