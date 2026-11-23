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
