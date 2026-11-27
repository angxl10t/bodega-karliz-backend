import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'notificacion_service.dart';
import 'notificaciones_sheet.dart';

/// Botón con campana y badge numérico de alertas en tiempo real.
/// Se coloca en la barra superior de caja, mostrador y dashboard.
class NotificacionesCampanaButton extends StatelessWidget {
  final VoidCallback? onAbrirPedidosWeb;
  final VoidCallback? onAbrirComprasInventario;
  final Color? iconColor;

  const NotificacionesCampanaButton({
    super.key,
    this.onAbrirPedidosWeb,
    this.onAbrirComprasInventario,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        iconColor ?? (isDark ? Colors.white70 : const Color(0xFF475569));

    return ValueListenableBuilder<int>(
      valueListenable: NotificacionService.noLeidasCountNotifier,
      builder: (context, noLeidas, _) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: noLeidas > 0
                  ? 'Centro de Alertas ($noLeidas sin leer)'
                  : 'Centro de Alertas',
              icon: Icon(
                noLeidas > 0 ? LucideIcons.bellRing : LucideIcons.bell,
                color: noLeidas > 0 ? const Color(0xFFEF4444) : color,
                size: 21,
              ),
              onPressed: () => NotificacionesSheet.show(
                context,
                onAbrirPedidosWeb: onAbrirPedidosWeb,
                onAbrirComprasInventario: onAbrirComprasInventario,
              ),
            ),
            if (noLeidas > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    noLeidas > 99 ? '99+' : '$noLeidas',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
