import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';
import 'pago_yape_modal.dart';

class PlanUpgradeModal extends StatelessWidget {
  final String featureName;
  final String featureDescription;
  final IconData icon;
  final VoidCallback? onPlanUpdated;

  const PlanUpgradeModal({
    super.key,
    required this.featureName,
    required this.featureDescription,
    this.icon = LucideIcons.sparkles,
    this.onPlanUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String featureName,
    required String featureDescription,
    IconData icon = LucideIcons.sparkles,
    VoidCallback? onPlanUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlanUpgradeModal(
        featureName: featureName,
        featureDescription: featureDescription,
        icon: icon,
        onPlanUpdated: onPlanUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Fila superior: Badge PRO + Botón Cerrar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFD97706)
                              .withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.lock,
                            size: 12,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'EXCLUSIVO PLAN MINIMARKET PRO',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFD97706),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    tooltip: 'Cerrar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Cabecera destacada de la función bloqueada
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFF59E0B)
                        .withValues(alpha: isDark ? 0.3 : 0.5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFFD97706),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            featureName,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF78350F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            featureDescription,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF92400E),
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

              // Beneficios del Plan PRO
              Text(
                'QUÉ DESBLOQUEAS CON EL PLAN PRO (S/ 100 /MES):',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.cardDarkSunken
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _buildBeneficioRow(
                      icon: LucideIcons.globe,
                      titulo: 'Mi Bodega Online',
                      descripcion: 'Enlace web propio para que vecinos manden pedidos directo a tu WhatsApp.',
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _buildBeneficioRow(
                      icon: LucideIcons.archive,
                      titulo: 'Detector de Productos Hueso',
                      descripcion: 'Alerta mercadería sin ventas en 30 días para liquidar y recuperar capital.',
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _buildBeneficioRow(
                      icon: LucideIcons.clipboardCheck,
                      titulo: 'Auditoría Rápida por Pasillo',
                      descripcion: 'Conteos ciegos de 5 minutos por categoría contra mermas y robo hormiga.',
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _buildBeneficioRow(
                      icon: LucideIcons.target,
                      titulo: 'Termómetro de Meta Diaria',
                      descripcion: 'Barra de avance en vivo que motiva tus ventas diarias en caja.',
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _buildBeneficioRow(
                      icon: LucideIcons.clock,
                      titulo: 'Mapa de Horas Punta & BI',
                      descripcion: 'Métricas de horarios pico y margen de ganancia real en soles.',
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _buildBeneficioRow(
                      icon: LucideIcons.send,
                      titulo: 'Reporte de Cierre al WhatsApp del Dueño',
                      descripcion: 'Resumen consolidado automático enviado a tu teléfono al cerrar caja.',
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _buildBeneficioRow(
                      icon: LucideIcons.boxes,
                      titulo: 'Catálogo de Productos Ilimitado',
                      descripcion:
                          'Sin el límite de 150 productos del Plan Básico.',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Botón de activación con Yape / Plin
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  PagoYapeModal.show(
                    context,
                    planInicial: 'PRO',
                    onPlanUpdated: onPlanUpdated,
                  );
                },
                icon: const Icon(LucideIcons.sparkles, size: 18),
                label: Text(
                  'Mejorar a Plan PRO con Yape / Plin (S/ 100 /mes)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Continuar con Plan Bodega Básico (S/ 50 /mes)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeneficioRow({
    required IconData icon,
    required String titulo,
    required String descripcion,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.accentGreen, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                descripcion,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
