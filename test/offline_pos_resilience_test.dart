import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/offline/uuid_helper.dart';
import 'package:bodega_mobile/core/offline/offline_models.dart';

void main() {
  group('Offline POS & Local-First Resilience Tests', () {
    test('UuidHelper generates valid RFC 4122 v4 UUID', () {
      final uuid1 = UuidHelper.generateV4();
      final uuid2 = UuidHelper.generateV4();

      expect(uuid1, isNotEmpty);
      expect(uuid2, isNotEmpty);
      expect(uuid1, isNot(equals(uuid2)));

      // Regex para validar formato UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      final uuidV4Regex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidV4Regex.hasMatch(uuid1), isTrue, reason: 'UUID 1 debe cumplir con el estándar RFC 4122 v4');
      expect(uuidV4Regex.hasMatch(uuid2), isTrue, reason: 'UUID 2 debe cumplir con el estándar RFC 4122 v4');
    });

    test('UuidHelper generates local ticket numbers', () {
      final ticket = UuidHelper.generateLocalTicket(3);
      expect(ticket.startsWith('TK-OFF-'), isTrue);
    });

    test('OfflineVenta serializes and deserializes cleanly without data loss', () {
      final uuid = UuidHelper.generateV4();
      final venta = OfflineVenta(
        uuid: uuid,
        localTicket: 'TK-OFF-12345',
        idBodega: 3,
        idCliente: 10,
        clienteDocumento: '72345678',
        clienteNombre: 'Juan Perez',
        metodoPago: 'Efectivo',
        tipoComprobante: 'BOLETA_ELECTRONICA',
        montoRecibido: 50.0,
        vuelto: 15.0,
        total: 35.0,
        usuarioRegistro: 'admin_karliz',
        fechaCreacion: DateTime(2026, 10, 25, 2, 0),
        detalles: [
          OfflineVentaDetalle(
            idProducto: 1,
            nombreProducto: 'Inca Kola 500ml',
            cantidad: 2.0,
            precioUnitario: 3.5,
            subtotal: 7.0,
            codigo: 'BEB-001',
          ),
          OfflineVentaDetalle(
            idProducto: 2,
            nombreProducto: 'Arroz Costeño 1kg',
            cantidad: 4.0,
            precioUnitario: 7.0,
            subtotal: 28.0,
            codigo: 'ABAR-001',
          ),
        ],
      );

      final json = venta.toJson();
      final decoded = OfflineVenta.fromJson(json);

      expect(decoded.uuid, equals(uuid));
      expect(decoded.localTicket, equals('TK-OFF-12345'));
      expect(decoded.total, equals(35.0));
      expect(decoded.detalles.length, equals(2));
      expect(decoded.detalles[0].nombreProducto, equals('Inca Kola 500ml'));
      expect(decoded.detalles[1].subtotal, equals(28.0));
    });

    test('OfflineVenta converts to VentaEnvio preserving IdempotencyKey', () {
      final uuid = UuidHelper.generateV4();
      final venta = OfflineVenta(
        uuid: uuid,
        localTicket: 'TK-OFF-9999',
        idBodega: 3,
        clienteNombre: 'Maria Garcia',
        metodoPago: 'Yape',
        total: 20.0,
        fechaCreacion: DateTime.now(),
        detalles: [
          OfflineVentaDetalle(
            idProducto: 5,
            nombreProducto: 'Leche Gloria',
            cantidad: 4.0,
            precioUnitario: 5.0,
            subtotal: 20.0,
          ),
        ],
      );

      final envio = venta.toVentaEnvio();
      expect(envio.idempotencyKey, equals(uuid));
      expect(envio.clienteNombre, equals('Maria Garcia'));
      expect(envio.metodoPago, equals('Yape'));
      expect(envio.detalles.length, equals(1));
      expect(envio.detalles[0].idProducto, equals(5));
      expect(envio.detalles[0].cantidad, equals(4.0));
    });

    test('OfflineVenta converts to VentaRegistro for seamless POS confirmation receipt', () {
      final venta = OfflineVenta(
        uuid: UuidHelper.generateV4(),
        localTicket: 'TK-OFF-7777',
        idBodega: 3,
        clienteNombre: 'Carlos Prado',
        metodoPago: 'Efectivo',
        total: 10.0,
        fechaCreacion: DateTime.now(),
        detalles: [
          OfflineVentaDetalle(
            idProducto: 8,
            nombreProducto: 'Galletas Soda',
            cantidad: 5.0,
            precioUnitario: 2.0,
            subtotal: 10.0,
          ),
        ],
      );

      final registro = venta.toVentaRegistro();
      expect(registro.serieCorrelativo, equals('TK-OFF-7777'));
      expect(registro.estadoSunat, equals('OFFLINE_PENDIENTE'));
      expect(registro.total, equals(10.0));
      expect(registro.detalles.length, equals(1));
      expect(registro.detalles[0].nombreProducto, equals('Galletas Soda'));
    });
  });
}
