import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/ventas/venta_model.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';
import 'package:bodega_mobile/features/home/usuarios_service.dart';

void main() {
  group('Option 1: POS & Cashier Idempotency and Receipt Model Tests', () {
    test('VentaEnvio serializes tipoComprobante and idempotencyKey correctly', () {
      final envio = VentaEnvio(
        clienteDocumento: '20601234567',
        clienteNombre: 'Distribuidora Lima S.A.C.',
        metodoPago: 'Yape',
        tipoComprobante: 'FACTURA_ELECTRONICA',
        idempotencyKey: 'pos_1729123456_849201',
        detalles: [
          VentaDetalleEnvio(idProducto: 10, cantidad: 2.0),
        ],
      );

      final json = envio.toJson();
      expect(json['tipoComprobante'], 'FACTURA_ELECTRONICA');
      expect(json['idempotencyKey'], 'pos_1729123456_849201');
      expect(json['clienteDocumento'], '20601234567');
      expect(json['clienteNombre'], 'Distribuidora Lima S.A.C.');
      expect(json['metodoPago'], 'Yape');
      expect(json['detalles'], hasLength(1));
    });

    test('VentaRegistro correctly handles Sunat Boleta and Factura labels', () {
      final factura = VentaRegistro(
        idVenta: 101,
        metodoPago: 'Efectivo',
        total: 150.0,
        tipoComprobante: 'FACTURA_ELECTRONICA',
        serieCorrelativo: 'F001-0000042',
        estadoSunat: 'ACEPTADO',
        detalles: [],
      );

      expect(factura.esFactura, isTrue);
      expect(factura.esBoleta, isFalse);
      expect(factura.esSunat, isTrue);
      expect(factura.etiquetaComprobante, 'Factura F001-0000042');

      final boleta = VentaRegistro(
        idVenta: 102,
        metodoPago: 'Plin',
        total: 25.0,
        tipoComprobante: 'BOLETA_ELECTRONICA',
        serieCorrelativo: 'B001-0000108',
        detalles: [],
      );

      expect(boleta.esBoleta, isTrue);
      expect(boleta.esFactura, isFalse);
      expect(boleta.esSunat, isTrue);
      expect(boleta.etiquetaComprobante, 'Boleta B001-0000108');

      final ticket = VentaRegistro(
        idVenta: 103,
        metodoPago: 'Efectivo',
        total: 10.0,
        tipoComprobante: 'TICKET',
        detalles: [],
      );

      expect(ticket.esSunat, isFalse);
      expect(ticket.etiquetaComprobante, 'Ticket #103');
    });
  });

  group('Option 2: Analytics & Subscription Ledger Model Tests', () {
    test('CierreCaja parses real-time financial channels correctly', () {
      final json = {
        'totalVentas': 450.50,
        'totalEfectivo': 200.00,
        'totalYape': 150.50,
        'totalPlin': 50.00,
        'totalTarjeta': 50.00,
        'cantidadVentas': 18,
        'fecha': '2026-10-17T12:00:00Z',
      };

      final cierre = CierreCaja.fromJson(json);
      expect(cierre.totalVentas, 450.50);
      expect(cierre.totalEfectivo, 200.00);
      expect(cierre.totalYape, 150.50);
      expect(cierre.totalPlin, 50.00);
      expect(cierre.totalTarjeta, 50.00);
      expect(cierre.cantidadVentas, 18);
      expect(cierre.fecha, isNotNull);
    });

    test('PagoSuscripcionItem parses voucher ledger audit records', () {
      final json = {
        'idPago': 1,
        'idBodega': 5,
        'nombreBodega': 'Bodega Central',
        'codigoOperacion': '84920193',
        'billetera': 'YAPE',
        'plan': 'PRO',
        'monto': 100.0,
        'fechaPago': '2026-10-17T03:30:00',
        'usuarioRegistro': 'admin',
        'estado': 'CONFIRMADO',
      };

      final pago = PagoSuscripcionItem.fromJson(json);
      expect(pago.idPago, 1);
      expect(pago.idBodega, 5);
      expect(pago.codigoOperacion, '84920193');
      expect(pago.billetera, 'YAPE');
      expect(pago.plan, 'PRO');
      expect(pago.monto, 100.0);
      expect(pago.estado, 'CONFIRMADO');
    });

    test('UsuarioItem parses with optional nombreCompleto field', () {
      final json = {
        'idUsuario': 10,
        'username': 'cajero_norte',
        'nombreCompleto': 'Carlos Méndez',
        'rol': 'CAJERO',
        'estado': true,
      };

      final usuario = UsuarioItem.fromJson(json);
      expect(usuario.idUsuario, 10);
      expect(usuario.username, 'cajero_norte');
      expect(usuario.nombreCompleto, 'Carlos Méndez');
      expect(usuario.rol, 'CAJERO');
      expect(usuario.estado, isTrue);
    });
  });
}
