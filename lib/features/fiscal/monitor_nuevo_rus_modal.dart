import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../home/bodega_service.dart';

class MonitorNuevoRusModal extends StatefulWidget {
  final VoidCallback? onRegimenCambiado;

  const MonitorNuevoRusModal({
    super.key,
    this.onRegimenCambiado,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onRegimenCambiado}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MonitorNuevoRusModal(
        onRegimenCambiado: onRegimenCambiado,
      ),
    );
  }

  @override
  State<MonitorNuevoRusModal> createState() => _MonitorNuevoRusModalState();
}

class _MonitorNuevoRusModalState extends State<MonitorNuevoRusModal> {
  final BodegaService _bodegaService = BodegaService();

  bool _isLoading = true;
  bool _isSaving = false;
  BodegaInfo? _bodegaInfo;
  ResumenNuevoRus? _resumenRus;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bodega = await _bodegaService.obtenerMiBodega();
      final resumen = await _bodegaService.obtenerMonitorNuevoRus();

      if (mounted) {
        setState(() {
          _bodegaInfo = bodega;
          _resumenRus = resumen;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudieron cargar los datos tributarios';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cambiarRegimen(bool esNuevoRus) async {
    final nuevoRegimen = esNuevoRus ? 'NUEVO_RUS' : 'INFORMAL';

    setState(() => _isSaving = true);
    try {
      final infoActualizada = await _bodegaService.actualizarRegimenTributario(nuevoRegimen);
      final nuevoResumen = await _bodegaService.obtenerMonitorNuevoRus();

      if (mounted) {
        setState(() {
          _bodegaInfo = infoActualizada;
          _resumenRus = nuevoResumen;
          _isSaving = false;
        });

        widget.onRegimenCambiado?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  esNuevoRus ? LucideIcons.badgeCheck : LucideIcons.leaf,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    esNuevoRus
                        ? 'Modo actualizado: Bodega en el Nuevo RUS (Ley N° 30877)'
                        : 'Modo actualizado: Bodega Independiente (Sin RUC / Sin SUNAT)',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: esNuevoRus ? AppTheme.accentGreen : const Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar de régimen: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final esNuevoRus = _bodegaInfo?.esNuevoRus ?? (_resumenRus?.esNuevoRus ?? true);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            // Barra superior drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Cabecera Modal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      LucideIcons.landmark,
                      color: Color(0xFF0284C7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frente Fiscal & Tributario',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Realidad del bodeguero peruano • Ley N° 30877',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 20),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Contenido Scrolleable
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.brandPrimary),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.alertTriangle, size: 40, color: AppTheme.alertRed),
                              const SizedBox(height: 12),
                              Text(_errorMessage!),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _cargarDatos,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(20),
                          children: [
                            // 1. Selector Maestro: ¿Comercio en el Nuevo RUS?
                            _buildCardSwitchRegimen(
                              isDark: isDark,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              esNuevoRus: esNuevoRus,
                            ),
                            const SizedBox(height: 18),

                            // 2. Contenido según Régimen
                            if (esNuevoRus) ...[
                              // MONITOR DEL NUEVO RUS (SEMÁFORO Y CUOTAS)
                              if (_resumenRus != null) ...[
                                _buildResumenCuotaCard(
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  resumen: _resumenRus!,
                                ),
                                const SizedBox(height: 16),

                                _buildTermometroVentas(
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  resumen: _resumenRus!,
                                ),
                                const SizedBox(height: 16),

                                _buildDesgloseMetricas(
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  resumen: _resumenRus!,
                                ),
                                const SizedBox(height: 16),

                                _buildGuiaPagoSunat(
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  resumen: _resumenRus!,
                                ),
                              ],
                            ] else ...[
                              // BODEGA INDEPENDIENTE (SIN SUNAT / SIN RUC)
                              _buildCardBodegaInformal(
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta del Switch Principal de Régimen
  Widget _buildCardSwitchRegimen({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required bool esNuevoRus,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esNuevoRus ? AppTheme.accentGreen.withValues(alpha: 0.4) : borderColor,
          width: esNuevoRus ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (esNuevoRus ? AppTheme.accentGreen : const Color(0xFF0D9488))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  esNuevoRus ? LucideIcons.store : LucideIcons.leaf,
                  size: 20,
                  color: esNuevoRus ? AppTheme.accentGreen : const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Bodega inscrita en el Nuevo RUS?',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      esNuevoRus
                          ? 'Formal con RUC 10 ante SUNAT (D.L. 937)'
                          : 'Bodega Independiente (Sin RUC / Sin SUNAT)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              _isSaving
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Switch.adaptive(
                      value: esNuevoRus,
                      activeTrackColor: AppTheme.accentGreen,
                      onChanged: _cambiarRegimen,
                    ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.info,
                  size: 16,
                  color: esNuevoRus ? AppTheme.accentGreen : const Color(0xFF0D9488),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    esNuevoRus
                        ? 'En el Nuevo RUS emites Tickets y Boletas simples. Cero facturas electrónicas. Te ayudamos a monitorear tus topes de S/ 5,000 y S/ 8,000 para pagar solo tu cuota fija (S/ 20 o S/ 50).'
                        : 'Modo Bodega Independiente: Cero obligaciones tributarias, cero cuotas y cero topes. Todos tus tickets son comprobantes de mostrador para tus clientes y tu cuadre de caja diario.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de Cuota Mensual Estimada y Categoría SUNAT
  Widget _buildResumenCuotaCard({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required ResumenNuevoRus resumen,
  }) {
    final esCat1 = resumen.categoriaActual == 'CATEGORIA_1';
    final esCat2 = resumen.categoriaActual == 'CATEGORIA_2';
    final esExcedido = resumen.categoriaActual == 'EXCEDIDO';

    final Color badgeColor = esCat1
        ? AppTheme.accentGreen
        : esCat2
            ? const Color(0xFFD97706)
            : AppTheme.alertRed;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.calendarDays, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    resumen.periodoNombre.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0284C7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  esCat1 ? 'CAT. 1' : esCat2 ? 'CAT. 2' : 'EXCEDIDO',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                esExcedido ? 'Límite Superado' : 'S/ ${resumen.cuotaMensualEstimada.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: esExcedido ? AppTheme.alertRed : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                esExcedido ? '' : 'cuota mensual SUNAT',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            resumen.mensajeDiagnostico,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              height: 1.4,
            ),
          ),

          if (resumen.advertencia != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, size: 16, color: AppTheme.alertRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      resumen.advertencia!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.alertRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Termómetro / Barra de Progreso Tricolor
  Widget _buildTermometroVentas({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required ResumenNuevoRus resumen,
  }) {
    final progresoCat2 = (resumen.porcentajeCat2 / 100).clamp(0.0, 1.0);
    final esCat1 = resumen.categoriaActual == 'CATEGORIA_1';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Termómetro Mensual del Nuevo RUS',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Tope: S/ 8,000.00',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barra tricolor con fondo
          Stack(
            children: [
              // Fondo base de la barra
              Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              // Tramo de progreso
              FractionallySizedBox(
                widthFactor: progresoCat2,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentGreen,
                        if (progresoCat2 > 0.62) const Color(0xFFF59E0B),
                        if (progresoCat2 > 0.90) AppTheme.alertRed,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Marcadores de límites
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'S/ 0',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF94A3B8)),
              ),
              Text(
                'S/ 5,000 (Cat. 1)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentGreen,
                ),
              ),
              Text(
                'S/ 8,000 (Cat. 2)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Saldo disponible para mantenerse en categoría
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.shieldCheck,
                  size: 16,
                  color: esCat1 ? AppTheme.accentGreen : const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    esCat1
                        ? 'Margen restante en Cat. 1: S/ ${resumen.restanteCat1.toStringAsFixed(2)}'
                        : 'Margen restante antes del tope máximo: S/ ${resumen.restanteCat2.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desglose de Ventas vs Compras
  Widget _buildDesgloseMetricas({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required ResumenNuevoRus resumen,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.trendingUp, size: 16, color: AppTheme.accentGreen),
                    const SizedBox(width: 6),
                    Text(
                      'Ventas del Mes',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'S/ ${resumen.totalVentasMes.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.truck, size: 16, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Text(
                      'Compras del Mes',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'S/ ${resumen.totalComprasMes.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Guía Práctica de Pago SUNAT (Pago Fácil Nuevo RUS)
  Widget _buildGuiaPagoSunat({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required ResumenNuevoRus resumen,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(LucideIcons.receipt, size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(
                '¿Cómo pagar tu cuota del Nuevo RUS?',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            resumen.sugerenciaPagoSunat ??
                'Paga en agentes BCP, BBVA, Interbank, Banco de la Nación o App SUNAT con tu número de RUC y periodo tributario.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.checkCircle2, size: 16, color: AppTheme.accentGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No necesitas contador ni llevar libros electrónicos mensuales en el Nuevo RUS.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Contenido cuando la bodega es independiente (fuera del Nuevo RUS / Sin SUNAT)
  Widget _buildCardBodegaInformal({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF0D9488).withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.leaf,
                  color: Color(0xFF0D9488),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🌿 Bodega Independiente (Sin SUNAT)',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Control 100% libre de trámites, topes e impuestos',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tu bodega opera de forma libre sin registro en SUNAT. En este modo:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12),
          _buildItemLista(
            icon: LucideIcons.receipt,
            texto: 'Mostrador enfocado: emite únicamente Tickets de Venta / Notas de Mostrador para entregar a tus clientes.',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildItemLista(
            icon: LucideIcons.shieldCheck,
            texto: 'Cero cuotas mensuales a pagar, sin declaraciones ni límites o semáforos de S/ 5,000 o S/ 8,000.',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildItemLista(
            icon: LucideIcons.sparkles,
            texto: 'Control total de tu negocio: cuadre diario de caja, control de stock de abarrotes y fiados vecinales.',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 18,
                  color: Color(0xFF0D9488),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Si más adelante decides inscribirte en el Nuevo RUS, obtendrás tu RUC 10 gratis en 5 min desde el celular (App Personas SUNAT) con tu DNI.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(LucideIcons.arrowLeftRight, size: 18),
              label: Text(
                'Cambiar mi bodega al Nuevo RUS',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => _cambiarRegimen(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemLista({
    required IconData icon,
    required String texto,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0D9488)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
