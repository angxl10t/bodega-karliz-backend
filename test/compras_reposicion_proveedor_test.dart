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
        nombre: 'Inca Kola 500ml',
        precioVenta: 3.50,
        stockActual: 4.0,
        stockMinimo: 10.0,
        codigo: 'INK01',
        idProveedor: 10,
        nombreProveedor: 'Arca Continental Lindley S.A.',
      ),
      Producto(
        idProducto: 2,
        nombre: 'Coca Cola 500ml',
        precioVenta: 3.50,
        stockActual: 15.0,
        stockMinimo: 10.0,
        codigo: 'COC01',
        idProveedor: 10,
        nombreProveedor: 'Arca Continental Lindley S.A.',
      ),
      Producto(
        idProducto: 3,
        nombre: 'Leche Gloria Azul 400g',
        precioVenta: 4.20,
        stockActual: 2.0,
        stockMinimo: 12.0,
        codigo: 'GLO01',
        idProveedor: 20,
        nombreProveedor: 'Leche Gloria S.A.',
      ),
    ]);

    ProveedorService.setMockProveedores([
      Proveedor(
        idProveedor: 10,
        razonSocial: 'Arca Continental Lindley S.A.',
        ruc: '20100010724',
        telefono: '987654321',
      ),
      Proveedor(
        idProveedor: 20,
        razonSocial: 'Leche Gloria S.A.',
        ruc: '20100190797',
        telefono: '912345678',
      ),
    ]);
  });

  group('Compras - Reposición y Filtrado por Proveedor', () {
    testWidgets(
      'Muestra datos de proveedor seleccionado, badge de productos y chips de catálogo',
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

        // Proveedor seleccionado automáticamente
        expect(find.text('Proveedor / Distribuidor'), findsOneWidget);
        expect(find.text('Arca Continental Lindley S.A.'), findsWidgets);

        // Badges en la tarjeta de proveedor
        expect(find.text('2 productos en catálogo'), findsOneWidget);
        expect(find.text('1 por reponer'), findsOneWidget);

        // Botón de Pedir Reposición en tarjeta de proveedor
        expect(find.text('Pedir Reposición'), findsOneWidget);

        // Chips de catálogo rápido
        expect(find.textContaining('Por Reponer'), findsWidgets);
        expect(find.textContaining('Todo el Catálogo'), findsWidgets);
      },
    );

    testWidgets(
      'Muestra estado vacío amigable cuando no hay proveedores registrados',
      (tester) async {
        ProveedorService.setMockProveedores([]);

        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ComprasScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Ningún distribuidor seleccionado'), findsOneWidget);
      },
    );

    testWidgets(
      'Botón Pedir Reposición abre modal con sugerencia y selector de proveedor',
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

        // Tocar el botón Pedir Reposición en la tarjeta del proveedor
        final pedirBtn = find.text('Pedir Reposición');
        expect(pedirBtn, findsOneWidget);
        await tester.tap(pedirBtn);
        await tester.pumpAndSettle();

        // Debe abrir el modal con el título de sugerencia de reposición
        expect(find.text('Sugerencia de Reposición'), findsOneWidget);
        expect(find.textContaining('Arca Continental Lindley S.A.'), findsWidgets);
        expect(find.textContaining('1 por reponer'), findsWidgets);
        expect(find.text('Cargar Todo'), findsOneWidget);
      },
    );
  });
}
