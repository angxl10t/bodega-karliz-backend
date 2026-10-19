import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/compras/compra_service.dart';
import 'package:bodega_mobile/features/movimientos/movimiento_model.dart';
import 'package:bodega_mobile/features/ventas/venta_service.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';

void main() {
  group('Kardex & Compras Reactivity and Models Tests', () {
    test('CompraService.comprasRevision increments on notifyComprasChanged', () {
      final initialVal = CompraService.comprasRevision.value;
      CompraService.notifyComprasChanged();
      expect(CompraService.comprasRevision.value, initialVal + 1);
    });

    test('VentaService.ventasRevision increments on notifyVentasChanged', () {
      final initialVal = VentaService.ventasRevision.value;
      VentaService.notifyVentasChanged();
      expect(VentaService.ventasRevision.value, initialVal + 1);
    });

    test('ProductoService.productosRevision increments on invalidateCache', () {
      final initialVal = ProductoService.productosRevision.value;
      ProductoService.invalidateCache();
      expect(ProductoService.productosRevision.value, initialVal + 1);
    });

    test('MovimientoInventario parses JSON correctly with full attributes', () {
      final json = {
        'idMovimiento': 101,
        'idProducto': 42,
        'nombreProducto': 'Arroz Costeño 1kg',
        'tipoMovimiento': 'SALIDA',
        'cantidad': 3.0,
        'motivo': 'Venta al cliente: Juan Perez',
        'fechaMovimiento': '2026-10-19T14:30:00Z',
      };

      final mov = MovimientoInventario.fromJson(json);

      expect(mov.idMovimiento, 101);
      expect(mov.idProducto, 42);
      expect(mov.nombreProducto, 'Arroz Costeño 1kg');
      expect(mov.tipoMovimiento, 'SALIDA');
      expect(mov.cantidad, 3.0);
      expect(mov.motivo, 'Venta al cliente: Juan Perez');
      expect(mov.fechaMovimiento, isNotNull);
      expect(mov.fechaMovimiento!.year, 2026);
    });

    test('MovimientoInventario handles null and fallback values safely', () {
      final json = <String, dynamic>{};

      final mov = MovimientoInventario.fromJson(json);

      expect(mov.idMovimiento, 0);
      expect(mov.idProducto, 0);
      expect(mov.nombreProducto, 'Producto');
      expect(mov.tipoMovimiento, 'DESCONOCIDO');
      expect(mov.cantidad, 0.0);
      expect(mov.motivo, '');
      expect(mov.fechaMovimiento, isNull);
    });

    test('Kardex movement classification distinguishes Entradas, Salidas and Devoluciones/Anulaciones', () {
      final entrada = MovimientoInventario(
        idMovimiento: 1,
        idProducto: 10,
        nombreProducto: 'Leche Gloria',
        tipoMovimiento: 'ENTRADA',
        cantidad: 24.0,
        motivo: 'Compra a proveedor Distribuidora Lima',
      );

      final salida = MovimientoInventario(
        idMovimiento: 2,
        idProducto: 10,
        nombreProducto: 'Leche Gloria',
        tipoMovimiento: 'SALIDA',
        cantidad: 2.0,
        motivo: 'Venta al cliente: Maria Gómez',
      );

      final anulacion = MovimientoInventario(
        idMovimiento: 3,
        idProducto: 10,
        nombreProducto: 'Leche Gloria',
        tipoMovimiento: 'ENTRADA',
        cantidad: 2.0,
        motivo: 'Anulación Venta #55 - Cliente devolvió producto',
      );

      bool isEntrada(MovimientoInventario m) {
        final tipo = m.tipoMovimiento.toUpperCase();
        return (tipo.contains('ENTRADA') || tipo.contains('COMPRA')) &&
            !m.motivo.toUpperCase().contains('ANULACI');
      }

      bool isSalida(MovimientoInventario m) {
        final tipo = m.tipoMovimiento.toUpperCase();
        return tipo.contains('SALIDA') || tipo.contains('VENTA');
      }

      bool isDevolucion(MovimientoInventario m) {
        final tipo = m.tipoMovimiento.toUpperCase();
        return tipo.contains('DEVOLUCION') ||
            tipo.contains('ANULACION') ||
            m.motivo.toUpperCase().contains('ANULACI');
      }

      expect(isEntrada(entrada), isTrue);
      expect(isSalida(entrada), isFalse);
      expect(isDevolucion(entrada), isFalse);

      expect(isEntrada(salida), isFalse);
      expect(isSalida(salida), isTrue);
      expect(isDevolucion(salida), isFalse);

      expect(isEntrada(anulacion), isFalse);
      expect(isSalida(anulacion), isFalse);
      expect(isDevolucion(anulacion), isTrue);
    });
  });
}
