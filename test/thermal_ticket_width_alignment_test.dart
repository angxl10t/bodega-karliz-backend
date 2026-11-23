import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/thermal_ticket_service.dart';
import 'package:bodega_mobile/core/widgets/thermal_ticket_preview_dialog.dart';

void main() {
  group('Thermal Ticket 58mm / 80mm Width & Edge-to-Edge Alignment Tests', () {
    test('generateReceiptText 58mm header and items match 32 columns', () {
      final receipt = ThermalTicketService.generateReceiptText(
        ticketId: 101,
        clienteNombre: 'Carlos Santana',
        clienteDocumento: '10203040',
        metodoPago: 'Efectivo',
        items: [
          TicketItem(
            nombre: 'Gaseosa Inka Kola 500ml',
            cantidad: 1,
            precioUnitario: 3.50,
            subtotal: 3.50,
          ),
        ],
        total: 3.50,
        pagadoCon: 5.00,
        vuelto: 1.50,
        width: ThermalTicketService.width58mm,
        tipoComprobante: 'BOLETA DE VENTA ELECTRONICA',
      );

      final lines = receipt.split('\n');

      // 1. Divider line is exactly 32 chars
      expect(lines.any((l) => l == ('-' * 32)), isTrue);

      // 2. Product header is exactly 32 chars
      expect(lines.any((l) => l == 'Cant Desc.           P.U.   Imp.'), isTrue);

      // 3. SUNAT representation wraps cleanly instead of truncating
      expect(lines.any((l) => l.contains('Representacion impresa')), isTrue);
      expect(lines.any((l) => l.endsWith('de compro')), isFalse);
      expect(
        lines.any((l) => l.contains('Boleta de Venta Electronica')),
        isTrue,
      );
    });

    test('generateReceiptText 80mm header and items match 48 columns', () {
      final receipt = ThermalTicketService.generateReceiptText(
        ticketId: 102,
        clienteNombre: 'Empresa Constructora SAC',
        clienteDocumento: '20601234567',
        metodoPago: 'Efectivo',
        items: [
          TicketItem(
            nombre: 'Cemento Sol 42.5kg',
            cantidad: 10,
            precioUnitario: 28.50,
            subtotal: 285.00,
          ),
        ],
        total: 285.00,
        width: ThermalTicketService.width80mm,
        tipoComprobante: 'FACTURA ELECTRONICA',
      );

      final lines = receipt.split('\n');

      // 1. Divider line is exactly 48 chars
      expect(lines.any((l) => l == ('-' * 48)), isTrue);

      // 2. Product header is exactly 48 chars
      final header80 = 'Cant. Desc.${' ' * 21}    P.U.    Imp.';
      expect(header80.length, equals(48));
      expect(lines.any((l) => l == header80), isTrue);
    });

    test('generateReceiptText eliminates redundant lines in 58mm and 80mm', () {
      // 1. Caso Bodega Nuevo RUS (Sin IGV discriminado, fecha compacta, sin lema duplicado)
      final receiptRus = ThermalTicketService.generateReceiptText(
        ticketId: 103,
        clienteNombre: 'Público General',
        clienteDocumento: null,
        metodoPago: 'Efectivo',
        items: [
          TicketItem(
            nombre: 'Galleta Soda 6pk',
            cantidad: 1,
            precioUnitario: 3.00,
            subtotal: 3.00,
          ),
        ],
        total: 3.00,
        pagadoCon: 5.00,
        vuelto: 2.00,
        width: ThermalTicketService.width58mm,
        lemaComercial: 'Gracias por su compra, vuelva pronto!',
        regimenTributario: 'NUEVO_RUS',
        tipoComprobante: 'BOLETA_ELECTRONICA',
      );

      final linesRus = receiptRus.split('\n');

      // Fecha y hora compactas en una sola línea (no separadas en 2 renglones)
      expect(linesRus.any((l) => l.startsWith('FECHA:')), isTrue);
      expect(linesRus.any((l) => l.startsWith('Fecha Emision:')), isFalse);
      expect(linesRus.any((l) => l.startsWith('Hora Emision:')), isFalse);

      // No duplica lema falso idéntico a la despedida en la cabecera
      final graciasCount = linesRus
          .where((l) => l.toLowerCase().contains('gracias'))
          .length;
      expect(graciasCount, equals(1)); // Solo en el pie

      // No imprime "Regimen: NUEVO_RUS" innecesario en la cabecera
      expect(linesRus.any((l) => l.contains('Regimen:')), isFalse);

      // Nuevo RUS no desglosa IGV
      expect(linesRus.any((l) => l.contains('OP. GRAVADA:')), isFalse);
      expect(linesRus.any((l) => l.contains('I.G.V. (18%):')), isFalse);

      // No imprime Doc: 99999999 innecesario para clientes anónimos
      expect(linesRus.any((l) => l.contains('Doc: 99999999')), isFalse);
      expect(
        linesRus.any((l) => l.contains('CLIENTE: Clientes Varios')),
        isTrue,
      );

      // Pago y vuelto sin redundancia de "VUELTO / CAMBIO" ni separadores dobles
      expect(linesRus.any((l) => l.contains('VUELTO / CAMBIO')), isFalse);
      expect(linesRus.any((l) => l.startsWith('VUELTO:')), isTrue);
      expect(linesRus.any((l) => l.startsWith('PAGO EFECTIVO:')), isTrue);

      // 2. Caso Factura Electrónica (Régimen General): sí discrimina IGV
      final receiptFactura = ThermalTicketService.generateReceiptText(
        ticketId: 104,
        clienteNombre: 'Comercializadora del Sur SAC',
        clienteDocumento: '20609998881',
        metodoPago: 'Yape',
        items: [
          TicketItem(
            nombre: 'Aceite Primor 1L',
            cantidad: 2,
            precioUnitario: 10.00,
            subtotal: 20.00,
          ),
        ],
        total: 20.00,
        width: ThermalTicketService.width80mm,
        regimenTributario: 'GENERAL',
        tipoComprobante: 'FACTURA_ELECTRONICA',
      );

      final linesFactura = receiptFactura.split('\n');
      expect(linesFactura.any((l) => l.contains('OP. GRAVADA:')), isTrue);
      expect(linesFactura.any((l) => l.contains('I.G.V. (18%):')), isTrue);
      expect(linesFactura.any((l) => l.contains('RUC: 20609998881')), isTrue);
      expect(linesFactura.any((l) => l.contains('PAGO:')), isTrue);
    });

    testWidgets('ThermalTicketPreviewDialog renders 58mm without clipping', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThermalTicketPreviewDialog(
              ticketId: 1,
              clienteNombre: 'Cliente Prueba',
              clienteDocumento: '77889900',
              metodo: 'Efectivo',
              items: [
                TicketItem(
                  nombre: 'Arroz Costeño 1kg',
                  cantidad: 2,
                  precioUnitario: 4.80,
                  subtotal: 9.60,
                ),
              ],
              total: 9.60,
              pagadoCon: 10.00,
              vuelto: 0.40,
              anchoInicial: ThermalTicketService.width58mm,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ThermalTicketPreviewDialog), findsOneWidget);
      expect(find.text('CAJAYA THERMAL POS'), findsOneWidget);
      expect(find.text('58mm'), findsOneWidget);
      expect(find.text('Papel 58 mm • 32 columnas ESC/POS'), findsOneWidget);

      // Switch to 80mm
      await tester.tap(find.text('80mm'));
      await tester.pumpAndSettle();

      expect(find.text('Papel 80 mm • 48 columnas ESC/POS'), findsOneWidget);
    });
  });
}
