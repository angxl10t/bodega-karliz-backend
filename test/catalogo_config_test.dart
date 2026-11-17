import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bodega_mobile/features/catalogo/catalogo_publico_screen.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/features/home/mi_bodega_online_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Catálogo Configuración Operativa (Abierto/Cerrado & Delivery Rápido)', () {
    testWidgets(
      'CatalogoPublicoScreen renders Cerrado temporalmente and Solo retiro en tienda when toggled off',
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
            'bodega': {
              'idBodega': 1,
              'nombreComercial': 'Bodega San Martín',
              'telefono': '912345678',
              'direccion': 'Calle Lima 456',
              'lemaComercial': 'Calidad y precio',
              'plan': 'PRO',
              'esPro': true,
              'catalogoAbierto': false,
              'deliveryActivo': false,
            },
            'categorias': ['Abarrotes'],
            'productos': [
              {
                'idProducto': 201,
                'codigo': '7750106001',
                'nombre': 'Leche Gloria Azul 400g',
                'marca': 'Gloria',
                'precioVenta': 4.20,
                'stockActual': 15.0,
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
              tiendaSlug: 'bodega-san-martin',
              httpClient: mockClient,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Bodega San Martín'), findsWidgets);
        // Badge Abierto should NOT appear, Cerrado temporalmente MUST appear
        expect(find.text('Abierto ahora'), findsNothing);
        expect(find.text('Cerrado temporalmente'), findsOneWidget);

        // Delivery rápido should NOT appear, Solo retiro en tienda MUST appear
        expect(find.text('Delivery rápido'), findsNothing);
        expect(find.text('Solo retiro en tienda'), findsOneWidget);

        // Closed store banner appears
        expect(find.textContaining('Tienda en pausa temporal'), findsOneWidget);
      },
    );

    testWidgets(
      'CatalogoPublicoScreen renders Abierto ahora and Delivery rápido when toggled on',
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
            'bodega': {
              'idBodega': 1,
              'nombreComercial': 'Bodega San Martín',
              'telefono': '912345678',
              'direccion': 'Calle Lima 456',
              'plan': 'PRO',
              'esPro': true,
              'catalogoAbierto': true,
              'deliveryActivo': true,
            },
            'categorias': ['Abarrotes'],
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
              tiendaSlug: 'bodega-san-martin',
              httpClient: mockClient,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Abierto ahora'), findsOneWidget);
        expect(find.text('Delivery rápido'), findsOneWidget);
        expect(find.text('Retiro en tienda'), findsOneWidget);
      },
    );

    testWidgets(
      'MiBodegaOnlineModal displays control switches for Abierto/Cerrado and Delivery rápido',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MiBodegaOnlineModal(
                nombreBodega: 'Bodega San Martín',
                telefonoBodega: '912345678',
                isPro: true,
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('CONTROL OPERATIVO DEL CATÁLOGO:'), findsOneWidget);
        expect(find.text('Abierto ahora'), findsOneWidget);
        expect(find.text('Delivery rápido'), findsOneWidget);
        expect(find.byType(Switch), findsNWidgets(2));
      },
    );

    test('BodegaInfo JSON serialization includes catalogoAbierto and deliveryActivo', () {
      final json = {
        'idBodega': 5,
        'nombreComercial': 'Mi Bodeguita',
        'colorPrimario': '#2563EB',
        'plan': 'PRO',
        'estado': true,
        'catalogoAbierto': false,
        'deliveryActivo': false,
      };

      final info = BodegaInfo.fromJson(json);
      expect(info.catalogoAbierto, isFalse);
      expect(info.deliveryActivo, isFalse);

      final copy = info.copyWith(catalogoAbierto: true, deliveryActivo: true);
      expect(copy.catalogoAbierto, isTrue);
      expect(copy.deliveryActivo, isTrue);
    });
  });
}
