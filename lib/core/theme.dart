import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'karliz_vectors.dart';

class AppTheme {
  // ============================================
  // REBRANDING "CajaYa POS"
  // Opción A: Fintech Cobalt & Deep Slate
  // ============================================
  static const Color brandPrimary = Color(0xFF2563EB); // Electric Cobalt
  static const Color brandDark = Color(0xFF1D4ED8); // Deep Cobalt
  static const Color brandLight = Color(
    0xFF60A5FA,
  ); // Sky Blue Luminoso (Dark Mode)
  static const Color brandInk = Color(0xFF0B0F19); // Obsidian Dark
  static const Color surfaceTint = Color(
    0xFFEFF6FF,
  ); // Porcelana Azul Cobalto Suave
  static const Color borderTint = Color(0xFFDBEAFE); // Borde Cobalto Sutil

  // Aliases de compatibilidad para unificar toda la app automáticamente
  static const Color primaryOrange = brandPrimary;
  static const Color primaryDark = brandDark;
  static const Color primaryLight = brandLight;
  static const Color peachSurface = surfaceTint;
  static const Color peachBorder = borderTint;

  // Semáforo Didáctico de Inventario y Finanzas
  static const Color accentGreen = Color(0xFF10B981); // Óptimo / Ingreso
  static const Color warningAmber = Color(
    0xFFF59E0B,
  ); // Por Agotar / Precaución
  static const Color alertRed = Color(
    0xFFEF4444,
  ); // Crítico / Salida / Anulación
  static const Color infoIndigo = Color(0xFF6366F1); // Auditoría / Proveedores

