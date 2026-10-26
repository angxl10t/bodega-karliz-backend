import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/ventas/venta_model.dart';
import 'package:bodega_mobile/features/ventas/ventas_screen.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';

void main() {
  group('POS Checkout UX & VentaEnvio Tests', () {
    test('VentaEnvio serializes anonymous customer without hardcoded 00000000', () {
      final venta = VentaEnvio(
        clienteDocumento: null,
        clienteNombre: 'Clientes Varios',
        metodoPago: 'Efectivo',
        tipoComprobante: 'BOLETA_ELECTRONICA',
        detalles: [
          VentaDetalleEnvio(idProducto: 1, cantidad: 2.0),
        ],
      );

      final json = venta.toJson();
      expect(json['clienteDocumento'], isNull);
      expect(json['clienteNombre'], equals('Clientes Varios'));
      expect(json['metodoPago'], equals('Efectivo'));
      expect(json['tipoComprobante'], equals('BOLETA_ELECTRONICA'));
      expect(json['detalles'], hasLength(1));
    });

    test('VentaEnvio serializes customer with valid DNI', () {
      final venta = VentaEnvio(
        clienteDocumento: '72839102',
        clienteNombre: 'JUAN PEREZ QUISPE',
        metodoPago: 'Yape',
        tipoComprobante: 'BOLETA_ELECTRONICA',
        detalles: [
          VentaDetalleEnvio(idProducto: 5, cantidad: 1.0),
        ],
      );

      final json = venta.toJson();
      expect(json['clienteDocumento'], equals('72839102'));
      expect(json['clienteNombre'], equals('JUAN PEREZ QUISPE'));
      expect(json['metodoPago'], equals('Yape'));
    });
  });

  group('VentasScreen POS UX Widget Tests', () {
    setUp(() {
      ProductoService.setMockProductos([
        Producto(
          idProducto: 1,
          nombre: 'Gaseosa Inka Cola 500ml',
          precioVenta: 3.50,
          stockActual: 20,
          codigo: 'PROD-001',
        ),
      ]);
    });

    testWidgets('Renders Consumidor Final (Sin DNI) by default on mobile layout', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VentasScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verificar que se renderiza el texto "Consumidor Final" y la etiqueta "Sin DNI"
      expect(find.text('Consumidor Final'), findsOneWidget);
      expect(find.text('Sin DNI'), findsOneWidget);
      expect(find.text('+ DNI'), findsOneWidget);

      // Verificar que NO existe ningún TextField con texto literal "00000000"
      expect(find.text('00000000'), findsNothing);

      // Tocar el botón "+ DNI" para activar la identificación con DNI
      await tester.tap(find.text('+ DNI'));
      await tester.pumpAndSettle();

      // Ahora debe mostrar la interfaz de identificación con DNI
      expect(find.text('Cliente con DNI'), findsOneWidget);
      expect(find.text('Consumidor Final'), findsWidgets); // botón para volver
    });

    testWidgets('Renders Consumidor Final and Cash options on tablet layout', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VentasScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // En layout tablet debe verse el panel de ticket
      expect(find.text('Consumidor Final'), findsOneWidget);
      expect(find.text('Sin DNI'), findsOneWidget);
      expect(find.text('TOTAL A COBRAR'), findsOneWidget);
      expect(find.text('CANASTA VACÍA'), findsOneWidget);
    });

    testWidgets('Payment method chips have showCheckmark: false and light up representative color', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VentasScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Buscar todos los ChoiceChip de métodos de pago
      final choiceChips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      final paymentChips = choiceChips.where((c) => 
        (c.label as Text).data == 'Efectivo' ||
        (c.label as Text).data == 'Yape' ||
        (c.label as Text).data == 'Plin' ||
        (c.label as Text).data == 'Tarjeta' ||
        (c.label as Text).data == 'Crédito'
      ).toList();

      expect(paymentChips.length, 5);
      for (final chip in paymentChips) {
        expect(chip.showCheckmark, isFalse, reason: 'El chip de pago no debe mostrar sombra circular ni check');
      }

      // Probar seleccionar Yape
      await tester.tap(find.text('Yape'));
      await tester.pumpAndSettle();

      final yapeChip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('Yape'), matching: find.byType(ChoiceChip))
      );
      expect(yapeChip.selected, isTrue);
      expect(yapeChip.showCheckmark, isFalse);
      expect(yapeChip.selectedColor, const Color(0xFF7C3AED));
    });
  });
}
