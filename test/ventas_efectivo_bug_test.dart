import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/features/ventas/ventas_screen.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';
import 'package:bodega_mobile/core/widgets/thermal_ticket_preview_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProductoService.setMockProductos([
      Producto(
        idProducto: 1,
        nombre: 'Galleta Oreo 36g',
        precioVenta: 1.50,
        stockActual: 30.0,
        codigo: 'GAL001',
        nombreCategoria: 'Snacks',
      ),
    ]);
  });

  testWidgets('Efectivo payment preserves cart items and ticket preview works', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VentasScreen())),
    );
    await tester.pumpAndSettle();

    // 1. Tap product to add to cart (non-pesable: directly adds 1 unit)
    await tester.tap(find.text('Galleta Oreo 36g').first);
    await tester.pumpAndSettle();

    expect(find.text('1 items seleccionados'), findsOneWidget);
    expect(find.text('Galleta Oreo 36g'), findsWidgets);

    // 2. Tap Yape
    await tester.tap(find.text('Yape'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Items are STILL in cart!
    expect(find.text('1 items seleccionados'), findsOneWidget);
    expect(find.text('Galleta Oreo 36g'), findsWidgets);

    // 3. Tap Efectivo - Cash input appears, suggested bills appear, and cart items ARE NOT DELETED!
    await tester.tap(find.text('Efectivo'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('1 items seleccionados'), findsOneWidget);
    expect(find.text('Galleta Oreo 36g'), findsWidgets);
    expect(find.text('Efectivo recibido'), findsOneWidget);
    expect(find.text('Pago Exacto'), findsOneWidget);

    // 4. Tap Ticket print preview button in POS actions
    final printButton = find.byTooltip('Imprimir Ticket Térmico (58 / 80 mm)');
    expect(printButton, findsOneWidget);
    await tester.tap(printButton);
    await tester.pumpAndSettle();

    // Verify modern realistic thermal ticket dialog is shown
    expect(find.byType(ThermalTicketPreviewDialog), findsOneWidget);
    expect(find.text('Ticket Térmico POS'), findsOneWidget);
    expect(find.text('CAJAYA THERMAL POS'), findsOneWidget);
    expect(find.text('58mm'), findsOneWidget);
    expect(find.text('80mm'), findsOneWidget);
    expect(find.text('Galleta Oreo 36g'), findsWidgets);

    // Close preview dialog
    final closeBtn = find.byKey(const ValueKey('thermal_dialog_close_btn'));
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    expect(find.byType(ThermalTicketPreviewDialog), findsNothing);
  });
}
