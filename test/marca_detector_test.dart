import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bodega_mobile/core/api_client.dart';
import 'package:bodega_mobile/core/marca_detector_service.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';

void main() {
  group('MarcaDetectorService Tests', () {
    test('Detección automática de marcas peruanas populares por nombre de producto', () {
      expect(
        MarcaDetectorService.detectarMarca(
          nombre: 'Gaseosa Pepsi 1.5L descartable',
        ),
        'Pepsi',
      );
      expect(
        MarcaDetectorService.detectarMarca(
          nombre: 'Gaseosa Inca Kola Sabor Original 500ml',
        ),
        'Inca Kola',
      );
      expect(
        MarcaDetectorService.detectarMarca(nombre: 'Pan Bimbo Artesano 550g'),
        'Bimbo',
      );
      expect(
        MarcaDetectorService.detectarMarca(
          nombre: 'Mayonesa AlaCena Doypack 400g',
        ),
        'AlaCena',
      );
      expect(
        MarcaDetectorService.detectarMarca(nombre: 'Salsa Tari Alacena 85g'),
        'AlaCena',
      );
      expect(
        MarcaDetectorService.detectarMarca(
          nombre: 'Helado Sandwich D\'Onofrio',
        ),
        "D'Onofrio",
      );
      expect(
        MarcaDetectorService.detectarMarca(
          nombre: 'Fideos Spaghetti Molitalia 500g',
        ),
        'Molitalia',
      );
      expect(
        MarcaDetectorService.detectarMarca(
          nombre: 'Papel Higiénico Elite Dúo 4 rollos',
        ),
        'Elite',
      );
      expect(
        MarcaDetectorService.detectarMarca(
          nombre: 'Papel Higiénico Paracas Black',
        ),
        'Paracas',
      );
      expect(
        MarcaDetectorService.detectarMarca(
          nombre: 'Cerveza Pilsen Callao 310ml lata',
        ),
        'Pilsen Callao',
      );
      expect(
        MarcaDetectorService.detectarMarca(
          nombre: 'Chocolate Sublime Clásico 30g',
        ),
        'Sublime',
      );
    });

    test('Normalización de marcas con variantes de mayúsculas y acentos', () {
      expect(MarcaDetectorService.normalizarMarca('alacena'), 'AlaCena');
      expect(MarcaDetectorService.normalizarMarca('PEPSI'), 'Pepsi');
      expect(MarcaDetectorService.normalizarMarca('lays'), "Lay's");
      expect(MarcaDetectorService.normalizarMarca('donofrio'), "D'Onofrio");
      expect(MarcaDetectorService.normalizarMarca('inka kola'), 'Inca Kola');
      expect(MarcaDetectorService.normalizarMarca('bimbo'), 'Bimbo');
      expect(
        MarcaDetectorService.normalizarMarca('marca artesanal'),
        'Marca Artesanal',
      );
    });

    test('Coincidencia exhaustiva de marcas con tolerancia a guiones, acentos y variantes', () {
      // 1. Coca-Cola
      expect(
        MarcaDetectorService.coincideMarca(
          'Coca-Cola',
          'Coca Cola',
          'Coca Cola 500ml',
        ),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'coca cola',
          'Coca-Cola',
          'Coca Cola Sabor Original 3 Litros',
        ),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'Coca Cola',
          'Coca Cola',
          'Gaseosa 500ml',
        ),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'Coca-Cola',
          null,
          'Coca Cola 1.5L descartable',
        ),
        isTrue,
      );

      // 2. Lay's / Lays / Frito-Lay
      expect(
        MarcaDetectorService.coincideMarca(
          "Lay's",
          'Lays',
          'Papas Lays Clásicas 160g',
        ),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'Lays',
          "Lay's",
          'Papas Fritas Ondas 150g',
        ),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          "Lay's",
          'Frito-Lay',
          "Papas Lay's Al Hilo 100g",
        ),
        isTrue,
      );

      // 3. 7Up / 7 Up
      expect(
        MarcaDetectorService.coincideMarca('7Up', '7 Up', 'Gaseosa 7 Up 500ml'),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca('7 Up', '7Up', 'Gaseosa 7-Up 3L'),
        isTrue,
      );

      // 4. D'Onofrio / Donofrio
      expect(
        MarcaDetectorService.coincideMarca(
          "D'Onofrio",
          'Donofrio',
          "Helado Sandwich D'Onofrio",
        ),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'donofrio',
          "D'Onofrio",
          'Helado Jet Paleta',
        ),
        isTrue,
      );

      // 5. Inca Kola / Inka Kola
      expect(
        MarcaDetectorService.coincideMarca(
          'Inca Kola',
          'Inka Kola',
          'Inca Kola 500ml',
        ),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'Inka Kola',
          'Inca Kola',
          'Inka Kola Sabor Original 3L',
        ),
        isTrue,
      );

      // 6. Marlboro / Malboro
      expect(
        MarcaDetectorService.coincideMarca(
          'Marlboro',
          'Malboro',
          'Malboro Gold Box 20',
        ),
        isTrue,
      );

      // 7. Acentos y variantes: Ángel, Bolívar, AlaCena, San Mateo
      expect(
        MarcaDetectorService.coincideMarca(
          'Ángel',
          'Angel',
          'Cereal Angel Flakes 250g',
        ),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'Bolívar',
          'Bolivar',
          'Detergente Bolivar 900g',
        ),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'AlaCena',
          'Alacena',
          'Mayonesa Alacena 400g',
        ),
        isTrue,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'San Mateo',
          'San-Mateo',
          'Agua Mineral San Mateo 600ml',
        ),
        isTrue,
      );

      // 8. Casos Negativos
      expect(
        MarcaDetectorService.coincideMarca(
          'Coca-Cola',
          'Inca Kola',
          'Inca Kola Sabor Original 500ml',
        ),
        isFalse,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'Pepsi',
          'Coca Cola',
          'Coca Cola 3 Litros',
        ),
        isFalse,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          'Bimbo',
          'Molitalia',
          'Fideos Spaghetti Molitalia 500g',
        ),
        isFalse,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          null,
          'Coca Cola',
          'Coca Cola 500ml',
        ),
        isFalse,
      );
      expect(
        MarcaDetectorService.coincideMarca(
          '   ',
          'Coca Cola',
          'Coca Cola 500ml',
        ),
        isFalse,
      );
    });

    test('Retorna null para nombres sin marca o vacíos', () {
      expect(MarcaDetectorService.detectarMarca(nombre: ''), isNull);
      expect(
        MarcaDetectorService.detectarMarca(nombre: 'Tomate fresco por kilo'),
        isNull,
      );
      expect(MarcaDetectorService.detectarMarca(), isNull);
    });
  });

  group('ProductoService getMarcas Local-First Fallback Tests', () {
    test(
      'getMarcas extrae y agrupa marcas ordenadas por cantidad de productos',
      () async {
        final mockProductos = [
          Producto(
            idProducto: 1,
            nombre: 'Gaseosa Pepsi 500ml',
            codigo: 'BEB-001',
            precioVenta: 2.50,
            stockActual: 10,
            stockMinimo: 2,
            marca: 'Pepsi',
            nombreCategoria: 'Gaseosas y Bebidas',
          ),
          Producto(
            idProducto: 2,
            nombre: 'Gaseosa Pepsi 1.5L',
            codigo: 'BEB-002',
            precioVenta: 5.00,
            stockActual: 8,
            stockMinimo: 2,
            marca: 'Pepsi',
            nombreCategoria: 'Gaseosas y Bebidas',
          ),
          Producto(
            idProducto: 3,
            nombre: 'Pan Bimbo Blanco',
            codigo: 'PAN-001',
            precioVenta: 6.50,
            stockActual: 15,
            stockMinimo: 3,
            marca: 'Bimbo',
            nombreCategoria: 'Panadería y Desayuno',
          ),
          Producto(
            idProducto: 4,
            nombre: 'Manzana Israel x Kilo',
            codigo: 'FRU-001',
            precioVenta: 4.00,
            stockActual: 20,
            stockMinimo: 5,
            marca: null,
            nombreCategoria: 'Frutas',
          ),
        ];

        ProductoService.setMockProductos(mockProductos);
        final mockClient = MockClient(
          (_) async => http.Response('Service Unavailable', 503),
        );
        final marcas = await ProductoService(
          apiClient: ApiClient(client: mockClient),
        ).getMarcas();

        expect(marcas.isNotEmpty, isTrue);
        // Pepsi tiene 2 productos, Bimbo tiene 1
        expect(marcas.first.nombre, 'Pepsi');
        expect(marcas.first.cantidadProductos, 2);
        expect(marcas[1].nombre, 'Bimbo');
        expect(marcas[1].cantidadProductos, 1);
        ProductoService.invalidateCache();
      },
    );
  });
}
