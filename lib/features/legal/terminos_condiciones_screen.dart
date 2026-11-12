import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/cajaya_vectors.dart';
import '../../core/theme.dart';

class TerminosCondicionesScreen extends StatelessWidget {
  const TerminosCondicionesScreen({super.key});

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
              'Términos y Condiciones',
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
                // Header
                Text(
                  'Términos y Condiciones de Uso del Servicio',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CajaYa Cloud POS • Plataforma SaaS de Gestión y Catálogo Digital para Bodegas del Perú\nÚltima actualización: Noviembre 2026',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
                const Divider(height: 32),

                _buildClausula(
                  isDark: isDark,
                  numero: '1',
                  titulo: 'Aceptación y Objeto del Servicio',
                  contenido: 'El presente documento regula el acceso y uso de la plataforma CajaYa Cloud POS (en adelante, "CajaYa"), software de punto de venta (POS) y catálogo digital en la nube diseñado para bodegas, minimarkets y comercios minoristas del Perú. Al acceder, registrarse o utilizar el sistema, el usuario declara haber leído, comprendido y aceptado en su totalidad estos Términos y Condiciones.',
                ),

                _buildClausula(
                  isDark: isDark,
                  numero: '2',
                  titulo:
                      'Naturaleza del Servicio y Responsabilidad Tributaria',
                  contenido:
                      'CajaYa es un facilitador tecnológico que provee herramientas de gestión de inventarios, registro de ventas, cuentas corrientes (fiados), control de caja y vitrina web.\n\n'
                      '• Conforme a la Ley N° 30877 (Ley General del Bodeguero), cada establecimiento comercial es el único responsable de determinar su régimen tributario ante la SUNAT (Nuevo RUS, Régimen Especial de Renta - RER, MYPE Tributario o Régimen General).\n'
                      '• La plataforma permite la emisión de tickets de control interno (conforme a los requerimientos del Nuevo RUS) o la vinculación opcional con Proveedores de Servicios Electrónicos (PSE/OSE) para comprobantes de pago electrónicos. CajaYa no asume responsabilidad civil, penal ni administrativa por omisiones o declaraciones inexactas del comerciante ante las autoridades fiscales.',
                ),

                _buildClausula(
                  isDark: isDark,
                  numero: '3',
                  titulo: 'Suscripciones, Tarifas y Políticas de Pago',
                  contenido:
                      'CajaYa opera bajo un modelo de suscripción mensual transparente, sin contratos de permanencia forzosa ni cobros automáticos a tarjetas de crédito no autorizados:\n\n'
                      '• Plan Bodega Básico: S/ 50.00 / mes (hasta 200 productos activos, 1 caja de atención).\n'
                      '• Plan Minimarket PRO: S/ 100.00 / mes (productos ilimitados, multi-caja, facturación electrónica SUNAT y catálogo digital para pedidos por WhatsApp). Incluye 30 días de prueba gratuita (Trial) para nuevos comercios.\n'
                      '• Las mensualidades se abonan directamente mediante Yape, Plin o transferencia bancaria oficial al titular autorizado Luis T., contando con conciliación asistida por macro o validación manual. Las suscripciones renovadas de forma anticipada se acumulan a la fecha de vencimiento vigente sin pérdida de días.',
                ),

                _buildClausula(
                  isDark: isDark,
                  numero: '4',
                  titulo:
                      'Catálogo Web y Relación con los Consumidores del Barrio',
                  contenido:
                      'El catálogo digital permite a los vecinos y consumidores consultar el surtido de la bodega y coordinar compras vía WhatsApp:\n\n'
                      '• Los precios, disponibilidad, calidad, vencimiento y entrega efectiva de los productos físicos exhibidos son de exclusiva responsabilidad de la bodega proveedora identificada en el catálogo.\n'
                      '• Las transacciones dinerarias entre el consumidor final y la bodega (contraentrega, Yape, Plin o efectivo) se rigen por los acuerdos directos entre ambas partes.',
                ),

                _buildClausula(
                  isDark: isDark,
                  numero: '5',
                  titulo: 'Disponibilidad, Continuidad y Modo Offline',
                  contenido: 'CajaYa implementa arquitectura de alta disponibilidad en la nube con respaldo automatizado. Para mitigar eventuales fallas de conectividad a internet en el mostrador, la app móvil cuenta con sincronización offline para continuar registrando transacciones que se sincronizan una vez restablecida la red.',
                ),

                _buildClausula(
                  isDark: isDark,
                  numero: '6',
                  titulo: 'Libro de Reclamaciones y Legislación Aplicable',
                  contenido:
                      'En estricto cumplimiento del Código de Protección y Defensa del Consumidor (Ley N° 29571) y el D.S. N° 011-2011-PCM, CajaYa pone a disposición de todos los usuarios y consumidores su Libro de Reclamaciones Virtual accesible permanentemente en la plataforma, garantizando respuesta en un plazo no mayor a quince (15) días hábiles.\n\n'
                      'Cualquier controversia se someterá a la jurisdicción de los jueces y tribunales del distrito judicial de Lima, República del Perú.',
                ),

                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'CajaYa Cloud POS © 2026 • Impulsando el comercio de barrio en el Perú',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getAdaptiveMutedText(isDark),
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

  Widget _buildClausula({
    required bool isDark,
    required String numero,
    required String titulo,
    required String contenido,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.brandPrimary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    numero,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              contenido,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
