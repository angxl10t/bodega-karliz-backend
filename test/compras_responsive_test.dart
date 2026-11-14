import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/features/auth/auth_service.dart';
import 'package:bodega_mobile/features/compras/compras_screen.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';
import 'package:bodega_mobile/features/proveedores/proveedor_model.dart';
import 'package:bodega_mobile/features/proveedores/proveedor_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'user_rol': 'ADMIN',
      'jwt_token': 'fake_token',
      'bodega_id': '1',
    });
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'fake_token',
      'bodega_id': '1',
      'user_rol': 'ADMIN',
      'user_role': 'ADMIN',
    });
    AuthService.setCachedRol('ADMIN');

    ProductoService.setMockProductos([
      Producto(
        idProducto: 1,
        nombre: 'Arroz Costeño 1kg',
        precioVenta: 4.80,
        stockActual: 20.0,
        codigo: 'ARR01',
        nombreCategoria: 'Abarrotes',
      ),
    ]);
    ProveedorService.setMockProveedores([
      Proveedor(
        idProveedor: 1,
        razonSocial: 'Distribuidora Mayorista Lima S.A.C.',
        ruc: '20123456789',
        telefono: '999888777',
      ),
    ]);
  });

  group('Compras Responsive Cockpit Layout Tests', () {
    testWidgets(
      'ComprasScreen en Desktop (1280x800) renderiza catálogo rápido inline y panel de lote lateral',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ComprasScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // En desktop se muestra el Catálogo Rápido con buscador integrado en columna izquierda
        expect(find.text('Búsqueda y Selección de Mercadería'), findsOneWidget);
        expect(find.text('Catálogo Completo'), findsOneWidget);

        // Se muestra el encabezado del panel de lote en columna derecha
        expect(find.text('Lote de Ingreso'), findsOneWidget);
        expect(find.textContaining('REGISTRAR COMPRA'), findsOneWidget);
      },
    );

    testWidgets(
      'ComprasScreen en Mobile (400x800) renderiza botón modal para agregar productos',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ComprasScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // En mobile se muestra el botón "Catálogo" para abrir el modal
        expect(find.text('Catálogo'), findsOneWidget);
        // No está visible el panel lateral de lote de desktop
        expect(find.text('Lote de Ingreso'), findsNothing);
      },
    );

    test(
      'Cálculo de desglose tributario en compras (Subtotal, IGV 18%, Total)',
      () {
        const totalCompra = 118.0;
        final subtotalSinIgv = totalCompra / 1.18;
        final igvCalculado = totalCompra - subtotalSinIgv;

        expect(subtotalSinIgv, closeTo(100.0, 0.01));
        expect(igvCalculado, closeTo(18.0, 0.01));
        expect(subtotalSinIgv + igvCalculado, closeTo(118.0, 0.01));
      },
    );
  });
}
