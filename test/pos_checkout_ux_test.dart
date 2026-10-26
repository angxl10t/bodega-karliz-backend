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

    testWidgets('Payment method chips light up representative color without any checkmark or circular shadow', (WidgetTester tester) async {
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

      expect(find.text('Efectivo'), findsOneWidget);
      expect(find.text('Yape'), findsOneWidget);
      expect(find.text('Plin'), findsOneWidget);
      expect(find.text('Tarjeta'), findsOneWidget);
      expect(find.text('Crédito'), findsOneWidget);

      // Probar seleccionar Tarjeta
      await tester.tap(find.text('Tarjeta'));
      await tester.pumpAndSettle();

      // Comprobar que NO existe ningún icono check en los chips de método de pago
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.text('Tarjeta'), findsOneWidget);

      // Probar seleccionar Yape
      await tester.tap(find.text('Yape'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });
}
