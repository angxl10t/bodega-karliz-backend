import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../productos/producto_model.dart';
import '../productos/producto_service.dart';
import 'movimiento_service.dart';

class AjusteStockSheet extends StatefulWidget {
  final Producto producto;
  final VoidCallback onAjusteCompletado;

  const AjusteStockSheet({
    super.key,
    required this.producto,
    required this.onAjusteCompletado,
  });

  static Future<void> show(
    BuildContext context,
    Producto producto,
    VoidCallback onAjusteCompletado,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AjusteStockSheet(
          producto: producto,
          onAjusteCompletado: onAjusteCompletado,
        ),
      ),
    );
  }

  @override
  State<AjusteStockSheet> createState() => _AjusteStockSheetState();
}

class _AjusteStockSheetState extends State<AjusteStockSheet> {
  final MovimientoService _movimientoService = MovimientoService();
  final TextEditingController _cantidadCtrl = TextEditingController(text: '1');
  final TextEditingController _motivoCtrl = TextEditingController();

  String _tipoAjuste = 'MERMA';
  bool _isSaving = false;

  final List<Map<String, dynamic>> _tipos = [
    {
      'id': 'MERMA',
      'label': 'Merma / Deterioro',
      'sub': 'Fruta, verdura o daño físico',
      'esSalida': true,
      'color': const Color(0xFFEA580C),
      'icon': LucideIcons.trash2,
    },
    {
      'id': 'ROTURA',
      'label': 'Rotura / Envase',
      'sub': 'Botella o empaque quebrado',
      'esSalida': true,
      'color': const Color(0xFFDC2626),
      'icon': LucideIcons.packageX,
    },
    {
      'id': 'VENCIMIENTO',
      'label': 'Vencido / Caducado',
      'sub': 'Fecha de expiración cumplida',
      'esSalida': true,
      'color': const Color(0xFFD97706),
      'icon': LucideIcons.calendarClock,
    },
    {
      'id': 'CONSUMO_INTERNO',
      'label': 'Consumo Interno',
      'sub': 'Uso en tienda o personal',
      'esSalida': true,
      'color': const Color(0xFF7C3AED),
      'icon': LucideIcons.cupSoda,
    },
    {
      'id': 'SOBRANTE',
      'label': 'Sobrante Físico',
      'sub': 'Excedente hallado en conteo',
      'esSalida': false,
      'color': AppTheme.accentGreen,
      'icon': LucideIcons.packagePlus,
    },
  ];

  final Map<String, List<String>> _motivosSugeridos = {
    'MERMA': ['Fruta/verdura mal estado', 'Empaque aplastado en bodega', 'Humedad o polilla'],
    'ROTURA': ['Botella rota al descargar', 'Frasco caído en mostrador', 'Lata abollada'],
    'VENCIMIENTO': ['Lote expirado en góndola', 'Retiro preventivo 1 día antes', 'Sin rotación comercial'],
    'CONSUMO_INTERNO': ['Limpieza y mantenimiento', 'Consumo personal turno noche', 'Muestra degustación'],
    'SOBRANTE': ['Conteo físico fin de mes', 'Ajuste de despacho proveedor', 'Error en venta anterior'],
  };

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  bool get _esSalida {
    final tipo = _tipos.firstWhere((t) => t['id'] == _tipoAjuste, orElse: () => _tipos[0]);
    return tipo['esSalida'] as bool;
  }

  double get _cantidadParsed {
    return double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0.0;
  }

  double get _nuevoStockProyectado {
    final cant = _cantidadParsed;
    if (_esSalida) {
      return widget.producto.stockActual - cant;
    } else {
      return widget.producto.stockActual + cant;
    }
  }

  Future<void> _guardarAjuste() async {
    final cant = _cantidadParsed;
    if (cant <= 0) {
      _mostrarAlerta('La cantidad debe ser mayor a cero.');
      return;
    }

    if (_esSalida && cant > widget.producto.stockActual) {
      _mostrarAlerta('No puedes descontar $cant u. porque el stock actual es de solo ${widget.producto.stockActual.toStringAsFixed(1)} u.');
      return;
    }

    final motivo = _motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      _mostrarAlerta('Ingresa o selecciona un motivo justificatorio.');
      return;
    }

    setState(() => _isSaving = true);
    final ok = await _movimientoService.registrarAjuste(
      idProducto: widget.producto.idProducto ?? 0,
      cantidad: cant,
      tipoAjuste: _tipoAjuste,
      motivo: motivo,
    );
    setState(() => _isSaving = false);

