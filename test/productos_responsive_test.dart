import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bodega_mobile/features/productos/productos_screen.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';
import 'package:bodega_mobile/features/home/bodega_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final mockBodega = BodegaInfo(
    idBodega: 10,
    nombreComercial: 'Bodega San Pedro',
    plan: 'PRO',
    colorPrimario: '#2563EB',
    estado: true,
    regimenTributario: 'RUS',
    esNuevoRus: true,
    facturacionSunatActiva: false,
    catalogoAbierto: true,
  );

  final now = DateTime.now();
  final mockProductos = [
    Producto(
      idProducto: 1,
      codigo: 'BEB-001',
      codigoBarras: '7751234001',
      nombre: 'Inca Kola 500ml',
      marca: 'Coca-Cola',
      nombreCategoria: 'Bebidas',
      precioVenta: 3.50,
      precioCosto: 2.20,
      stockActual: 24.0,
      stockMinimo: 10.0,
    ),
    Producto(
      idProducto: 2,
      codigo: 'ABA-002',
      codigoBarras: '7751234002',
      nombre: 'Arroz Costeño 1kg',
      marca: 'Costeño',
      nombreCategoria: 'Abarrotes',
      precioVenta: 4.80,
      precioCosto: 3.60,
      stockActual: 3.0, // <= 10 * 0.5 (5.0) -> Crítico
      stockMinimo: 10.0,
    ),
    Producto(
      idProducto: 3,
      codigo: 'LAC-003',
      codigoBarras: '7751234003',
      nombre: 'Leche Gloria Azul 400g',
      marca: 'Gloria',
      nombreCategoria: 'Lácteos',
      precioVenta: 4.20,
      precioCosto: 3.10,
      stockActual: 7.0, // > 5.0 and <= 10.0 -> Por Agotar (Bajo)
      stockMinimo: 10.0,
    ),
    Producto(
      idProducto: 4,
      codigo: 'LAC-004',
      codigoBarras: '7751234004',
      nombre: 'Yogurt Fresa 1L',
      marca: 'Gloria',
      nombreCategoria: 'Lácteos',
      precioVenta: 6.50,
      precioCosto: 4.50,
      stockActual: 15.0,
      stockMinimo: 5.0,
      controlaVencimiento: true,
      fechaVencimiento: now.add(
        const Duration(days: 3),
      ), // Vence en 3 días (crítico FIFO)
    ),
  ];

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'fake_jwt_token',
      'user_rol': 'ADMIN',
      'plan_bodega': 'PRO',
      'nombre_bodega': 'Bodega San Pedro',
    });
    SharedPreferences.setMockInitialValues({
      'user_rol': 'ADMIN',
      'plan_bodega': 'PRO',
    });
    ProductoService.setMockProductos(mockProductos);
    BodegaService.setMockMiBodega(mockBodega);
    BodegaService.mockSugerenciasPendientes = 0;
  });

  tearDown(() {
    ProductoService.invalidateCache();
    BodegaService.clearCache();
    BodegaService.mockSugerenciasPendientes = null;
  });

  group('ProductosScreen Responsive & Calma Visual Tests', () {
    testWidgets(
      'Desktop resolution (1280x800) renders cockpit, dual mode, and audited cards without steppers',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ProductosScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Header title and count
        expect(find.text('Stock & Inventario'), findsOneWidget);
        expect(find.text('4 items'), findsOneWidget);

        // Dual mode selector
        expect(find.text('📦 Gestión Stock'), findsOneWidget);
        expect(find.text('🌐 Catálogo Web'), findsOneWidget);

        // Financial Cockpit in Stock Mode
        expect(find.text('CAPITAL INVERTIDO'), findsOneWidget);
        expect(find.text('VENTA PROYECTADA'), findsOneWidget);
        expect(find.text('SALUD DEL INVENTARIO'), findsOneWidget);

        // Verify NO informal + / - stepper buttons exist on the page
        expect(find.widgetWithIcon(IconButton, Icons.add), findsNothing);
        expect(find.widgetWithIcon(IconButton, Icons.remove), findsNothing);

        // Verify Audited "Ajustar" button is present on product cards
        expect(find.text('Ajustar'), findsWidgets);

        // Verify Sort menu button
        expect(find.text('A - Z'), findsOneWidget);

        // Verify Calma Visual filter chips
        expect(find.text('Todos'), findsOneWidget);
        expect(find.text('Por Agotar'), findsOneWidget);
        expect(find.text('Críticos'), findsOneWidget);

        // Switch to Web Catalog mode
        await tester.tap(find.text('🌐 Catálogo Web'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Web Catalog banner should appear
        expect(find.text('Catálogo Digital & WhatsApp Activo'), findsOneWidget);
        expect(find.text('Copiar'), findsOneWidget);
        expect(find.text('QR / Compartir'), findsOneWidget);

        // Product cards show "En Catálogo"
        expect(find.text('En Catálogo'), findsWidgets);
      },
    );

    testWidgets(
      'Mobile resolution (390x844) renders without overflow and modal shows financial audit info',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ProductosScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // No overflow errors should be thrown on mobile
        expect(tester.takeException(), isNull);

        // Check header and dual mode
        expect(find.text('Stock & Inventario'), findsOneWidget);
        expect(find.text('📦 Gestión Stock'), findsOneWidget);

        // Tap on the first product card to open the detail modal
        await tester.tap(find.text('Arroz Costeño 1kg'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Detail modal verifies Calma Visual financial breakdown
        expect(find.text('PRECIO VENTA'), findsOneWidget);
        expect(find.text('COSTO COMPRA'), findsOneWidget);
        expect(find.text('MARGEN BRUTO'), findsOneWidget);
        expect(find.text('Stock Físico:'), findsOneWidget);

        // Verify audited notice is visible in modal
        expect(
          find.textContaining(
            'La recepción de compras se registra mediante Compras',
          ),
          findsOneWidget,
        );

        // Verify modal has AJUSTAR and EDITAR actions, and strictly NO + / - steppers
        expect(find.text('AJUSTAR'), findsOneWidget);
        expect(find.text('EDITAR'), findsOneWidget);
        expect(find.text('LISTO'), findsOneWidget);
        expect(find.widgetWithIcon(IconButton, Icons.add), findsNothing);
        expect(find.widgetWithIcon(IconButton, Icons.remove), findsNothing);

        // Close modal
        await tester.tap(find.text('LISTO'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Filter and Sort logic works correctly in ProductosScreen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProductosScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on "Críticos" filter
      await tester.tap(find.text('Críticos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Only Arroz Costeño (stock 3 <= 5) should appear
      expect(find.text('Arroz Costeño 1kg'), findsOneWidget);
      expect(find.text('Inca Kola 500ml'), findsNothing);

      // Tap on "Todos" to reset
      await tester.tap(find.text('Todos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Inca Kola 500ml'), findsOneWidget);
      expect(find.text('Arroz Costeño 1kg'), findsOneWidget);
    });
  });
}
