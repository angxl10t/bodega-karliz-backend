import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';
import '../configuracion_ticket_service.dart';
import '../thermal_ticket_service.dart';
import '../../features/configuracion/configuracion_screen.dart';

/// Dibuja los dientes de sierra característicos del corte de papel en guillotinas térmicas.
class SawtoothPainter extends CustomPainter {
  final Color color;
  final double toothWidth;

  const SawtoothPainter({required this.color, this.toothWidth = 8.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);

    double x = 0;
    while (x < size.width) {
      final midX = x + (toothWidth / 2);
      final nextX = x + toothWidth;
      path.lineTo(midX, size.height);
      path.lineTo(nextX, 0);
      x = nextX;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SawtoothPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.toothWidth != toothWidth;
}

/// Modal insignia para previsualizar el ticket térmico con simulación de hardware físico:
/// chasis industrial, LEDs de estado, papel térmico cálido, tipografía monospace y corte en sierra.
class ThermalTicketPreviewDialog extends StatefulWidget {
  final List<TicketItem> items;
  final double total;
  final String metodo;
  final double? pagadoCon;
  final double? vuelto;
  final double descuento;
  final int? ticketId;
  final String? clienteNombre;
  final String? clienteDocumento;
  final String? tipoComprobante;
  final String? serieCorrelativo;
  final String? estadoSunat;
  final String? sunatHash;
  final String? cajero;
  final DateTime? fecha;
  final String? nombreComercio;
  final String? rucDni;
  final String? direccion;
  final String? telefono;
  final String? lemaComercial;
  final String? regimenTributario;
  final ConfiguracionTicket? configTicket;
  final int? anchoInicial;

  const ThermalTicketPreviewDialog({
    super.key,
    required this.items,
    required this.total,
    required this.metodo,
    this.pagadoCon,
    this.vuelto,
    this.descuento = 0.0,
    this.ticketId,
    this.clienteNombre,
    this.clienteDocumento,
    this.tipoComprobante,
    this.serieCorrelativo,
    this.estadoSunat,
    this.sunatHash,
    this.cajero,
    this.fecha,
    this.nombreComercio,
    this.rucDni,
    this.direccion,
    this.telefono,
    this.lemaComercial,
    this.regimenTributario,
    this.configTicket,
    this.anchoInicial,
  });

  static Future<void> show(
    BuildContext context, {
    required List<TicketItem> items,
    required double total,
    required String metodo,
    double? pagadoCon,
    double? vuelto,
    double descuento = 0.0,
    int? ticketId,
    String? clienteNombre,
    String? clienteDocumento,
    String? tipoComprobante,
    String? serieCorrelativo,
    String? estadoSunat,
    String? sunatHash,
    String? cajero,
    DateTime? fecha,
    String? nombreComercio,
    String? rucDni,
    String? direccion,
    String? telefono,
    String? lemaComercial,
    String? regimenTributario,
    ConfiguracionTicket? configTicket,
    int? anchoInicial,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ThermalTicketPreviewDialog(
        items: items,
        total: total,
        metodo: metodo,
        pagadoCon: pagadoCon,
        vuelto: vuelto,
        descuento: descuento,
        ticketId: ticketId,
        clienteNombre: clienteNombre,
        clienteDocumento: clienteDocumento,
        tipoComprobante: tipoComprobante,
        serieCorrelativo: serieCorrelativo,
        estadoSunat: estadoSunat,
        sunatHash: sunatHash,
        cajero: cajero,
        fecha: fecha,
        nombreComercio: nombreComercio,
        rucDni: rucDni,
        direccion: direccion,
        telefono: telefono,
        lemaComercial: lemaComercial,
        regimenTributario: regimenTributario,
        configTicket: configTicket,
        anchoInicial: anchoInicial,
      ),
    );
  }

  @override
  State<ThermalTicketPreviewDialog> createState() =>
      _ThermalTicketPreviewDialogState();
}

class _ThermalTicketPreviewDialogState
    extends State<ThermalTicketPreviewDialog> {
  late int _anchoSeleccionado;
  late ConfiguracionTicket _cfg;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _anchoSeleccionado =
        widget.anchoInicial ??
        widget.configTicket?.anchoPapel ??
        ConfiguracionTicketService.actual.anchoPapel;
    _cfg = (widget.configTicket ?? ConfiguracionTicketService.actual).copyWith(
      anchoPapel: _anchoSeleccionado,
    );
  }

  String _generarTextoTicket() {
    return ThermalTicketService.generateReceiptText(
      ticketId: widget.ticketId,
      clienteNombre: widget.clienteNombre ?? 'Público General',
      clienteDocumento: widget.clienteDocumento,
      metodoPago: widget.metodo,
      items: widget.items,
      total: widget.total,
      descuento: widget.descuento,
      pagadoCon: widget.pagadoCon,
      vuelto: widget.vuelto,
      cajero: widget.cajero,
      fecha: widget.fecha,
      width: _anchoSeleccionado,
      nombreComercio: widget.nombreComercio ?? 'BODEGA',
      rucDni: widget.rucDni,
      direccion: widget.direccion,
      telefono: widget.telefono,
      lemaComercial: widget.lemaComercial,
      tipoComprobante: widget.tipoComprobante ?? 'TICKET',
      serieCorrelativo: widget.serieCorrelativo,
      estadoSunat: widget.estadoSunat,
      sunatHash: widget.sunatHash,
      regimenTributario: widget.regimenTributario,
      configTicket: _cfg,
    );
  }

  List<int> _generarBytesEscPos(String receiptText) {
    return ThermalTicketService.generateEscPosBytes(
      ticketId: widget.ticketId,
      clienteNombre: widget.clienteNombre ?? 'Público General',
      clienteDocumento: widget.clienteDocumento,
      metodoPago: widget.metodo,
      items: widget.items,
      total: widget.total,
      descuento: widget.descuento,
      pagadoCon: widget.pagadoCon,
      vuelto: widget.vuelto,
      width: _anchoSeleccionado,
      nombreComercio: widget.nombreComercio ?? 'BODEGA',
      rucDni: widget.rucDni,
      direccion: widget.direccion,
      telefono: widget.telefono,
      lemaComercial: widget.lemaComercial,
      tipoComprobante: widget.tipoComprobante ?? 'TICKET',
      serieCorrelativo: widget.serieCorrelativo,
      estadoSunat: widget.estadoSunat,
      sunatHash: widget.sunatHash,
      regimenTributario: widget.regimenTributario,
      configTicket: _cfg,
      forzarAperturaGaveta:
          _cfg.abrirGaveta && widget.metodo.toLowerCase().contains('efectivo'),
    );
  }

  Future<void> _imprimirTicket() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final receiptText = _generarTextoTicket();
      final escPosBytes = _generarBytesEscPos(receiptText);

      final res = await ThermalTicketService.imprimirTicketDirecto(
        escPosBytes: escPosBytes,
        receiptText: receiptText,
        config: _cfg,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  res.exito
                      ? LucideIcons.checkCheck
                      : LucideIcons.alertTriangle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    res.mensaje,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: res.exito
                ? AppTheme.accentGreen
                : AppTheme.alertRed,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bool is80mm = _anchoSeleccionado == ThermalTicketService.width80mm;

    // Dimensiones físicas fijas del rollo térmico según estándar ESC/POS (58mm / 80mm).
    // Deterministas para evitar colapsos o anchos reducidos en la primera apertura
    // mientras la fuente web (GoogleFonts) se descarga asíncronamente en Web/móvil.
    final double horizontalPadding = is80mm ? 12.0 : 10.0;
    final double contentWidth = is80mm ? 306.0 : 220.0;
    final double paperWidth = is80mm ? 330.0 : 240.0;
    final double headWidth = paperWidth + 40.0;

    final textStyle =
        GoogleFonts.firaCode(
          color: const Color(0xFF111827),
          fontSize: is80mm ? 10.5 : 11.5,
          height: 1.34,
          fontWeight: FontWeight.w500,
        ).copyWith(
          fontFamilyFallback: const [
            'Courier New',
            'Consolas',
            'Menlo',
            'Monaco',
            'monospace',
          ],
        );

    final receiptText = _generarTextoTicket();

    return Dialog(
      backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(
          minWidth: is80mm ? 400.0 : 320.0,
          maxWidth: is80mm ? 480.0 : 400.0,
          maxHeight: 740,
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera del Diálogo
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.printer,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ticket Térmico POS',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.2,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Simulador físico ESC/POS • ${_anchoSeleccionado}mm',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Configurar Hardware',
                  icon: const Icon(LucideIcons.settings, size: 18),
                  onPressed: () async {
                    await ConfiguracionScreen.abrir(
                      context,
                      tabInicial: ConfiguracionTab.hardware,
                    );
                    if (mounted) {
                      setState(() {
                        _anchoSeleccionado =
                            ConfiguracionTicketService.actual.anchoPapel;
                        _cfg = ConfiguracionTicketService.actual.copyWith(
                          anchoPapel: _anchoSeleccionado,
                        );
                      });
                    }
                  },
                ),
                IconButton(
                  key: const ValueKey('thermal_dialog_close_btn'),
                  tooltip: 'Cerrar',
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Selector de Ancho (58mm / 80mm) con estilo ergonómico
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: ThermalTicketService.width58mm,
                    label: Text('58mm'),
                    icon: Icon(LucideIcons.receipt, size: 14),
                  ),
                  ButtonSegment(
                    value: ThermalTicketService.width80mm,
                    label: Text('80mm'),
                    icon: Icon(LucideIcons.scroll, size: 14),
                  ),
                ],
                selected: {_anchoSeleccionado},
                onSelectionChanged: (val) {
                  setState(() {
                    _anchoSeleccionado = val.first;
                    _cfg = _cfg.copyWith(anchoPapel: _anchoSeleccionado);
                  });
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Contenedor Scrollable del Chasis Físico y Ticket
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Chasis del Cabezal de Impresora Térmica
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: headWidth,
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                              bottom: Radius.circular(4),
                            ),
                            border: Border.all(
                              color: const Color(0xFF374151),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.printer,
                                      size: 14,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'CAJAYA THERMAL POS',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.6,
                                            color: const Color(0xFFD1D5DB),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.8),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6)
                                              .withValues(alpha: 0.8),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 2. Ranura de Expulsión del Papel
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: paperWidth + 14.0,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF030712),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // 3. Hoja Física de Papel Térmico
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: paperWidth,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFDF8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 16,
                          ),
                          child: SizedBox(
                            width: contentWidth,
                            child: FittedBox(
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.centerLeft,
                              child: SelectableText(
                                receiptText,
                                textAlign: TextAlign.left,
                                style: textStyle,
                              ),
                            ),
                          ),
                        ),

                        // 4. Borde en Zigzag / Dientes de Sierra (Guillotina de corte)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: paperWidth,
                          height: 6,
                          child: const CustomPaint(
                            size: Size.infinite,
                            painter: SawtoothPainter(
                              color: Color(0xFFFFFDF8),
                              toothWidth: 8.0,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 5. Pastilla Informativa de Columnas ESC/POS
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2436)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF262E44)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  is80mm
                                      ? LucideIcons.scroll
                                      : LucideIcons.receipt,
                                  size: 13,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  is80mm
                                      ? 'Papel 80 mm • 48 columnas ESC/POS'
                                      : 'Papel 58 mm • 32 columnas ESC/POS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Acciones: Copiar y Mandar a Imprimir
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.white70
                        : const Color(0xFF475569),
                    side: BorderSide(
                      color: isDark
                          ? AppTheme.borderDark
                          : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(LucideIcons.copy, size: 16),
                  label: const Text('Copiar Texto'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: receiptText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '¡Texto del ticket copiado al portapapeles!',
                        ),
                        backgroundColor: AppTheme.accentGreen,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.printer, size: 17),
                    label: Text(
                      _isPrinting ? 'Imprimiendo...' : 'Imprimir ESC/POS',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    onPressed: _isPrinting ? null : _imprimirTicket,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
