import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/marca_detector_service.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';

void main() {
  group('MarcaDetectorService Tests', () {
    test('Detección automática de marcas peruanas populares por nombre de producto', () {
      expect(MarcaDetectorService.detectarMarca(nombre: 'Gaseosa Pepsi 1.5L descartable'), 'Pepsi');
      expect(MarcaDetectorService.detectarMarca(nombre: 'Gaseosa Inca Kola Sabor Original 500ml'), 'Inca Kola');
      expect(MarcaDetectorService.detectarMarca(nombre: 'Pan Bimbo Artesano 550g'), 'Bimbo');
      expect(MarcaDetectorService.detectarMarca(nombre: 'Mayonesa AlaCena Doypack 400g'), 'AlaCena');
      expect(MarcaDetectorService.detectarMarca(nombre: 'Salsa Tari Alacena 85g'), 'AlaCena');
      expect(MarcaDetectorService.detectarMarca(nombre: 'Helado Sandwich D\'Onofrio'), "D'Onofrio");
      expect(MarcaDetectorService.detectarMarca(nombre: 'Fideos Spaghetti Molitalia 500g'), 'Molitalia');
      expect(MarcaDetectorService.detectarMarca(nombre: 'Papel Higiénico Elite Dúo 4 rollos'), 'Elite');
      expect(MarcaDetectorService.detectarMarca(nombre: 'Papel Higiénico Paracas Black'), 'Paracas');
      expect(MarcaDetectorService.detectarMarca(nombre: 'Cerveza Pilsen Callao 310ml lata'), 'Pilsen Callao');
      expect(MarcaDetectorService.detectarMarca(nombre: 'Chocolate Sublime Clásico 30g'), 'Sublime');
    });

    test('Normalización de marcas con variantes de mayúsculas y acentos', () {
      expect(MarcaDetectorService.normalizarMarca('alacena'), 'AlaCena');
      expect(MarcaDetectorService.normalizarMarca('PEPSI'), 'Pepsi');
      expect(MarcaDetectorService.normalizarMarca('lays'), "Lay's");
      expect(MarcaDetectorService.normalizarMarca('donofrio'), "D'Onofrio");
      expect(MarcaDetectorService.normalizarMarca('inka kola'), 'Inca Kola');
      expect(MarcaDetectorService.normalizarMarca('bimbo'), 'Bimbo');
      expect(MarcaDetectorService.normalizarMarca('marca artesanal'), 'Marca Artesanal');
    });

    test('Retorna null para nombres sin marca o vacíos', () {
      expect(MarcaDetectorService.detectarMarca(nombre: ''), isNull);
      expect(MarcaDetectorService.detectarMarca(nombre: 'Tomate fresco por kilo'), isNull);
      expect(MarcaDetectorService.detectarMarca(), isNull);
    });
  });

  group('ProductoService getMarcas Local-First Fallback Tests', () {
    test('getMarcas extrae y agrupa marcas ordenadas por cantidad de productos', () async {
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
      final marcas = await ProductoService().getMarcas();

      expect(marcas.isNotEmpty, isTrue);
      // Pepsi tiene 2 productos, Bimbo tiene 1
      expect(marcas.first.nombre, 'Pepsi');
      expect(marcas.first.cantidadProductos, 2);
      expect(marcas[1].nombre, 'Bimbo');
      expect(marcas[1].cantidadProductos, 1);
    });
  });
}
