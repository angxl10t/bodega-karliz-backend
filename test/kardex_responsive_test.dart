import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/features/movimientos/kardex_screen.dart';
import 'package:bodega_mobile/features/movimientos/movimiento_model.dart';
import 'package:bodega_mobile/features/movimientos/movimiento_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'fake_token',
      'bodega_id': '1',
      'user_rol': 'ADMIN',
    });

    MovimientoService.setMockMovimientos([
      MovimientoInventario(
        idMovimiento: 101,
        idProducto: 1,
        nombreProducto: 'Arroz Costeño 1kg',
        tipoMovimiento: 'ENTRADA',
        cantidad: 50.0,
        motivo: 'Compra según Factura F001-00248 mayorista',
        fechaMovimiento: DateTime(2026, 11, 13, 18, 42),
        usuarioResponsable: 'Admin Karliz',
      ),
      MovimientoInventario(
        idMovimiento: 102,
        idProducto: 2,
        nombreProducto: 'Aceite Primor Premium 1L',
        tipoMovimiento: 'CAMBIO_PRECIO',
        cantidad: 0.0,
        motivo: 'Cambio de precio de venta: S/ 8.50 -> S/ 9.20 por alza de proveedor',
        fechaMovimiento: DateTime(2026, 11, 13, 17, 15),
        usuarioResponsable: 'Admin Karliz',
      ),
      MovimientoInventario(
        idMovimiento: 103,
        idProducto: 3,
        nombreProducto: 'Inca Kola 1.5L Vidrio Retornable',
        tipoMovimiento: 'SALIDA',
        cantidad: 2.0,
        motivo: 'Venta en caja POS Ticket #TK-00842',
        fechaMovimiento: DateTime(2026, 11, 13, 16, 50),
        usuarioResponsable: 'Cajero Juan',
      ),
    ]);
  });

  tearDown(() {
    MovimientoService.setMockMovimientos(null);
  });

  group('Kardex Responsive Cockpit Layout Tests', () {
    testWidgets(
      'KardexScreen en Desktop (1280x800) renderiza cockpit de 2 columnas, grid de 6 KPIs e inspector lateral',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: KardexScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // En desktop se muestra el grid superior de KPIs con subtítulos ejecutivos
        expect(find.text('Entradas'), findsAtLeastNWidgets(1));
        expect(find.text('Compras de stock'), findsOneWidget);
        expect(find.text('Salidas'), findsAtLeastNWidgets(1));
        expect(find.text('Ventas en caja POS'), findsOneWidget);

        // Se muestra la cabecera fija de la tabla contable
        expect(find.text('PRODUCTO & MOTIVO SUSTENTATORIO'), findsOneWidget);
        expect(find.text('INSIGNIA'), findsOneWidget);

        // Se muestra el inspector lateral de auditoría
        expect(find.text('Ficha de Auditoría'), findsOneWidget);
        expect(find.text('#MOV-101'), findsAtLeastNWidgets(1));
        expect(find.text('Control de Fugas & Mermas'), findsOneWidget);
      },
    );

    testWidgets(
      'KardexScreen en Mobile (400x800) renderiza vista vertical con banner didáctico',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: KardexScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // En mobile se muestra el Banner Didáctico
        expect(find.text('Auditoría Integral de Kardex'), findsOneWidget);

        // NO se muestra la Ficha de Auditoría de la columna lateral de desktop
        expect(find.text('Ficha de Auditoría'), findsNothing);
        expect(find.text('PRODUCTO & MOTIVO SUSTENTATORIO'), findsNothing);
      },
    );
  });
}
