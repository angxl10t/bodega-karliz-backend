import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../categorias/categoria_model.dart';
import '../categorias/categoria_service.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import 'producto_model.dart';
import 'producto_service.dart';

class EditarProductoSheet extends StatefulWidget {
  final Producto producto;
  final VoidCallback onActualizado;

  const EditarProductoSheet({
    super.key,
    required this.producto,
    required this.onActualizado,
  });

  static Future<void> show(BuildContext context, Producto producto, VoidCallback onActualizado) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditarProductoSheet(producto: producto, onActualizado: onActualizado),
    );
  }

  @override
  State<EditarProductoSheet> createState() => _EditarProductoSheetState();
}

class _EditarProductoSheetState extends State<EditarProductoSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _precioCtrl;
  late TextEditingController _marcaCtrl;
  late TextEditingController _codigoBarrasCtrl;
  late TextEditingController _stockMinCtrl;

  final ProductoService _productoService = ProductoService();
  final CategoriaService _categoriaService = CategoriaService();

  List<Categoria> _categorias = [];
  int? _idCategoriaSeleccionada;
  bool _isLoadingCategorias = true;
  bool _isGuardando = false;
  late bool _controlaVencimiento;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.producto.nombre);
    _precioCtrl = TextEditingController(text: widget.producto.precioVenta.toStringAsFixed(2));
    _marcaCtrl = TextEditingController(text: widget.producto.marca ?? '');
    _codigoBarrasCtrl = TextEditingController(text: widget.producto.codigoBarras ?? '');
    _stockMinCtrl = TextEditingController(text: widget.producto.stockMinimo.toStringAsFixed(0));
    _controlaVencimiento = widget.producto.controlaVencimiento;
    _idCategoriaSeleccionada = widget.producto.idCategoria ?? 1;
    _cargarCategorias();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _marcaCtrl.dispose();
    _codigoBarrasCtrl.dispose();
    _stockMinCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    final cats = await _categoriaService.getCategorias();
    if (mounted) {
      setState(() {
        _categorias = cats;
        _isLoadingCategorias = false;
        if (cats.any((c) => c.idCategoria == widget.producto.idCategoria)) {
          _idCategoriaSeleccionada = widget.producto.idCategoria;
        } else if (cats.isNotEmpty) {
          _idCategoriaSeleccionada = cats.first.idCategoria;
        }
      });
    }
  }

  Future<void> _guardarCambios() async {
    if (_isGuardando) return;
    if (!_formKey.currentState!.validate()) return;

    final precio = double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final stockMin = double.tryParse(_stockMinCtrl.text.replaceAll(',', '.')) ?? 5.0;

    if (precio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El precio debe ser mayor a 0'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    if (stockMin < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El stock mínimo no puede ser negativo'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    setState(() => _isGuardando = true);

    final barcodeClean = _codigoBarrasCtrl.text.trim().replaceAll(RegExp(r'[\r\n\t]'), '');
    final actualizado = Producto(
      idProducto: widget.producto.idProducto,
      idCategoria: _idCategoriaSeleccionada ?? 1,
      codigo: widget.producto.codigo,
      codigoBarras: barcodeClean.isNotEmpty ? barcodeClean : null,
      marca: _marcaCtrl.text.trim().isNotEmpty ? _marcaCtrl.text.trim() : null,
      nombre: _nombreCtrl.text.trim(),
      precioVenta: precio,
      stockActual: widget.producto.stockActual,
      stockMinimo: stockMin,
      controlaVencimiento: _controlaVencimiento,
    );

    final res = await _productoService.actualizarProductoConDetalle(actualizado);

    if (!mounted) return;
    setState(() => _isGuardando = false);

    if (res.ok) {
      Navigator.pop(context);
      widget.onActualizado();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Producto "${actualizado.nombre}" actualizado!',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Error al actualizar el producto en el servidor'),
          backgroundColor: AppTheme.alertRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  Future<void> _confirmarDesactivar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '¿Dar de baja producto?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          'El artículo "${widget.producto.nombre}" ya no aparecerá en el catálogo ni en ventas.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Dar de baja', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmar == true && widget.producto.idProducto != null) {
      final exito = await _productoService.desactivarProducto(widget.producto.idProducto!);
      if (mounted) {
        if (exito) {
          Navigator.pop(context);
          widget.onActualizado();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto dado de baja con éxito'), backgroundColor: AppTheme.warningAmber),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al dar de baja el producto'), backgroundColor: AppTheme.alertRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final inputBg = isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8);
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 14,
        bottom: 22 + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Cabecera
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.pencil, color: AppTheme.brandPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar Producto',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'SKU: ${widget.producto.codigo}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, color: AppTheme.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Nombre
              Text(
                'Nombre del Producto *',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: borderColor)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),

              // Fila Precio y Marca
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precio Venta (S/) *',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _precioCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.brandPrimary),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.circleDollarSign, size: 18, color: AppTheme.brandPrimary),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: borderColor)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requerido';
                            final p = double.tryParse(v.replaceAll(',', '.').trim());
                            if (p == null) return 'Número inválido';
                            if (p <= 0) return 'Mayor a 0';
                            if (p > 9999999.99) return 'Máx: 9,999,999.99';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marca',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _marcaCtrl,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Ej. Gloria',
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: borderColor)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Categoría
              Text(
                'Categoría',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (_isLoadingCategorias)
                const LinearProgressIndicator(color: AppTheme.brandPrimary)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _idCategoriaSeleccionada,
                      isExpanded: true,
                      dropdownColor: isDark ? AppTheme.cardDark : Colors.white,
                      items: _categorias.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat.idCategoria,
                          child: Text(
                            cat.nombre,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _idCategoriaSeleccionada = val);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // Código de Barras y Stock Mínimo
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Código de Barras', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _codigoBarrasCtrl,
                          keyboardType: TextInputType.text,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'EAN-13',
                            prefixIcon: const Icon(LucideIcons.scanBarcode, size: 17),
                            suffixIcon: IconButton(
                              tooltip: 'Escanear con cámara',
                              icon: const Icon(LucideIcons.camera, color: AppTheme.brandPrimary, size: 18),
                              onPressed: () async {
                                final code = await KarlizBarcodeScannerModal.scan(
                                  context,
                                  title: 'Escanear Código de Barras',
                                  subtitle: 'Enfoque el código del producto para asignarlo',
                                );
                                if (code != null && code.isNotEmpty) {
                                  setState(() => _codigoBarrasCtrl.text = code);
                                }
                              },
                            ),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: borderColor)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock Mínimo Alerta', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _stockMinCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.alertTriangle, size: 17),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: borderColor)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final sm = double.tryParse(v.replaceAll(',', '.').trim());
                            if (sm == null) return 'Número inválido';
                            if (sm < 0) return 'No puede ser negativo';
                            if (sm > 9999999.99) return 'Máx: 9,999,999.99';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Control de Vencimiento / Perecible
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _controlaVencimiento ? AppTheme.brandPrimary.withValues(alpha: 0.15) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.calendarClock,
                        size: 18,
                        color: _controlaVencimiento ? AppTheme.brandPrimary : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Control de Vencimiento',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            'Alerta si el producto es perecible o tiene caducidad',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _controlaVencimiento,
                      activeTrackColor: AppTheme.brandPrimary,
                      onChanged: (val) => setState(() => _controlaVencimiento = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Botón Guardar
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isGuardando ? null : _guardarCambios,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 3,
                  ),
                  icon: _isGuardando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.checkCheck, size: 18),
                  label: Text(
                    _isGuardando ? 'GUARDANDO...' : 'GUARDAR CAMBIOS',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Botón Dar de Baja
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppTheme.alertRed),
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: Text(
                  'Dar de baja este producto',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                onPressed: _confirmarDesactivar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
