import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/features/movimientos/vencimientos_screen.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final now = DateTime.now();

  final mockProductos = [
    Producto(
      idProducto: 1,
      idCategoria: 2,
      nombreCategoria: 'Lácteos',
      codigo: 'YOG-001',
      codigoBarras: '7750106001014',
      nombre: 'Yogur Fresa Gloria 1L',
      precioVenta: 6.80,
      stockActual: 12.0,
      stockMinimo: 5.0,
      controlaVencimiento: true,
      fechaVencimiento: now.subtract(const Duration(days: 2)), // Vencido
      precioCosto: 5.20,
    ),
    Producto(
      idProducto: 2,
      idCategoria: 3,
      nombreCategoria: 'Panadería',
      codigo: 'PAN-002',
      codigoBarras: '7750201002028',
      nombre: 'Pan Bimbo Artesano 550g',
      precioVenta: 7.50,
      stockActual: 8.0,
      stockMinimo: 3.0,
      controlaVencimiento: true,
      fechaVencimiento: now.add(const Duration(days: 4)), // Crítico (1-7 días)
      precioCosto: 5.80,
    ),
    Producto(
      idProducto: 3,
      idCategoria: 4,
      nombreCategoria: 'Embutidos',
      codigo: 'EMB-003',
      codigoBarras: '7750302003032',
      nombre: 'Jamónada San Fernando 250g',
      precioVenta: 5.50,
      stockActual: 15.0,
      stockMinimo: 4.0,
      controlaVencimiento: true,
      fechaVencimiento: now.add(
        const Duration(days: 18),
      ), // Rotación (8-30 días)
      precioCosto: 4.10,
    ),
    Producto(
      idProducto: 4,
      idCategoria: 5,
      nombreCategoria: 'Conservas',
      codigo: 'CON-004',
      codigoBarras: '7750403004046',
      nombre: 'Atún Primor Trozos en Aceite',
      precioVenta: 6.20,
      stockActual: 40.0,
      stockMinimo: 10.0,
      controlaVencimiento: true,
      fechaVencimiento: now.add(
        const Duration(days: 120),
      ), // Vigente (> 30 días)
      precioCosto: 4.80,
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'fake_token',
      'bodega_id': '1',
      'user_rol': 'ADMIN',
    });

    ProductoService.setMockProductos(mockProductos);
  });

  tearDown(() {
    ProductoService.invalidateCache(notify: false);
  });

  group('Vencimientos Responsive Cockpit Layout Tests', () {
    testWidgets(
      'VencimientosScreen en Desktop (1280x800) renderiza cockpit de 2 columnas, grid de 4 KPIs e inspector lateral',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: VencimientosScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Grid superior de 4 KPIs
        expect(find.text('Vencidos (≤ 0d)'), findsOneWidget);
        expect(find.text('Críticos (1-7d)'), findsOneWidget);
        expect(find.text('Rotación (8-30d)'), findsOneWidget);
        expect(find.text('Vigentes (> 30d)'), findsOneWidget);

        // 2. Cabecera fija de la tabla contable FEFO
        expect(find.text('ESTADO FEFO'), findsOneWidget);
        expect(find.text('PRODUCTO & CATEGORÍA'), findsOneWidget);
        expect(find.text('VENCIMIENTO / LOTE'), findsOneWidget);
        expect(find.text('STOCK & VALOR'), findsOneWidget);

        // 3. Productos en la tabla
        expect(find.text('Yogur Fresa Gloria 1L'), findsAtLeastNWidgets(1));
        expect(find.text('Pan Bimbo Artesano 550g'), findsOneWidget);

        // 4. Inspector lateral derecho con expediente financiero y acciones
        expect(find.text('EXPEDIENTE FINANCIERO DEL LOTE'), findsOneWidget);
        expect(find.text('ACCIONES DE GESTIÓN & LIQUIDACIÓN'), findsOneWidget);
        expect(find.text('Actualizar Fecha de Lote'), findsOneWidget);
        expect(find.text('Calcular Remate Preventivo (-25%)'), findsOneWidget);
        expect(find.text('Dar de Baja (Ajuste de Merma)'), findsOneWidget);
        expect(find.text('Imprimir Rótulo de Góndola'), findsOneWidget);
      },
    );

    testWidgets(
      'VencimientosScreen en Mobile (400x800) renderiza vista vertical con scroll horizontal de KPIs y banner didáctico',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: VencimientosScreen())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Vista móvil muestra el banner didáctico FIFO
        expect(find.textContaining('Criterio FIFO Activo'), findsOneWidget);

        // Muestra las tarjetas individuales con botones rápidos
        expect(find.text('Actualizar Lote'), findsAtLeastNWidgets(1));
        expect(find.text('Dar de Baja'), findsAtLeastNWidgets(1));

        // En móvil no debe mostrarse el encabezado de tabla desktop
        expect(find.text('ESTADO FEFO'), findsNothing);
        expect(find.text('EXPEDIENTE FINANCIERO DEL LOTE'), findsNothing);
      },
    );
  });
}
