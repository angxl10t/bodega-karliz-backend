import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/responsive_layout.dart';
import '../../core/secure_storage_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/adaptive_modal.dart';
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
    return AdaptiveModal.show(
      context: context,
      maxWidth: 600,
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
  bool _catalogoAbierto = true;
  bool _deliveryActivo = true;
  bool _guardandoEstado = false;
  BodegaInfo? _bodegaInfo;
  late final TextEditingController _telefonoCtrl;
  final BodegaService _bodegaService = BodegaService();

  String get _nombreComercialSeguro {
    final infoName = _bodegaInfo?.nombreComercial.trim();
    if (infoName != null && infoName.length >= 3) {
      return infoName;
    }
    final widgetName = widget.nombreBodega.trim();
    if (widgetName.length >= 3) {
      return widgetName;
    }
    return 'Mi Bodega';
  }

  bool get _esGastronomico {
    final giro = _bodegaInfo?.giroNegocio?.toUpperCase();
    return giro == 'POLLERIA' ||
        giro == 'CHIFA' ||
        giro == 'FASTFOOD' ||
        giro == 'RESTAURANTE';
  }

  String get _tituloModal {
    final giro = _bodegaInfo?.giroNegocio?.toUpperCase();
    switch (giro) {
      case 'POLLERIA':
        return 'Mi Pollería Online';
      case 'CHIFA':
        return 'Mi Chifa Online';
      case 'FASTFOOD':
        return 'Mi Fast Food Online';
      case 'RESTAURANTE':
        return 'Mi Restaurante Online';
      case 'BODEGA':
      default:
        return 'Mi Bodega Online';
    }
  }

  String get _subtituloModal {
    if (_esGastronomico) {
      return 'Tu carta digital para pedidos de clientes por WhatsApp';
    }
    return 'Tu vitrina digital para pedidos de vecinos por WhatsApp';
  }

  String _formatearErrorRed(Object error, String defaultMsg) {
    final str = error.toString();
    if (str.contains('Failed to fetch') ||
        str.contains('XMLHttpRequest') ||
        str.contains('ClientException') ||
        str.contains('SocketException') ||
        str.contains('503') ||
        str.contains('502') ||
        str.contains('TimeoutException')) {
      return 'No se pudo conectar con el servidor en la nube (cajaya-api). El backend puede estar iniciando en Render. Por favor espera unos segundos y vuelve a intentar.';
    }
    return '$defaultMsg: ${str.replaceAll('Exception:', '').trim()}';
  }

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
      if (mounted && info != null) {
        setState(() {
          _bodegaInfo = info;
          _catalogoAbierto = info.catalogoAbierto;
          _deliveryActivo = info.deliveryActivo;
          if (info.telefono != null && info.telefono!.isNotEmpty) {
            _telefono = info.telefono!;
            if (!_editandoTelefono) {
              _telefonoCtrl.text = _telefono;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _cambiarEstadoCatalogo(bool nuevoEstado) async {
    if (_guardandoEstado) return;
    setState(() {
      _guardandoEstado = true;
      _catalogoAbierto = nuevoEstado;
    });
    try {
      await _bodegaService.actualizarConfiguracion(
        nombreComercial: _nombreComercialSeguro,
        catalogoAbierto: nuevoEstado,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  nuevoEstado ? LucideIcons.store : LucideIcons.doorClosed,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nuevoEstado
                        ? '¡Tienda abierta! Tu catálogo digital ahora recibe pedidos.'
                        : 'Tienda en pausa. El catálogo mostrará que estás cerrado temporalmente.',
                  ),
                ),
              ],
            ),
            backgroundColor: nuevoEstado
                ? const Color(0xFF10B981)
                : const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _catalogoAbierto = !nuevoEstado);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _formatearErrorRed(e, 'Error al cambiar estado de la tienda'),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guardandoEstado = false);
      }
    }
  }

  Future<void> _cambiarModalidadDelivery(bool nuevoEstado) async {
    if (_guardandoEstado) return;
    setState(() {
      _guardandoEstado = true;
      _deliveryActivo = nuevoEstado;
    });
    try {
      await _bodegaService.actualizarConfiguracion(
        nombreComercial: _nombreComercialSeguro,
        deliveryActivo: nuevoEstado,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  nuevoEstado ? LucideIcons.bike : LucideIcons.shoppingBag,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nuevoEstado
                        ? '¡Delivery rápido activado! Los clientes pueden pedir a domicilio.'
                        : 'Modalidad configurada: Solo retiro en tienda.',
                  ),
                ),
              ],
            ),
            backgroundColor: nuevoEstado
                ? const Color(0xFF2563EB)
                : const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deliveryActivo = !nuevoEstado);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _formatearErrorRed(e, 'Error al cambiar modalidad de entrega'),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guardandoEstado = false);
      }
    }
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
        nombreComercial: _nombreComercialSeguro,
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
            content: Text(_formatearErrorRed(e, 'Error al guardar número')),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
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

    final mensajeWhatsApp = _esGastronomico
        ? '¡Hola! 👋\n\n'
              'Ya puedes revisar toda la carta, combos, promociones y platos de *${widget.nombreBodega}* en nuestro menú digital:\n'
              '$catalogoUrl\n\n'
              'Haz tu orden y mándanos tu pedido por aquí para prepararlo de inmediato. ¡Gracias por tu preferencia!'
        : '¡Hola vecino! 👋\n\n'
              'Ya puedes revisar todos los productos, ofertas y precios actualizados de *${widget.nombreBodega}* en nuestro catálogo digital:\n'
              '$catalogoUrl\n\n'
              'Elige tus productos y mándanos tu pedido por aquí para tenerlo listo al instante. ¡Gracias por tu preferencia!';

    final isWide = ResponsiveLayout.isTabletOrLarger(context);
    final cardBg = isDark ? AppTheme.cardDarkElevated : Colors.white;
    final resolvedRadius = isWide
        ? BorderRadius.circular(24)
        : const BorderRadius.vertical(top: Radius.circular(24));

    return Align(
      alignment: isWide ? Alignment.center : Alignment.bottomCenter,
      heightFactor: isWide ? 1.0 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * (isWide ? 0.88 : 0.90),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: resolvedRadius,
            border: isDark
                ? Border.all(color: AppTheme.borderDarkElevated, width: 1.2)
                : Border.all(
                    color: isWide ? AppTheme.borderLight : Colors.transparent,
                    width: 1.0,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
                blurRadius: isWide ? 30 : 20,
                offset: isWide ? const Offset(0, 10) : const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            isWide ? 20 : 12,
            20,
            24 + (isWide ? 0 : MediaQuery.of(context).viewInsets.bottom),
          ),
          child: SafeArea(
            top: isWide,
            bottom: !isWide,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Manija superior solo en móvil
                  if (!isWide) ...[
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
                  ],
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
                                  _tituloModal,
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
                              _subtituloModal,
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
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.copy, size: 16),
                              tooltip: 'Copiar Enlace',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: catalogoUrl),
                                );
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
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                  const SizedBox(height: 12),

                  // Tarjeta: Operación y Disponibilidad del Catálogo
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.cardDarkSunken
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.borderDark
                            : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.sliders,
                              size: 15,
                              color: AppTheme.brandPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'CONTROL OPERATIVO DEL CATÁLOGO:',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brandPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (_guardandoEstado) ...[
                              const Spacer(),
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.brandPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Switch 1: Estado de Tienda (Abierto / Cerrado)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _catalogoAbierto
                                  ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.3)
                                  : const Color(0xFFEF4444)
                                        .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color:
                                      (_catalogoAbierto
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444))
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _catalogoAbierto
                                      ? LucideIcons.store
                                      : LucideIcons.doorClosed,
                                  size: 18,
                                  color: _catalogoAbierto
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
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
                                          _catalogoAbierto
                                              ? 'Abierto ahora'
                                              : 'Cerrado temporalmente',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : AppTheme.textDark,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (_catalogoAbierto
                                                        ? const Color(
                                                            0xFF10B981,
                                                          )
                                                        : const Color(
                                                            0xFFEF4444,
                                                          ))
                                                    .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            _catalogoAbierto
                                                ? 'ONLINE'
                                                : 'EN PAUSA',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: _catalogoAbierto
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFEF4444),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _catalogoAbierto
                                          ? 'Aceptando pedidos normalmente en la web'
                                          : 'Pausa pedidos si saliste o estás surtiendo',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppTheme.textDarkSecondary
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _catalogoAbierto,
                                activeTrackColor: const Color(0xFF10B981),
                                onChanged: widget.isPro
                                    ? _cambiarEstadoCatalogo
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Switch 2: Opción Delivery Rápido
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _deliveryActivo
                                  ? AppTheme.brandPrimary.withValues(alpha: 0.3)
                                  : const Color(0xFFCBD5E1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color:
                                      (_deliveryActivo
                                              ? AppTheme.brandPrimary
                                              : const Color(0xFF64748B))
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _deliveryActivo
                                      ? LucideIcons.bike
                                      : LucideIcons.shoppingBag,
                                  size: 18,
                                  color: _deliveryActivo
                                      ? AppTheme.brandPrimary
                                      : const Color(0xFF64748B),
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
                                          _deliveryActivo
                                              ? 'Delivery rápido'
                                              : 'Solo retiro en tienda',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : AppTheme.textDark,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (_deliveryActivo
                                                        ? AppTheme.brandPrimary
                                                        : const Color(
                                                            0xFF64748B,
                                                          ))
                                                    .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            _deliveryActivo
                                                ? 'ACTIVO'
                                                : 'DESACTIVADO',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: _deliveryActivo
                                                  ? AppTheme.brandPrimary
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _deliveryActivo
                                          ? 'Clientes pueden solicitar envío a domicilio'
                                          : 'Solo pedidos para recoger en el local',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppTheme.textDarkSecondary
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _deliveryActivo,
                                activeTrackColor: AppTheme.brandPrimary,
                                onChanged: widget.isPro
                                    ? _cambiarModalidadDelivery
                                    : null,
                              ),
                            ],
                          ),
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
                          'Mejorar a Plan PRO con Yape / Plin (S/ 79 /mes)',
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
                        foregroundColor: isDark
                            ? Colors.white
                            : AppTheme.textDark,
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
        ),
      ),
    );
  }
}
