import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme.dart';
import '../../features/ventas/venta_service.dart';

/// Modal Ergonómico para el Registro Inmediato de Egresos de Caja Chica (Petty Cash)
/// Diseñado para que el Cajero o Administrador registre salidas de dinero en menos de 5 segundos
/// sin abandonar la estación de cobro (POS).
class EgresoCajaModal extends StatefulWidget {
  const EgresoCajaModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const EgresoCajaModal(),
    );
  }

  @override
  State<EgresoCajaModal> createState() => _EgresoCajaModalState();
}

class _EgresoCajaModalState extends State<EgresoCajaModal> {
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _motivoCtrl = TextEditingController();
  final VentaService _ventaService = VentaService();

  String _categoriaSeleccionada = 'VARIOS';
  bool _isSaving = false;
  String _errorMsg = '';

  static const List<({String key, String label, IconData icon})> _categorias = [
    (key: 'BOLSAS', label: 'Bolsas / Descartables', icon: LucideIcons.shoppingBag),
    (key: 'PANADERIA', label: 'Panadería / Huevos', icon: LucideIcons.croissant),
    (key: 'HIELO', label: 'Hielo / Bebidas', icon: LucideIcons.snowflake),
    (key: 'LIMPIEZA', label: 'Artículos de Limpieza', icon: LucideIcons.sparkles),
    (key: 'PROVEEDOR', label: 'Pago Menor Proveedor', icon: LucideIcons.truck),
    (key: 'VARIOS', label: 'Gastos Varios / Menores', icon: LucideIcons.receipt),
  ];

  static const List<double> _montosRapidos = [2.0, 5.0, 10.0, 20.0, 50.0];

  @override
  void dispose() {
    _montoCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  void _seleccionarMontoRapido(double monto) {
    HapticFeedback.selectionClick();
    setState(() {
      _montoCtrl.text = monto.toStringAsFixed(2);
      _errorMsg = '';
    });
  }

  Future<void> _guardarEgreso() async {
    final montoStr = _montoCtrl.text.trim().replaceAll(',', '.');
    final monto = double.tryParse(montoStr) ?? 0.0;

    if (monto <= 0) {
      HapticFeedback.heavyImpact();
      setState(() => _errorMsg = 'Ingresa un monto válido mayor a S/ 0.00');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = '';
    });

    try {
      final motivo = _motivoCtrl.text.trim().isNotEmpty
          ? _motivoCtrl.text.trim()
          : 'Egreso de caja chica ($_categoriaSeleccionada)';

      final ok = await _ventaService.registrarEgreso(
        monto: monto,
        motivo: motivo,
        categoriaGasto: _categoriaSeleccionada,
      );

      if (!mounted) return;

      if (ok) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(LucideIcons.circleCheck, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Egreso de S/ ${monto.toStringAsFixed(2)} registrado en caja.',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _isSaving = false;
          _errorMsg = 'Error al registrar el egreso en el servidor.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _isSaving = false;
        _errorMsg = 'Excepción: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isDark ? const BorderSide(color: AppTheme.borderDarkElevated, width: 1) : BorderSide.none,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.arrowDownRight, color: Color(0xFFE11D48), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Egreso Rápido de Caja',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Retiro inmediato de efectivo del cajón para gastos menores',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Campo de Monto Principal
              Text(
                'Monto a Retirar de Caja Chica:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _montoCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE11D48),
                ),
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 6),
                    child: Center(
                      widthFactor: 0.0,
                      child: Text(
                        'S/',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                  ),
                  hintText: '0.00',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE11D48), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _guardarEgreso(),
              ),
              const SizedBox(height: 10),

              // Botones de Monto Rápido
              Row(
                children: _montosRapidos.map((m) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => _seleccionarMontoRapido(m),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDarkElevated : AppTheme.borderLight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '+S/ ${m.toInt()}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Categoría de Gasto (Chips)
              Text(
                'Categoría de Gasto Menor:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categorias.map((cat) {
                  final isSelected = _categoriaSeleccionada == cat.key;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _categoriaSeleccionada = cat.key);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE11D48).withValues(alpha: 0.15)
                            : (isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFE11D48)
                              : (isDark ? AppTheme.borderDarkElevated : AppTheme.borderLight),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat.icon,
                            size: 14,
                            color: isSelected ? const Color(0xFFE11D48) : (isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? Colors.white : const Color(0xFFBE123C))
                                  : (isDark ? AppTheme.textDarkSecondary : AppTheme.textDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Detalle / Motivo opcional
              Text(
                'Detalle / Observación (Opcional):',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _motivoCtrl,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Ej. 50 bolsas plásticas grandes, delivery pan, etc.',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF101622) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),

              if (_errorMsg.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.alertRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, size: 16, color: AppTheme.alertRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppTheme.alertRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Botones de Acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _isSaving ? null : _guardarEgreso,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(LucideIcons.arrowDownRight, size: 18),
                      label: Text(
                        _isSaving ? 'Registrando...' : 'Registrar Egreso',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
