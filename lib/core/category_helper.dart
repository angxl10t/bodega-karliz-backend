import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'theme.dart';

/// Utilidad compartida para estandarizar iconos y colores temáticos por categoría
/// en toda la aplicación (POS, Stock, Inventario, Kardex y Compras).
class CategoryHelper {
  CategoryHelper._();

  /// Sanitiza y unifica nombres de categorías en las 12 canónicas del sistema CajaYa Cloud POS
  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'General';
    final clean = raw.trim();
    final lower = clean.toLowerCase();
    if (lower.contains('bebidas refrescantes') || lower == 'bebidas y gaseosas' || lower == 'bebidas') {
      return 'Gaseosas y Bebidas';
    }
    if (lower == 'licores y cervezas') return 'Bebidas Alcohólicas';
    if (lower == 'snacks y golosinas') return 'Snacks y Piqueos';
    if (lower == 'lácteos y huevos' || lower == 'lacteos y huevos') return 'Lácteos y Derivados';
    if (lower == 'abarrotes y fideos') return 'Abarrotes y Despensa';
    if (lower == 'helados y postres') return 'Helados y Congelados';
    if (lower == 'cuidado personal') return 'Cuidado Personal y Dental';
    if (lower == 'limpieza del hogar') return 'Limpieza y Cuidado del Hogar';
    if (lower == 'cigarrillos y tabacos') return 'Cigarrillos y Tabaco';
    return clean;
  }

  static IconData getIcon(String? categoryName) {
    if (categoryName == null) return LucideIcons.package2;
    final cat = categoryName.toLowerCase().trim();
    if (cat.contains('frecuente') || cat.contains('estrella') || cat.contains('favorito')) {
      return LucideIcons.flame;
    }
    if (cat.contains('todo')) {
      return LucideIcons.layoutGrid;
    }
    if (cat.contains('bebid') ||
        cat.contains('gaseos') ||
        cat.contains('cervez') ||
        cat.contains('licor') ||
        cat.contains('agua') ||
        cat.contains('jugo') ||
        cat.contains('refresco')) {
      return LucideIcons.cupSoda;
    }
    if (cat.contains('snack') ||
        cat.contains('gallet') ||
        cat.contains('piqueo') ||
        cat.contains('frito') ||
        cat.contains('chips') ||
        cat.contains('papa')) {
      return LucideIcons.cookie;
    }
    if (cat.contains('abarrot') ||
        cat.contains('arroz') ||
        cat.contains('azucar') ||
        cat.contains('fideo') ||
        cat.contains('aceite') ||
        cat.contains('menestr') ||
        cat.contains('conserv') ||
        cat.contains('atun')) {
      return LucideIcons.shoppingBasket;
    }
    if (cat.contains('limpiez') ||
        cat.contains('detergent') ||
        cat.contains('jabon') ||
        cat.contains('aseo') ||
        cat.contains('shampoo') ||
        cat.contains('desinfectante') ||
        cat.contains('lejia')) {
      return LucideIcons.sparkles;
    }
    if (cat.contains('lacteo') ||
        cat.contains('leche') ||
        cat.contains('yogurt') ||
        cat.contains('queso') ||
        cat.contains('mantequilla') ||
        cat.contains('huevo') ||
        cat.contains('embutid')) {
      return LucideIcons.egg;
    }
    if (cat.contains('golosin') ||
        cat.contains('dulce') ||
        cat.contains('caramel') ||
        cat.contains('chocolat') ||
        cat.contains('bombom')) {
      return LucideIcons.candy;
    }
    if (cat.contains('panader') || cat.contains('pan') || cat.contains('torta')) {
      return LucideIcons.croissant;
    }
    if (cat.contains('fruta') || cat.contains('verdur') || cat.contains('vegetal')) {
      return LucideIcons.apple;
    }
    return LucideIcons.package2;
  }

  static Color getColor(String? categoryName, bool isDark) {
    if (categoryName == null) {
      return isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted;
    }
    final cat = categoryName.toLowerCase().trim();
    if (cat.contains('frecuente') || cat.contains('estrella')) {
      return const Color(0xFFF97316); // Naranja cálido
    }
    if (cat.contains('bebid') || cat.contains('gaseos') || cat.contains('cervez') || cat.contains('licor')) {
      return const Color(0xFF0284C7); // Celeste / Azul
    }
    if (cat.contains('snack') || cat.contains('gallet') || cat.contains('piqueo')) {
      return const Color(0xFFF59E0B); // Ámbar dorado
    }
    if (cat.contains('abarrot') || cat.contains('arroz') || cat.contains('aceite')) {
      return const Color(0xFF10B981); // Esmeralda Botanical
    }
    if (cat.contains('limpiez') || cat.contains('aseo')) {
      return const Color(0xFF06B6D4); // Cyan brillante
    }
    if (cat.contains('lacteo') || cat.contains('huevo')) {
      return const Color(0xFF8B5CF6); // Púrpura suave
    }
    if (cat.contains('golosin') || cat.contains('dulce')) {
      return const Color(0xFFEC4899); // Rosa frambuesa
    }
    if (cat.contains('panader') || cat.contains('pan')) {
      return const Color(0xFFD97706); // Caramelo tostado
    }
    if (cat.contains('fruta') || cat.contains('verdur')) {
      return const Color(0xFF22C55E); // Verde fresco
    }
    return AppTheme.brandPrimary;
  }
}
