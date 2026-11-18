import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'theme.dart';

/// Utilidad compartida para estandarizar iconos y colores temáticos por categoría
/// en toda la aplicación (Catálogo Online, POS, Stock, Inventario, Kardex y Compras).
class CategoryHelper {
  CategoryHelper._();

  /// Normaliza tildes y diacríticos para que categorías como "Lácteos y Derivados",
  /// "Bebidas Alcohólicas" o "Panadería y Desayuno" coincidan siempre con su icono y color.
  static String _stripAccents(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  /// Sanitiza y unifica nombres de categorías en las 13 canónicas del sistema CajaYa Cloud POS
  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'General';
    final clean = raw.trim();
    final lower = _stripAccents(clean);
    if (lower.contains('bebidas refrescantes') ||
        lower == 'bebidas y gaseosas' ||
        lower == 'bebidas') {
      return 'Gaseosas y Bebidas';
    }
    if (lower == 'licores y cervezas') return 'Bebidas Alcohólicas';
    if (lower == 'snacks y golosinas') return 'Snacks y Piqueos';
    if (lower == 'lacteos y huevos') return 'Lácteos y Derivados';
    if (lower == 'abarrotes y fideos') return 'Abarrotes y Despensa';
    if (lower == 'helados y postres') return 'Helados y Congelados';
    if (lower == 'cuidado personal') return 'Cuidado Personal y Dental';
    if (lower == 'limpieza del hogar') return 'Limpieza y Cuidado del Hogar';
    if (lower == 'cigarrillos y tabacos') return 'Cigarrillos y Tabaco';
    if (lower == 'mascotas' || lower == 'comida para mascotas') {
      return 'Mascotas y Alimento';
    }
    return clean;
  }

  static IconData getIcon(String? categoryName) {
    if (categoryName == null) return LucideIcons.package2;
    final cat = _stripAccents(categoryName);

    if (cat.contains('frecuente') ||
        cat.contains('estrella') ||
        cat.contains('favorito') ||
        cat.contains('oferta') ||
        cat.contains('promo')) {
      return LucideIcons.flame;
    }
    if (cat == 'todas' || cat.contains('todo')) {
      return LucideIcons.layoutGrid;
    }
    // Bebidas Alcohólicas ANTES que Bebidas genéricas para diferenciar icono
    if (cat.contains('alcohol') ||
        cat.contains('licor') ||
        cat.contains('cervez') ||
        cat.contains('vino') ||
        cat.contains('pisco') ||
        cat.contains('whisky') ||
        cat.contains('ron')) {
      return LucideIcons.wine;
    }
    if (cat.contains('bebid') ||
        cat.contains('gaseos') ||
        cat.contains('agua') ||
        cat.contains('jugo') ||
        cat.contains('refresco') ||
        cat.contains('energiz')) {
      return LucideIcons.cupSoda;
    }
    if (cat.contains('helad') ||
        cat.contains('congelad') ||
        cat.contains('nugget') ||
        cat.contains('hamburgues')) {
      return LucideIcons.snowflake;
    }
    if (cat.contains('mascot') ||
        cat.contains('perro') ||
        cat.contains('gato') ||
        cat.contains('ricocan') ||
        cat.contains('pedigree')) {
      return LucideIcons.pawPrint;
    }
    if (cat.contains('embutid') ||
        cat.contains('fiambr') ||
        cat.contains('jamon') ||
        cat.contains('salchich') ||
        cat.contains('hot dog') ||
        cat.contains('choriz')) {
      return LucideIcons.beef;
    }
    if (cat.contains('lacteo') ||
        cat.contains('leche') ||
        cat.contains('yogur') ||
        cat.contains('queso') ||
        cat.contains('mantequill') ||
        cat.contains('huevo')) {
      return LucideIcons.milk;
    }
    if (cat.contains('cuidado personal') ||
        cat.contains('dental') ||
        cat.contains('shampoo') ||
        cat.contains('higiene') ||
        cat.contains('panal') ||
        cat.contains('botiquin') ||
        cat.contains('desodorant')) {
      return LucideIcons.bath;
    }
    if (cat.contains('limpiez') ||
        cat.contains('detergent') ||
        cat.contains('jabon') ||
        cat.contains('aseo') ||
        cat.contains('desinfectante') ||
        cat.contains('lejia') ||
        cat.contains('hogar')) {
      return LucideIcons.sparkles;
    }
    if (cat.contains('cigarr') ||
        cat.contains('tabac') ||
        cat.contains('fosfor')) {
      return LucideIcons.cigarette;
    }
    if (cat.contains('golosin') ||
        cat.contains('dulce') ||
        cat.contains('caramel') ||
        cat.contains('chocolat') ||
        cat.contains('bombom') ||
        cat.contains('chicle')) {
      return LucideIcons.candy;
    }
    if (cat.contains('snack') ||
        cat.contains('gallet') ||
        cat.contains('piqueo') ||
        cat.contains('frito') ||
        cat.contains('chips') ||
        cat.contains('papa')) {
      return LucideIcons.popcorn;
    }
    if (cat.contains('panader') ||
        cat.contains('desayun') ||
        cat.contains('pan') ||
        cat.contains('cafe') ||
        cat.contains('avena') ||
        cat.contains('torta')) {
      return LucideIcons.croissant;
    }
    if (cat.contains('abarrot') ||
        cat.contains('despens') ||
        cat.contains('arroz') ||
        cat.contains('azucar') ||
        cat.contains('fideo') ||
        cat.contains('aceite') ||
        cat.contains('menestr') ||
        cat.contains('conserv') ||
        cat.contains('atun')) {
      return LucideIcons.shoppingBasket;
    }
    if (cat.contains('fruta') ||
        cat.contains('verdur') ||
        cat.contains('vegetal')) {
      return LucideIcons.apple;
    }
    return LucideIcons.package2;
  }

