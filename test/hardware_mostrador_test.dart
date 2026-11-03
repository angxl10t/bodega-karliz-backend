import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/core/thermal_ticket_service.dart';
import 'package:bodega_mobile/core/configuracion_ticket_service.dart';
import 'package:bodega_mobile/features/ventas/hardware_mostrador_modal.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Frente de Operatividad & Hardware en Mostrador Tests', () {
    test('ThermalTicketService.openDrawerBytes conforms to standard Pin 2 & Pin 5 pulses', () {
      final pulse = ThermalTicketService.openDrawerBytes;
      expect(pulse, isNotEmpty);
      expect(pulse.length, equals(10));
      // Pin 2: ESC p 0 25 250 -> 0x1B, 0x70, 0x00, 0x19, 0xFA
      expect(pulse.sublist(0, 5), equals([0x1B, 0x70, 0x00, 0x19, 0xFA]));
      // Pin 5: ESC p 1 25 250 -> 0x1B, 0x70, 0x01, 0x19, 0xFA
      expect(pulse.sublist(5, 10), equals([0x1B, 0x70, 0x01, 0x19, 0xFA]));
    });

    test('ThermalTicketService.generatePrintableHtml formats 58mm continuous roll with zero margins', () {
      final html = ThermalTicketService.generatePrintableHtml(
        'BODEGA DON PEPE\nTOTAL: S/ 25.50\nGRACIAS POR SU COMPRA',
        widthMm: 58,
      );

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('size: 58mm auto;'));
      expect(html, contains('margin: 0;'));
      expect(html, contains('font-family: \'Courier New\''));
      expect(html, contains('BODEGA DON PEPE'));
      expect(html, contains('TOTAL: S/ 25.50'));
      expect(html, contains('window.print();'));
    });

    test('ThermalTicketService.generatePrintableHtml formats 80mm format for heavy desktop printers', () {
      final html = ThermalTicketService.generatePrintableHtml(
        'MINIMARKET CENTRAL\nTOTAL: S/ 140.00',
        widthMm: 80,
      );

      expect(html, contains('size: 80mm auto;'));
      expect(html, contains('font-size: 12px;'));
      expect(html, contains('MINIMARKET CENTRAL'));
    });

    test('ThermalTicketService.abrirGavetaDinero sends pure pulse without error in test environment', () async {
      const cfg = ConfiguracionTicket(
        modoConexion: 'navegador',
        abrirGaveta: true,
      );

      final res = await ThermalTicketService.abrirGavetaDinero(config: cfg);
      expect(res.exito, isTrue);
    });

    testWidgets('HardwareMostradorModal renders 4 counter diagnostic tabs and widgets', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testProducts = [
        Producto(
          idProducto: 1,
          codigo: 'P001',
          codigoBarras: '7750182001011',
          nombre: 'Gaseosa Inka Kola 500ml',
          precioVenta: 3.50,
          stockActual: 24,
          stockMinimo: 6,
          controlaVencimiento: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => HardwareMostradorModal.show(ctx, productos: testProducts),
                  child: const Text('Abrir Hardware'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Hardware'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar encabezado
      expect(find.text('Hardware & Mostrador POS'), findsOneWidget);
      expect(find.text('Ticketera Térmica'), findsOneWidget);
      expect(find.text('Lector de Barras'), findsOneWidget);
      expect(find.text('Gaveta de Dinero'), findsOneWidget);
      expect(find.text('Atajos & Kiosco'), findsOneWidget);

      // En pestaña Ticketera
      expect(find.text('ANCHO DE PAPEL DE LA TICKETERA'), findsOneWidget);
      expect(find.textContaining('58 mm'), findsOneWidget);
      expect(find.textContaining('Imprimir Ticket de Diagnóstico'), findsOneWidget);

      // Deslizar a pestaña Lector de Barras
      await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('ZONA DE DISPARO INTERACTIVA'), findsOneWidget);

      // Deslizar a pestaña Gaveta de Dinero
      await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('ABRIR GAVETA AHORA'), findsOneWidget);
      expect(find.textContaining('Atajo de teclado F7'), findsOneWidget);

      // Deslizar a pestaña Atajos & Kiosco
      await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('F2'), findsOneWidget);
      expect(find.text('F4 / F12'), findsOneWidget);
      expect(find.text('F7'), findsOneWidget);
      expect(find.text('F8'), findsOneWidget);
      expect(find.text('F9'), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
    });
  });
}
