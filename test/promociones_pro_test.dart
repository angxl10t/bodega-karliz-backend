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

    test(
      'Promocion with scheduled dates serializes and deserializes correctly',
      () {
        final json = {
          'idPromocion': 25,
          'idBodega': 3,
          'titulo': 'Semana Coca-Cola 20% OFF',
          'descripcion': 'Promoción programada de bebidas de marca Coca-Cola',
          'tipoPromocion': 'PORCENTAJE',
          'alcance': 'MARCA',
          'valorDescuento': 20.0,
          'marcaObjetivo': 'Coca Cola',
          'badgeTexto': '🔥 -20%',
          'colorBadge': '#EF4444',
          'fechaInicio': '2026-11-05',
          'fechaFin': '2026-11-12',
          'activo': true,
        };

        final promo = Promocion.fromJson(json);

        expect(promo.fechaInicio, '2026-11-05');
        expect(promo.fechaFin, '2026-11-12');
        expect(promo.marcaObjetivo, 'Coca Cola');

        final map = promo.toJson();
        expect(map['fechaInicio'], '2026-11-05');
        expect(map['fechaFin'], '2026-11-12');
      },
    );

    test(
      'Promocion 3x2 (TRES_POR_DOS) serializes and deserializes correctly',
      () {
        final json = {
          'idPromocion': 33,
          'idBodega': 3,
          'titulo': '¡Lleva 3 Paga 2 en Galletas Casino!',
          'descripcion': 'Por la compra de 3 paquetes pagas solo 2',
          'tipoPromocion': 'TRES_POR_DOS',
          'alcance': 'PRODUCTO',
          'idProductoPrincipal': 105,
          'nombreProductoPrincipal': 'Galleta Casino Chocolate',
          'badgeTexto': '🎁 3x2',
          'colorBadge': '#2563EB',
          'activo': true,
        };

        final promo = Promocion.fromJson(json);

        expect(promo.idPromocion, 33);
        expect(promo.tipoPromocion, 'TRES_POR_DOS');
        expect(promo.idProductoPrincipal, 105);
        expect(promo.nombreProductoPrincipal, 'Galleta Casino Chocolate');
        expect(promo.badgeTexto, '🎁 3x2');
        expect(promo.activo, isTrue);

        final map = promo.toJson();
        expect(map['idPromocion'], 33);
        expect(map['tipoPromocion'], 'TRES_POR_DOS');
        expect(map['badgeTexto'], '🎁 3x2');
      },
    );

    test('Promocion 3x2 calculation logic produces exact trios discount', () {
      const double precioUnitario = 4.50;

      double calcularDescuento3x2(int cantidad) {
        if (cantidad < 3) return 0.0;
        final trios = cantidad ~/ 3;
        return trios * precioUnitario;
      }

      // 1 or 2 units -> no discount
      expect(calcularDescuento3x2(1), 0.0);
      expect(calcularDescuento3x2(2), 0.0);

      // 3 units -> 1 unit free (S/ 4.50 discount, customer pays S/ 9.00 instead of S/ 13.50)
      expect(calcularDescuento3x2(3), 4.50);

      // 4 units -> 1 unit free (S/ 4.50 discount, customer pays S/ 13.50)
      expect(calcularDescuento3x2(4), 4.50);

      // 5 units -> 1 unit free (S/ 4.50 discount)
      expect(calcularDescuento3x2(5), 4.50);

      // 6 units -> 2 units free (S/ 9.00 discount, customer pays S/ 18.00 instead of S/ 27.00)
      expect(calcularDescuento3x2(6), 9.00);

      // 7 units -> 2 units free (S/ 9.00 discount)
      expect(calcularDescuento3x2(7), 9.00);

      // 9 units -> 3 units free (S/ 13.50 discount)
      expect(calcularDescuento3x2(9), 13.50);
    });

    test(
      'SugerenciaComboHueso deserializes financial & strategic combo metrics',
      () {
        final json = {
          'idProductoHueso': 45,
          'nombreHueso': 'Galletas Chocochips 6pk',
          'categoriaHueso': 'Golosinas',
          'imagenUrlHueso':
              'https://cajaya-pos.onrender.com/packshots/chocochips.png',
          'stockHueso': 18.0,
          'costoHueso': 2.80,
          'precioRegularHueso': 4.50,
          'capitalInmovilizado': 50.40,
          'idProductoEstrella': 88,
          'nombreEstrella': 'Inca Kola 500ml',
          'categoriaEstrella': 'Bebidas',
          'imagenUrlEstrella':
              'https://cajaya-pos.onrender.com/packshots/inca_kola.png',
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
      },
    );
  });

  group('PromocionesScreen UI & Security Tests', () {
    testWidgets('PromocionesScreen renders lock screen when isPro is false', (
      tester,
    ) async {
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
      expect(
        find.textContaining('descuentos estratégicos por marcas'),
        findsOneWidget,
      );
    });

    testWidgets(
      'PromocionesScreen renders navigation tabs and action buttons when isPro is true',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1000));

        await tester.pumpWidget(
          const MaterialApp(
            home: PromocionesScreen(isPro: true, nombreBodega: 'Bodega KARLIZ'),
          ),
        );

        await tester.pump();

        expect(find.text('Promociones y Descuentos'), findsOneWidget);
        expect(find.text('PRO'), findsOneWidget);
        expect(find.text('Bodega KARLIZ'), findsOneWidget);
        expect(find.text('NUEVA'), findsOneWidget);
        expect(find.textContaining('Promociones ('), findsOneWidget);
        expect(find.textContaining('Combos Huesos ('), findsOneWidget);
      },
    );
  });
}
