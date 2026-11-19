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
import 'package:bodega_mobile/features/compras/compra_model.dart';
import 'package:bodega_mobile/features/compras/compra_service.dart';
import 'package:bodega_mobile/core/widgets/product_image_widget.dart';

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
        precioCosto: 3.50,
        stockActual: 2.0, // menor al stock mínimo -> activa reposición
        stockMinimo: 5.0,
        codigo: 'ARR01',
        codigoBarras: '7750243000123',
        nombreCategoria: 'Abarrotes',
        imagenUrl:
            'https://cajaya-pos.onrender.com/packshots/arroz_costeno.png',
      ),
      Producto(
        idProducto: 2,
        nombre: 'Inca Kola 1.5L',
        precioVenta: 7.50,
        precioCosto: 5.50,
        stockActual: 15.0,
        stockMinimo: 6.0,
        codigo: 'BEB01',
        codigoBarras: '7750106001234',
        nombreCategoria: 'Bebidas',
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

    CompraService.setMockCompras([
      CompraRegistro(
        idCompra: 101,
        idProveedor: 1,
        razonSocialProveedor: 'Distribuidora Mayorista Lima S.A.C.',
        comprobante: 'F001-000452',
        total: 236.0,
        fechaCompra: DateTime(2026, 11, 19, 10, 30),
        detalles: [
          CompraDetalleItem(
            idDetalleCompra: 1,
            idProducto: 1,
            nombreProducto: 'Arroz Costeño 1kg',
            cantidad: 50.0,
            precioUnitario: 3.50,
            subtotal: 175.0,
          ),
        ],
      ),
    ]);
  });

  group('Compras & Abastecimiento Calma Visual Enhancements', () {
    testWidgets(
      'Renderiza TabBar cápsula con etiquetas y selector interactivo',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E3A8A),
              ),
            ),
            home: const Scaffold(body: ComprasScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Nueva Compra en Lote'), findsOneWidget);
        expect(find.text('Historial de Compras'), findsOneWidget);
      },
    );

    testWidgets(
      'Muestra banner de reposición inteligente cuando hay stock crítico',
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

        expect(find.textContaining('requiere reposición'), findsOneWidget);
        expect(find.text('Sugerir'), findsOneWidget);
      },
    );

    testWidgets(
      'Catálogo rápido renderiza ProductImageWidget para productos peruanos',
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

        expect(find.byType(ProductImageWidget), findsWidgets);
        expect(find.text('Arroz Costeño 1kg'), findsWidgets);
      },
    );

    testWidgets(
      'Pestaña Historial de Compras muestra KPIs ejecutivos y badge de Factura',
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

        // Cambiar a la pestaña de Historial de Compras
        await tester.tap(find.text('Historial de Compras'));
        await tester.pumpAndSettle();

        // Verificar KPIs ejecutivos
        expect(find.text('Compras Totales'), findsOneWidget);
        expect(find.text('Inversión Total'), findsOneWidget);
        expect(find.text('Facturas SUNAT'), findsOneWidget);

        // Verificar badge de tipo de comprobante
        expect(find.text('FACTURA'), findsOneWidget);
        expect(find.textContaining('F001-000452'), findsOneWidget);
      },
    );
  });
}