  // Superficies Modo Claro (Alabaster Minimal)
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color cardLight = Colors.white;
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF334155); // Slate 700 - Máximo Contraste WCAG AAA (>10:1) para personas mayores y pantallas con bajo brillo

  // ============================================
  // MODO OSCURO DE ÉLITE: VELVET OBSIDIAN & HIGH-CONTRAST TEXT
  // Optimizado con WCAG AAA (>7:1) para personas mayores y pantallas con brillo bajo.
  // ============================================
  static const Color bgDark = Color(
    0xFF090A0F,
  ); // Canvas Velvet Obsidian (Espacio profundo puro)
  static const Color cardDark = Color(
    0xFF141724,
  ); // Tarjeta Primaria (Contraste palpable y silueta definida)
  static const Color cardDarkElevated = Color(
    0xFF1E2436,
  ); // Superficie Flotante (Modales, Hojas, Diálogos, Sheets)
  static const Color cardDarkHighlight = Color(
    0xFF283149,
  ); // Superficie Activa (Chips seleccionados, Hover, Botones tonales)
  static const Color cardDarkSunken = Color(
    0xFF0D0F17,
  ); // Superficie Hundida Inset (Inputs, Buscadores, Celdas)
  static const Color borderDark = Color(
    0xFF262E44,
  ); // Micro-borde perimetral 1px nítido
  static const Color borderDarkElevated = Color(
    0xFF384362,
  ); // Borde de realce en superficies flotantes
  static const Color surfaceTintDark = Color(
    0xFF131D31,
  ); // Glow cobalto suave de fondo
  static const Color borderTintDark = Color(
    0xFF1E3A8A,
  ); // Borde cobalto de acento
  static const Color textDarkPrimary = Color(
    0xFFFFFFFF,
  ); // 100% Blanco Puro Nítido (21:1 Máximo Contraste)
  static const Color textDarkSecondary = Color(
    0xFFF1F5F9,
  ); // Slate 100 (95% Luminancia - Blanco suave de lectura fácil)
  static const Color textDarkMuted = Color(
    0xFFE2E8F0,
  ); // Slate 200 (89% Luminancia - Ultra visible con bajo brillo)

  /// Retorna un color de texto atenuado/secundario según el tema con alto contraste WCAG AAA
  static Color getAdaptiveMutedText(bool isDark) =>
      isDark ? textDarkMuted : textMuted;

  /// Retorna un color de placeholder/hint legible y con contraste seguro en claro y oscuro
  static Color getAdaptiveHintText(bool isDark) =>
      isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

  /// Retorna un color de texto secundario nítido según el tema
  static Color getAdaptiveSecondaryText(bool isDark) =>
      isDark ? textDarkSecondary : const Color(0xFF334155);

  /// Retorna un color de texto primario de alto contraste según el tema
  static Color getAdaptivePrimaryText(bool isDark) =>
      isDark ? textDarkPrimary : textDark;

  // ============================================
  // IDENTIDAD DE MARCA DINÁMICA POR TIENDA (CALMA VISUAL)
  // Permite que la paleta elegida por el bodeguero personalice
  // las superficies y controles del sistema de administración sin saturar.
  // ============================================

  /// Color primario activo configurado para la tienda (o Cobalto por defecto)
  static Color primaryColorOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Tono oscuro calibrado para degradados y sombras de la marca activa
  static Color brandDarkOf(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hsl = HSLColor.fromColor(primary);
    return hsl
        .withLightness((hsl.lightness - 0.12).clamp(0.12, 0.65))
        .withSaturation((hsl.saturation + 0.06).clamp(0.40, 1.0))
        .toColor();
  }

  /// Tono luminoso legible para Modo Oscuro de la marca activa (WCAG AAA)
  static Color brandLightOf(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hsl = HSLColor.fromColor(primary);
    return hsl
        .withLightness((hsl.lightness + 0.22).clamp(0.55, 0.88))
        .withSaturation((hsl.saturation + 0.05).clamp(0.45, 1.0))
        .toColor();
  }

  /// Superficie porcelana suave tintada con la marca activa (fondo de chips y tarjetas activas)
  static Color surfaceTintOf(BuildContext context) {
    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
  }

  /// Micro-borde sutil tintado con la marca activa
  static Color borderTintOf(BuildContext context) {
    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.24);
  }

  // ============================================
  // TIPOGRAFÍA DE MARCA UNIFICADA
  // ============================================
  static TextStyle headingStyle({
    double size = 18,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double letterSpacing = -0.4,
  }) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle bodyStyle({
    double size = 13.5,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  // ============================================
  // TEMA CLARO (LIGHT THEME)
  // ============================================
  static ThemeData buildLightTheme({
    Color? primaryColor,
    bool highContrast = false,
  }) {
    final primary = primaryColor ?? brandPrimary;
    final baseFont = GoogleFonts.plusJakartaSans();
    final effectiveBorder = highContrast
        ? const Color(0xFF0F172A)
        : borderLight;
    final borderWidth = highContrast ? 1.6 : 1.0;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: baseFont.fontFamily,
      scaffoldBackgroundColor: highContrast ? Colors.white : bgLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: brandInk,
        surface: cardLight,
        outline: effectiveBorder,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardLight,
        foregroundColor: textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: textDark,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
        shape: Border(
          bottom: BorderSide(color: effectiveBorder, width: borderWidth),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: effectiveBorder, width: borderWidth),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: effectiveBorder, width: borderWidth),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: textMuted,
          fontSize: 13.5,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: textMuted,
          fontSize: 13.5,
        ),
        prefixIconColor: textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardLight,
        elevation: 0,
        height: 68,
        indicatorColor: primary,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white, size: 20);
          }
          return const IconThemeData(color: textMuted, size: 20);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? primary : textMuted,
          );
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get lightTheme => buildLightTheme();

  // ============================================
  // TEMA OSCURO (DARK THEME - Executive Obsidian & Deep Slate)
  // ============================================
  static ThemeData buildDarkTheme({
    Color? primaryColor,
    bool highContrast = false,
  }) {
    final primary = primaryColor ?? brandPrimary;
    final baseFont = GoogleFonts.plusJakartaSans();
    final effectiveBg = highContrast ? const Color(0xFF000000) : bgDark;
    final effectiveCard = highContrast ? const Color(0xFF0D0E15) : cardDark;
    final effectiveBorder = highContrast ? const Color(0xFFFFFFFF) : borderDark;
    final borderWidth = highContrast ? 1.6 : 1.0;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: baseFont.fontFamily,
      scaffoldBackgroundColor: effectiveBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        secondary: brandLight,
        surface: effectiveCard,
        surfaceContainer: highContrast
            ? const Color(0xFF161922)
            : cardDarkElevated,
        surfaceContainerHighest: highContrast
            ? const Color(0xFF222634)
            : cardDarkHighlight,
        onSurface: textDarkPrimary,
        onSurfaceVariant: textDarkSecondary,
        outline: effectiveBorder,
        outlineVariant: highContrast ? Colors.white : borderDarkElevated,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: effectiveCard,
        foregroundColor: textDarkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: textDarkPrimary,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        shape: Border(
          bottom: BorderSide(color: effectiveBorder, width: borderWidth),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: effectiveCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: effectiveBorder, width: borderWidth),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardDarkElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardDarkElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderDarkElevated, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardDarkHighlight,
        selectedColor: primary.withValues(alpha: 0.22),
        secondarySelectedColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderDark, width: 1),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textDarkPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: brandLight,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardDarkElevated,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: textDarkPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderDarkElevated, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDarkSunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderDark, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandPrimary, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: textDarkSecondary,
          fontSize: 13.5,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: textDarkMuted,
          fontSize: 13.5,
        ),
        prefixIconColor: textDarkSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandLight,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardDark,
        elevation: 0,
        height: 68,
        indicatorColor: primary,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white, size: 20);
          }
          return const IconThemeData(color: Colors.white, size: 20);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
            color: isSelected ? brandLight : Colors.white,
          );
        }),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          color: textDarkPrimary,
          fontWeight: FontWeight.w800,
        ),
        displayMedium: GoogleFonts.outfit(
          color: textDarkPrimary,
          fontWeight: FontWeight.w800,
        ),
        displaySmall: GoogleFonts.outfit(
          color: textDarkPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.outfit(
          color: textDarkPrimary,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: GoogleFonts.outfit(
          color: textDarkPrimary,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: GoogleFonts.outfit(
          color: textDarkPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.outfit(
          color: textDarkPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          color: textDarkPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          color: textDarkSecondary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: textDarkPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: textDarkSecondary,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          color: textDarkSecondary,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          color: textDarkPrimary,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          color: textDarkSecondary,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          color: textDarkSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static ThemeData get darkTheme => buildDarkTheme();
}

/// Banner didáctico reutilizable para guiar al usuario paso a paso en cada módulo
class DidacticBanner extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;

  const DidacticBanner({
    super.key,
    required this.title,
    required this.description,
    this.icon = LucideIcons.lightbulb,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = accentColor ?? AppTheme.brandPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.12) : AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? color.withValues(alpha: 0.35) : AppTheme.borderTint,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDark ? AppTheme.brandLight : color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Logotipo vectorial minimalista de la marca KARLIZ
class KarlizLogoMark extends StatelessWidget {
  final double size;
  final bool inverted;

  const KarlizLogoMark({super.key, this.size = 38, this.inverted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: inverted
              ? [Colors.white, const Color(0xFFE2E8F0)]
              : [AppTheme.brandPrimary, AppTheme.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandPrimary.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: KarlizStoreIcon(
          color: inverted ? AppTheme.brandPrimary : Colors.white,
          size: size * 0.54,
        ),
      ),
    );
  }
}
