import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/ventas/venta_model.dart';
import 'package:bodega_mobile/core/csv_exporter.dart';

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

    test('Date boundaries for date picker safely normalize time components and prevent assert failures', () {
      final now = DateTime(2026, 10, 20, 9, 15, 30);
      final today = DateTime(now.year, now.month, now.day);
      final firstDate = today.subtract(const Duration(days: 365));
      final lastDate = today;

      // Case 1: Initial date from sale recorded later in the evening (18:00) of today
      final eveningToday = DateTime(2026, 10, 20, 18, 45, 0);
      DateTime safeInitial1 = DateTime(eveningToday.year, eveningToday.month, eveningToday.day);
      if (safeInitial1.isAfter(lastDate)) safeInitial1 = lastDate;
      if (safeInitial1.isBefore(firstDate)) safeInitial1 = firstDate;

      expect(safeInitial1.isAfter(lastDate), isFalse);
      expect(safeInitial1.isBefore(firstDate), isFalse);
      expect(safeInitial1, today);

      // Case 2: Future date requested
      final futureDate = DateTime(2026, 10, 25);
      DateTime safeInitial2 = DateTime(futureDate.year, futureDate.month, futureDate.day);
      if (safeInitial2.isAfter(lastDate)) safeInitial2 = lastDate;
      if (safeInitial2.isBefore(firstDate)) safeInitial2 = firstDate;

      expect(safeInitial2, lastDate);

      // Case 3: Distant past date requested (> 365 days ago)
      final distantPast = DateTime(2024, 1, 1);
      DateTime safeInitial3 = DateTime(distantPast.year, distantPast.month, distantPast.day);
      if (safeInitial3.isAfter(lastDate)) safeInitial3 = lastDate;
      if (safeInitial3.isBefore(firstDate)) safeInitial3 = firstDate;

      expect(safeInitial3, firstDate);
    });

    test('CierreCaja.fromJson correctly parses fondoInicial, egresos and totalEfectivoEsperado', () {
      final json = {
        'totalVentas': 450.00,
        'totalEfectivo': 300.00,
        'totalYape': 150.00,
        'cantidadVentas': 10,
        'fondoInicial': 50.00,
        'totalEgresos': 25.00,
        'totalEfectivoEsperado': 325.00,
        'egresos': [
          {
            'idEgreso': 1,
            'monto': 15.00,
            'motivo': 'Compra de bolsas',
            'categoriaGasto': 'BOLSAS',
            'estado': true,
          },
          {
            'idEgreso': 2,
            'monto': 10.00,
            'motivo': 'Hielo en bolsa',
            'categoriaGasto': 'HIELO',
            'estado': true,
          }
        ],
      };

      final cierre = CierreCaja.fromJson(json);

      expect(cierre.fondoInicial, 50.00);
      expect(cierre.totalEgresos, 25.00);
      expect(cierre.totalEfectivoEsperado, 325.00);
      expect(cierre.egresos.length, 2);
      expect(cierre.egresos[0].motivo, 'Compra de bolsas');
      expect(cierre.egresos[1].monto, 10.00);
    });

    test('CsvExporter safely escapes formula injection characters and formats properly', () {
      final inputFormula = '=SUM(A1:A10)';
      final inputPlus = '+cmd| /C calc';
      final inputQuotes = 'Pan "Especial" Francés';

      expect(CsvExporter.escapar(inputFormula), "'=SUM(A1:A10)");
      expect(CsvExporter.escapar(inputPlus), "'+cmd| /C calc");
      expect(CsvExporter.escapar(inputQuotes), '"Pan ""Especial"" Francés"');
    });
  });
}
