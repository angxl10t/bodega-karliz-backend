import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../features/home/bodega_service.dart';

class PagoYapeModal {
  /// Número oficial de Yape / Plin y WhatsApp de soporte/suscripciones CajaYa POS.
  static const String officialPhoneLocal = '981006081';
  static const String officialPhoneE164 = '51981006081';
  static const String officialYapeDisplay = '981 006 081';
  static const String officialPhoneDisplay = '+51 981 006 081';

  /// Camino de cobro activo:
  /// - `false` (Camino A): registra el comprobante (`PENDIENTE`) + envío por WhatsApp y activación manual desde SuperAdmin.
  /// - `true` (Camino B): conciliación automática inmediata vía webhook MacroDroid.
  static const bool yapeWebhookAutomaticoActivo = false;

  static Uri buildWhatsAppSupportUri(String mensaje) {
    return Uri.parse(
      'https://wa.me/$officialPhoneE164?text=${Uri.encodeComponent(mensaje)}',
    );
  }

  static Future<void> _abrirWhatsApp({
    required BuildContext context,
    required String plan,
    required double monto,
    String? codigoOperacion,
  }) async {
    final cod = (codigoOperacion != null && codigoOperacion.isNotEmpty)
        ? ' Código de operación: $codigoOperacion.'
        : '';
    final mensaje =
        'Hola, adjunto mi comprobante de pago para mi suscripción CajaYa Cloud POS (Plan $plan - S/ ${monto.toStringAsFixed(2)}).$cod Favor de confirmar la activación.';
    final uri = buildWhatsAppSupportUri(mensaje);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Comunícate al WhatsApp oficial: $officialPhoneDisplay',
            ),
          ),
        );
      }
    }
  }

  static Future<void> _mostrarDialogoComprobanteReportado({
    required BuildContext context,
    required bool isDark,
    required String codigoOperacion,
    required String planSeleccionado,
    required double monto,
  }) {
    final String detalle = yapeWebhookAutomaticoActivo
        ? 'Tu operación N° $codigoOperacion ha sido registrada como PENDIENTE.\n\nEl sistema la validará en breve. También puedes enviar tu captura por WhatsApp al $officialYapeDisplay para agilizar la atención.'
        : 'Tu operación N° $codigoOperacion ha sido registrada como PENDIENTE.\n\nVerificaremos tu abono manualmente y activaremos tu Plan $planSeleccionado en minutos. Envía tu captura por WhatsApp al $officialYapeDisplay para atención inmediata.';

    return showDialog(
      context: context,
      builder: (alertCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.clockAlert,
                color: Color(0xFFD97706),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Comprobante Reportado',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          detalle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(alertCtx),
            child: Text(
              'Cerrar',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(alertCtx);
              _abrirWhatsApp(
                context: context,
                plan: planSeleccionado,
                monto: monto,
                codigoOperacion: codigoOperacion,
              );
            },
            icon: const Icon(LucideIcons.messageCircle, size: 16),
            label: const Text('Enviar a WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> show(
    BuildContext context, {
    String planInicial = 'PRO',
    VoidCallback? onPlanUpdated,
  }) {
    final codOperacionCtrl = TextEditingController();
    String planSeleccionado = (planInicial.toUpperCase() == 'PRO')
        ? 'PRO'
        : 'BASICO';
    String billetera = 'YAPE';
    bool isSubmitting = false;
    String modalError = '';
    final BodegaService bodegaService = BodegaService();

    return showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          final double monto = planSeleccionado == 'PRO' ? 100.0 : 50.0;
          final Color walletPrimary = billetera == 'YAPE'
              ? const Color(0xFF732283)
              : const Color(0xFF0084FF);

          return Dialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: walletPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            LucideIcons.qrCode,
                            color: walletPrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pago Directo Yape / Plin',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                '0% Comisiones • Renovación Inmediata',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'SELECCIONA EL PLAN A ACTIVAR / RENOVAR:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(
                              () => planSeleccionado = 'BASICO',
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: planSeleccionado == 'BASICO'
                                    ? AppTheme.brandPrimary.withValues(
                                        alpha: 0.12,
                                      )
                                    : (isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: planSeleccionado == 'BASICO'
                                      ? AppTheme.brandPrimary
                                      : Colors.transparent,
                                  width: 1.8,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Plan Bodega',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'S/ 50.00 /mes',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.brandPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'POS + Stock + Caja diaria',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF334155),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setModalState(() => planSeleccionado = 'PRO'),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: planSeleccionado == 'PRO'
                                    ? AppTheme.accentGreen.withValues(
                                        alpha: 0.12,
                                      )
                                    : (isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: planSeleccionado == 'PRO'
                                      ? AppTheme.accentGreen
                                      : Colors.transparent,
                                  width: 1.8,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Plan PRO',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        LucideIcons.sparkles,
                                        size: 12,
                                        color: AppTheme.accentGreen,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'S/ 100.00 /mes',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Online + Hueso + Anti-Robo + BI',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF334155),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.cardDarkSunken
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setModalState(() => billetera = 'YAPE'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: billetera == 'YAPE'
                                      ? const Color(0xFF732283)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'YAPE',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: billetera == 'YAPE'
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white60
                                                : AppTheme.textDark),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setModalState(() => billetera = 'PLIN'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: billetera == 'PLIN'
                                      ? const Color(0xFF0084FF)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'PLIN',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: billetera == 'PLIN'
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white60
                                                : AppTheme.textDark),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: walletPrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: walletPrimary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: walletPrimary.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: walletPrimary.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/images/yape_qr_cajaya.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                      child: Icon(
                                        LucideIcons.qrCode,
                                        color: walletPrimary,
                                        size: 54,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.checkCheck,
                                      size: 13,
                                      color: AppTheme.accentGreen,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'QR Oficial Interoperable',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accentGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Titular: Luis T.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              await Clipboard.setData(
                                const ClipboardData(text: officialPhoneLocal),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Número Yape/Plin copiado: $officialYapeDisplay',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: walletPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: walletPrimary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.copy,
                                    size: 13,
                                    color: walletPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Número $billetera: $officialYapeDisplay',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: walletPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Escanea el QR o yapea al número indicado',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: walletPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Monto exacto a pagar: S/ ${monto.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: walletPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (modalError.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.alertRed.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  LucideIcons.alertTriangle,
                                  color: AppTheme.alertRed,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    modalError,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: AppTheme.alertRed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: isSubmitting
                                  ? null
                                  : () async {
                                      final cod = codOperacionCtrl.text.trim();
                                      if (cod.length < 4) {
                                        setModalState(
                                          () => modalError = 'Ingresa un código de operación válido para reportar.',
                                        );
                                        return;
                                      }

                                      setModalState(() {
                                        isSubmitting = true;
                                        modalError = '';
                                      });

                                      try {
                                        await bodegaService.reportarPagoManual(
                                          codigoOperacion: cod,
                                          plan: planSeleccionado,
                                          monto: monto,
                                          billetera: billetera,
                                        );

                                        if (dialogCtx.mounted) {
                                          Navigator.pop(dialogCtx);
                                        }

                                        onPlanUpdated?.call();

                                        if (context.mounted) {
                                          _mostrarDialogoComprobanteReportado(
                                            context: context,
                                            isDark: isDark,
                                            codigoOperacion: cod,
                                            planSeleccionado: planSeleccionado,
                                            monto: monto,
                                          );
                                        }
                                      } catch (errReport) {
                                        setModalState(() {
                                          isSubmitting = false;
                                          modalError = errReport
                                              .toString()
                                              .replaceAll('Exception: ', '');
                                        });
                                      }
                                    },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.shade700.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.fileCheck2,
                                      size: 15,
                                      color: Colors.amber.shade800,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '¿Ya transferiste? Reportar comprobante y enviar por WhatsApp',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.amber.shade900,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    TextFormField(
                      controller: codOperacionCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Código de Operación ($billetera)',
                        hintText: 'Ej: 849201 (6 a 10 dígitos)',
                        prefixIcon: const Icon(
                          LucideIcons.receiptText,
                          size: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        helperText: yapeWebhookAutomaticoActivo
                            ? 'Validación en tiempo real vía pasarela $billetera'
                            : 'Tras transferir, registra el N° de operación para validar y activar tu plan.',
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: walletPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final cod = codOperacionCtrl.text.trim();
                              if (cod.length < 4) {
                                setModalState(
                                  () => modalError = 'Ingresa un código de operación válido (mín. 4 dígitos).',
                                );
                                return;
                              }

                              final messenger = ScaffoldMessenger.of(context);
                              setModalState(() {
                                isSubmitting = true;
                                modalError = '';
                              });

                              try {
                                if (yapeWebhookAutomaticoActivo) {
                                  await bodegaService.registrarPagoYape(
                                    codigoOperacion: cod,
                                    plan: planSeleccionado,
                                    monto: monto,
                                    billetera: billetera,
                                  );

                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }

                                  onPlanUpdated?.call();

                                  messenger.showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.accentGreen,
                                      content: Text(
                                        '¡Suscripción actualizada exitosamente con $billetera! Tu plan $planSeleccionado está activo por 30 días adicionales.',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  await bodegaService.reportarPagoManual(
                                    codigoOperacion: cod,
                                    plan: planSeleccionado,
                                    monto: monto,
                                    billetera: billetera,
                                  );

                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }

                                  onPlanUpdated?.call();

                                  if (context.mounted) {
                                    _mostrarDialogoComprobanteReportado(
                                      context: context,
                                      isDark: isDark,
                                      codigoOperacion: cod,
                                      planSeleccionado: planSeleccionado,
                                      monto: monto,
                                    );
                                  }
                                }
                              } catch (e) {
                                setModalState(() {
                                  isSubmitting = false;
                                  modalError = e.toString().replaceAll(
                                    'Exception: ',
                                    '',
                                  );
                                });
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              yapeWebhookAutomaticoActivo
                                  ? 'CONFIRMAR Y ACTIVAR SUSCRIPCIÓN'
                                  : 'REGISTRAR COMPROBANTE Y SOLICITAR ACTIVACIÓN',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () => _abrirWhatsApp(
                              context: context,
                              plan: planSeleccionado,
                              monto: monto,
                              codigoOperacion: codOperacionCtrl.text.trim(),
                            ),
                      icon: const Icon(
                        LucideIcons.messageCircle,
                        size: 16,
                        color: AppTheme.accentGreen,
                      ),
                      label: Text(
                        'Enviar comprobante directo por WhatsApp',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF334155),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: isDark
                              ? AppTheme.borderDark
                              : const Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
