import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/promociones/promocion_model.dart';
import 'package:bodega_mobile/features/promociones/promociones_screen.dart';

void main() {
  group('Promocion & SugerenciaComboHueso Model Tests', () {
    test('Promocion deserializes from JSON correctly', () {
      final json = {
        'idPromocion': 12,
        'idBodega': 3,
        'titulo': '¡15% en Todas las Bebidas!',
        'descripcion': 'Aprovecha el descuento exclusivo en catálogo online.',
        'tipoPromocion': 'PORCENTAJE',
        'alcance': 'CATEGORIA',
        'valorDescuento': 15.0,
        'categoriaObjetivo': 'Bebidas',
        'badgeTexto': '🔥 -15%',
        'colorBadge': '#EF4444',
        'activo': true,
        'esSugerenciaHueso': false,
      };

      final promo = Promocion.fromJson(json);

      expect(promo.idPromocion, 12);
      expect(promo.idBodega, 3);
      expect(promo.titulo, '¡15% en Todas las Bebidas!');
      expect(promo.tipoPromocion, 'PORCENTAJE');
      expect(promo.alcance, 'CATEGORIA');
      expect(promo.valorDescuento, 15.0);
      expect(promo.categoriaObjetivo, 'Bebidas');
      expect(promo.badgeTexto, '🔥 -15%');
      expect(promo.colorBadge, '#EF4444');
      expect(promo.activo, isTrue);
      expect(promo.esSugerenciaHueso, isFalse);

      final map = promo.toJson();
      expect(map['idPromocion'], 12);
      expect(map['tipoPromocion'], 'PORCENTAJE');
    });

    test('SugerenciaComboHueso deserializes financial & strategic combo metrics', () {
      final json = {
        'idProductoHueso': 45,
        'nombreHueso': 'Galletas Chocochips 6pk',
        'categoriaHueso': 'Golosinas',
        'imagenUrlHueso': 'https://cajaya-pos.onrender.com/packshots/chocochips.png',
        'stockHueso': 18.0,
        'costoHueso': 2.80,
        'precioRegularHueso': 4.50,
        'capitalInmovilizado': 50.40,
        'idProductoEstrella': 88,
        'nombreEstrella': 'Inca Kola 500ml',
        'categoriaEstrella': 'Bebidas',
        'imagenUrlEstrella': 'https://cajaya-pos.onrender.com/packshots/inca_kola.png',
        'precioRegularEstrella': 3.50,
        'tituloSugerido': 'Combo Dúo: Chocochips + Inca Kola',
        'descripcionSugerida': 'Lleva ambos con 15% de descuento.',
        'precioRegularTotal': 8.00,
        'precioComboSugerido': 6.80,
        'ahorroCliente': 1.20,
        'porcentajeDescuentoSugerido': 15.0,
        'razonEstrategica': 'Libera S/ 50.40 inmovilizados combinando este producto con tu gaseosa estrella.',
        'badgeSugerido': '⭐ COMBO -15%',
      };

      final sug = SugerenciaComboHueso.fromJson(json);

      expect(sug.idProductoHueso, 45);
      expect(sug.nombreHueso, 'Galletas Chocochips 6pk');
      expect(sug.capitalInmovilizado, 50.40);
      expect(sug.idProductoEstrella, 88);
      expect(sug.precioRegularTotal, 8.00);
      expect(sug.precioComboSugerido, 6.80);
      expect(sug.ahorroCliente, 1.20);
      expect(sug.porcentajeDescuentoSugerido, 15.0);
      expect(sug.badgeSugerido, '⭐ COMBO -15%');
      expect(sug.razonEstrategica, contains('Libera S/ 50.40'));
    });
  });

  group('PromocionesScreen UI & Security Tests', () {
    testWidgets('PromocionesScreen renders lock screen when isPro is false', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      await tester.pumpWidget(
        const MaterialApp(
          home: PromocionesScreen(
            isPro: false,
            nombreBodega: 'Bodega Don Pepe',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Módulo Exclusivo Plan Minimarket PRO'), findsOneWidget);
      expect(find.text('Mejorar a Plan PRO (S/ 100 /mes)'), findsOneWidget);
      expect(find.textContaining('descuentos estratégicos por marcas'), findsOneWidget);
    });

    testWidgets('PromocionesScreen renders navigation tabs and action buttons when isPro is true', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      await tester.pumpWidget(
        const MaterialApp(
          home: PromocionesScreen(
            isPro: true,
            nombreBodega: 'Bodega KARLIZ',
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Promociones y Descuentos'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('Bodega KARLIZ'), findsOneWidget);
      expect(find.text('NUEVA'), findsOneWidget);
      expect(find.textContaining('Promociones ('), findsOneWidget);
      expect(find.textContaining('Combos Huesos ('), findsOneWidget);
    });
  });
}
