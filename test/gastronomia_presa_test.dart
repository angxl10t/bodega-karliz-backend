import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/gastronomia_helper.dart';
import 'package:bodega_mobile/core/thermal_ticket_service.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/ventas/venta_model.dart';
import 'package:bodega_mobile/features/catalogo/pedido_web_service.dart';
import 'package:bodega_mobile/features/catalogo/catalogo_publico_screen.dart';

void main() {
  group('GastronomiaHelper Presa & Gastro Tests', () {
    test(
      'esProductoConPresa detects 1/4 Pollo, Mostrito and Broaster accurately',
      () {
        expect(
          GastronomiaHelper.esProductoConPresa(
            '1/4 Pollo a la Brasa con Papas y Ensalada',
            'Brasas y Pollos',
          ),
          isTrue,
        );
        expect(
          GastronomiaHelper.esProductoConPresa(
            'Cuarto de Pollo a la Brasa',
            'Pollos',
          ),
          isTrue,
        );
        expect(
          GastronomiaHelper.esProductoConPresa(
            'Mostrito Especial (1/4 Pollo + Chaufa + Papas)',
            'Brasas y Pollos',
          ),
          isTrue,
        );
        expect(
          GastronomiaHelper.esProductoConPresa(
            '1/4 Pollo Broaster Crujiente',
            'Pollo Broaster y Frito',
          ),
          isTrue,
        );
        expect(
          GastronomiaHelper.esProductoConPresa(
            '1/2 Pollo a la Brasa',
            'Brasas y Pollos',
          ),
          isTrue,
        );
        expect(
          GastronomiaHelper.esProductoConPresa(
            'Presa de Pollo a la Brasa Suelta',
            'Brasas y Pollos',
          ),
          isTrue,
        );

        // Non-chicken / standard grocery items must NOT require presa
        expect(
          GastronomiaHelper.esProductoConPresa(
            'Inca Kola Sabor Original 500ml',
            'Gaseosas y Bebidas',
          ),
          isFalse,
        );
        expect(
          GastronomiaHelper.esProductoConPresa(
            'Arroz Costeño Extra 1kg',
            'Abarrotes',
          ),
          isFalse,
        );
        expect(
          GastronomiaHelper.esProductoConPresa(
            'Aceite Primor Premium 1L',
            'Abarrotes',
          ),
          isFalse,
        );
        expect(
          GastronomiaHelper.esProductoConPresa(
            'Porción de Papas Fritas Amarillas',
            'Guarniciones',
          ),
          isFalse,
        );
        expect(
          GastronomiaHelper.esProductoConPresa(
            'Arroz Chaufa de Pollo Clásico',
            'Arroces y Salteados',
          ),
          isFalse,
        );
      },
    );

    test('opcionesPresa returns Pecho vs Pierna for 1/4 and appropriate cuts for 1/2', () {
      final opcionesCuarto = GastronomiaHelper.opcionesPresa(
        '1/4 Pollo a la Brasa',
      );
      expect(opcionesCuarto, contains('Pecho (con ala)'));
      expect(opcionesCuarto, contains('Pierna (con encuentro)'));
      expect(opcionesCuarto.length, equals(2));

      final opcionesMedio = GastronomiaHelper.opcionesPresa(
        '1/2 Pollo a la Brasa',
      );
      expect(opcionesMedio, contains('Pecho y Pierna (Clásico)'));
      expect(opcionesMedio, contains('2 Pechos (con ala)'));
      expect(opcionesMedio, contains('2 Piernas (con encuentro)'));
    });

    test(
      'formatearNombreConVariante formats name, cut and kitchen notes properly',
      () {
        final res1 = GastronomiaHelper.formatearNombreConVariante(
          '1/4 Pollo a la Brasa',
          'Pecho (con ala)',
          'Ensalada cocida',
        );
        expect(
          res1,
          equals('1/4 Pollo a la Brasa - Pecho (con ala) (Ensalada cocida)'),
        );

        final res2 = GastronomiaHelper.formatearNombreConVariante(
          '1/4 Pollo a la Brasa',
          'Pierna (con encuentro)',
        );
        expect(res2, equals('1/4 Pollo a la Brasa - Pierna (con encuentro)'));
      },
    );
  });

  group('CartItem & Venta Models Gastro Variants', () {
    test('CartItem stores and serializes variante and notas', () {
      final producto = Producto(
        idProducto: 101,
        codigo: 'POL001',
        nombre: '1/4 Pollo a la Brasa',
        precioVenta: 18.50,
        precioCosto: 12.00,
        stockActual: 30.0,
        nombreCategoria: 'Brasas y Pollos',
      );

      final item = CartItem(
        producto: producto,
        cantidad: 2.0,
        variante: 'Pecho (con ala)',
        notas: 'Piel bien crocante, ají extra',
      );

      expect(item.variante, equals('Pecho (con ala)'));
      expect(item.notas, equals('Piel bien crocante, ají extra'));
      expect(item.subtotal, equals(37.00));

      final json = item.toJson();
      expect(json['variante'], equals('Pecho (con ala)'));
      expect(json['notas'], equals('Piel bien crocante, ají extra'));

      final restoredItem = CartItem.fromJson(json);
      expect(restoredItem.variante, equals('Pecho (con ala)'));
      expect(restoredItem.notas, equals('Piel bien crocante, ají extra'));
    });

    test('PedidoWebItem stores and serializes variante and notas', () {
      final webItem = PedidoWebItem(
        idProducto: 101,
        nombre: '1/4 Pollo a la Brasa',
        cantidad: 1.0,
        precioUnitario: 18.50,
        subtotal: 18.50,
        variante: 'Pierna (con encuentro)',
        notas: 'Ensalada cocida, papas bien doradas',
      );

      final json = webItem.toJson();
      expect(json['variante'], equals('Pierna (con encuentro)'));
      expect(json['notas'], equals('Ensalada cocida, papas bien doradas'));

      final restored = PedidoWebItem.fromJson(json);
      expect(restored.variante, equals('Pierna (con encuentro)'));
      expect(restored.notas, equals('Ensalada cocida, papas bien doradas'));
    });

    test('TicketItem stores variante and notas for thermal printer', () {
      final ticketItem = TicketItem(
        nombre: '1/4 Pollo a la Brasa (Pecho (con ala))',
        cantidad: 1.0,
        precioUnitario: 18.50,
        subtotal: 18.50,
        variante: 'Pecho (con ala)',
        notas: 'Papas aparte',
      );

      expect(ticketItem.variante, equals('Pecho (con ala)'));
      expect(ticketItem.notas, equals('Papas aparte'));
      expect(ticketItem.subtotal, equals(18.50));
    });

    test('ItemCarritoPublico generates distinct cart keys for different chicken cuts', () {
      final itemPecho = ItemCarritoPublico(
        idProducto: 101,
        cantidad: 1,
        variante: 'Pecho (con ala)',
        notas: 'Ensalada fresca',
      );

      final itemPierna = ItemCarritoPublico(
        idProducto: 101,
        cantidad: 1,
        variante: 'Pierna (con encuentro)',
        notas: 'Ensalada cocida',
      );

      expect(itemPecho.cartKey, equals('101#Pecho (con ala)'));
      expect(itemPierna.cartKey, equals('101#Pierna (con encuentro)'));
      expect(itemPecho.cartKey, isNot(equals(itemPierna.cartKey)));
    });
  });
}
