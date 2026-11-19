import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bodega_mobile/core/theme.dart';
import 'package:bodega_mobile/core/theme_provider.dart';
import 'package:bodega_mobile/features/categorias/categoria_model.dart';
import 'package:bodega_mobile/features/categorias/categoria_service.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/productos/producto_service.dart';
import 'package:bodega_mobile/features/promociones/crear_promocion_sheet.dart';
import 'package:bodega_mobile/features/promociones/promocion_model.dart';
import 'package:bodega_mobile/features/promociones/promocion_service.dart';
import 'package:bodega_mobile/features/promociones/promociones_screen.dart';

Widget _createPromocionesScreen({
  bool isPro = true,
  String nombreBodega = 'Bodega Karliz',
  int initialTab = 0,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.buildLightTheme(),
      home: PromocionesScreen(
        isPro: isPro,
        nombreBodega: nombreBodega,
        initialTab: initialTab,
      ),
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'fake_token',
      'user_rol': 'ADMIN',
      'id_bodega': '1',
      'plan_bodega': 'PRO',
    });
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'fake_token',
      'user_rol': 'ADMIN',
      'id_bodega': '1',
      'plan_bodega': 'PRO',
    });

    CategoriaService.setMockCategorias([
      Categoria(idCategoria: 1, nombre: 'Abarrotes'),
      Categoria(idCategoria: 2, nombre: 'Bebidas'),
      Categoria(idCategoria: 3, nombre: 'Snacks'),
    ]);

    ProductoService.setMockProductos([
      Producto(
        idProducto: 101,
        codigo: 'PROD-101',
        nombre: 'Atún Campomar 170g',
        precioVenta: 5.50,
        precioCosto: 3.80,
        stockActual: 24,
        nombreCategoria: 'Abarrotes',
      ),
      Producto(
        idProducto: 102,
        codigo: 'PROD-102',
        nombre: 'Fideos Molitalia Spaghetti 500g',
        precioVenta: 3.60,
        precioCosto: 2.60,
        stockActual: 48,
        nombreCategoria: 'Abarrotes',
      ),
      Producto(
        idProducto: 103,
        codigo: 'PROD-103',
        nombre: 'Galleta Pícaras Chocolate',
        precioVenta: 2.50,
        precioCosto: 1.80,
        stockActual: 36,
        nombreCategoria: 'Snacks',
      ),
      Producto(
        idProducto: 104,
        codigo: 'PROD-104',
        nombre: 'Leche Ideal Cremosa 395g',
        precioVenta: 3.90,
        precioCosto: 3.10,
        stockActual: 50,
        nombreCategoria: 'Lácteos',
      ),
    ]);

    PromocionService.setMockData(
      promociones: [
        const Promocion(
          idPromocion: 1,
          idBodega: 1,
          titulo: 'Combo Almuerzo Bodeguero',
          descripcion: 'Atún Campomar + Fideos Molitalia',
          tipoPromocion: 'COMBO_HUESO',
          alcance: 'COMBO',
          valorDescuento: 14.0,
          idProductoPrincipal: 101,
          nombreProductoPrincipal: 'Atún Campomar 170g',
          idProductoSecundario: 102,
          nombreProductoSecundario: 'Fideos Molitalia Spaghetti 500g',
          precioCombo: 7.80,
          badgeTexto: '⭐ COMBO DÚO',
          colorBadge: '#2563EB',
          activo: true,
          esSugerenciaHueso: true,
        ),
        const Promocion(
          idPromocion: 2,
          idBodega: 1,
          titulo: '2x1 Inka Chips Fin de Semana',
          descripcion: 'Paga 1 y lleva 2',
          tipoPromocion: 'DOS_POR_UNO',
          alcance: 'PRODUCTO',
          valorDescuento: 50.0,
          idProductoPrincipal: 103,
          nombreProductoPrincipal: 'Inka Chips Sal Marina 142g',
          badgeTexto: '🔥 2x1',
          colorBadge: '#F59E0B',
          activo: true,
        ),
        const Promocion(
          idPromocion: 3,
          idBodega: 1,
          titulo: '15% OFF en Gaseosas',
          descripcion: 'Descuento directo en gaseosas',
          tipoPromocion: 'PORCENTAJE',
          alcance: 'CATEGORIA',
          valorDescuento: 15.0,
          categoriaObjetivo: 'Bebidas',
          badgeTexto: '⚡ 15% OFF',
          colorBadge: '#10B981',
          activo: false,
        ),
      ],
      sugerencias: [
        const SugerenciaComboHueso(
          idProductoHueso: 103,
          nombreHueso: 'Galleta Pícaras Chocolate',
          categoriaHueso: 'Snacks',
          stockHueso: 36,
          costoHueso: 1.80,
          precioRegularHueso: 2.50,
          capitalInmovilizado: 64.80,
          idProductoEstrella: 104,
          nombreEstrella: 'Leche Ideal Cremosa 395g',
          categoriaEstrella: 'Lácteos',
          precioRegularEstrella: 3.90,
          tituloSugerido: 'Combo Desayuno Dulce',
          descripcionSugerida: 'Pícaras + Leche Ideal a precio especial',
          precioRegularTotal: 6.40,
          precioComboSugerido: 5.30,
          ahorroCliente: 1.10,
          porcentajeDescuentoSugerido: 17.2,
          razonEstrategica: '36 paquetes sin rotar hace 44 días. Emparejar con leche matutina.',
          badgeSugerido: '⭐ COMBO DESAYUNO',
        ),
      ],
    );
  });

  tearDown(() {
    PromocionService.setMockData(promociones: null, sugerencias: null);
  });

  testWidgets(
    '1. PromocionesScreen renders Cockpit KPIs, tabs and active promos',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_createPromocionesScreen());
      await tester.pumpAndSettle();

      expect(find.text('Promociones y Descuentos'), findsOneWidget);
      expect(find.text('PRO'), findsWidgets);

      // Verify Cockpit KPI titles
      expect(find.text('Promociones Activas'), findsOneWidget);
      expect(find.text('Capital en Huesos Detectado'), findsOneWidget);
      expect(find.text('Ahorro Promedio Ofrecido'), findsOneWidget);
      expect(find.text('Impacto en Rotación'), findsOneWidget);

      // Verify Promotions rendered
      expect(find.text('Combo Almuerzo Bodeguero'), findsOneWidget);
      expect(find.text('2x1 Inka Chips Fin de Semana'), findsOneWidget);
    },
  );

  testWidgets('2. Filter pills filter promotions by type and status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_createPromocionesScreen());
    await tester.pumpAndSettle();

    // Initially "Todas (3)" is active
    expect(find.text('Combo Almuerzo Bodeguero'), findsOneWidget);
    expect(find.text('2x1 Inka Chips Fin de Semana'), findsOneWidget);

    // Tap "Combos Dúo" filter pill
    final combosPill = find.text('Combos Dúo (1)');
    expect(combosPill, findsOneWidget);
    await tester.tap(combosPill);
    await tester.pumpAndSettle();

    expect(find.text('Combo Almuerzo Bodeguero'), findsOneWidget);
    expect(find.text('2x1 Inka Chips Fin de Semana'), findsNothing);

    // Tap "Pausadas" filter pill
    final pausadasPill = find.text('Pausadas (1)');
    expect(pausadasPill, findsOneWidget);
    await tester.ensureVisible(pausadasPill);
    await tester.tap(pausadasPill);
    await tester.pumpAndSettle();

    expect(find.text('15% OFF en Gaseosas'), findsOneWidget);
    expect(find.text('Combo Almuerzo Bodeguero'), findsNothing);
  });

  testWidgets('3. Switch toggle pauses/activates promotion with snackbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_createPromocionesScreen());
    await tester.pumpAndSettle();

    final switches = find.byType(Switch);
    expect(switches, findsWidgets);

    // Tap the first switch (active -> paused)
    await tester.tap(switches.first);
    await tester.pumpAndSettle();

    // Verify snackbar feedback
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('pausada'), findsOneWidget);
  });

  testWidgets(
    '4. Tab Combos Hueso displays AI suggestions and 1-tap activation modal',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Open screen with initialTab = 1 (Combos Hueso)
      await tester.pumpWidget(_createPromocionesScreen(initialTab: 1));
      await tester.pumpAndSettle();

      // Verify AI banner and card
      expect(
        find.text('Descongelamiento Táctico de Mercadería'),
        findsOneWidget,
      );
      expect(find.text('HUESO (36 u.)'), findsOneWidget);
      expect(find.text('LÍDER DE VENTA'), findsOneWidget);
      expect(find.text('Leche Ideal Cremosa 395g'), findsOneWidget);
      expect(find.text('S/ 64.80 inmovilizados'), findsOneWidget);

      // Verify 1-Tap Activation button
      final btnActivar = find.text('Activar Combo en 1 Clic');
      expect(btnActivar, findsOneWidget);
      await tester.tap(btnActivar);
      await tester.pumpAndSettle();

      // Should open CrearPromocionSheet prefilled
      expect(find.byType(CrearPromocionSheet), findsOneWidget);
      expect(find.text('Crear Combo Antiestancamiento'), findsOneWidget);
    },
  );

  testWidgets('5. Wide Desktop/Tablet displays 2-column cockpit layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_createPromocionesScreen());
    await tester.pumpAndSettle();

    // On wide screen, both columns are simultaneously rendered
    expect(find.text('Ofertas y Descuentos en Vigencia'), findsOneWidget);
    expect(find.text('Motor Inteligente "Combos Hueso"'), findsOneWidget);
    expect(find.text('Combo Almuerzo Bodeguero'), findsOneWidget);
    expect(find.text('HUESO (36 u.)'), findsOneWidget);
    expect(find.text('Activar Combo en 1 Clic'), findsOneWidget);
  });

  testWidgets('6. Non-Pro users see Pro upgrade block modal', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_createPromocionesScreen(isPro: false));
    await tester.pumpAndSettle();

    expect(find.text('Módulo Exclusivo Plan Minimarket PRO'), findsOneWidget);
    expect(find.text('Mejorar a Plan PRO (S/ 79 /mes)'), findsOneWidget);
  });
}
