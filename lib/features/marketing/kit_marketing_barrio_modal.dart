import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cajaya_vectors.dart';
import '../../core/responsive_layout.dart';
import '../../core/thermal_ticket_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/adaptive_modal.dart';
import '../home/bodega_service.dart';

class KitMarketingBarrioModal extends StatefulWidget {
  final String nombreBodega;
  final String? telefono;
  final String? lemaComercial;
  final String? slugOrId;
  final int? bodegaId;
  final String? giroNegocio;

  const KitMarketingBarrioModal({
    super.key,
    required this.nombreBodega,
    this.telefono,
    this.lemaComercial,
    this.slugOrId,
    this.bodegaId,
    this.giroNegocio,
  });

  static Future<void> show(
    BuildContext context, {
    required String nombreBodega,
    String? telefono,
    String? lemaComercial,
    String? slugOrId,
    int? bodegaId,
    String? giroNegocio,
  }) {
    return AdaptiveModal.show(
      context: context,
      maxWidth: 620,
      builder: (ctx) => KitMarketingBarrioModal(
        nombreBodega: nombreBodega,
        telefono: telefono,
        lemaComercial: lemaComercial,
        slugOrId: slugOrId,
        bodegaId: bodegaId,
        giroNegocio: giroNegocio,
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

  static String buildUrlCatalogo({
    String? slugOrId,
    String? nombreBodega,
    int? bodegaId,
  }) {
    if (slugOrId != null && slugOrId.trim().isNotEmpty) {
      final s = normalizarSlug(slugOrId);
      if (s.isNotEmpty) {
        return 'https://cajaya-pos.onrender.com/#/catalogo?tienda=${Uri.encodeComponent(s)}';
      }
    }
    final nombreVal = (nombreBodega ?? '').trim();
    if (nombreVal.isNotEmpty &&
        nombreVal.toLowerCase() != 'cajaya pos' &&
        nombreVal.toLowerCase() != 'cajaya') {
      final s = normalizarSlug(nombreVal);
      if (s.isNotEmpty) {
        return 'https://cajaya-pos.onrender.com/#/catalogo?tienda=${Uri.encodeComponent(s)}';
      }
    }
    if (bodegaId != null && bodegaId > 0) {
      return 'https://cajaya-pos.onrender.com/#/catalogo?tienda=$bodegaId';
    }
    return 'https://cajaya-pos.onrender.com/#/catalogo?tienda=bodega-karliz';
  }

  @override
  State<KitMarketingBarrioModal> createState() =>
      _KitMarketingBarrioModalState();
}

class _KitMarketingBarrioModalState extends State<KitMarketingBarrioModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _cantidadVolantes = 5;
  bool _isPrinting = false;

  late String _nombreBodega;
  late String _telefono;
  late String _lemaComercial;
  late String _giroNegocio;
  int? _bodegaId;

  bool get _esGastronomico =>
      _giroNegocio == 'POLLERIA' ||
      _giroNegocio == 'CHIFA' ||
      _giroNegocio == 'FASTFOOD' ||
      _giroNegocio == 'RESTAURANTE';

  String get _urlCatalogo => KitMarketingBarrioModal.buildUrlCatalogo(
    slugOrId: widget.slugOrId,
    nombreBodega: _nombreBodega,
    bodegaId: _bodegaId,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _nombreBodega = widget.nombreBodega.trim().isEmpty
        ? 'Bodega Karliz'
        : widget.nombreBodega.trim();
    _telefono = widget.telefono?.trim() ?? '';
    _lemaComercial = widget.lemaComercial?.trim() ?? '';
    _bodegaId = widget.bodegaId;
    _giroNegocio = (widget.giroNegocio ?? 'BODEGA').toUpperCase();
    _cargarInfoBodega();
  }

  Future<void> _cargarInfoBodega() async {
    try {
      final info = await BodegaService().obtenerMiBodega();
      if (info != null && mounted) {
        setState(() {
          if (info.giroNegocio != null && info.giroNegocio!.isNotEmpty) {
            _giroNegocio = info.giroNegocio!.toUpperCase();
          }
          if (info.nombreComercial.isNotEmpty &&
              (_nombreBodega == 'CajaYa POS' || _nombreBodega.isEmpty)) {
            _nombreBodega = info.nombreComercial;
          }
          if (_telefono.isEmpty &&
              info.telefono != null &&
              info.telefono!.trim().isNotEmpty) {
            _telefono = info.telefono!.trim();
          }
          if (_lemaComercial.isEmpty &&
              info.lemaComercial != null &&
              info.lemaComercial!.trim().isNotEmpty) {
            _lemaComercial = info.lemaComercial!.trim();
          }
          _bodegaId ??= info.idBodega;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _imprimirVolantesTermicos() async {
    setState(() => _isPrinting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final lema = _lemaComercial.isNotEmpty
          ? _lemaComercial
          : widget.lemaComercial;
      final tel = _telefono.isNotEmpty ? _telefono : widget.telefono;

      final List<int> singleVolanteBytes =
          ThermalTicketService.generateVolanteBarrioEscPosBytes(
            nombreComercio: _nombreBodega,
            urlCatalogo: _urlCatalogo,
            lemaComercial: lema,
            telefono: tel,
            giroNegocio: _giroNegocio,
          );

      final String plainText = ThermalTicketService.generateVolanteBarrioText(
        nombreComercio: _nombreBodega,
        urlCatalogo: _urlCatalogo,
        lemaComercial: lema,
        telefono: tel,
        giroNegocio: _giroNegocio,
      );

      // Concatenar N copias si se solicitaron varias
      final List<int> totalBytes = [];
      for (int i = 0; i < _cantidadVolantes; i++) {
        totalBytes.addAll(singleVolanteBytes);
      }

      final result = await ThermalTicketService.printReceipt(
        context,
        escPosBytes: totalBytes,
        plainText: plainText,
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: result.exito
                ? AppTheme.accentGreen
                : AppTheme.alertRed,
            content: Text(
              result.exito
                  ? (_esGastronomico
                        ? '¡$_cantidadVolantes volantes de carta digital enviados a la ticketera con éxito!'
                        : '¡$_cantidadVolantes volantes de barrio enviados a la ticketera con éxito!')
                  : result.mensaje,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.alertRed,
            content: Text('Error al imprimir volantes: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _compartirEnWhatsApp(String texto) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: texto));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Mensaje copiado al portapapeles! Puedes pegarlo directamente en WhatsApp.',
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final isWide = ResponsiveLayout.isTabletOrLarger(context);
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final resolvedRadius = isWide
        ? BorderRadius.circular(24)
        : const BorderRadius.vertical(top: Radius.circular(28));

    return Align(
      alignment: isWide ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(context).height * (isWide ? 0.88 : 0.92),
        ),
        child: Container(
          margin: EdgeInsets.only(bottom: isWide ? 0 : bottomInset),
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
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.35),
                blurRadius: isWide ? 30 : 20,
                offset: isWide ? const Offset(0, 10) : const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: isWide,
            bottom: !isWide,
            child: Column(
              children: [
                // Barra de arrastre solo en móvil
                if (!isWide) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
                SizedBox(height: isWide ? 18 : 14),

                // Cabecera
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.megaphone,
                                color: Color(0xFFD97706),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _esGastronomico
                                        ? 'Viralidad & Carta Digital'
                                        : 'Viralidad & Marketing de Barrio',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _esGastronomico
                                        ? 'Llena tus mesas y atrae comensales por WhatsApp'
                                        : 'Llena tu bodega y fideliza a tus vecinos',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          size: 20,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF64748B),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Selector de Pestañas
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.brandPrimary,
                  indicatorColor: AppTheme.brandPrimary,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(
                      icon: const Icon(LucideIcons.receipt, size: 16),
                      text: _esGastronomico
                          ? 'Volante Carta'
                          : 'Volante Térmico',
                    ),
                    Tab(
                      icon: const Icon(LucideIcons.qrCode, size: 16),
                      text: _esGastronomico
                          ? 'Afiche Salón / Mesa'
                          : 'Afiche Vitrina',
                    ),
                    const Tab(
                      icon: Icon(LucideIcons.messageCircle, size: 16),
                      text: 'Difusión WhatsApp',
                    ),
                    const Tab(
                      icon: Icon(LucideIcons.users, size: 16),
                      text: 'Referir Colega',
                    ),
                  ],
                ),
                const Divider(height: 1),

                // Contenido de las pestañas
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabVolanteTermico(isDark),
                      _buildTabAficheVitrina(isDark),
                      _buildTabDifusionVecinal(isDark),
                      _buildTabReferidos(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. PESTAÑA: VOLANTE TÉRMICO DE BOLSILLO ---
  Widget _buildTabVolanteTermico(bool isDark) {
    final lema = _lemaComercial.isNotEmpty
        ? _lemaComercial
        : widget.lemaComercial;
    final tel = _telefono.isNotEmpty ? _telefono : widget.telefono;

    final previewText = ThermalTicketService.generateVolanteBarrioText(
      nombreComercio: _nombreBodega,
      urlCatalogo: _urlCatalogo,
      lemaComercial: lema,
      telefono: tel,
      giroNegocio: _giroNegocio,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.printer,
                  color: AppTheme.brandPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _esGastronomico
                          ? 'Volante de Mesa y Cuenta'
                          : 'Volante de Bolsillo para el Vuelto',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    Text(
                      _esGastronomico
                          ? 'Imprime volantes en tu ticketera térmica y entrégalos con la cuenta o pedidos para llevar.'
                          : 'Imprime volantes en tu ticketera térmica y entrégalos a tus clientes con su vuelto.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Selector de copias
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cantidad a imprimir:',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Row(
                children: [1, 5, 10, 20].map((qty) {
                  final isSelected = _cantidadVolantes == qty;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text('$qty'),
                      selected: isSelected,
                      selectedColor: AppTheme.brandPrimary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) =>
                          setState(() => _cantidadVolantes = qty),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Previsualización de Ticket Térmico
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: Text(
              previewText,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: _isPrinting ? null : _imprimirVolantesTermicos,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: _isPrinting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(LucideIcons.printer, size: 18),
            label: Text(
              _isPrinting
                  ? 'Imprimiendo volantes...'
                  : 'IMPRIMIR $_cantidadVolantes VOLANTES EN TICKETERA',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. PESTAÑA: AFICHE DE VITRINA / REJA ---
  Widget _buildTabAficheVitrina(bool isDark) {
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=350x350&data=${Uri.encodeComponent(_urlCatalogo)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Afiche Diseñado para Reja / Vitrina / Mesa
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFEFF6FF), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.brandPrimary.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const CajaYaLogoMark(size: 42),
                const SizedBox(height: 8),
                Text(
                  _nombreBodega.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.brandDark,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_lemaComercial.isNotEmpty ||
                    (widget.lemaComercial != null &&
                        widget.lemaComercial!.isNotEmpty)) ...[
                  const SizedBox(height: 2),
                  Text(
                    _lemaComercial.isNotEmpty
                        ? _lemaComercial
                        : widget.lemaComercial!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getAdaptiveMutedText(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.messageCircle,
                        color: Color(0xFF16A34A),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _esGastronomico
                            ? '¡PIDE DESDE TU MESA O LLEVA A CASA!'
                            : '¡VECINO, PIDE DESDE CASA POR WHATSAPP!',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF16A34A),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Contenedor del Código QR
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Image.network(
                    qrUrl,
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 180,
                      height: 180,
                      color: const Color(0xFFF1F5F9),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.qrCode,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _urlCatalogo,
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  _esGastronomico
                      ? 'Apunta con la cámara de tu celular y revisa nuestra carta digital y promociones del día'
                      : 'Apunta con la cámara de tu celular y revisa nuestros precios y promociones del día',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Badges de Medios de Pago
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildPaymentBadge('YAPE', const Color(0xFF732283)),
                    _buildPaymentBadge('PLIN', const Color(0xFF0084FF)),
                    _buildPaymentBadge('EFECTIVO', const Color(0xFF16A34A)),
                    _buildPaymentBadge('DELIVERY', const Color(0xFFD97706)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _urlCatalogo));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enlace copiado al portapapeles'),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.copy, size: 16),
                  label: const Text('Copiar Enlace'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final texto = _esGastronomico
                        ? '¡Hola! Te comparto la carta virtual de $_nombreBodega. Puedes escanear o ingresar aquí para hacer tus pedidos: $_urlCatalogo'
                        : '¡Hola vecinos! Les comparto el catálogo virtual de $_nombreBodega. Pueden escanear o ingresar aquí: $_urlCatalogo';
                    _compartirEnWhatsApp(texto);
                  },
                  icon: const Icon(LucideIcons.share2, size: 16),
                  label: const Text('Compartir QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. PESTAÑA: DIFUSIÓN POR WHATSAPP ---
  Widget _buildTabDifusionVecinal(bool isDark) {
    final String mensajeVecinal;
    switch (_giroNegocio) {
      case 'POLLERIA':
        mensajeVecinal =
            '🍗 ¡Hola! En *$_nombreBodega* ya tenemos carta digital online.\n\n'
            'Puedes revisar nuestra carta completa, pollos a la brasa, combos y hacernos tu pedido directo por WhatsApp sin esperas:\n'
            '👉 $_urlCatalogo\n\n'
            '🔥 Pollos doraditos, papas crocantes, cremas y bebidas con delivery o para llevar.\n'
            '💵 Aceptamos Yape, Plin y Efectivo contraentrega.\n\n'
            '¡Gracias por elegirnos! Buen provecho 😊🍗🍟';
        break;
      case 'CHIFA':
        mensajeVecinal =
            '🥢 ¡Hola! En *$_nombreBodega* ya tenemos carta digital online.\n\n'
            'Puedes revisar nuestros platos al wok, chaufas, combinados y hacernos tu pedido directo por WhatsApp:\n'
            '👉 $_urlCatalogo\n\n'
            '🥡 Chaufas al wok, wantanes crocantes y bebidas con delivery o para llevar.\n'
            '💵 Aceptamos Yape, Plin y Efectivo contraentrega.\n\n'
            '¡Gracias por tu preferencia! Buen provecho 😊🥢🥡';
        break;
      case 'FASTFOOD':
        mensajeVecinal =
            '🍔 ¡Hola! En *$_nombreBodega* ya tenemos menú digital online.\n\n'
            'Puedes revisar nuestras hamburguesas, salchipapas, broaster y hacernos tu pedido directo por WhatsApp:\n'
            '👉 $_urlCatalogo\n\n'
            '🍟 Combos irresistibles, salsas de la casa y bebidas con delivery o para llevar.\n'
            '💵 Aceptamos Yape, Plin y Efectivo contraentrega.\n\n'
            '¡Gracias por elegirnos! 😊🍔🍟';
        break;
      case 'RESTAURANTE':
        mensajeVecinal =
            '🍽️ ¡Hola! En *$_nombreBodega* ya tenemos carta digital online.\n\n'
            'Puedes revisar nuestra carta de platos, menú ejecutivo del día y hacernos tu pedido directo por WhatsApp:\n'
            '👉 $_urlCatalogo\n\n'
            '🥗 Platos preparados al momento, postres y refrescos naturales con delivery o para llevar.\n'
            '💵 Aceptamos Yape, Plin y Efectivo contraentrega.\n\n'
            '¡Gracias por tu preferencia! Buen provecho 😊🍽️';
        break;
      case 'BODEGA':
      default:
        mensajeVecinal =
            '👋 ¡Hola vecinos! En *$_nombreBodega* ya tenemos tienda virtual.\n\n'
            'Pueden revisar nuestros precios del día, ofertas y hacernos sus pedidos directo por WhatsApp sin salir de casa ni hacer colas:\n'
            '👉 $_urlCatalogo\n\n'
            '🧀 Abarrotes, lácteos, bebidas y golosinas con delivery en el barrio.\n'
            '💵 Aceptamos Yape, Plin y Efectivo contraentrega.\n\n'
            '¡Gracias por apoyar a tu bodega amiga de siempre! 😊🥖🥤';
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.messageSquare,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _esGastronomico
                          ? 'Mensaje Listo para Clientes & Comensales'
                          : 'Mensaje Listo para Grupos del Barrio',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    Text(
                      _esGastronomico
                          ? 'Envíalo a tus clientes frecuentes, listas de difusión o estados de WhatsApp.'
                          : 'Envíalo al grupo de WhatsApp de tu urbanización, edificio o a tus caseros frecuentes.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: SelectableText(
              mensajeVecinal,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white70 : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: () => _compartirEnWhatsApp(mensajeVecinal),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.send, size: 18),
            label: Text(
              _esGastronomico
                  ? 'ENVIAR CARTA POR WHATSAPP'
                  : 'ENVIAR POR WHATSAPP A VECINOS',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. PESTAÑA: DE COLEGA A COLEGA (REFERIDOS) ---
  Widget _buildTabReferidos(bool isDark) {
    final String mensajeReferido = _esGastronomico
        ? '🤝 ¡Hola colega! Te recomiendo *CajaYa Cloud POS* para llevar las cuentas y comandas de tu pollería, chifa o restaurante.\n\n'
              '• Te permite vender rápido, controlar caja sin descuadres y compartir tu carta digital por WhatsApp.\n'
              '• Pruébalo 30 días gratis en: https://cajaya-pos.onrender.com\n\n'
              '¡Es ideal para locales gastronómicos y comercios del Perú!'
        : '🤝 ¡Hola colega! Te recomiendo *CajaYa Cloud POS* para llevar las cuentas de tu bodega o minimarket.\n\n'
              '• Te permite vender rápido, fiar con control, hacer arqueos sin descuadres y vender por WhatsApp a los vecinos.\n'
              '• Pruébalo 30 días gratis en: https://cajaya-pos.onrender.com\n\n'
              '¡Es ideal para bodegas de barrio del Perú!';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.heartHandshake,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recomendar a un Colega Comerciante',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    Text(
                      _esGastronomico
                          ? 'Comparte la solución con amigos que tengan restaurante, pollería, chifa o local de comida.'
                          : 'Comparte la solución con amigos que tengan tienda, market o bazar.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: SelectableText(
              mensajeReferido,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white70 : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: () => _compartirEnWhatsApp(mensajeReferido),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.share, size: 18),
            label: Text(
              'RECOMENDAR CAJAYA POR WHATSAPP',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
