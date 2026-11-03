import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/secure_storage_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/pago_yape_modal.dart';
import 'bodega_service.dart';

class MiBodegaOnlineModal extends StatefulWidget {
  final String nombreBodega;
  final String telefonoBodega;
  final bool isPro;
  final VoidCallback? onTelefonoUpdated;

  const MiBodegaOnlineModal({
    super.key,
    required this.nombreBodega,
    this.telefonoBodega = '',
    this.isPro = true,
    this.onTelefonoUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String nombreBodega,
    String telefonoBodega = '',
    bool isPro = true,
    VoidCallback? onTelefonoUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MiBodegaOnlineModal(
        nombreBodega: nombreBodega,
        telefonoBodega: telefonoBodega,
        isPro: isPro,
        onTelefonoUpdated: onTelefonoUpdated,
      ),
    );
  }

  static String normalizarSlug(String texto) {
    if (texto.trim().isEmpty) return '';
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  @override
  State<MiBodegaOnlineModal> createState() => _MiBodegaOnlineModalState();
}

class _MiBodegaOnlineModalState extends State<MiBodegaOnlineModal> {
  late String _telefono;
  bool _editandoTelefono = false;
  bool _guardandoTelefono = false;
  late final TextEditingController _telefonoCtrl;
  final BodegaService _bodegaService = BodegaService();

  @override
  void initState() {
    super.initState();
    _telefono = widget.telefonoBodega.trim();
    _telefonoCtrl = TextEditingController(text: _telefono);
    _cargarTelefonoActualizado();
  }

  @override
  void dispose() {
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTelefonoActualizado() async {
    try {
      final info = await _bodegaService.obtenerMiBodega();
      if (mounted &&
          info != null &&
          info.telefono != null &&
          info.telefono!.isNotEmpty) {
        setState(() {
          _telefono = info.telefono!;
          if (!_editandoTelefono) {
            _telefonoCtrl.text = _telefono;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _guardarTelefono() async {
    final nuevo = _telefonoCtrl.text.trim();
    if (nuevo.isNotEmpty && nuevo.length != 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El número celular debe tener exactamente 9 dígitos.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _guardandoTelefono = true);
    try {
      await _bodegaService.actualizarConfiguracion(
        nombreComercial: widget.nombreBodega,
        telefono: nuevo.isEmpty ? null : nuevo,
      );
      if (nuevo.isNotEmpty) {
        await SecureStorageService.write('telefono_bodega', nuevo);
      }

      if (mounted) {
        setState(() {
          _telefono = nuevo;
          _editandoTelefono = false;
          _guardandoTelefono = false;
        });
        widget.onTelefonoUpdated?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  LucideIcons.checkCheck,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nuevo.isNotEmpty
                        ? '¡Número de WhatsApp actualizado! Los pedidos ahora se enviarán a +51 $nuevo.'
                        : 'Número de WhatsApp eliminado.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardandoTelefono = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar número: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slug = MiBodegaOnlineModal.normalizarSlug(widget.nombreBodega);
    final catalogoUrl =
        'https://cajaya-pos.onrender.com/#/catalogo?tienda=$slug';

    final mensajeWhatsApp =
        '¡Hola vecino! 👋\n\n'
        'Ya puedes revisar todos los productos, ofertas y precios actualizados de *${widget.nombreBodega}* en nuestro catálogo digital:\n'
        '$catalogoUrl\n\n'
        'Elige tus productos y mándanos tu pedido por aquí para tenerlo listo al instante. ¡Gracias por tu preferencia!';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                    child: const Icon(
                      LucideIcons.globe,
                      color: AppTheme.brandPrimary,
                      size: 22,
                    ),
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
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (widget.isPro
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFD97706))
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!widget.isPro) ...[
                                    const Icon(
                                      LucideIcons.lock,
                                      size: 9,
                                      color: Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    'PLAN PRO',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: widget.isPro
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Tu vitrina digital para pedidos de vecinos por WhatsApp',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (!widget.isPro) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.lock,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Esta función es exclusiva del Plan PRO. Tus clientes podrán realizar pedidos en cuanto actives tu suscripción.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Tarjeta de Enlace Digital
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.cardDarkSunken
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFCBD5E1),
                  ),
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
                                content: Text(
                                  'Enlace copiado al portapapeles.',
                                ),
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
              const SizedBox(height: 12),

              // Tarjeta de Teléfono / WhatsApp para Pedidos (Editable directamente)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.cardDarkSunken
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1E3A2F)
                        : const Color(0xFFBBF7D0),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.messageCircle,
                          size: 15,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'WHATSAPP PARA RECIBIR PEDIDOS:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF16A34A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (!_editandoTelefono)
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  _telefono.isNotEmpty
                                      ? '+51 $_telefono'
                                      : 'Sin número asignado',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: _telefono.isNotEmpty
                                        ? (isDark
                                              ? Colors.white
                                              : AppTheme.textDark)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                                if (_telefono.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'ACTIVO',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.brandPrimary,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            icon: const Icon(LucideIcons.pencil, size: 14),
                            label: Text(
                              _telefono.isNotEmpty ? 'Cambiar' : 'Asignar',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: () =>
                                setState(() => _editandoTelefono = true),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _telefonoCtrl,
                                keyboardType: TextInputType.phone,
                                autofocus: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(9),
                                ],
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ej. 987654321',
                                  prefixText: '+51 ',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _guardandoTelefono
                                ? null
                                : _guardarTelefono,
                            child: _guardandoTelefono
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Guardar',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              _telefonoCtrl.text = _telefono;
                              setState(() => _editandoTelefono = false);
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botón Principal
              if (!widget.isPro)
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(LucideIcons.sparkles, size: 18),
                    label: Text(
                      'Mejorar a Plan PRO con Yape / Plin (S/ 100 /mes)',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      PagoYapeModal.show(context, planInicial: 'PRO');
                    },
                  ),
                )
              else
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(LucideIcons.send, size: 18),
                    label: Text(
                      'Compartir Catálogo por WhatsApp',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final uri = Uri.parse(
                        'https://wa.me/?text=${Uri.encodeComponent(mensajeWhatsApp)}',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
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
                    side: BorderSide(
                      color: isDark
                          ? AppTheme.borderDark
                          : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  label: Text(
                    'Ver Catálogo como Cliente',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse(catalogoUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cerrar Ventana',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
