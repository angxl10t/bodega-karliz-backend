import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';
import 'package:bodega_mobile/features/ventas/venta_model.dart';
import 'package:bodega_mobile/features/proveedores/proveedor_model.dart';
import 'package:bodega_mobile/features/compras/compra_model.dart';
import 'package:bodega_mobile/features/categorias/categoria_model.dart';

bool coincideCodigoTest(Producto p, String rawCode) {
  if (rawCode.trim().isEmpty) return false;
  final codeClean = rawCode.trim().toLowerCase();
  final codeDigits = codeClean.replaceAll(RegExp(r'\D'), '');

  final bc = (p.codigoBarras ?? '').trim().toLowerCase();
  final cod = p.codigo.trim().toLowerCase();

  if (bc.isNotEmpty && bc == codeClean) return true;
  if (cod.isNotEmpty && cod == codeClean) return true;

  if (codeDigits.isNotEmpty) {
    final bcDigits = bc.replaceAll(RegExp(r'\D'), '');
    if (bcDigits.isNotEmpty) {
      if (bcDigits == codeDigits) return true;
      if (codeDigits.length == 13 && codeDigits.startsWith('0') && codeDigits.substring(1) == bcDigits) return true;
      if (bcDigits.length == 13 && bcDigits.startsWith('0') && bcDigits.substring(1) == codeDigits) return true;
      if (codeDigits.length == 14 && codeDigits.startsWith('00') && codeDigits.substring(2) == bcDigits) return true;
      if (bcDigits.length == 14 && bcDigits.startsWith('00') && bcDigits.substring(2) == codeDigits) return true;
    }
  }

  return false;
}

