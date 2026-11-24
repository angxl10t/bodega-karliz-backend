import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bodega_mobile/core/category_helper.dart';

void main() {
  group('CategoryHelper - Iconos y Normalización de Categorías', () {
    test('Bebidas Alcohólicas y sus variantes retornan LucideIcons.bottleWine (icono de botella oficial unificado)', () {
      expect(
        CategoryHelper.getIcon('Bebidas Alcohólicas'),
        LucideIcons.bottleWine,
      );
      expect(
        CategoryHelper.getIcon('Bebidas Alcoholicas'),
        LucideIcons.bottleWine,
      );
      expect(
        CategoryHelper.getIcon('Licores y Cervezas'),
        LucideIcons.bottleWine,
      );
      expect(
        CategoryHelper.getIcon('Cervezas y Licores'),
        LucideIcons.bottleWine,
      );
      expect(CategoryHelper.getIcon('Cervezas'), LucideIcons.bottleWine);
      expect(CategoryHelper.getIcon('Cerveza'), LucideIcons.bottleWine);
      expect(CategoryHelper.getIcon('Vinos y Piscos'), LucideIcons.bottleWine);
      expect(CategoryHelper.getIcon('Whisky'), LucideIcons.bottleWine);
      expect(CategoryHelper.getIcon('Ron'), LucideIcons.bottleWine);
      expect(
        CategoryHelper.getIcon('Cerveza Cristal 650ml'),
        LucideIcons.bottleWine,
      );
    });

    test('Bebidas no alcohólicas retornan LucideIcons.cupSoda', () {
      expect(CategoryHelper.getIcon('Gaseosas y Bebidas'), LucideIcons.cupSoda);
      expect(CategoryHelper.getIcon('Bebidas y Gaseosas'), LucideIcons.cupSoda);
      expect(CategoryHelper.getIcon('Aguas'), LucideIcons.cupSoda);
      expect(CategoryHelper.getIcon('Jugos'), LucideIcons.cupSoda);
    });

    test('Normalización de categorías alcohólicas canónicas', () {
      expect(
        CategoryHelper.normalize('licores y cervezas'),
        'Bebidas Alcohólicas',
      );
      expect(
        CategoryHelper.normalize('cervezas y licores'),
        'Bebidas Alcohólicas',
      );
      expect(
        CategoryHelper.normalize('bebidas alcoholicas'),
        'Bebidas Alcohólicas',
      );
      expect(
        CategoryHelper.normalize('Bebidas Alcohólicas'),
        'Bebidas Alcohólicas',
      );
      expect(CategoryHelper.normalize('cervezas'), 'Bebidas Alcohólicas');
      expect(CategoryHelper.normalize('licores'), 'Bebidas Alcohólicas');
    });

    test(
      'Color de categoría Bebidas Alcohólicas en modo claro y modo oscuro',
      () {
        final colorLight = CategoryHelper.getColor(
          'Bebidas Alcohólicas',
          false,
        );
        final colorDark = CategoryHelper.getColor('Bebidas Alcohólicas', true);

        expect(colorLight, isNotNull);
        expect(colorDark, isNotNull);
        // Violeta Real
        expect(colorLight, const Color(0xFF7C3AED));
        expect(colorDark, const Color(0xFFA78BFA));
      },
    );
  });
}
