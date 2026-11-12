import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/widgets/plan_comparativa_table.dart';

/// Modal especializado para comparar exhaustivamente y seleccionar el plan SaaS
/// durante el onboarding / registro de una nueva bodega.
///
/// Viene preseleccionado por defecto en el Plan Minimarket PRO con 1 mes gratis (30 días),
/// detallando punto por punto las diferencias frente al Plan Bodega Básico.
class SelectorPlanRegistroModal extends StatefulWidget {
  final String planActual;

  const SelectorPlanRegistroModal({super.key, this.planActual = 'PRO'});

  static Future<String?> show(
    BuildContext context, {
    String planActual = 'PRO',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SelectorPlanRegistroModal(planActual: planActual),
    );
  }

  @override
  State<SelectorPlanRegistroModal> createState() =>
      _SelectorPlanRegistroModalState();
}

class _SelectorPlanRegistroModalState extends State<SelectorPlanRegistroModal> {
  late String _planSeleccionado;

  @override
  void initState() {
    super.initState();
    _planSeleccionado = (widget.planActual == 'BASICO') ? 'BASICO' : 'PRO';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isPro = _planSeleccionado == 'PRO';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Barra superior de arrastre
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),

            // Cabecera con título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.crown,
                            color: Color(0xFF8B5CF6),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Elige el Plan para tu Bodega',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                'Prueba 30 días gratis en Plan PRO • Sin tarjetas',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.pop(context, _planSeleccionado),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),

            // Contenido con scroll
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner destacado de 1 Mes Gratis
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF14532D)
                                      .withValues(alpha: 0.5),
                                  const Color(0xFF052E16)
                                      .withValues(alpha: 0.6),
                                ]
                              : [
                                  const Color(0xFFDCFCE7),
                                  const Color(0xFFF0FDF4),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.accentGreen.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withValues(
                                alpha: 0.2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.gift,
                              color: AppTheme.accentGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¡Tu Primer Mes es 100% GRATIS (S/ 0.00)!',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFF166534),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Inicia con 30 días de acceso total al Plan Minimarket PRO sin compromiso, sin ingresar tarjeta de crédito y sin renovación forzosa.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF166534),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Selector de Tarjetas de Plan
                    Text(
                      'SELECCIONA UNA OPCIÓN',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 1. Tarjeta Plan Minimarket PRO (Preseleccionada)
                    _buildPlanCard(
                      id: 'PRO',
                      titulo: 'Plan Minimarket PRO',
                      precioDestacado: 'S/ 0.00',
                      subtituloPrecio: 'el 1er mes (luego S/ 100 / mes)',
                      badgeSuperior: '🔥 RECOMENDADO • 1 MES GRATIS',
                      colorBadge: AppTheme.accentGreen,
                      descripcion: 'Para bodegas y minimarkets que buscan crecer, vender por WhatsApp y tener catálogo web online propio.',
                      limiteProductos: 'ILIMITADO (Sin tope)',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),

                    // 2. Tarjeta Plan Bodega Básico
                    _buildPlanCard(
                      id: 'BASICO',
                      titulo: 'Plan Bodega Básico',
                      precioDestacado: 'S/ 50.00',
                      subtituloPrecio: '/ mes (facturación mensual)',
                      badgeSuperior: '🏪 BODEGAS TRADICIONALES',
                      colorBadge: const Color(0xFF64748B),
                      descripcion: 'Para pequeños puestos o bodegas con surtido acotado que solo necesitan registrar ventas rápidas de mostrador.',
                      limiteProductos: 'Hasta 150 productos',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),

                    // Tabla Comparativa Exhaustiva de Funcionalidades
                    PlanComparativaTable(
                      highlightedPlan: _planSeleccionado,
                      isRegistroConMesGratis: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Barra persistente inferior con el botón de confirmación
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _planSeleccionado),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPro
                        ? AppTheme.accentGreen
                        : AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPro ? LucideIcons.gift : LucideIcons.check,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isPro
                            ? 'CONFIRMAR PLAN PRO (1 MES GRATIS)'
                            : 'CONFIRMAR PLAN BÁSICO (S/ 50 / MES)',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String titulo,
    required String precioDestacado,
    required String subtituloPrecio,
    required String badgeSuperior,
    required Color colorBadge,
    required String descripcion,
    required String limiteProductos,
    required bool isDark,
  }) {
    final isSelected = _planSeleccionado == id;
    final isPro = id == 'PRO';

    return InkWell(
      onTap: () => setState(() => _planSeleccionado = id),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isPro
                    ? AppTheme.accentGreen.withValues(
                        alpha: isDark ? 0.16 : 0.08,
                      )
                    : AppTheme.brandPrimary.withValues(
                        alpha: isDark ? 0.16 : 0.06,
                      ))
              : (isDark ? AppTheme.cardDarkElevated : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? (isPro ? AppTheme.accentGreen : AppTheme.brandPrimary)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        (isPro ? AppTheme.accentGreen : AppTheme.brandPrimary)
                            .withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorBadge.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorBadge.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      badgeSuperior,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isDark && colorBadge == const Color(0xFF64748B)
                            ? AppTheme.textDarkMuted
                            : colorBadge,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  color: isSelected
                      ? (isPro ? AppTheme.accentGreen : AppTheme.brandPrimary)
                      : AppTheme.getAdaptiveHintText(isDark),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  precioDestacado,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subtituloPrecio,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getAdaptiveMutedText(isDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            Text(
              titulo,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isPro
                    ? (isDark
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF15803D))
                    : (isDark ? Colors.white : AppTheme.brandDark),
              ),
            ),
            const SizedBox(height: 4),

            Text(
              descripcion,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF475569),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPro ? LucideIcons.infinity : LucideIcons.package,
                    size: 14,
                    color: isPro
                        ? AppTheme.accentGreen
                        : AppTheme.getAdaptiveMutedText(isDark),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Inventario: $limiteProductos',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isPro
                            ? (isDark
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFF166534))
                            : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