    if (ok) {
      if (mounted) {
        ProductoService.productosRevision.value++;
        widget.onAjusteCompletado();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentGreen,
            content: Row(
              children: [
                const Icon(LucideIcons.checkCheck, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ajuste registrado exitosamente en Kardex (${_esSalida ? "-" : "+"}$cant u.)',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        _mostrarAlerta('Error al registrar el ajuste. Verifica tu conexión y permisos de Administrador.');
      }
    }
  }

  void _mostrarAlerta(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.alertRed,
        content: Text(
          mensaje,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedConfig = _tipos.firstWhere((t) => t['id'] == _tipoAjuste, orElse: () => _tipos[0]);
    final Color selectedColor = selectedConfig['color'] as Color;
    final nuevoStock = _nuevoStockProyectado;
    final bool stockInvalido = _esSalida && nuevoStock < 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tirador superior
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Cabecera con datos del producto
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selectedColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selectedColor.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Icon(selectedConfig['icon'] as IconData, color: selectedColor, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajuste de Inventario (Kardex)',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    Text(
                      '${widget.producto.nombre} • SKU: ${widget.producto.codigo}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Selector de Motivo / Tipo de Ajuste
          Text(
            'Tipo de Ajuste',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tipos.map((tipo) {
                final bool isSelected = _tipoAjuste == tipo['id'];
                final Color col = tipo['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _tipoAjuste = tipo['id'] as String;
                        // Sugerir primer motivo típico
                        final sugeridos = _motivosSugeridos[_tipoAjuste];
                        if (sugeridos != null && sugeridos.isNotEmpty && _motivoCtrl.text.isEmpty) {
                          _motivoCtrl.text = sugeridos[0];
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? col.withValues(alpha: isDark ? 0.28 : 0.12)
                            : (isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8F9FA)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? col : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tipo['icon'] as IconData,
                            size: 15,
                            color: isSelected ? col : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tipo['label'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? col : (isDark ? Colors.white : AppTheme.textDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Visualizador de Stock Actual -> Nuevo Stock
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: stockInvalido
                    ? AppTheme.alertRed
                    : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Actual',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                    ),
                    Text(
                      '${widget.producto.stockActual.toStringAsFixed(1)} u.',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _esSalida ? LucideIcons.arrowRight : LucideIcons.arrowRight,
                  color: selectedColor,
                  size: 20,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _esSalida ? 'Stock Restante' : 'Nuevo Stock',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: stockInvalido ? AppTheme.alertRed : (isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                      ),
                    ),
                    Text(
                      '${nuevoStock.toStringAsFixed(1)} u.',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: stockInvalido
                            ? AppTheme.alertRed
                            : (_esSalida ? selectedColor : AppTheme.accentGreen),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (stockInvalido) ...[
            const SizedBox(height: 6),
            Text(
              '⚠️ La merma excede las existencias disponibles en tienda.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.alertRed,
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Cantidad a Ajustar
          Text(
            'Cantidad a ${_esSalida ? "descontar" : "sumar"}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(LucideIcons.minus, size: 18),
                onPressed: () {
                  final cur = _cantidadParsed;
                  if (cur > 1) {
                    setState(() => _cantidadCtrl.text = (cur - 1).toStringAsFixed(0));
                  }
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _cantidadCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(LucideIcons.plus, size: 18),
                onPressed: () {
                  final cur = _cantidadParsed;
                  setState(() => _cantidadCtrl.text = (cur + 1).toStringAsFixed(0));
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Justificación / Motivo
          Text(
            'Motivo / Justificación del Ajuste',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          // Chips de motivos rápidos
          if (_motivosSugeridos[_tipoAjuste] != null) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _motivosSugeridos[_tipoAjuste]!.map((mot) {
                final bool isSelected = _motivoCtrl.text == mot;
                return ActionChip(
                  label: Text(
                    mot,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : (isDark ? Colors.white : AppTheme.textDark),
                    ),
                  ),
                  backgroundColor: isSelected
                      ? AppTheme.brandPrimary
                      : (isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9)),
                  onPressed: () => setState(() => _motivoCtrl.text = mot),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          TextFormField(
            controller: _motivoCtrl,
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Describe la razón del ajuste para auditoría...',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              filled: true,
              fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8F9FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: stockInvalido ? Colors.grey : selectedColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.check, size: 18),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Confirmar Ajuste',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  onPressed: (_isSaving || stockInvalido) ? null : _guardarAjuste,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
