import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../theme_provider.dart';
import '../karliz_sound_service.dart';
import '../responsive_layout.dart';
import 'adaptive_modal.dart';

/// Preset de color con nombre semántico para la paleta de tienda
class BrandColorPreset {
  final String name;
  final String hex;
  final Color color;

  const BrandColorPreset({
    required this.name,
    required this.hex,
    required this.color,
  });
}

/// Panel Adaptativo de Accesibilidad, Ergonomía Visual y Personalización de Marca para CajaYa POS.
///
/// Permite al cajero y administrador ajustar en tiempo real:
/// 1. Color de tienda / identidad de marca (Cobalto, Esmeralda, Verde Retail, Violeta, Rubí)
/// 2. Escala de tipografía global (100% Normal, 115% Cómodo, 130% Grande)
/// 3. Contraste Extremo (WCAG AAA) para pantallas gastadas o fatiga visual
/// 4. Asistencia para daltonismo (iconos y etiquetas textuales explícitas)
/// 5. Sonidos de escáner y cobro (beeps POS) con botón de prueba en vivo
class AccessibilityPanelModal extends StatelessWidget {
  const AccessibilityPanelModal({super.key});

  static const List<BrandColorPreset> colorPresets = [
    BrandColorPreset(name: 'Cobalto', hex: '#2563EB', color: Color(0xFF2563EB)),
    BrandColorPreset(
      name: 'Esmeralda',
      hex: '#059669',
      color: Color(0xFF059669),
    ),
    BrandColorPreset(
      name: 'Verde Retail',
      hex: '#16A34A',
      color: Color(0xFF16A34A),
    ),
    BrandColorPreset(name: 'Violeta', hex: '#7C3AED', color: Color(0xFF7C3AED)),
    BrandColorPreset(name: 'Rubí', hex: '#DC2626', color: Color(0xFFDC2626)),
  ];

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return AdaptiveModal.show(
      context: context,
      maxWidth: 520,
      builder: (ctx) => const AccessibilityPanelModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final isWide = ResponsiveLayout.isTabletOrLarger(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final cardBg = isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? AppTheme.borderDarkElevated
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: isWide
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppTheme.borderDarkElevated : AppTheme.borderLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.20),
            blurRadius: isWide ? 30 : 20,
            offset: isWide ? const Offset(0, 10) : const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * (isWide ? 0.88 : 0.90),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Manija superior solo en móvil
              if (!isWide) const AdaptiveDragHandle(),

              // Encabezado del Panel
              Padding(
                padding: EdgeInsets.fromLTRB(20, isWide ? 20 : 6, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            LucideIcons.slidersHorizontal,
                            size: 19,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accesibilidad & Confort',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Ergonomía visual y personalización del POS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        LucideIcons.x,
                        size: 20,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Cuerpo con Scroll
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECCIÓN 1: Color de Marca de la Tienda
                      _buildSectionHeader(
                        context,
                        icon: LucideIcons.palette,
                        title: 'Color de Marca (POS & Web)',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            themeProvider.accentColorHex,
                            style: GoogleFonts.firaCode(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aplica el color distintivo de tu negocio a botones de cobro, pestañas y acentos visuales.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textDarkMuted
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildColorPalette(context, themeProvider, isDark),

                      const SizedBox(height: 20),

                      // SECCIÓN 2: Escala de Texto
                      _buildSectionHeader(
                        context,
                        icon: LucideIcons.type,
                        title: 'Tamaño de Texto (Lectura Fácil)',
                        trailing: Text(
                          '${(themeProvider.fontScale * 100).round()}%',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aumenta la legibilidad general sin romper la estructura de las tablas de venta ni los tickets.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textDarkMuted
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFontScaleSelector(context, themeProvider, isDark),

                      const SizedBox(height: 20),

                      // SECCIÓN 3: Contraste Extremo (WCAG AAA)
                      _buildSettingCard(
                        context,
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        icon: LucideIcons.contrast,
                        iconColor: const Color(0xFF38BDF8),
                        title: 'Contraste Extremo (WCAG AAA)',
                        subtitle: 'Fondos negros puros y bordes reforzados. Ideal para pantallas gastadas o baja luminosidad.',
                        trailing: Switch.adaptive(
                          value: themeProvider.highContrast,
                          activeTrackColor: primaryColor,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            themeProvider.setHighContrast(val);
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // SECCIÓN 4: Iconos Asistidos (Daltonismo)
                      _buildSettingCard(
                        context,
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        icon: LucideIcons.eye,
                        iconColor: const Color(0xFF10B981),
                        title: 'Iconos Asistidos (Daltonismo)',
                        subtitle: 'Agrega símbolos textuales explícitos (✓, ⚠, ✕) en estados de stock y vencimiento.',
                        trailing: Switch.adaptive(
                          value: themeProvider.assistedIcons,
                          activeTrackColor: primaryColor,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            themeProvider.setAssistedIcons(val);
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // SECCIÓN 5: Sonidos del Escáner y Cobro
                      _buildSettingCard(
                        context,
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        icon: LucideIcons.volume2,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Beeps Auditivos POS',
                        subtitle: 'Retroalimentación sonora táctica al pistolear productos con código de barras o cobrar.',
                        trailing: Switch.adaptive(
                          value: themeProvider.soundEnabled,
                          activeTrackColor: primaryColor,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            themeProvider.setSoundEnabled(val);
                          },
                        ),
                        bottomAction: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: themeProvider.soundEnabled
                                  ? () async {
                                      HapticFeedback.mediumImpact();
                                      await KarlizSoundService.instance
                                          .playBarcodeBeep();
                                    }
                                  : null,
                              icon: const Icon(LucideIcons.play, size: 13),
                              label: Text(
                                'Probar Beep de Escáner',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                side: BorderSide(
                                  color: themeProvider.soundEnabled
                                      ? primaryColor.withValues(alpha: 0.4)
                                      : Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Banner informativo de guardado automático
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.sparkles,
                              size: 16,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tus preferencias de confort se guardan automáticamente en este terminal.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildColorPalette(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: colorPresets.map((preset) {
            final isSelected =
                themeProvider.accentColorHex.toUpperCase() ==
                preset.hex.toUpperCase();

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                themeProvider.setAccentColorFromHex(preset.hex);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? preset.color
                        : (isDark
                              ? AppTheme.borderDark
                              : const Color(0xFFCBD5E1)),
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: preset.color.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: preset.color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(
                                LucideIcons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preset.name,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? preset.color
                            : (isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFontScaleSelector(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    final primary = Theme.of(context).colorScheme.primary;

    final scales = [
      {'label': '100% Normal', 'scale': 1.0},
      {'label': '115% Cómodo', 'scale': 1.15},
      {'label': '130% Grande', 'scale': 1.30},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: scales.map((item) {
          final scale = item['scale'] as double;
          final label = item['label'] as String;
          final isSelected = (themeProvider.fontScale - scale).abs() < 0.05;

          return Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                themeProvider.setFontScale(scale);
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    Widget? bottomAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textDarkMuted
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
          if (bottomAction != null) ...[
            const SizedBox(height: 10),
            bottomAction,
          ],
        ],
      ),
    );
  }
}
