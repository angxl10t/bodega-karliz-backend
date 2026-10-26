import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import 'cliente_model.dart';
import 'cliente_service.dart';

class EstadoCuentaModal extends StatefulWidget {
  final Cliente cliente;
  final String nombreBodega;

  const EstadoCuentaModal({
    super.key,
    required this.cliente,
    required this.nombreBodega,
  });

  static Future<void> show(
    BuildContext context, {
    required Cliente cliente,
    required String nombreBodega,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EstadoCuentaModal(
        cliente: cliente,
        nombreBodega: nombreBodega,
      ),
    );
  }

  @override
  State<EstadoCuentaModal> createState() => _EstadoCuentaModalState();
}

class _EstadoCuentaModalState extends State<EstadoCuentaModal> {
  final ClienteService _clienteService = ClienteService();
  EstadoCuentaCliente? _estadoCuenta;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final data = await _clienteService.getEstadoCuenta(widget.cliente.idCliente!);
    if (mounted) {
      setState(() {
        _estadoCuenta = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.cliente;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDarkElevated : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: isDark ? const Border(top: BorderSide(color: AppTheme.borderDarkElevated, width: 1.2)) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Manija superior
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header Cliente
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.brandPrimary.withValues(alpha: 0.15),
                child: Text(
                  c.nombreCompleto.isNotEmpty ? c.nombreCompleto.substring(0, 1).toUpperCase() : 'C',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.brandPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombreCompleto,
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'DNI: ${c.documento ?? "No especificado"} • Tel: ${c.telefono ?? "Sin teléfono"}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tarjetas de Resumen
          Container(
            padding: const EdgeInsets.all(14),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saldo Deudor Actual', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          'S/ ${c.saldoDeudor.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: c.tieneDeuda ? AppTheme.alertRed : AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Límite de Crédito', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          'S/ ${c.limiteCredito.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: c.porcentajeCreditoUsado,
                    minHeight: 6,
                    backgroundColor: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      c.porcentajeCreditoUsado > 0.85 ? AppTheme.alertRed : AppTheme.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Título de Movimientos
          Text(
            'Historial de Compras y Abonos',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),

          // Lista de Movimientos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_estadoCuenta == null ||
                        (_estadoCuenta!.comprasCreditoRecientes.isEmpty && _estadoCuenta!.abonosRecientes.isEmpty))
                    ? Center(
                        child: Text(
                          'No hay movimientos registrados para este cliente.',
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      )
                    : ListView(
                        children: [
                          if (_estadoCuenta!.abonosRecientes.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Abonos y Pagos Recibidos',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                            ),
                            ..._estadoCuenta!.abonosRecientes.map((ab) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    dense: true,
                                    leading: const CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Color(0xFFDCFCE7),
                                      child: Icon(LucideIcons.arrowDownLeft, size: 14, color: AppTheme.accentGreen),
                                    ),
                                    title: Text(
                                      'Abono: ${ab.comprobanteNumero ?? "#${ab.idAbono}"}',
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      '${ab.metodoPago} • ${ab.fechaAbono.day}/${ab.fechaAbono.month}/${ab.fechaAbono.year}',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11),
                                    ),
                                    trailing: Text(
                                      '+ S/ ${ab.monto.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.accentGreen,
                                      ),
                                    ),
                                  ),
                                )),
                          ],
                          if (_estadoCuenta!.comprasCreditoRecientes.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                'Compras al Crédito / Fiado',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.brandPrimary,
                                ),
                              ),
                            ),
                            ..._estadoCuenta!.comprasCreditoRecientes.map((vt) {
                              final total = (vt['total'] as num?)?.toDouble() ?? 0.0;
                              final correlativo = vt['serieCorrelativo'] as String? ?? "#${vt['idVenta']}";
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  dense: true,
                                  leading: const CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Color(0xFFEFF6FF),
                                    child: Icon(LucideIcons.shoppingBag, size: 14, color: AppTheme.brandPrimary),
                                  ),
                                  title: Text(
                                    'Venta $correlativo',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    'Crédito en mostrador',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                                  ),
                                  trailing: Text(
                                    'S/ ${total.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.alertRed,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
          ),
          const SizedBox(height: 12),

          // Botón Enviar WhatsApp
          if (c.telefono != null && c.telefono!.trim().isNotEmpty && c.tieneDeuda)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => ClienteService.abrirWhatsAppRecordatorio(
                cliente: c,
                nombreBodega: widget.nombreBodega,
              ),
              icon: const Icon(LucideIcons.messageSquare, size: 17),
              label: Text(
                'Enviar Recordatorio por WhatsApp',
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    ),
  ),
);
  }
}
