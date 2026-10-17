import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/ventas/venta_model.dart';

void main() {
  group('CierreCaja & Arqueo Financial Reconciliation Tests', () {
    test('CierreCaja.fromJson parses cash received and change returned correctly', () {
      final json = {
        'totalVentas': 350.50,
        'totalEfectivo': 150.50,
        'totalEfectivoRecibido': 200.00,
        'totalVueltoEntregado': 49.50,
        'totalYape': 100.00,
        'totalPlin': 50.00,
        'totalTarjeta': 50.00,
        'cantidadVentas': 8,
        'fecha': '2026-10-17T18:00:00Z',
      };

      final cierre = CierreCaja.fromJson(json);

      expect(cierre.totalVentas, 350.50);
      expect(cierre.totalEfectivo, 150.50);
      expect(cierre.totalEfectivoRecibido, 200.00);
      expect(cierre.totalVueltoEntregado, 49.50);
      expect(cierre.totalEfectivoRecibido - cierre.totalVueltoEntregado, 150.50);
      expect(cierre.totalYape, 100.00);
      expect(cierre.totalPlin, 50.00);
      expect(cierre.totalTarjeta, 50.00);
      expect(cierre.cantidadVentas, 8);
      expect(cierre.fecha, isNotNull);
    });

    test('CierreCaja.fromJson gracefully handles legacy backends without breakdown', () {
      final jsonLegacy = {
        'totalVentas': 80.00,
        'totalEfectivo': 80.00,
        'totalYape': 0.0,
        'totalPlin': 0.0,
        'totalTarjeta': 0.0,
        'cantidadVentas': 2,
      };

      final cierre = CierreCaja.fromJson(jsonLegacy);

      expect(cierre.totalVentas, 80.00);
      expect(cierre.totalEfectivo, 80.00);
      expect(cierre.totalEfectivoRecibido, 80.00);
      expect(cierre.totalVueltoEntregado, 0.0);
    });

    test('VentaRegistro handles ANULADA_LOCAL and SUNAT status indicators', () {
      final jsonVenta = {
        'idVenta': 99,
        'clienteNombre': 'Público General',
        'metodoPago': 'Efectivo',
        'total': 25.00,
        'montoRecibido': 50.00,
        'vuelto': 25.00,
        'estado': 'ANULADA',
        'tipoComprobante': 'BOLETA_ELECTRONICA',
        'serieCorrelativo': 'B001-00000099',
        'estadoSunat': 'ANULADA_LOCAL',
        'sunatMensaje': 'Comprobante anulado localmente antes del despacho telemático a SUNAT.',
        'detalles': [],
      };

      final venta = VentaRegistro.fromJson(jsonVenta);

      expect(venta.isAnulada, isTrue);
      expect(venta.esBoleta, isTrue);
      expect(venta.estadoSunat, 'ANULADA_LOCAL');
      expect(venta.montoRecibido, 50.00);
      expect(venta.vuelto, 25.00);
      expect(venta.etiquetaComprobante, 'Boleta B001-00000099');
    });
  });
}
