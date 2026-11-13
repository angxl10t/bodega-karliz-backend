import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/compras/compra_service.dart';
import 'package:bodega_mobile/features/movimientos/movimiento_model.dart';
import 'package:bodega_mobile/features/ventas/venta_service.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';
import 'package:bodega_mobile/features/categorias/categoria_service.dart';
import 'package:bodega_mobile/features/proveedores/proveedor_service.dart';

void main() {
  group('Kardex & Compras Reactivity and Models Tests', () {
    test(
      'CompraService.comprasRevision increments on notifyComprasChanged',
      () {
        final initialVal = CompraService.comprasRevision.value;
        CompraService.notifyComprasChanged();
        expect(CompraService.comprasRevision.value, initialVal + 1);
      },
    );

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

    test(
      'CategoriaService.categoriasRevision increments on invalidateCache',
      () {
        final initialVal = CategoriaService.categoriasRevision.value;
        CategoriaService.invalidateCache();
        expect(CategoriaService.categoriasRevision.value, initialVal + 1);
      },
    );

    test(
      'ProveedorService.proveedoresRevision increments on invalidateCache',
      () {
        final initialVal = ProveedorService.proveedoresRevision.value;
        ProveedorService.invalidateCache();
        expect(ProveedorService.proveedoresRevision.value, initialVal + 1);
      },
    );

    test('MovimientoInventario parses JSON correctly with full attributes', () {
      final json = {
        'idMovimiento': 101,
        'idProducto': 42,
        'nombreProducto': 'Arroz Costeño 1kg',
        'tipoMovimiento': 'SALIDA',
        'cantidad': 3.0,
        'motivo': 'Venta al cliente: Juan Perez',
        'fechaMovimiento': '2026-10-19T14:30:00Z',
        'usuarioResponsable': 'admin',
      };

      final mov = MovimientoInventario.fromJson(json);

      expect(mov.idMovimiento, 101);
      expect(mov.idProducto, 42);
      expect(mov.nombreProducto, 'Arroz Costeño 1kg');
      expect(mov.tipoMovimiento, 'SALIDA');
      expect(mov.cantidad, 3.0);
      expect(mov.motivo, 'Venta al cliente: Juan Perez');
      expect(mov.usuarioResponsable, 'admin');
      expect(mov.fechaMovimiento, isNotNull);
      expect(mov.fechaMovimiento!.year, 2026);
    });

    test('MovimientoInventario parses auditoria admin fields properly', () {
      final jsonPrecio = {
        'idMovimiento': 201,
        'idProducto': 50,
        'nombreProducto': 'Inca Kola 1.5L',
        'tipoMovimiento': 'CAMBIO_PRECIO',
        'cantidad': 0.0,
        'motivo': 'Actualización de precio de venta: de S/ 7.50 a S/ 8.00',
        'usuarioResponsable': 'admin',
      };

      final mov = MovimientoInventario.fromJson(jsonPrecio);
      expect(mov.tipoMovimiento, 'CAMBIO_PRECIO');
      expect(mov.cantidad, 0.0);
      expect(mov.usuarioResponsable, 'admin');
      expect(mov.motivo, contains('de S/ 7.50 a S/ 8.00'));
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

    test('Kardex categorizes admin audits for prices, costs, and catalog changes without confounding with stock arrows', () {
      final cambioPrecio = MovimientoInventario(
        idMovimiento: 10,
        idProducto: 1,
        nombreProducto: 'Galleta Soda Field',
        tipoMovimiento: 'CAMBIO_PRECIO',
        cantidad: 0.0,
        motivo: 'Actualización de precio de venta: de S/ 1.00 a S/ 1.20',
        usuarioResponsable: 'admin',
      );

      final cambioCosto = MovimientoInventario(
        idMovimiento: 11,
        idProducto: 1,
        nombreProducto: 'Galleta Soda Field',
        tipoMovimiento: 'CAMBIO_COSTO',
        cantidad: 0.0,
        motivo: 'Actualización de costo de compra: de S/ 0.70 a S/ 0.85',
        usuarioResponsable: 'admin',
      );

      final cambioNombre = MovimientoInventario(
        idMovimiento: 12,
        idProducto: 1,
        nombreProducto: 'Galleta Soda Field 6pk',
        tipoMovimiento: 'CAMBIO_NOMBRE',
        cantidad: 0.0,
        motivo: 'Modificación de nombre/descripción: "Galleta Soda" -> "Galleta Soda Field 6pk"',
        usuarioResponsable: 'admin',
      );

      final cambioCategoria = MovimientoInventario(
        idMovimiento: 13,
        idProducto: 1,
        nombreProducto: 'Galleta Soda Field 6pk',
        tipoMovimiento: 'CAMBIO_CATEGORIA',
        cantidad: 0.0,
        motivo: 'Cambio de categoría: "Snacks" -> "Abarrotes"',
        usuarioResponsable: 'admin',
      );

      final cambioCodigo = MovimientoInventario(
        idMovimiento: 14,
        idProducto: 1,
        nombreProducto: 'Galleta Soda Field 6pk',
        tipoMovimiento: 'CAMBIO_CODIGO',
        cantidad: 0.0,
        motivo: 'Código de barras modificado: "77501" -> "77502"',
        usuarioResponsable: 'admin',
      );

      bool esCambioPrecio(MovimientoInventario m) {
        final t = m.tipoMovimiento.toUpperCase();
        final mot = m.motivo.toUpperCase();
        return t.contains('PRECIO') ||
            t.contains('COSTO') ||
            mot.contains('CAMBIO DE PRECIO') ||
            mot.contains('PRECIO DE VENTA') ||
            mot.contains('CAMBIO DE COSTO');
      }

      bool esCambioDatos(MovimientoInventario m) {
        if (esCambioPrecio(m)) return false;
        final t = m.tipoMovimiento.toUpperCase();
        final mot = m.motivo.toUpperCase();
        return t.contains('NOMBRE') ||
            t.contains('CATEGORIA') ||
            t.contains('MARCA') ||
            t.contains('CODIGO') ||
            t.contains('VENCIMIENTO') ||
            t.contains('EDICION') ||
            mot.contains('NOMBRE/DESCRIPCIÓN');
      }

      expect(esCambioPrecio(cambioPrecio), isTrue);
      expect(esCambioPrecio(cambioCosto), isTrue);
      expect(esCambioPrecio(cambioNombre), isFalse);

      expect(esCambioDatos(cambioNombre), isTrue);
      expect(esCambioDatos(cambioCategoria), isTrue);
      expect(esCambioDatos(cambioCodigo), isTrue);
      expect(esCambioDatos(cambioPrecio), isFalse);
    });
  });
}
