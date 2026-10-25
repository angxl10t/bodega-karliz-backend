import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/configuracion_ticket_service.dart';
import '../../core/thermal_ticket_service.dart';
import '../../core/theme.dart';
import 'cliente_model.dart';
import 'cliente_service.dart';

class RegistrarAbonoSheet extends StatefulWidget {
  final Cliente cliente;
  final String nombreBodega;
  final VoidCallback onAbonoExitoso;

  const RegistrarAbonoSheet({
    super.key,
    required this.cliente,
    required this.nombreBodega,
    required this.onAbonoExitoso,
  });

  static Future<void> show(
    BuildContext context, {
    required Cliente cliente,
    required String nombreBodega,
    required VoidCallback onAbonoExitoso,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RegistrarAbonoSheet(
        cliente: cliente,
        nombreBodega: nombreBodega,
        onAbonoExitoso: onAbonoExitoso,
      ),
    );
  }

  @override
  State<RegistrarAbonoSheet> createState() => _RegistrarAbonoSheetState();
}

class _RegistrarAbonoSheetState extends State<RegistrarAbonoSheet> {
  final _montoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final ClienteService _clienteService = ClienteService();

  String _metodoPago = 'Efectivo';
  bool _isGuardando = false;
  bool _imprimiendo = false;
  String? _errorMsg;
  AbonoCredito? _abonoCreado;

  final List<String> _metodos = ['Efectivo', 'Yape', 'Plin', 'Transferencia'];

