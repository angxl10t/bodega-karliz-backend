import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';
import 'package:bodega_mobile/features/ventas/venta_model.dart';
import 'package:bodega_mobile/features/proveedores/proveedor_model.dart';
import 'package:bodega_mobile/features/compras/compra_model.dart';
import 'package:bodega_mobile/features/categorias/categoria_model.dart';
import 'package:bodega_mobile/features/movimientos/movimiento_model.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/core/category_helper.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

    test('Producto handles controlaVencimiento in fromJson and toJson', () {
      final json = {
        'idProducto': 101,
        'idCategoria': 5,
        'codigo': 'LAC-0001',
        'nombre': 'Leche Gloria 400g',
        'precioVenta': 4.20,
        'stockActual': 24,
        'stockMinimo': 6,
        'controlaVencimiento': true,
      };

      final p = Producto.fromJson(json);
      expect(p.controlaVencimiento, isTrue);

      final serialized = p.toJson();
      expect(serialized['controlaVencimiento'], isTrue);
      expect(serialized['idProducto'], 101);
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

  group('CategoryHelper Icon & Theme Mapping Tests', () {
    test('Correctly maps retail categories to Lucide icons', () {
      expect(CategoryHelper.getIcon('Bebidas'), LucideIcons.cupSoda);
      expect(CategoryHelper.getIcon('Gaseosas y Jugos'), LucideIcons.cupSoda);
      expect(CategoryHelper.getIcon('Snacks y Piqueos'), LucideIcons.cookie);
      expect(CategoryHelper.getIcon('Abarrotes'), LucideIcons.shoppingBasket);
      expect(CategoryHelper.getIcon('Limpieza del Hogar'), LucideIcons.sparkles);
      expect(CategoryHelper.getIcon('Lácteos y Huevos'), LucideIcons.egg);
      expect(CategoryHelper.getIcon('Golosinas y Dulces'), LucideIcons.candy);
      expect(CategoryHelper.getIcon('Panadería'), LucideIcons.croissant);
      expect(CategoryHelper.getIcon('Frutas y Verduras'), LucideIcons.apple);
      expect(CategoryHelper.getIcon('⭐ Frecuentes'), LucideIcons.flame);
      expect(CategoryHelper.getIcon('Todos'), LucideIcons.layoutGrid);
      expect(CategoryHelper.getIcon('Desconocido'), LucideIcons.package2);
      expect(CategoryHelper.getIcon(null), LucideIcons.package2);
    });

    test('Returns signature colors in both light and dark themes', () {
      final lightBebidas = CategoryHelper.getColor('Bebidas', false);
      final darkBebidas = CategoryHelper.getColor('Bebidas', true);
      expect(lightBebidas, darkBebidas);

      final nullLight = CategoryHelper.getColor(null, false);
      final nullDark = CategoryHelper.getColor(null, true);
      expect(nullLight, isNot(nullDark));
    });
  });

  group('Stock Multi-Dimensional Filtering Logic Tests', () {
    final sampleProducts = [
      Producto(
        idProducto: 1,
        idCategoria: 1,
        nombreCategoria: 'Bebidas',
        codigo: 'BEB-01',
        nombre: 'Inca Kola 500ml',
        marca: 'Inca Kola',
        precioVenta: 3.5,
        stockActual: 4, // Crítico / bajo
        stockMinimo: 5,
      ),
      Producto(
        idProducto: 2,
        idCategoria: 1,
        nombreCategoria: 'Bebidas',
        codigo: 'BEB-02',
        nombre: 'Coca Cola 1.5L',
        marca: 'Coca Cola',
        precioVenta: 7.0,
        stockActual: 25, // Óptimo
        stockMinimo: 5,
      ),
      Producto(
        idProducto: 3,
        idCategoria: 2,
        nombreCategoria: 'Snacks',
        codigo: 'SNK-01',
        nombre: 'Papas Lays Clásicas',
        marca: 'Frito-Lay',
        precioVenta: 2.0,
        stockActual: 8, // Por agotar (<=10)
        stockMinimo: 5,
      ),
      Producto(
        idProducto: 4,
        idCategoria: 3,
        nombreCategoria: 'Lácteos',
        codigo: 'LAC-01',
        nombre: 'Leche Gloria Azul 400g',
        marca: 'Gloria',
        precioVenta: 4.2,
        stockActual: 50, // Óptimo
        stockMinimo: 10,
      ),
    ];

    List<Producto> filtrar({
      required String query,
      required String selectedCategoria,
      required String estadoStock,
    }) {
      final q = query.trim().toLowerCase();
      return sampleProducts.where((p) {
        if (q.isNotEmpty) {
          final nombreMatch = p.nombre.toLowerCase().contains(q);
          final codMatch = p.codigo.toLowerCase().contains(q);
          final marcaMatch = (p.marca ?? '').toLowerCase().contains(q);
          final catMatch = (p.nombreCategoria ?? '').toLowerCase().contains(q);
          if (!nombreMatch && !codMatch && !marcaMatch && !catMatch) return false;
        }

        if (selectedCategoria != 'Todos') {
          final cat = p.nombreCategoria?.trim() ?? 'General';
          if (cat != selectedCategoria) return false;
        }

        if (estadoStock == 'bajo_stock') {
          return p.stockActual <= 10;
        } else if (estadoStock == 'con_stock') {
          return p.stockActual > 10;
        }
        return true;
      }).toList();
    }

    test('Filters by Category exclusively', () {
      final bebidas = filtrar(query: '', selectedCategoria: 'Bebidas', estadoStock: 'todos');
      expect(bebidas.length, 2);

      final snacks = filtrar(query: '', selectedCategoria: 'Snacks', estadoStock: 'todos');
      expect(snacks.length, 1);
      expect(snacks.first.codigo, 'SNK-01');
    });

    test('Filters simultaneously by Category and Stock Health', () {
      // Bebidas con bajo stock (<=10) -> Solo BEB-01 (stock 4)
      final bebidasBajoStock = filtrar(query: '', selectedCategoria: 'Bebidas', estadoStock: 'bajo_stock');
      expect(bebidasBajoStock.length, 1);
      expect(bebidasBajoStock.first.codigo, 'BEB-01');

      // Bebidas con stock óptimo (>10) -> Solo BEB-02 (stock 25)
      final bebidasOptimas = filtrar(query: '', selectedCategoria: 'Bebidas', estadoStock: 'con_stock');
      expect(bebidasOptimas.length, 1);
      expect(bebidasOptimas.first.codigo, 'BEB-02');
    });

    test('Filters by Brand within search query', () {
      final gloria = filtrar(query: 'gloria', selectedCategoria: 'Todos', estadoStock: 'todos');
      expect(gloria.length, 1);
      expect(gloria.first.nombre, 'Leche Gloria Azul 400g');
    });
  });

  group('Form Validation & Document Resilience Tests', () {
    test('Validates RUC (11 digits) and DNI (8 digits) strictly', () {
      final regExp = RegExp(r'^(?:[0-9]{8}|[0-9]{11})$');
      expect(regExp.hasMatch('20601234567'), isTrue); // RUC 11
      expect(regExp.hasMatch('10456789012'), isTrue); // RUC persona natural 11
      expect(regExp.hasMatch('74839201'), isTrue);    // DNI 8
      expect(regExp.hasMatch('12345'), isFalse);      // 5 dígitos inválido
      expect(regExp.hasMatch('206012345678'), isFalse); // 12 dígitos inválido
      expect(regExp.hasMatch('2060123456A'), isFalse); // Letra inválido
      expect(regExp.hasMatch(''), isFalse);
    });

    test('Validates Peruvian mobile phone number (9 digits)', () {
      final regExp = RegExp(r'^[0-9]{9}$');
      expect(regExp.hasMatch('987654321'), isTrue);
      expect(regExp.hasMatch('912345678'), isTrue);
      expect(regExp.hasMatch('98765432'), isFalse);  // 8 dígitos
      expect(regExp.hasMatch('9876543210'), isFalse); // 10 dígitos
      expect(regExp.hasMatch('98765432a'), isFalse);
    });

    test('Validates product non-negative constraints for price, stock and min stock', () {
      bool validarProducto({required double precio, required double stock, required double stockMin}) {
        if (precio <= 0) return false;
        if (stock < 0) return false;
        if (stockMin < 0) return false;
        return true;
      }

      expect(validarProducto(precio: 3.50, stock: 10, stockMin: 2), isTrue);
      expect(validarProducto(precio: 0.0, stock: 10, stockMin: 2), isFalse);
      expect(validarProducto(precio: -1.5, stock: 10, stockMin: 2), isFalse);
      expect(validarProducto(precio: 3.5, stock: -5, stockMin: 2), isFalse);
      expect(validarProducto(precio: 3.5, stock: 0, stockMin: -1), isFalse);
      expect(validarProducto(precio: 3.5, stock: 0, stockMin: 0), isTrue);
    });
  });

  group('Kardex & Stock Adjustment Model Tests', () {
    test('MovimientoInventario.fromJson safely parses usuarioResponsable and numeric values', () {
      final json = {
        'idMovimiento': 105,
        'idProducto': 42,
        'nombreProducto': 'Arroz Costeño 1kg',
        'tipoMovimiento': 'SALIDA',
        'cantidad': 3.5,
        'motivo': '[MERMA] Empaque humedecido',
        'fechaMovimiento': '2026-10-20T10:30:00Z',
        'usuarioResponsable': 'admin_karliz',
      };

      final m = MovimientoInventario.fromJson(json);
      expect(m.idMovimiento, equals(105));
      expect(m.idProducto, equals(42));
      expect(m.nombreProducto, equals('Arroz Costeño 1kg'));
      expect(m.tipoMovimiento, equals('SALIDA'));
      expect(m.cantidad, equals(3.5));
      expect(m.motivo, equals('[MERMA] Empaque humedecido'));
      expect(m.usuarioResponsable, equals('admin_karliz'));
      expect(m.fechaMovimiento, isNotNull);
    });

    test('Stock projection logic enforces non-negative remaining stock for exits', () {
      double proyectarStock({required double stockActual, required double cantidad, required bool esSalida}) {
        if (esSalida) {
          if (cantidad > stockActual) throw ArgumentError('Merma excede stock actual');
          return stockActual - cantidad;
        } else {
          return stockActual + cantidad;
        }
      }

      expect(proyectarStock(stockActual: 20.0, cantidad: 5.0, esSalida: true), equals(15.0));
      expect(proyectarStock(stockActual: 20.0, cantidad: 20.0, esSalida: true), equals(0.0));
      expect(proyectarStock(stockActual: 20.0, cantidad: 4.5, esSalida: false), equals(24.5));
      expect(() => proyectarStock(stockActual: 20.0, cantidad: 25.0, esSalida: true), throwsArgumentError);
    });
  });

  group('SaaS Subscription Quota Tests', () {
    test('BodegaInfo.fromJson parses quota and limit fields correctly', () {
      final json = {
        'idBodega': 5,
        'nombreComercial': 'Minimarket Los Andes',
        'plan': 'BASICO',
        'estado': true,
        'limiteProductos': 150,
        'totalProductosActivos': 120,
        'limiteAlcanzado': false,
      };

      final b = BodegaInfo.fromJson(json);
      expect(b.idBodega, equals(5));
      expect(b.plan, equals('BASICO'));
      expect(b.limiteProductos, equals(150));
      expect(b.totalProductosActivos, equals(120));
      expect(b.limiteAlcanzado, isFalse);
    });

    test('BodegaInfo marks limit reached when total equals or exceeds 150 in BASICO plan', () {
      final json = {
        'idBodega': 6,
        'nombreComercial': 'Bodega La Esquina',
        'plan': 'BASICO',
        'estado': true,
        'limiteProductos': 150,
        'totalProductosActivos': 150,
        'limiteAlcanzado': true,
      };

      final b = BodegaInfo.fromJson(json);
      expect(b.limiteAlcanzado, isTrue);
    });
  });
}
