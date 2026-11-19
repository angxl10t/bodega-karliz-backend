import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bodega_mobile/features/promociones/promocion_model.dart';
import 'package:bodega_mobile/features/promociones/promocion_service.dart';
import 'package:bodega_mobile/features/promociones/promociones_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    PromocionService.setMockData(promociones: null, sugerencias: null);
  });

  test(
    'SugerenciaComboHueso deserializa nuevos campos de sección y afinidad',
    () {
      final json = {
        'idProductoHueso': 101,
        'nombreHueso': 'Tortees Sal Picante 150g',
        'categoriaHueso': 'Snacks',
        'stockHueso': 20.0,
        'costoHueso': 2.50,
        'precioRegularHueso': 3.50,
        'capitalInmovilizado': 50.00,
        'idProductoEstrella': 202,
        'nombreEstrella': 'Gaseosa Inka Kola 500ml',
        'categoriaEstrella': 'Bebidas',
        'precioRegularEstrella': 3.00,
        'tituloSugerido': 'Combo Tractor: Gaseosa Inka Kola + Tortees',
        'descripcionSugerida': 'Lleva ambos con descuento especial',
        'precioRegularTotal': 6.50,
        'precioComboSugerido': 5.60,
        'ahorroCliente': 0.90,
        'porcentajeDescuentoSugerido': 14.0,
        'razonEstrategica': 'Libera capital inmovilizado',
        'badgeSugerido': '🚀 TRACTOR AFÍN -14%',
        'seccionSugerencia': 'HUESO_ESTRELLA',
        'tipoAfinidad': '🍿 SNACK & GASEOSA',
        'impactoMargen': 'Margen estrella 100% protegido.',
      };

      final sug = SugerenciaComboHueso.fromJson(json);

      expect(sug.seccionSugerencia, 'HUESO_ESTRELLA');
      expect(sug.tipoAfinidad, '🍿 SNACK & GASEOSA');
      expect(sug.impactoMargen, contains('Margen estrella 100% protegido'));
    },
  );

  testWidgets(
    'PromocionesScreen muestra las secciones de sugerencias y filtra adecuadamente',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sugerencias = [
        const SugerenciaComboHueso(
          idProductoHueso: 101,
          nombreHueso: 'Tortees Sal Picante',
          categoriaHueso: 'Snacks',
          stockHueso: 15,
          costoHueso: 2.50,
          precioRegularHueso: 3.50,
          capitalInmovilizado: 37.50,
          idProductoEstrella: 202,
          nombreEstrella: 'Inka Kola 500ml',
          categoriaEstrella: 'Bebidas',
          precioRegularEstrella: 3.00,
          tituloSugerido: 'Combo Tractor: Inka Kola + Tortees',
          descripcionSugerida: 'Snack y gaseosa con descuento',
          precioRegularTotal: 6.50,
          precioComboSugerido: 5.60,
          ahorroCliente: 0.90,
          porcentajeDescuentoSugerido: 14.0,
          razonEstrategica: 'Libera capital estancado en Tortees',
          badgeSugerido: '🚀 TRACTOR AFÍN -14%',
          seccionSugerencia: 'HUESO_ESTRELLA',
          tipoAfinidad: '🍿 SNACK & GASEOSA',
          impactoMargen: 'Margen estrella 100% protegido.',
        ),
        const SugerenciaComboHueso(
          idProductoHueso: 301,
          nombreHueso: 'Piqueo Snax Familiar',
          categoriaHueso: 'Snacks',
          stockHueso: 40,
          costoHueso: 4.50,
          precioRegularHueso: 6.00,
          capitalInmovilizado: 0.0,
          idProductoEstrella: 401,
          nombreEstrella: 'Cerveza Pilsen 630ml',
          categoriaEstrella: 'Licores',
          precioRegularEstrella: 7.00,
          tituloSugerido: 'Dúo Ocasión: Pilsen + Piqueo',
          descripcionSugerida: 'La mejor ocasión de consumo',
          precioRegularTotal: 13.00,
          precioComboSugerido: 12.10,
          ahorroCliente: 0.90,
          porcentajeDescuentoSugerido: 7.0,
          razonEstrategica: 'Incrementa el ticket promedio',
          badgeSugerido: '⭐ DUO ESTRELLA -7%',
          seccionSugerencia: 'ALTA_ROTACION',
          tipoAfinidad: '🍻 PIQUEO & BRINDIS',
          impactoMargen: 'Descuento ligero (7%) para cuidar margen.',
        ),
        const SugerenciaComboHueso(
          idProductoHueso: 501,
          nombreHueso: 'Fideos Spaghetti 500g',
          categoriaHueso: 'Abarrotes',
          stockHueso: 25,
          costoHueso: 1.80,
          precioRegularHueso: 2.60,
          capitalInmovilizado: 45.0,
          idProductoEstrella: 502,
          nombreEstrella: 'Salsa Pomarola 150g',
          categoriaEstrella: 'Abarrotes',
          precioRegularEstrella: 2.20,
          tituloSugerido: 'Pack Liquidación: Fideos + Salsa',
          descripcionSugerida: 'Pack de liquidación',
          precioRegularTotal: 4.80,
          precioComboSugerido: 3.80,
          ahorroCliente: 1.00,
          porcentajeDescuentoSugerido: 20.0,
          razonEstrategica: 'Liquidación en pack',
          badgeSugerido: '🏷️ PACK CLEARANCE -20%',
          seccionSugerencia: 'LIQUIDACION_PAREJA',
          tipoAfinidad: '🥫 ALMUERZO BODEGUERO',
          impactoMargen: 'Liquidación de 2 dormidos sin afectar estrellas.',
        ),
      ];

      PromocionService.setMockData(promociones: [], sugerencias: sugerencias);

      await tester.pumpWidget(
        const MaterialApp(
          home: PromocionesScreen(
            isPro: true,
            initialTab: 1,
            nombreBodega: 'Bodega KARLIZ',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar pills de secciones
      expect(find.text('✨ Todos (3)'), findsOneWidget);
      expect(find.text('🚀 Tractor Afín (1)'), findsOneWidget);
      expect(find.text('⭐ Dúo Alta Salida (1)'), findsOneWidget);
      expect(find.text('🏷️ Pack Liquidación (1)'), findsOneWidget);

      // En vista inicial ("✨ Todos"), se ven los 3 combos
      expect(find.text('🍿 SNACK & GASEOSA'), findsOneWidget);
      expect(find.text('🍻 PIQUEO & BRINDIS'), findsOneWidget);
      expect(find.text('🥫 ALMUERZO BODEGUERO'), findsOneWidget);

      // Filtrar por "⭐ Dúo Alta Salida (1)"
      final pillAltaSalida = find.text('⭐ Dúo Alta Salida (1)');
      await tester.ensureVisible(pillAltaSalida);
      await tester.tap(pillAltaSalida);
      await tester.pumpAndSettle();

      // Solo debe verse el combo de cerveza + piqueo
      expect(find.text('🍻 PIQUEO & BRINDIS'), findsOneWidget);
      expect(find.text('🍿 SNACK & GASEOSA'), findsNothing);
      expect(find.text('🥫 ALMUERZO BODEGUERO'), findsNothing);

      // Filtrar por "🚀 Tractor Afín (1)"
      final pillTractor = find.text('🚀 Tractor Afín (1)');
      await tester.ensureVisible(pillTractor);
      await tester.tap(pillTractor);
      await tester.pumpAndSettle();

      // Debe mostrar el combo tractor y el banner de protección de margen
      expect(find.text('🍿 SNACK & GASEOSA'), findsOneWidget);
      expect(find.text('Margen estrella 100% protegido.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
    },
  );
}
