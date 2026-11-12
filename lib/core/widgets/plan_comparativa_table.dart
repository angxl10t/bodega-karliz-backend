import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';

/// Tabla comparativa reutilizable de funcionalidades entre el Plan Bodega Básico
/// y el Plan Minimarket PRO. Garantiza ajuste sin desbordamiento en pantallas angostas.
class PlanComparativaTable extends StatelessWidget {
  /// Plan actualmente activo o seleccionado ('BASICO', 'PRO' o null).
  final String? highlightedPlan;

  /// Muestra 'PRO (1er Mes S/0)' en el encabezado para el flujo de registro nuevo.
  final bool isRegistroConMesGratis;

  /// Usa tipografía y márgenes ligeramente más compactos para modales/diálogos.
  final bool compact;

  /// Título opcional sobre la tabla. Si se omite, usa 'COMPARATIVA DETALLADA DE FUNCIONES'.
  final String title;

  const PlanComparativaTable({
    super.key,
    this.highlightedPlan,
    this.isRegistroConMesGratis = false,
    this.compact = false,
    this.title = 'COMPARATIVA DETALLADA DE FUNCIONES',
  });

  static const List<_PlanFeatureDiff> _features = [
    _PlanFeatureDiff(
      nombre: 'Capacidad de Productos en Inventario',
      detalle: 'Límite de catálogo activo en sistema',
      valorBasico: 'Máx. 150',
      valorPro: 'ILIMITADO',
      isProExclusive: true,
    ),
    _PlanFeatureDiff(
      nombre: 'Catálogo Web Online Oficial Propio',
      detalle: 'cajaya-pos.onrender.com/#/catalogo?tienda=tu-bodega',
      valorBasico: '❌ No',
      valorPro: '✅ Sí (WhatsApp)',
      isProExclusive: true,
    ),
    _PlanFeatureDiff(
      nombre: 'Kit Viralidad & Marketing de Barrio',
      detalle: 'Volantes térmicos para vuelto y afiches con QR',
      valorBasico: '❌ No',
      valorPro: '✅ Sí',
      isProExclusive: true,
    ),
    _PlanFeatureDiff(
      nombre: 'Dashboard BI & Rotación ABC',
      detalle: 'Margen neto en soles, utilidad y productos estrella',
      valorBasico: '❌ No',
      valorPro: '✅ Sí',
      isProExclusive: true,
    ),
    _PlanFeatureDiff(
      nombre: 'Detector de Mercadería Hueso',
      detalle: 'Alertas de dinero inmovilizado y combos sugeridos',
      valorBasico: '❌ No',
      valorPro: '✅ Sí',
      isProExclusive: true,
    ),
    _PlanFeatureDiff(
      nombre: 'Auditoría Ciega de Caja',
      detalle: 'Cierre y arqueo sin mostrar monto teórico a cajeros',
      valorBasico: '❌ No',
      valorPro: '✅ Sí',
      isProExclusive: true,
    ),
    _PlanFeatureDiff(
      nombre: 'Envío de Cierre Auditado a WhatsApp',
      detalle: 'Resumen de ventas y dinero en caja directo al dueño',
      valorBasico: '❌ No',
      valorPro: '✅ Sí',
      isProExclusive: true,
    ),
    _PlanFeatureDiff(
      nombre: 'Módulo de Mermas y Desmedros',
      detalle: 'Registro de vencidos y mermas con cálculo en soles',
      valorBasico: '❌ No',
      valorPro: '✅ Sí',
      isProExclusive: true,
    ),
    _PlanFeatureDiff(
      nombre: 'POS Rápido en Mostrador & Tickets 58/80mm',
      detalle: 'Ventas ágiles, código de barras y gaveta RJ11',
      valorBasico: '✅ Sí',
      valorPro: '✅ Sí',
      isProExclusive: false,
    ),
    _PlanFeatureDiff(
      nombre: 'Caja Chica, Arqueos & Libreta de Fiados',
      detalle: 'Cobros Yape/Plin, control de clientes y saldos',
      valorBasico: '✅ Sí',
      valorPro: '✅ Sí',
      isProExclusive: false,
    ),
    _PlanFeatureDiff(
      nombre: 'Modo Offline Resiliente (Sin Internet)',
      detalle: 'Sigue vendiendo ante cortes de señal móvil',
      valorBasico: '✅ Sí',
      valorPro: '✅ Sí',
      isProExclusive: false,
    ),
    _PlanFeatureDiff(
      nombre: 'Cajeros y Administradores con PIN',
      detalle: 'Roles y personal ilimitado por tienda',
      valorBasico: '✅ Ilimitados',
      valorPro: '✅ Ilimitados',
      isProExclusive: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normPlan = highlightedPlan?.toUpperCase();
    final isBasicoHighlight = normPlan == 'BASICO';
    final isProHighlight = normPlan == 'PRO';

    final hPad = compact ? 10.0 : 14.0;
    final vPad = compact ? 8.0 : 11.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.arrowLeftRight,
              size: 16,
              color: AppTheme.brandPrimary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: compact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white : AppTheme.brandDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // Encabezado de la tabla
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: compact ? 8 : 10,
                  ),
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'Funcionalidad',
                          style: GoogleFonts.outfit(
                            fontSize: compact ? 11 : 11.5,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: isBasicoHighlight
                              ? BoxDecoration(
                                  color: AppTheme.brandPrimary.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                )
                              : null,
                          child: Text(
                            'Básico (S/50)',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: compact ? 10 : 11,
                              fontWeight: isBasicoHighlight
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: isBasicoHighlight
                                  ? AppTheme.brandPrimary
                                  : (isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: isProHighlight
                              ? BoxDecoration(
                                  color: AppTheme.accentGreen.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                )
                              : null,
                          child: Text(
                            isRegistroConMesGratis
                                ? 'PRO (1er Mes S/0)'
                                : 'PRO (S/100)',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: compact ? 10 : 11,
                              fontWeight: FontWeight.w800,
                              color: isProHighlight
                                  ? (isDark
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFF15803D))
                                  : AppTheme.brandPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                for (int i = 0; i < _features.length; i++)
                  _buildFeatureRow(
                    feature: _features[i],
                    isDark: isDark,
                    isLast: i == _features.length - 1,
                    hPad: hPad,
                    vPad: vPad,
                    compact: compact,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow({
    required _PlanFeatureDiff feature,
    required bool isDark,
    required bool isLast,
    required double hPad,
    required double vPad,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.nombre,
                  style: GoogleFonts.outfit(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  feature.detalle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: compact ? 9.5 : 10.5,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: Center(
              child: Text(
                feature.valorBasico,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w600,
                  color: feature.valorBasico.startsWith('❌')
                      ? const Color(0xFFEF4444)
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: feature.isProExclusive
                  ? BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Center(
                child: Text(
                  feature.valorPro,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: compact ? 10.5 : 11.5,
                    fontWeight: FontWeight.w800,
                    color: feature.isProExclusive
                        ? (isDark
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF15803D))
                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanFeatureDiff {
  final String nombre;
  final String detalle;
  final String valorBasico;
  final String valorPro;
  final bool isProExclusive;

  const _PlanFeatureDiff({
    required this.nombre,
    required this.detalle,
    required this.valorBasico,
    required this.valorPro,
    required this.isProExclusive,
  });
}
