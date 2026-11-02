import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import 'garantia_botella_model.dart';
import 'garantia_botella_service.dart';

class DevolverBotellaDialog extends StatefulWidget {
  final GarantiaBotella garantia;
  final VoidCallback onDevuelto;

  const DevolverBotellaDialog({
    super.key,
    required this.garantia,
    required this.onDevuelto,
  });

  static Future<void> show(
    BuildContext context, {
    required GarantiaBotella garantia,
    required VoidCallback onDevuelto,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => DevolverBotellaDialog(
        garantia: garantia,
        onDevuelto: onDevuelto,
      ),
    );
  }

  @override
  State<DevolverBotellaDialog> createState() => _DevolverBotellaDialogState();
}

class _DevolverBotellaDialogState extends State<DevolverBotellaDialog> {
  final GarantiaBotellaService _service = GarantiaBotellaService();

  late int _cantidadADevolver;
  late double _montoAEntregar;
  final TextEditingController _notasCtrl = TextEditingController();
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cantidadADevolver = widget.garantia.botellasRestantes;
    _montoAEntregar = widget.garantia.montoRestante;
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  void _recalcularMonto() {
    if (widget.garantia.botellasRestantes > 0) {
      final unitario = widget.garantia.montoRestante / widget.garantia.botellasRestantes;
      _montoAEntregar = _cantidadADevolver * unitario;
    } else {
      _montoAEntregar = widget.garantia.montoRestante;
    }
  }

  Future<void> _confirmarDevolucion() async {
    setState(() => _procesando = true);
    HapticFeedback.heavyImpact();

    try {
      await _service.devolverGarantia(
        widget.garantia.idGarantia,
        cantidadDevolver: _cantidadADevolver,
        montoEntregado: _montoAEntregar,
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onDevuelto();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Se recibieron $_cantidadADevolver botellas y se entregó S/ ${_montoAEntregar.toStringAsFixed(2)} a ${widget.garantia.nombrePersona}!',
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final totalRestantes = widget.garantia.botellasRestantes;

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.packageCheck, color: Color(0xFF16A34A), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Devolución de Botellas',
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de la persona y lo dejado
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.user, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.garantia.nombrePersona,
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.garantia.tipoBotella} • ${widget.garantia.cantidadBotellas} botellas registradas',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : AppTheme.textMuted,
                    ),
                  ),
                  if (widget.garantia.notas != null && widget.garantia.notas!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Nota: ${widget.garantia.notas}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selector de cuántas botellas devuelve
            Text(
              '¿Cuántas botellas devuelve ahora?',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.minus, size: 16),
                        onPressed: _cantidadADevolver > 1
                            ? () {
                                setState(() {
                                  _cantidadADevolver--;
                                  _recalcularMonto();
                                });
                              }
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: Text(
                          '$_cantidadADevolver',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.plus, size: 16),
                        onPressed: _cantidadADevolver < totalRestantes
                            ? () {
                                setState(() {
                                  _cantidadADevolver++;
                                  _recalcularMonto();
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'de $totalRestantes pendientes',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? Colors.white54 : AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recuadro llamativo del dinero a entregar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.handCoins, color: Color(0xFF16A34A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dinero a Entregar al Cliente:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                        Text(
                          'S/ ${_montoAEntregar.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Nota opcional
            TextField(
              controller: _notasCtrl,
              decoration: InputDecoration(
                hintText: 'Observación de entrega (opcional)',
                filled: true,
                isDense: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _procesando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _procesando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(LucideIcons.check, size: 16),
          label: Text('Entregar S/ ${_montoAEntregar.toStringAsFixed(2)} y Recibir Envase'),
          onPressed: _procesando ? null : _confirmarDevolucion,
        ),
      ],
    );
  }
}