  /// Color temático WCAG-optimizado para cada una de las 13 categorías canónicas.
  /// En modo claro usa tonos ricos y legibles; en modo oscuro usa variantes luminosas.
  static Color getColor(String? categoryName, bool isDark) {
    if (categoryName == null) {
      return isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted;
    }
    final cat = _stripAccents(categoryName);

    if (cat.contains('frecuente') ||
        cat.contains('estrella') ||
        cat.contains('oferta') ||
        cat.contains('promo')) {
      return isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48);
    }
    if (cat == 'todas' || cat.contains('todo')) {
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    }
    // Bebidas Alcohólicas -> Violeta Real
    if (cat.contains('alcohol') ||
        cat.contains('licor') ||
        cat.contains('cervez') ||
        cat.contains('vino') ||
        cat.contains('pisco')) {
      return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    }
    // Gaseosas y Bebidas -> Azul Océano vibrante
    if (cat.contains('bebid') ||
        cat.contains('gaseos') ||
        cat.contains('agua') ||
        cat.contains('jugo')) {
      return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    }
    // Helados y Congelados -> Azul Glaciar frío
    if (cat.contains('helad') || cat.contains('congelad')) {
      return isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
    }
    // Mascotas y Alimento -> Terracota cálido
    if (cat.contains('mascot') ||
        cat.contains('perro') ||
        cat.contains('gato')) {
      return isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
    }
    // Embutidos y Fiambrería -> Rojo Carmesí
    if (cat.contains('embutid') || cat.contains('fiambr')) {
      return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    }
    // Lácteos y Derivados -> Cobalto Lácteo limpio
    if (cat.contains('lacteo') ||
        cat.contains('leche') ||
        cat.contains('yogur') ||
        cat.contains('queso') ||
        cat.contains('huevo')) {
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    }
    // Cuidado Personal y Dental -> Teal Spa fresco
    if (cat.contains('cuidado personal') ||
        cat.contains('dental') ||
        cat.contains('higiene')) {
      return isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
    }
    // Limpieza y Cuidado del Hogar -> Cyan Fresco
    if (cat.contains('limpiez') ||
        cat.contains('aseo') ||
        cat.contains('hogar')) {
      return isDark ? const Color(0xFF22D3EE) : const Color(0xFF0891B2);
    }
    // Cigarrillos y Tabaco -> Pizarra Grafito sobrio
    if (cat.contains('cigarr') || cat.contains('tabac')) {
      return isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    }
    // Golosinas y Chocolates -> Frambuesa / Berry vibrante
    if (cat.contains('golosin') ||
        cat.contains('dulce') ||
        cat.contains('chocolat')) {
      return isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777);
    }
    // Snacks y Piqueos -> Ámbar Dorado intenso
    if (cat.contains('snack') ||
        cat.contains('gallet') ||
        cat.contains('piqueo')) {
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    }
    // Panadería y Desayuno -> Caramelo Tostado artesanal
    if (cat.contains('panader') ||
        cat.contains('desayun') ||
        cat.contains('pan')) {
      return isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309);
    }
    // Abarrotes y Despensa -> Esmeralda Botánico
    if (cat.contains('abarrot') ||
        cat.contains('despens') ||
        cat.contains('arroz') ||
        cat.contains('aceite')) {
      return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    }
    if (cat.contains('fruta') || cat.contains('verdur')) {
      return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    }
    return isDark ? const Color(0xFF60A5FA) : AppTheme.brandPrimary;
  }

  /// Devuelve un par de colores para gradientes sutiles o botones activos de categoría.
  static List<Color> getGradientColors(String? categoryName, bool isDark) {
    final base = getColor(categoryName, false);
    final hsl = HSLColor.fromColor(base);
    final deeper = hsl
        .withLightness((hsl.lightness - 0.10).clamp(0.18, 0.45))
        .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
        .toColor();
    final brighter = hsl
        .withLightness(
          (hsl.lightness + (isDark ? 0.06 : 0.04)).clamp(0.32, 0.58),
        )
        .toColor();
    return [deeper, brighter];
  }
}