  @override
  void initState() {
    super.initState();
    _montoCtrl.text = widget.cliente.saldoDeudor.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _seleccionarMontoRapido(double monto) {
    HapticFeedback.selectionClick();
    setState(() {
      _montoCtrl.text = monto.toStringAsFixed(2);
    });
  }

  Future<void> _procesarAbono() async {
    final monto = double.tryParse(_montoCtrl.text.trim()) ?? 0.0;
    if (monto <= 0) {
      setState(() => _errorMsg = 'El monto a abonar debe ser mayor a S/ 0.00');
      return;
    }

    if (monto > widget.cliente.saldoDeudor + 0.01) {
      setState(() => _errorMsg = 'El monto no puede exceder la deuda actual (S/ ${widget.cliente.saldoDeudor.toStringAsFixed(2)})');
      return;
    }

    setState(() {
      _isGuardando = true;
      _errorMsg = null;
    });

    try {
      final abono = await _clienteService.registrarAbono(
        widget.cliente.idCliente!,
        monto: monto,
        metodoPago: _metodoPago,
        notas: _notasCtrl.text.trim().isNotEmpty ? _notasCtrl.text.trim() : null,
      );

      widget.onAbonoExitoso();
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _abonoCreado = abono;
          _isGuardando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString().replaceFirst('Exception: ', '');
          _isGuardando = false;
        });
      }
    }
  }

  Future<void> _enviarComprobanteWhatsApp() async {
    if (_abonoCreado == null) return;
    final telRaw = (widget.cliente.telefono ?? '').replaceAll(RegExp(r'\D'), '');
    if (telRaw.isEmpty) return;

    final tel = telRaw.length == 9 ? '51$telRaw' : telRaw;
    final numRecibo = _abonoCreado!.comprobanteNumero ?? 'AB-${_abonoCreado!.idAbono}';

    final mensaje = '¡Hola ${widget.cliente.nombreCompleto}! Le confirmamos su pago en *${widget.nombreBodega}* ✅.\n\n'
        '📄 *Comprobante de Abono:* $numRecibo\n'
        '💰 *Monto Abonado:* S/ ${_abonoCreado!.monto.toStringAsFixed(2)} ($_metodoPago)\n'
        '📉 *Saldo Anterior:* S/ ${_abonoCreado!.saldoAnterior.toStringAsFixed(2)}\n'
        '✨ *Saldo Restante:* S/ ${_abonoCreado!.saldoRestante.toStringAsFixed(2)}\n\n'
        '¡Muchas gracias por su puntualidad!';

    final uri = Uri.parse('https://wa.me/$tel?text=${Uri.encodeComponent(mensaje)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _imprimirComprobanteTermico() async {
    if (_abonoCreado == null || _imprimiendo) return;
    setState(() => _imprimiendo = true);

    try {
      final config = ConfiguracionTicketService.actual;
      final bytes = ThermalTicketService.generateAbonoEscPosBytes(
        comprobanteNumero: _abonoCreado!.comprobanteNumero ?? 'AB-${_abonoCreado!.idAbono}',
        clienteNombre: widget.cliente.nombreCompleto,
        clienteDocumento: widget.cliente.documento,
        montoAbonado: _abonoCreado!.monto,
        saldoAnterior: _abonoCreado!.saldoAnterior,
        saldoRestante: _abonoCreado!.saldoRestante,
        metodoPago: _abonoCreado!.metodoPago,
        notas: _abonoCreado!.notas,
        cajero: _abonoCreado!.usuarioRegistro,
        nombreComercio: widget.nombreBodega.isNotEmpty ? widget.nombreBodega : 'CajaYa POS',
        width: config.anchoPapel == 80 ? ThermalTicketService.width80mm : ThermalTicketService.width58mm,
        configTicket: config,
      );

      final text = ThermalTicketService.generateAbonoReceiptText(
        comprobanteNumero: _abonoCreado!.comprobanteNumero ?? 'AB-${_abonoCreado!.idAbono}',
        clienteNombre: widget.cliente.nombreCompleto,
        clienteDocumento: widget.cliente.documento,
        montoAbonado: _abonoCreado!.monto,
        saldoAnterior: _abonoCreado!.saldoAnterior,
        saldoRestante: _abonoCreado!.saldoRestante,
        metodoPago: _abonoCreado!.metodoPago,
        notas: _abonoCreado!.notas,
        cajero: _abonoCreado!.usuarioRegistro,
        nombreComercio: widget.nombreBodega.isNotEmpty ? widget.nombreBodega : 'CajaYa POS',
        width: config.anchoPapel == 80 ? ThermalTicketService.width80mm : ThermalTicketService.width58mm,
        configTicket: config,
      );

      final res = await ThermalTicketService.imprimirTicketDirecto(
        escPosBytes: bytes,
        receiptText: text,
        config: config,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.mensaje),
            backgroundColor: res.exito ? AppTheme.accentGreen : AppTheme.alertRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al imprimir comprobante: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_abonoCreado != null) {
      return _buildVistaExito(isDark);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Manija superior
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.banknote, size: 20, color: AppTheme.accentGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registrar Pago / Abono',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        widget.cliente.nombreCompleto,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brandPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tarjeta de Deuda Actual
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1A22) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deuda Pendiente Actual',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Límite: S/ ${widget.cliente.limiteCredito.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  Text(
                    'S/ ${widget.cliente.saldoDeudor.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.alertRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMsg != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMsg!,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppTheme.alertRed, fontWeight: FontWeight.w600),
                ),
              ),

            // Píldoras de Monto Rápido
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text('Pagar Todo (S/ ${widget.cliente.saldoDeudor.toStringAsFixed(2)})'),
                  backgroundColor: AppTheme.accentGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentGreen,
                    fontSize: 12,
                  ),
                  onPressed: () => _seleccionarMontoRapido(widget.cliente.saldoDeudor),
                ),
                if (widget.cliente.saldoDeudor > 10)
                  ActionChip(
                    label: const Text('S/ 10.00'),
                    onPressed: () => _seleccionarMontoRapido(10.0),
                  ),
                if (widget.cliente.saldoDeudor > 20)
                  ActionChip(
                    label: const Text('S/ 20.00'),
                    onPressed: () => _seleccionarMontoRapido(20.0),
                  ),
                if (widget.cliente.saldoDeudor > 50)
                  ActionChip(
                    label: const Text('S/ 50.00'),
                    onPressed: () => _seleccionarMontoRapido(50.0),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Campo de Monto a Abonar
            TextFormField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.brandPrimary),
              decoration: InputDecoration(
                labelText: 'Monto a Abonar (S/) *',
                prefixText: 'S/ ',
                prefixStyle: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),

            // Selector de Método de Pago
            Text(
              'Método de Pago Recibido',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: _metodos.map((metodo) {
                final isSelected = _metodoPago == metodo;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _metodoPago = metodo);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.brandPrimary
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            metodo,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Notas
            TextFormField(
              controller: _notasCtrl,
              decoration: InputDecoration(
                labelText: 'Nota u Observación (Opcional)',
                hintText: 'Ej. Pagó en efectivo en tienda...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),

            // Botón Confirmar Abono
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isGuardando ? null : _procesarAbono,
                icon: _isGuardando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.checkCheck, size: 20),
                label: Text(
                  'Confirmar Pago de Abono',
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildVistaExito(bool isDark) {
    final saldoRestante = _abonoCreado!.saldoRestante;
    final tieneTelefono = widget.cliente.telefono != null && widget.cliente.telefono!.trim().isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.check, size: 32, color: AppTheme.accentGreen),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '¡Abono Registrado con Éxito!',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Comprobante: ${_abonoCreado!.comprobanteNumero ?? "AB-${_abonoCreado!.idAbono}"}',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Monto Abonado:', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted)),
                    Text('S/ ${_abonoCreado!.monto.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.accentGreen)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Medio de Pago:', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted)),
                    Text(_abonoCreado!.metodoPago, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Saldo Restante:', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(
                      saldoRestante <= 0.01 ? 'DEUDA CANCELADA 🎉' : 'S/ ${saldoRestante.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: saldoRestante <= 0.01 ? AppTheme.accentGreen : AppTheme.alertRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _imprimiendo ? null : _imprimirComprobanteTermico,
            icon: _imprimiendo
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(LucideIcons.printer, size: 18),
            label: Text(
              _imprimiendo ? 'Imprimiendo comprobante...' : 'Imprimir Ticket Térmico (ESC/POS)',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          if (tieneTelefono) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _enviarComprobanteWhatsApp,
              icon: const Icon(LucideIcons.messageSquare, size: 18),
              label: Text(
                'Enviar Comprobante por WhatsApp',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar y Volver a la Libreta',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
