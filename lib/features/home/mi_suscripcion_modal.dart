import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/widgets/pago_yape_modal.dart';
import '../../core/widgets/plan_comparativa_table.dart';
import 'bodega_service.dart';

class MiSuscripcionModal extends StatefulWidget {
  final String nombreBodega;
  final String planActual;
  final VoidCallback? onPlanUpdated;

  const MiSuscripcionModal({
    super.key,
    required this.nombreBodega,
    required this.planActual,
    this.onPlanUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String nombreBodega,
    required String planActual,
    VoidCallback? onPlanUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MiSuscripcionModal(
        nombreBodega: nombreBodega,
        planActual: planActual,
        onPlanUpdated: onPlanUpdated,
      ),
    );
  }

  @override
  State<MiSuscripcionModal> createState() => _MiSuscripcionModalState();
}

class _MiSuscripcionModalState extends State<MiSuscripcionModal> {
  final BodegaService _bodegaService = BodegaService();
  bool _isLoading = true;
  int _diasRestantes = 30;
  String _estadoSuscripcion = 'ACTIVO';
  DateTime? _fechaVencimiento;

  @override
  void initState() {
    super.initState();
    _cargarInfoBodega();
  }

  Future<void> _cargarInfoBodega() async {
    try {
      final info = await _bodegaService.obtenerMiBodega();
      if (mounted) {
        setState(() {
          _isLoading = false;

          if (info?.fechaVencimientoPlan != null) {
            try {
              _fechaVencimiento = DateTime.parse(info!.fechaVencimientoPlan!);
              final diff = _fechaVencimiento!.difference(DateTime.now()).inDays;
              _diasRestantes = diff >= 0 ? diff : 0;
              if (diff > 5) {
                _estadoSuscripcion = 'ACTIVO';
              } else if (diff >= 0) {
                _estadoSuscripcion = 'POR_VENCER';
              } else {
                _estadoSuscripcion = 'VENCIDO';
              }
            } catch (_) {}
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _contactarWhatsAppComercial() async {
    final bodegaNombre = widget.nombreBodega.isNotEmpty
        ? widget.nombreBodega
        : 'Mi Bodega';
    final plan = widget.planActual.toUpperCase();
    final mensaje =
        'Hola, soy de la bodega "$bodegaNombre" (Plan $plan). Deseo renovar o coordinar mi mensualidad de CajaYa Cloud POS.';

    final uri = PagoYapeModal.buildWhatsAppSupportUri(mensaje);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp automáticamente.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPro = widget.planActual.toUpperCase() == 'PRO';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (_estadoSuscripcion == 'VENCIDO') {
      statusColor = AppTheme.alertRed;
      statusText = 'Plan Vencido';
      statusIcon = LucideIcons.alertTriangle;
    } else if (_estadoSuscripcion == 'POR_VENCER') {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'Por Vencer ($_diasRestantes días)';
      statusIcon = LucideIcons.clock;
    } else {
      statusColor = AppTheme.accentGreen;
      statusText = 'Plan Activo ($_diasRestantes días)';
      statusIcon = LucideIcons.checkCircle2;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de arrastre
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

            // Cabecera
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
                            color: AppTheme.brandPrimary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.crown,
                            color: AppTheme.brandPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mi Plan y Suscripción',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                widget.nombreBodega.isNotEmpty
                                    ? widget.nombreBodega
                                    : 'CajaYa Cloud POS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),

            // Contenido Scrolleable
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Tarjeta de Estado del Plan Actual
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        const Color(0xFF1E293B),
                                        const Color(0xFF0F172A),
                                      ]
                                    : [
                                        const Color(0xFFF8FAFC),
                                        const Color(0xFFEEF2F6),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            isPro
                                                ? 'Plan Minimarket PRO'
                                                : 'Plan Bodega Básico',
                                            style: GoogleFonts.outfit(
                                              fontSize: 17.5,
                                              fontWeight: FontWeight.w900,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppTheme.textDark,
                                            ),
                                          ),
                                        ),
                                        if (isPro) ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                            LucideIcons.sparkles,
                                            color: Color(0xFFF59E0B),
                                            size: 16,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            statusIcon,
                                            color: statusColor,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              statusText,
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isPro
                                      ? 'Tarifa: S/ 100.00 /mes • Catálogo Ilimitado + Ventas Online'
                                      : 'Tarifa: S/ 50.00 /mes • POS Rápido + Caja Diaria',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.brandPrimary,
                                  ),
                                ),
                                if (_fechaVencimiento != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Fecha de Corte / Renovación: ${_fechaVencimiento!.day}/${_fechaVencimiento!.month}/${_fechaVencimiento!.year}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 2. Información de Cobro Transparente (Gestión Directa por Macro / Sin Débito Automático)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.brandPrimary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.brandPrimary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.shieldCheck,
                                  color: AppTheme.brandPrimary,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gestión de Cobro 100% Controlada',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? AppTheme.brandLight
                                              : AppTheme.brandDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'No realizamos débitos automáticos en tarjeta. El pago mensual se coordina de forma directa vía Yape, Plin o WhatsApp.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? AppTheme.textDarkSecondary
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 3. Botones de Acción (Renovación y Soporte)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final yapeBtn = ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF732283),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(LucideIcons.qrCode, size: 18),
                                label: Text(
                                  'Pagar con Yape / Plin',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  PagoYapeModal.show(
                                    context,
                                    planInicial: widget.planActual,
                                    onPlanUpdated: widget.onPlanUpdated,
                                  );
                                },
                              );
                              final whatsappBtn = OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF16A34A),
                                  side: const BorderSide(
                                    color: Color(0xFF16A34A),
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(
                                  LucideIcons.messageCircle,
                                  size: 18,
                                ),
                                label: Text(
                                  'WhatsApp Oficial',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: _contactarWhatsAppComercial,
                              );

                              if (constraints.maxWidth < 330) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    yapeBtn,
                                    const SizedBox(height: 10),
                                    whatsappBtn,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: yapeBtn),
                                  const SizedBox(width: 10),
                                  Expanded(child: whatsappBtn),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 22),

                          // 4. Beneficios incluidos en el Plan Activo
                          Text(
                            isPro
                                ? 'INCLUIDO EN TU PLAN MINIMARKET PRO:'
                                : 'INCLUIDO EN TU PLAN BODEGA BÁSICO:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),

                          if (isPro) ...[
                            _buildFeatureItem(
                              icon: LucideIcons.shoppingBag,
                              title: 'Catálogo Digital "Mi Bodega Online"',
                              subtitle: 'Enlace web propio para recibir pedidos de clientes por WhatsApp sin comisiones.',
                              isDark: isDark,
                            ),
                            _buildFeatureItem(
                              icon: LucideIcons.infinity,
                              title: 'Inventario y Catálogo Ilimitado',
                              subtitle: 'Registra todos los productos, códigos y presentaciones de tu minimarket.',
                              isDark: isDark,
                            ),
                            _buildFeatureItem(
                              icon: LucideIcons.badgePercent,
                              title: 'Promociones 3x2, Combos y Detector Hueso',
                              subtitle: 'Campañas automáticas y alertas de capital inmovilizado.',
                              isDark: isDark,
                            ),
                            _buildFeatureItem(
                              icon: LucideIcons.eyeOff,
                              title:
                                  'Auditoría Ciega, BI & Cierre por WhatsApp',
                              subtitle: 'Control anti-robo hormiga, utilidad neta y resumen al dueño.',
                              isDark: isDark,
                            ),
                          ] else ...[
                            _buildFeatureItem(
                              icon: LucideIcons.scanBarcode,
                              title: 'POS Rápido & Tickets Térmicos 58/80mm',
                              subtitle: 'Cobro ágil con escáner de código de barras e impresión directa.',
                              isDark: isDark,
                            ),
                            _buildFeatureItem(
                              icon: LucideIcons.package,
                              title: 'Inventario Activo (Hasta 150 productos)',
                              subtitle: 'Control de stock en tiempo real y alertas de vencimiento básicas.',
                              isDark: isDark,
                            ),
                            _buildFeatureItem(
                              icon: LucideIcons.wallet,
                              title:
                                  'Caja Diaria, Yape/Plin y Libreta de Fiados',
                              subtitle: 'Apertura, egresos, arqueo de turno y cuentas por cobrar de vecinos.',
                              isDark: isDark,
                            ),
                            _buildFeatureItem(
                              icon: LucideIcons.users,
                              title: 'Modo Offline & Personal Ilimitado',
                              subtitle: 'Vende incluso sin internet con roles de administrador y cajeros.',
                              isDark: isDark,
                            ),
                          ],

                          const SizedBox(height: 10),
                          PlanComparativaTable(
                            highlightedPlan: isPro ? 'PRO' : 'BASICO',
                            title: 'COMPARATIVA DETALLADA: BÁSICO VS PRO',
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppTheme.accentGreen),
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
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
    );
  }
}
