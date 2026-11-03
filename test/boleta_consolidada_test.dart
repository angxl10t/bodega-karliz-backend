import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/fiscal/boleta_consolidada_service.dart';
import 'package:bodega_mobile/core/thermal_ticket_service.dart';

void main() {
  group('Boleta Consolidada Diaria Nuevo RUS Tests', () {
    test('ResumenVentasMenores parsea correctamente datos sugeridos de ventas <= S/ 5.00', () {
      final json = {
        'fecha': '2026-11-03',
        'cantidadOperacionesSugeridas': 18,
        'montoSugerido': 48.50,
        'yaRegistrada': false,
        'baseLegal': 'Art. 8, Num. 3.2 de la Res. de Superintendencia N° 007-99/SUNAT',
      };

      final resumen = ResumenVentasMenores.fromJson(json);

      expect(resumen.fecha.year, equals(2026));
      expect(resumen.fecha.month, equals(11));
      expect(resumen.fecha.day, equals(3));
      expect(resumen.cantidadOperacionesSugeridas, equals(18));
      expect(resumen.montoSugerido, equals(48.50));
      expect(resumen.yaRegistrada, isFalse);
      expect(resumen.serieCorrelativo, isNull);
    });

    test('ResumenVentasMenores con boleta ya registrada parsea correctamente campos', () {
      final json = {
        'fecha': '2026-11-03',
        'cantidadOperacionesSugeridas': 25,
        'montoSugerido': 72.80,
        'yaRegistrada': true,
        'idBoletaConsolidada': 105,
        'serieCorrelativo': '001-000452',
        'tipoEmision': 'TALONARIO_FISICO',
        'montoRegistrado': 72.80,
        'cantidadOperacionesRegistradas': 25,
        'observaciones': 'Boleta física del talonario manual',
        'usuarioRegistro': 'Don Pepe',
        'fechaRegistro': '2026-11-03T21:45:00',
        'baseLegal': 'Art. 8, Num. 3.2 de la Res. de Superintendencia N° 007-99/SUNAT',
      };

      final resumen = ResumenVentasMenores.fromJson(json);

      expect(resumen.yaRegistrada, isTrue);
      expect(resumen.idBoletaConsolidada, equals(105));
      expect(resumen.serieCorrelativo, equals('001-000452'));
      expect(resumen.montoRegistrado, equals(72.80));
      expect(resumen.cantidadOperacionesRegistradas, equals(25));
      expect(resumen.tipoEmision, equals('TALONARIO_FISICO'));
      expect(resumen.usuarioRegistro, equals('Don Pepe'));
      expect(resumen.observaciones, equals('Boleta física del talonario manual'));
    });

    test('BoletaConsolidadaRecord parsea correctamente registro del historial', () {
      final json = {
        'idBoletaConsolidada': 201,
        'fechaEmision': '2026-11-02',
        'montoTotal': 54.00,
        'cantidadOperaciones': 14,
        'serieCorrelativo': 'B001-00000005',
        'tipoEmision': 'SISTEMA_CAJAYA',
        'observaciones': 'Cierre digital',
        'usuarioRegistro': 'admin',
        'fechaRegistro': '2026-11-02T22:00:00',
      };

      final record = BoletaConsolidadaRecord.fromJson(json);

      expect(record.idBoletaConsolidada, equals(201));
      expect(record.fechaEmision.day, equals(2));
      expect(record.montoTotal, equals(54.00));
      expect(record.cantidadOperaciones, equals(14));
      expect(record.serieCorrelativo, equals('B001-00000005'));
      expect(record.tipoEmision, equals('SISTEMA_CAJAYA'));
      expect(record.usuarioRegistro, equals('admin'));
    });

    test('ThermalTicketService.generateBoletaConsolidadaText genera texto estructurado de respaldo', () {
      final text = ThermalTicketService.generateBoletaConsolidadaText(
        serieCorrelativo: '001-000452',
        fechaEmision: DateTime(2026, 11, 3),
        montoTotal: 72.80,
        cantidadOperaciones: 25,
        tipoEmision: 'TALONARIO_FISICO',
        observaciones: 'Consolidado día martes',
        cajero: 'Don Pepe',
        nombreComercio: 'Bodega Don Pepe',
        rucDni: '10456789012',
        direccion: 'Jr. Las Palmeras 123',
        telefono: '999888777',
        lemaComercial: 'La bodega de confianza',
        width: ThermalTicketService.width58mm,
      );

      expect(text, contains('BODEGA DON PEPE'));
      expect(text, contains('RUC: 10456789012'));
      expect(text, contains('BOLETA DE VENTA CONSOLIDADA'));
      expect(text, contains('VENTAS MENORES A S/ 5.00'));
      expect(text, contains('Res. SUNAT 007-99 Art. 8.3.2'));
      expect(text, contains('001-000452'));
      expect(text, contains('TOTAL CONSOLIDADO'));
      expect(text, contains('S/ 72.80'));
      expect(text, contains('OPERACIONES'));
      expect(text, contains('25'));
      expect(text, contains('Talonario Fisico'));
      expect(text, contains('Don Pepe'));
      expect(text, contains('Consolidado día martes'));
    });

    test('ThermalTicketService.generateBoletaConsolidadaEscPosBytes genera bytes válidos ESC/POS', () {
      final bytes = ThermalTicketService.generateBoletaConsolidadaEscPosBytes(
        serieCorrelativo: 'B001-00000001',
        fechaEmision: DateTime(2026, 11, 3),
        montoTotal: 45.00,
        cantidadOperaciones: 15,
        tipoEmision: 'SISTEMA_CAJAYA',
        nombreComercio: 'Bodega Central',
      );

      expect(bytes, isNotEmpty);
      // Debe contener inicialización de impresora ESC @ (0x1B, 0x40)
      expect(bytes, contains(0x1B));
      expect(bytes, contains(0x40));
      // Debe contener el corte de papel parcial (GS V 66 0 -> 0x1D, 0x56, 0x42, 0x00)
      expect(bytes, contains(0x1D));
      expect(bytes, contains(0x56));

      final decoded = utf8.decode(bytes, allowMalformed: true);
      expect(decoded, contains('BOLETA DE VENTA CONSOLIDADA'));
      expect(decoded, contains('B001-00000001'));
      expect(decoded, contains('S/ 45.00'));
    });
  });
}
