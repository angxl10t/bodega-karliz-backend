import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'theme.dart';

/// Logotipo vectorial oficial de CajaYa (SaaS Cloud POS)
class CajaYaLogoMark extends StatelessWidget {
  final double size;
  final bool inverted;
  final Color? customColor;

  const CajaYaLogoMark({
    super.key,
    this.size = 40,
    this.inverted = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final primary = customColor ?? AppTheme.brandPrimary;
    final dark = customColor != null ? customColor!.withValues(alpha: 0.85) : AppTheme.brandDark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: inverted
              ? [Colors.white, const Color(0xFFE2E8F0)]
              : [primary, dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.28),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.58,
          height: size * 0.58,
          child: CustomPaint(
            painter: _CajaYaLogoPainter(
              color: inverted ? primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _CajaYaLogoPainter extends CustomPainter {
  final Color color;
  _CajaYaLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Terminal POS / Caja registradora moderna
    // 1. Pantalla inclinada
    final screenPath = Path()
      ..moveTo(w * 0.12, h * 0.15)
      ..lineTo(w * 0.88, h * 0.15)
      ..lineTo(w * 0.82, h * 0.65)
      ..lineTo(w * 0.18, h * 0.65)
      ..close();
    canvas.drawPath(screenPath, strokePaint);

    // 2. Base de caja con ranura de ticket
    final basePath = Path()
      ..moveTo(w * 0.10, h * 0.88)
      ..lineTo(w * 0.90, h * 0.88);
    canvas.drawPath(basePath, strokePaint);

    // 3. Rayo / Flecha de velocidad "Ya" (Checkmark dinámico central)
    final checkPath = Path()
      ..moveTo(w * 0.32, h * 0.40)
      ..lineTo(w * 0.46, h * 0.52)
      ..lineTo(w * 0.70, h * 0.28);
    canvas.drawPath(checkPath, strokePaint);

    // 4. Ranura frontal de efectivo/tarjeta
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.35, h * 0.74, w * 0.30, h * 0.08),
        Radius.circular(w * 0.04),
      ),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CajaYaLogoPainter oldDelegate) => oldDelegate.color != color;
}

/// Gráfico Vectorial Tecnológico B2B para la pantalla de Login y Portada SaaS
/// Representa un terminal POS en la nube, métricas en vivo y pagos digitales ágiles.
class CajaYaHeroGraphic extends StatelessWidget {
  final double width;
  final double height;

  const CajaYaHeroGraphic({
    super.key,
    this.width = 240,
    this.height = 175,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.brandPrimary;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF111827), const Color(0xFF0F172A)]
              : [const Color(0xFFF0F7FF), const Color(0xFFE0EFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark
              ? primary.withValues(alpha: 0.3)
              : const Color(0xFFBFDBFE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Patrón de fondo tecnológico sutil
          Positioned(
            right: -15,
            top: -15,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: isDark ? 0.08 : 0.06),
              ),
            ),
          ),

          // Contenedor principal: Terminal POS Digital
          Container(
            width: width * 0.82,
            height: height * 0.72,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Barra superior: Indicador Live & Nube
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.accentGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'POS ONLINE',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      LucideIcons.cloudCheck,
                      size: 15,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ],
                ),

                // Centro: Monto de venta en soles y gráfica rápida
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Venta Rápida',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          'S/ 124.50',
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppTheme.brandInk,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),

                    // Mini barras de ventas
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBar(height: 12, primary: primary),
                        const SizedBox(width: 3),
                        _buildBar(height: 20, primary: primary),
                        const SizedBox(width: 3),
                        _buildBar(height: 16, primary: primary),
                        const SizedBox(width: 3),
                        _buildBar(height: 26, primary: primary, active: true),
                      ],
                    ),
                  ],
                ),

                // Barra inferior: Chips de métodos de pago
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPaymentBadge('YAPE / PLIN', isDark),
                      const SizedBox(width: 5),
                      _buildPaymentBadge('EFECTIVO', isDark),
                      const SizedBox(width: 5),
                      _buildPaymentBadge('TARJETA', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Badge flotante superior izquierdo: Escáner de código de barras
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.scanLine, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '1-CLICK',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Badge flotante inferior derecho: Impresión térmica instantánea
          Positioned(
            right: 12,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.printer, size: 12, color: AppTheme.accentGreen),
                  const SizedBox(width: 4),
                  Text(
                    'TICKET ESC/POS',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildBar({required double height, required Color primary, bool active = false}) {
    return Container(
      width: 5,
      height: height,
      decoration: BoxDecoration(
        color: active ? primary : primary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  static Widget _buildPaymentBadge(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
      ),
    );
  }
}
