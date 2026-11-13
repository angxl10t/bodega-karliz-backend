import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/core/balanza_barcode_helper.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/core/offline/offline_sync_manager.dart';
import 'package:bodega_mobile/core/offline/offline_models.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BalanzaBarcodeHelper Tests', () {
    test('Detecta y decodifica correctamente código GS1 de balanza prefijo 20', () {
      // 20 [00125] [00350] 4 -> SKU 125, 350 gramos = 0.350 kg
      const code = '2000125003504';
      expect(BalanzaBarcodeHelper.esCodigoBalanza(code), isTrue);

      final result = BalanzaBarcodeHelper.parse(code);
      expect(result, isNotNull);
      expect(result!.rawCode, equals(code));
      expect(result.codigoBase, equals('125'));
      expect(result.sku5, equals('00125'));
      expect(result.sku4, equals('0012'));
      expect(result.pesoKg, closeTo(0.350, 0.0001));
      expect(result.esPorPeso, isTrue);
    });

    test('Detecta y decodifica código de balanza prefijo 21 (1.250 kg)', () {
      // 21 [00999] [01250] 8 -> SKU 999, 1250 gramos = 1.250 kg
      const code = '2100999012508';
      expect(BalanzaBarcodeHelper.esCodigoBalanza(code), isTrue);

      final result = BalanzaBarcodeHelper.parse(code);
      expect(result, isNotNull);
      expect(result!.codigoBase, equals('999'));
      expect(result.pesoKg, closeTo(1.250, 0.0001));
    });

    test('Rechaza códigos normales que no son de balanza', () {
      expect(BalanzaBarcodeHelper.esCodigoBalanza('7750123456789'), isFalse);
      expect(BalanzaBarcodeHelper.parse('7750123456789'), isNull);
      expect(BalanzaBarcodeHelper.esCodigoBalanza('12345'), isFalse);
    });
  });

  group('Producto.esPesableOGranel Tests', () {
    test('Reconoce productos a granel o pesables por nombre o categoría', () {
      final p1 = Producto(
        idProducto: 1,
        codigo: 'GR01',
        nombre: 'Arroz Superior Costeño a Granel',
        precioVenta: 4.20,
        stockActual: 50.0,
      );
      expect(p1.esPesableOGranel, isTrue);

      final p2 = Producto(
        idProducto: 2,
        codigo: 'PO01',
        nombre: 'Pechuga de Pollo Fresca',
        nombreCategoria: 'Carnes y Aves',
        precioVenta: 14.50,
        stockActual: 20.0,
      );
      expect(p2.esPesableOGranel, isTrue);

      final p3 = Producto(
        idProducto: 3,
        codigo: 'LE01',
        nombre: 'Lentejas del Norte',
        precioVenta: 6.00,
        stockActual: 15.0,
      );
      expect(p3.esPesableOGranel, isTrue);

      final p4 = Producto(
        idProducto: 4,
        codigo: 'GA01',
        nombre: 'Gaseosa Inka Kola 500ml',
        nombreCategoria: 'Bebidas',
        precioVenta: 3.00,
        stockActual: 48.0,
      );
      expect(p4.esPesableOGranel, isFalse);
    });
  });

  group('OfflineSyncManager Modo Blindado Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Activar Modo Offline Blindado fuerza flag reactivo y omite bloqueos de red', () async {
      final manager = OfflineSyncManager.instance;
      await manager.init();

      expect(manager.isForceOffline, isFalse);

      await manager.setForceOffline(true);
      expect(manager.isForceOffline, isTrue);
      expect(manager.forceOfflineNotifier.value, isTrue);
      expect(manager.isOfflineNotifier.value, isTrue);

      await manager.setForceOffline(false);
      expect(manager.isForceOffline, isFalse);
      expect(manager.forceOfflineNotifier.value, isFalse);
    });

    test('Encolar ventas offline descuenta stock y acumula totales', () async {
      final manager = OfflineSyncManager.instance;
      await manager.init();

      final venta = OfflineVenta(
        uuid: 'test-uuid-001',
        localTicket: 'TK-001',
        idBodega: 10,
        clienteNombre: 'Cliente General',
        tipoComprobante: 'NOTA_VENTA',
        metodoPago: 'EFECTIVO',
        total: 25.50,
        fechaCreacion: DateTime.now(),
        detalles: [
          OfflineVentaDetalle(
            idProducto: 100,
            nombreProducto: 'Arroz a Granel',
            cantidad: 2.5,
            precioUnitario: 4.20,
            subtotal: 10.50,
          ),
        ],
      );

      await manager.enqueueSale(venta);
      expect(manager.pendingCount, greaterThanOrEqualTo(1));
      expect(manager.pendingTotal, greaterThanOrEqualTo(25.50));

      // Limpiar cola de prueba
      await manager.clearQueueForTesting();
      expect(manager.pendingCount, equals(0));
    });
  });

  group('SuperAdmin 1-Click Payments Model Tests', () {
    test('BodegaInfo copyWith actualiza plan y fechaVencimientoPlan', () {
      final original = BodegaInfo(
        idBodega: 99,
        nombreComercial: 'Bodega Central',
        colorPrimario: '#0084FF',
        plan: 'FREE',
        fechaVencimientoPlan: '2026-11-01T00:00:00',
        estado: true,
      );

      final renovada = original.copyWith(
        plan: 'PRO',
        fechaVencimientoPlan: '2026-12-01T00:00:00',
      );

      expect(renovada.plan, equals('PRO'));
      expect(renovada.fechaVencimientoPlan, equals('2026-12-01T00:00:00'));
      expect(renovada.nombreComercial, equals('Bodega Central'));
    });
  });
}
