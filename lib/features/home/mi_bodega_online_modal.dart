import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';

class MiBodegaOnlineModal extends StatelessWidget {
  final String nombreBodega;
  final String telefonoBodega;

  const MiBodegaOnlineModal({
    super.key,
    required this.nombreBodega,
    this.telefonoBodega = '',
  });

  static Future<void> show(BuildContext context, {required String nombreBodega, String telefonoBodega = ''}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MiBodegaOnlineModal(
        nombreBodega: nombreBodega,
        telefonoBodega: telefonoBodega,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slug = nombreBodega.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
    final catalogoUrl = 'https://cajaya-pos.onrender.com/#/catalogo?tienda=$slug';

    final mensajeWhatsApp = '¡Hola vecino! 👋\n\n'
        'Ya puedes revisar todos los productos, ofertas y precios actualizados de *$nombreBodega* en nuestro catálogo digital:\n'
        '$catalogoUrl\n\n'
        'Elige tus productos y mándanos tu pedido por aquí para tenerlo listo al instante. ¡Gracias por tu preferencia!';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.globe, color: AppTheme.brandPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Mi Bodega Online',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PLAN PRO',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Tu vitrina digital para pedidos de vecinos por WhatsApp',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Tarjeta de Enlace
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ENLACE DIGITAL DE TU TIENDA:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.brandPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        catalogoUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.copy, size: 16),
                      tooltip: 'Copiar Enlace',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: catalogoUrl));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enlace copiado al portapapeles.'),
                            backgroundColor: AppTheme.brandPrimary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botón Principal: Compartir por WhatsApp
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(LucideIcons.send, size: 18),
              label: Text(
                'Compartir Catálogo por WhatsApp',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(mensajeWhatsApp)}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
          const SizedBox(height: 10),

          // Botón Secundario: Probar Enlace
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppTheme.textDark,
                side: BorderSide(color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(LucideIcons.externalLink, size: 16),
              label: Text(
                'Ver Catálogo como Cliente',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                final uri = Uri.parse(catalogoUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
