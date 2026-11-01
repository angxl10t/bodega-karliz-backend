import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../features/home/bodega_service.dart';

class PagoYapeModal {
  static Future<void> show(
    BuildContext context, {
    String planInicial = 'PRO',
    VoidCallback? onPlanUpdated,
  }) {
    final codOperacionCtrl = TextEditingController();
    String planSeleccionado = (planInicial.toUpperCase() == 'PRO') ? 'PRO' : 'BASICO';
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                          child: Icon(LucideIcons.qrCode, color: walletPrimary, size: 24),
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
                                  color: isDark ? Colors.white : AppTheme.textDark,
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
                          onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'SELECCIONA EL PLAN A ACTIVAR / RENOVAR:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => planSeleccionado = 'BASICO'),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              decoration: BoxDecoration(
                                color: planSeleccionado == 'BASICO'
                                    ? AppTheme.brandPrimary.withValues(alpha: 0.12)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
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
                                      color: isDark ? Colors.white : AppTheme.textDark,
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
                                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
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
                            onTap: () => setModalState(() => planSeleccionado = 'PRO'),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              decoration: BoxDecoration(
                                color: planSeleccionado == 'PRO'
                                    ? AppTheme.accentGreen.withValues(alpha: 0.12)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
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
                                          color: isDark ? Colors.white : AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(LucideIcons.sparkles, size: 12, color: AppTheme.accentGreen),
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
                                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
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
                        color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => billetera = 'YAPE'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
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
                                          : (isDark ? Colors.white60 : AppTheme.textDark),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => billetera = 'PLIN'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
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
                                          : (isDark ? Colors.white60 : AppTheme.textDark),
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
                        border: Border.all(color: walletPrimary.withValues(alpha: 0.2)),
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
                              border: Border.all(color: walletPrimary.withValues(alpha: 0.25), width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/images/yape_qr_cajaya.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Icon(LucideIcons.qrCode, color: walletPrimary, size: 54),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.checkCheck, size: 13, color: AppTheme.accentGreen),
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
                          const SizedBox(height: 2),
                          Text(
                            'Escanea directamente con Yape o Plin',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
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

                    TextFormField(
                      controller: codOperacionCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Código de Operación ($billetera)',
                        hintText: 'Ej: 849201 (6 a 10 dígitos)',
                        prefixIcon: const Icon(LucideIcons.receiptText, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        helperText: 'Validación en tiempo real vía pasarela $billetera',
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: walletPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final cod = codOperacionCtrl.text.trim();
                              if (cod.length < 4) {
                                setModalState(() => modalError = 'Ingresa un código de operación válido (mín. 4 dígitos).');
                                return;
                              }

                              final messenger = ScaffoldMessenger.of(context);
                              setModalState(() {
                                isSubmitting = true;
                                modalError = '';
                              });

                              try {
                                await bodegaService.registrarPagoYape(
                                  codigoOperacion: cod,
                                  plan: planSeleccionado,
                                  monto: monto,
                                  billetera: billetera,
                                );

                                if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                                onPlanUpdated?.call();

                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.accentGreen,
                                    content: Text(
                                      '¡Suscripción actualizada exitosamente con $billetera! Tu plan $planSeleccionado está activo por 30 días adicionales.',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                setModalState(() {
                                  isSubmitting = false;
                                  modalError = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'CONFIRMAR Y ACTIVAR SUSCRIPCIÓN',
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800),
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