void main() {
  group('Producto Model & Serialization Tests', () {
    test('Producto.fromJson properly parses int and num IDs without crash', () {
      final json = {
        'idProducto': 42,
        'idCategoria': 3,
        'nombreCategoria': 'Bebidas',
        'codigo': 'GSE-0001',
        'codigoBarras': '7751234567890',
        'nombre': 'Inca Kola 500ml',
        'marca': 'Inca Kola',
        'precioVenta': 3.5,
        'stockActual': 12,
        'stockMinimo': 5,
      };

      final p = Producto.fromJson(json);
      expect(p.idProducto, 42);
      expect(p.idCategoria, 3);
      expect(p.codigo, 'GSE-0001');
      expect(p.codigoBarras, '7751234567890');
      expect(p.nombre, 'Inca Kola 500ml');
      expect(p.precioVenta, 3.5);
      expect(p.stockActual, 12.0);
    });

    test('Producto.fromJson handles double num representation for id', () {
      final json = {
        'idProducto': 99.0,
        'idCategoria': 2.0,
        'codigo': 'SNK-0002',
        'nombre': 'Papas Lays',
        'precioVenta': 2.0,
        'stockActual': 1.0,
      };

      final p = Producto.fromJson(json);
      expect(p.idProducto, 99);
      expect(p.idCategoria, 2);
    });
  });

  group('Barcode Matching Logic Tests', () {
    final producto = Producto(
      idProducto: 10,
      idCategoria: 1,
      codigo: 'ABA-0005',
      codigoBarras: '7751234567890',
      nombre: 'Arroz Costeño 1kg',
      precioVenta: 4.80,
      stockActual: 3.0,
    );

    test('Matches exact barcode', () {
      expect(coincideCodigoTest(producto, '7751234567890'), isTrue);
    });

    test('Matches barcode with whitespace and newline', () {
      expect(coincideCodigoTest(producto, '  7751234567890\n'), isTrue);
    });

    test('Matches internal SKU code', () {
      expect(coincideCodigoTest(producto, 'ABA-0005'), isTrue);
      expect(coincideCodigoTest(producto, 'aba-0005'), isTrue);
    });

    test('Matches UPC-A / EAN-13 variation with leading zero', () {
      final upcProd = Producto(
        idProducto: 11,
        idCategoria: 1,
        codigo: 'SNK-0010',
        codigoBarras: '123456789012', // 12 digits
        nombre: 'Galletas Casino',
        precioVenta: 1.20,
        stockActual: 5.0,
      );

      // Scanned with leading zero (13 digits)
      expect(coincideCodigoTest(upcProd, '0123456789012'), isTrue);
      // Scanned exact
      expect(coincideCodigoTest(upcProd, '123456789012'), isTrue);
    });

    test('Does not match unrelated codes', () {
      expect(coincideCodigoTest(producto, '9999999999999'), isFalse);
      expect(coincideCodigoTest(producto, ''), isFalse);
    });
  });

  group('Reactive Cache Synchronization Tests', () {
    test('invalidateCache increments revision counter', () {
      final initialRevision = ProductoService.productosRevision.value;
      ProductoService.invalidateCache();
      expect(ProductoService.productosRevision.value, initialRevision + 1);
    });
  });

  group('Venta Model & Anulación Tests', () {
    test('VentaRegistro.fromJson parses completed sale correctly', () {
      final json = {
        'idVenta': 105,
        'clienteDocumento': '71234567',
        'clienteNombre': 'Juan Perez',
        'metodoPago': 'Yape',
        'total': 45.50,
        'fechaVenta': '2026-10-15T14:30:00Z',
        'estado': 'COMPLETADA',
        'detalles': [
          {
            'idDetalleVenta': 1,
            'idProducto': 10,
            'nombreProducto': 'Arroz Costeño',
            'cantidad': 2.0,
            'precioUnitario': 4.80,
            'subtotal': 9.60,
          }
        ],
      };

      final v = VentaRegistro.fromJson(json);
      expect(v.idVenta, 105);
      expect(v.clienteNombre, 'Juan Perez');
      expect(v.metodoPago, 'Yape');
      expect(v.total, 45.50);
      expect(v.isAnulada, isFalse);
      expect(v.estado, 'COMPLETADA');
      expect(v.detalles.length, 1);
      expect(v.detalles.first.idProducto, 10);
    });

    test('VentaRegistro.fromJson parses ANULADA sale with audit information', () {
      final json = {
        'idVenta': 106.0,
        'clienteDocumento': '00000000',
        'clienteNombre': 'Público General',
        'metodoPago': 'Efectivo',
        'total': 15.00,
        'fechaVenta': '2026-10-15T15:00:00Z',
        'estado': 'ANULADA',
        'fechaAnulacion': '2026-10-15T15:10:00Z',
        'usuarioAnulacion': 'admin',
        'motivoAnulacion': 'Error en cobro de vuelto',
        'detalles': [],
      };

      final v = VentaRegistro.fromJson(json);
      expect(v.idVenta, 106);
      expect(v.isAnulada, isTrue);
      expect(v.estado, 'ANULADA');
      expect(v.usuarioAnulacion, 'admin');
      expect(v.motivoAnulacion, 'Error en cobro de vuelto');
      expect(v.fechaAnulacion, isNotNull);
    });
  });

  group('Proveedor & Compra Model Tests', () {
    test('Proveedor.fromJson handles safe numeric parsing', () {
      final json = {
        'idProveedor': 15.0,
        'ruc': '20601234567',
        'razonSocial': 'Gloria S.A.',
        'telefono': '987654321',
        'estado': true,
      };

      final p = Proveedor.fromJson(json);
      expect(p.idProveedor, 15);
      expect(p.ruc, '20601234567');
      expect(p.razonSocial, 'Gloria S.A.');
    });

    test('CompraRegistro.fromJson handles safe numeric parsing', () {
      final json = {
        'idCompra': 50.0,
        'idProveedor': 15.0,
        'razonSocialProveedor': 'Gloria S.A.',
        'comprobante': 'FAC-001',
        'total': 250.0,
        'detalles': [
          {
            'idDetalleCompra': 100.0,
            'idProducto': 5.0,
            'nombreProducto': 'Leche Gloria',
            'cantidad': 50.0,
            'precioUnitario': 4.0,
            'subtotal': 200.0,
          }
        ],
      };

      final c = CompraRegistro.fromJson(json);
      expect(c.idCompra, 50);
      expect(c.idProveedor, 15);
      expect(c.detalles.first.idProducto, 5);
      expect(c.detalles.first.idDetalleCompra, 100);
    });
  });

  group('Categoria Model Tests', () {
    test('Categoria.fromJson safely parses integer from numeric double', () {
      final json = {
        'idCategoria': 7.0,
        'nombre': 'Lácteos',
        'descripcion': 'Leches y derivados',
      };

      final cat = Categoria.fromJson(json);
      expect(cat.idCategoria, 7);
      expect(cat.nombre, 'Lácteos');
    });
  });
}
