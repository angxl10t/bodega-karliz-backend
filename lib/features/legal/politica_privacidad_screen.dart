import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/cajaya_vectors.dart';
import '../../core/theme.dart';

class PoliticaPrivacidadScreen extends StatelessWidget {
  const PoliticaPrivacidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CajaYaLogoMark(size: 26),
            const SizedBox(width: 8),
            Text(
              'Política de Privacidad',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Política de Privacidad y Tratamiento de Datos',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Conforme a la Ley N° 29733 (Ley de Protección de Datos Personales del Perú)\nÚltima actualización: Noviembre 2026',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
                const Divider(height: 32),

                _buildSeccion(
                  isDark: isDark,
                  titulo: '1. Compromiso de Privacidad',
                  contenido: 'CajaYa Cloud POS (en adelante, "CajaYa") respeta el derecho a la privacidad de sus usuarios, clientes y vecinos consumidores. En cumplimiento de la Ley N° 29733 y su Reglamento aprobado por D.S. N° 003-2013-JUS, informamos el tratamiento que otorgamos a los datos recopilados en nuestra aplicación móvil y plataforma web.',
                ),

                _buildSeccion(
                  isDark: isDark,
                  titulo: '2. Información que Recopilamos',
                  contenido:
                      'Para prestar el servicio, recopilamos únicamente los datos necesarios según el perfil de uso:\n\n'
                      '• Datos del Comerciante / Bodeguero: Nombre o razón social, RUC o DNI, dirección del establecimiento, número de teléfono o WhatsApp, y credenciales de acceso seguras (contraseña y PIN de turno).\n'
                      '• Datos Operativos del POS: Catálogo de productos, precios, registros de ventas, apertura y cierre de caja, y control de cuentas corrientes (fiados).\n'
                      '• Datos del Consumidor en Catálogo Web: Nombre o alias y número de WhatsApp para remitir pedidos a la tienda seleccionada.\n'
                      '• Datos de Reclamaciones: Datos de contacto y pretensión del reclamante conforme al Libro de Reclamaciones de INDECOPI.',
                ),

                _buildSeccion(
                  isDark: isDark,
                  titulo: '3. Permisos Solicitados en el Dispositivo Móvil',
                  contenido:
                      'La aplicación requiere permisos estrictamente vinculados a su funcionamiento operativo en el mostrador:\n\n'
                      '• Cámara: Utilizada exclusivamente para el lector óptico de códigos de barras (EAN-13) de los productos del catálogo. No se capturan ni transmiten fotografías personales.\n'
                      '• Bluetooth / Ubicación aproximada: Requerido por el sistema operativo Android para la detección y vinculación de impresoras térmicas de tickets (ESC/POS).\n'
                      '• Almacenamiento Local: Para mantener la caché del inventario y permitir la emisión de ventas en modo Offline ante caídas de internet.',
                ),

                _buildSeccion(
                  isDark: isDark,
                  titulo: '4. Seguridad y Aislamiento de Información (Multi-Tenant)',
                  contenido: 'Implementamos políticas de Row Level Security (RLS) en base de datos PostgreSQL, garantizando aislamiento estricto entre tiendas. Ningún comercio o usuario no autorizado puede acceder a la información contable, clientes o ventas de otra bodega.',
                ),

                _buildSeccion(
                  isDark: isDark,
                  titulo: '5. Derechos ARCO (Acceso, Rectificación, Cancelación y Oposición)',
                  contenido: 'El titular de los datos personales puede ejercer en cualquier momento sus derechos de información, acceso, rectificación, cancelación y oposición comunicándose a nuestro canal de soporte legal vía correo electrónico a privacidad@cajaya-pos.onrender.com o mediante el WhatsApp oficial de la plataforma.',
                ),

                _buildSeccion(
                  isDark: isDark,
                  titulo: '6. Modificaciones a la Política',
                  contenido: 'Cualquier cambio a la presente Política de Privacidad será comunicado oportunamente mediante la aplicación y nuestro sitio web oficial.',
                ),

                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'CajaYa Cloud POS © 2026 • Privacidad y Seguridad Garantizada',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeccion({
    required bool isDark,
    required String titulo,
    required String contenido,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: GoogleFonts.outfit(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.brandPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            contenido,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
