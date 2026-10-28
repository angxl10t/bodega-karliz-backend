import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/catalogo_imagenes_service.dart';
import '../../core/categoria_suggester_service.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../core/widgets/catalogo_foto_picker_modal.dart';
import '../categorias/categoria_model.dart';
import '../categorias/categoria_service.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import 'producto_model.dart';
import 'producto_service.dart';

class NuevoProductoSheet extends StatefulWidget {
  final VoidCallback onProductoCreado;

  const NuevoProductoSheet({
    super.key,
    required this.onProductoCreado,
  });

  static Future<void> show(BuildContext context, VoidCallback onProductoCreado) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NuevoProductoSheet(onProductoCreado: onProductoCreado),
    );
  }

  @override
  State<NuevoProductoSheet> createState() => _NuevoProductoSheetState();
}

class _NuevoProductoSheetState extends State<NuevoProductoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _codigoBarrasCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _stockMinCtrl = TextEditingController(text: '5');

  final ProductoService _productoService = ProductoService();
  final CategoriaService _categoriaService = CategoriaService();

  List<Categoria> _categorias = [];
  List<Producto> _todosLosProductos = [];
  int? _idCategoriaSeleccionada;
  bool _isLoadingCategorias = true;
  bool _isGuardando = false;
  bool _mostrarOpcionesAvanzadas = false;
  bool _controlaVencimiento = false;
  DateTime? _fechaVencimiento;
  final _precioCostoCtrl = TextEditingController();
  String? _categoriaDetectadaAuto;
  bool _categoriaModificadaManualmente = false;
  String? _imagenUrl;
  ProductoStudioFoto? _fotoSugerida;
  bool _imagenModificadaManualmente = false;

  String _calcularSiguienteCodigo(String prefix) {
    int maxNum = 0;
    final regex = RegExp('^${RegExp.escape(prefix)}-(\\d+)\$', caseSensitive: false);
    for (final prod in _todosLosProductos) {
      final match = regex.firstMatch(prod.codigo.trim());
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (num > maxNum) {
          maxNum = num;
        }
      }
    }
    final nextNum = maxNum + 1;
    final formatted = nextNum.toString().padLeft(4, '0');
    return '$prefix-$formatted';
  }

  void _actualizarCodigoSegunCategoria() {
    if (_idCategoriaSeleccionada == null || _categorias.isEmpty) return;
    final cat = _categorias.firstWhere(
      (c) => c.idCategoria == _idCategoriaSeleccionada,
      orElse: () => _categorias.first,
    );
    final prefix = CategoriaSuggesterService.getPrefixForCategory(cat.nombre);
    final nextCodigo = _calcularSiguienteCodigo(prefix);
    _codigoCtrl.text = nextCodigo;
  }

  void _actualizarSugerenciaCategoria() {
    if (_categoriaModificadaManualmente || _categorias.isEmpty) return;
    final texto = _nombreCtrl.text.trim();
    final barcode = _codigoBarrasCtrl.text.trim();
    if (texto.isEmpty && barcode.isEmpty) return;

    final cat = CategoriaSuggesterService.sugerirCategoria(
      nombre: texto.isNotEmpty ? texto : null,
      codigoBarras: barcode.isNotEmpty ? barcode : null,
      categoriasDisponibles: _categorias,
    );

    if (cat != null && cat.idCategoria != _idCategoriaSeleccionada) {
      setState(() {
        _idCategoriaSeleccionada = cat.idCategoria;
        _categoriaDetectadaAuto = cat.nombre;
        _actualizarCodigoSegunCategoria();
      });
    }
  }

  void _onNombreChanged() {
    _actualizarSugerenciaCategoria();
    _buscarFotoSugerida();
  }

  void _onCodigoBarrasChanged() {
    _actualizarSugerenciaCategoria();
    _buscarFotoSugerida();
  }

  void _buscarFotoSugerida() {
    final barcode = _codigoBarrasCtrl.text.trim();
    final nombre = _nombreCtrl.text.trim();

    if (barcode.isEmpty && (nombre.isEmpty || nombre.length < 3)) {
      if (_fotoSugerida != null && !_imagenModificadaManualmente) {
        setState(() {
          _fotoSugerida = null;
          _imagenUrl = null;
        });
      }
      return;
    }

    final sugerencia = CatalogoImagenesService.buscarSugerencia(
      codigoBarras: barcode.isNotEmpty ? barcode : null,
      nombre: nombre.isNotEmpty ? nombre : null,
    );

    if (sugerencia != null) {
      if (_fotoSugerida?.id != sugerencia.id) {
        setState(() {
          _fotoSugerida = sugerencia;
          if (!_imagenModificadaManualmente) {
            _imagenUrl = sugerencia.imagenUrl;
          }
        });
      }
    } else {
      if (_fotoSugerida != null && !_imagenModificadaManualmente) {
        setState(() {
          _fotoSugerida = null;
          _imagenUrl = null;
        });
      }
    }
  }

  String? get _categoriaSeleccionadaNombre {
    if (_idCategoriaSeleccionada == null || _categorias.isEmpty) return null;
    return _categorias
        .firstWhere((c) => c.idCategoria == _idCategoriaSeleccionada, orElse: () => _categorias.first)
        .nombre;
  }

  @override
  void initState() {
    super.initState();
    _nombreCtrl.addListener(_onNombreChanged);
    _codigoBarrasCtrl.addListener(_onCodigoBarrasChanged);
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _nombreCtrl.removeListener(_onNombreChanged);
    _codigoBarrasCtrl.removeListener(_onCodigoBarrasChanged);
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _codigoBarrasCtrl.dispose();
    _marcaCtrl.dispose();
    _precioCtrl.dispose();
    _stockCtrl.dispose();
    _stockMinCtrl.dispose();
    _precioCostoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() => _isLoadingCategorias = true);
    try {
      final results = await Future.wait([
        _categoriaService.getCategorias(),
        _productoService.getProductos(),
      ]);
      if (mounted) {
        final cats = results[0] as List<Categoria>;
        final prods = results[1] as List<Producto>;
        setState(() {
          _categorias = cats;
          _todosLosProductos = prods;
          _isLoadingCategorias = false;
          if (cats.isNotEmpty) {
            _idCategoriaSeleccionada = cats.first.idCategoria;
          } else {
            _idCategoriaSeleccionada = 1; // Default fallback
          }
          _actualizarCodigoSegunCategoria();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCategorias = false);
      }
    }
  }

  Future<void> _crearNuevaCategoriaDialog() async {
    final ctrl = TextEditingController();
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.folderPlus, color: AppTheme.brandPrimary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Nueva Categoría',
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Ej. Lácteos, Snacks, Abarrotes...',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              filled: true,
              fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF5F6F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, ctrl.text.trim());
                }
              },
              child: Text('Crear', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

      if (result != null && result.isNotEmpty) {
        final nueva = await _categoriaService.crearCategoria(result);
        if (nueva != null && mounted) {
          setState(() {
            _categorias.add(nueva);
            _idCategoriaSeleccionada = nueva.idCategoria;
            _categoriaModificadaManualmente = true;
            _categoriaDetectadaAuto = null;
            _actualizarCodigoSegunCategoria();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Categoría "$result" creada y seleccionada.'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _guardarProducto() async {
    if (_isGuardando) return;
    if (!_formKey.currentState!.validate()) return;

    final precio = double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final stock = double.tryParse(_stockCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final stockMin = double.tryParse(_stockMinCtrl.text.replaceAll(',', '.')) ?? 5.0;

    if (precio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El precio de venta debe ser mayor a 0'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    if (stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El stock inicial no puede ser negativo'),
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
    final costo = double.tryParse(_precioCostoCtrl.text.trim().replaceAll(',', '.'));
    final nuevo = Producto(
      idCategoria: _idCategoriaSeleccionada ?? 1,
      codigo: _codigoCtrl.text.trim(),
      codigoBarras: barcodeClean.isNotEmpty ? barcodeClean : null,
      marca: _marcaCtrl.text.trim().isNotEmpty ? _marcaCtrl.text.trim() : null,
      nombre: _nombreCtrl.text.trim(),
      precioVenta: precio,
      stockActual: stock,
      stockMinimo: stockMin,
      controlaVencimiento: _controlaVencimiento,
      fechaVencimiento: _controlaVencimiento ? _fechaVencimiento : null,
      precioCosto: costo,
      imagenUrl: _imagenUrl,
    );

    final res = await _productoService.crearProductoConDetalle(nuevo);

    if (!mounted) return;
    setState(() => _isGuardando = false);

    if (res.ok) {
      Navigator.pop(context);
      widget.onProductoCreado();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Producto "${nuevo.nombre}" registrado con éxito!',
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
          content: Text(res.error ?? 'Error al guardar el producto.'),
          backgroundColor: AppTheme.alertRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
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
        color: isDark ? AppTheme.cardDarkElevated : Colors.white,
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
              // Asa superior del modal
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

              // Cabecera del modal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.plusCircle, color: AppTheme.brandPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nuevo Producto',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Añadir artículo al inventario de la bodega',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tarjeta de Fotografía de Estudio (Vista Frontal)
              _buildFotoProductoCard(isDark, borderColor),
              const SizedBox(height: 18),

              // Campo Nombre
              Text(
                'Nombre del Producto *',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Ej. Galletas Casino Fresa 6pk',
                  prefixIcon: const Icon(LucideIcons.tag, size: 18),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa el nombre del producto' : null,
              ),
              const SizedBox(height: 16),

              // Selector de Categoría con botón "+ Nueva"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Categoría *',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppTheme.brandPrimary,
                    ),
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: Text(
                      'Nueva Categoría',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _crearNuevaCategoriaDialog,
                  ),
                ],
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
                      dropdownColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
                      items: _categorias.isNotEmpty
                          ? _categorias.map((cat) {
                              return DropdownMenuItem<int>(
                                value: cat.idCategoria,
                                child: Text(
                                  cat.nombre,
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
                                ),
                              );
                            }).toList()
                          : const [
                              DropdownMenuItem<int>(
                                value: 1,
                                child: Text('General (Abarrotes)'),
                              ),
                            ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _idCategoriaSeleccionada = val;
                            _categoriaModificadaManualmente = true;
                            _categoriaDetectadaAuto = null;
                            _actualizarCodigoSegunCategoria();
                          });
                        }
                      },
                    ),
                  ),
                ),
              if (_categoriaDetectadaAuto != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.sparkles, color: Color(0xFF10B981), size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Categoría detectada: $_categoriaDetectadaAuto',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Fila Código y Generador
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Código / SKU *',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _codigoCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Ej. PROD-1029',
                            prefixIcon: const Icon(LucideIcons.qrCode, size: 18),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Requerido' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 25),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        side: const BorderSide(color: AppTheme.brandPrimary, width: 1.2),
                        foregroundColor: AppTheme.brandPrimary,
                      ),
                      icon: const Icon(LucideIcons.refreshCw, size: 15),
                      label: Text(
                        'Generar',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: _actualizarCodigoSegunCategoria,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Fila Precio y Stock Inicial
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precio Venta (S/) *',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _precioCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixIcon: const Icon(LucideIcons.circleDollarSign, size: 18, color: AppTheme.brandPrimary),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Requerido';
                            final p = double.tryParse(val.replaceAll(',', '.').trim());
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
                          'Stock Inicial *',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _stockCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: '0',
                            prefixIcon: const Icon(LucideIcons.boxes, size: 18),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Requerido';
                            final s = double.tryParse(val.replaceAll(',', '.').trim());
                            if (s == null) return 'Número inválido';
                            if (s < 0) return 'No puede ser negativo';
                            if (s > 9999999.99) return 'Máx: 9,999,999.99';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Botón desplegable para Opciones Avanzadas (Marca, Código de Barras, Stock Mínimo)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _mostrarOpcionesAvanzadas = !_mostrarOpcionesAvanzadas),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _mostrarOpcionesAvanzadas ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 16,
                        color: AppTheme.brandPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _mostrarOpcionesAvanzadas ? 'Ocultar campos opcionales' : 'Más opciones (Marca, Código de barras)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_mostrarOpcionesAvanzadas) ...[
                const SizedBox(height: 10),
                // Marca
                Text(
                  'Marca del Producto (Opcional)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _marcaCtrl,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Ej. Gloria, San Jorge, Coca-Cola...',
                    prefixIcon: const Icon(LucideIcons.badgeCheck, size: 17),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Código de Barras (EAN13)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Código de Barras (Opcional)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _codigoBarrasCtrl,
                            keyboardType: TextInputType.text,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Ej. 7751234567890',
                              prefixIcon: const Icon(LucideIcons.scanBarcode, size: 17),
                              suffixIcon: IconButton(
                                tooltip: 'Escanear con cámara',
                                icon: const Icon(LucideIcons.camera, color: AppTheme.brandPrimary, size: 19),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(color: borderColor),
                              ),
                            ),
                          ),
                          if (_fotoSugerida != null &&
                              _fotoSugerida!.codigosBarras.isNotEmpty &&
                              _codigoBarrasCtrl.text.trim().isEmpty) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() {
                                  _codigoBarrasCtrl.text = _fotoSugerida!.codigosBarras.first;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.barcode, size: 14, color: Color(0xFF10B981)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'EAN oficial: ${_fotoSugerida!.codigosBarras.first} (Autocompletar)',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10B981),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          elevation: 1,
                        ),
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
                        icon: const Icon(LucideIcons.camera, size: 16),
                        label: Text(
                          'Escanear',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stock Mínimo
                Text(
                  'Alerta Stock Mínimo (Unidades)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _stockMinCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '5',
                    prefixIcon: const Icon(LucideIcons.alertTriangle, size: 17),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    final sm = double.tryParse(val.replaceAll(',', '.').trim());
                    if (sm == null) return 'Número inválido';
                    if (sm < 0) return 'No puede ser negativo';
                    if (sm > 9999999.99) return 'Máx: 9,999,999.99';
                    return null;
                  },
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
                          color: _controlaVencimiento ? AppTheme.brandPrimary : (isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
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
                                color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
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

                if (_controlaVencimiento) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFCBD5E1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.calendar, size: 16, color: AppTheme.brandPrimary),
                            const SizedBox(width: 8),
                            Text(
                              'Fecha de Caducidad de Lote',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaVencimiento ?? now.add(const Duration(days: 30)),
                              firstDate: now.subtract(const Duration(days: 365)),
                              lastDate: now.add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null) {
                              setState(() => _fechaVencimiento = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.cardDark : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _fechaVencimiento != null ? AppTheme.brandPrimary : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.calendarCheck,
                                  size: 16,
                                  color: _fechaVencimiento != null ? AppTheme.brandPrimary : (isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _fechaVencimiento != null
                                        ? '${_fechaVencimiento!.day.toString().padLeft(2, '0')}/${_fechaVencimiento!.month.toString().padLeft(2, '0')}/${_fechaVencimiento!.year}'
                                        : 'Seleccionar fecha (opcional)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: _fechaVencimiento != null ? FontWeight.w700 : FontWeight.w500,
                                      color: _fechaVencimiento != null ? (isDark ? Colors.white : AppTheme.textDark) : (isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                                    ),
                                  ),
                                ),
                                if (_fechaVencimiento != null)
                                  IconButton(
                                    icon: const Icon(LucideIcons.x, size: 16),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(() => _fechaVencimiento = null),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(LucideIcons.tag, size: 16, color: AppTheme.accentGreen),
                            const SizedBox(width: 8),
                            Text(
                              'Costo de Compra / Proveedor (S/.)',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _precioCostoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'Ej. 2.50 (Opcional, para margen y mermas)',
                            prefixIcon: const Icon(LucideIcons.coins, size: 16),
                            filled: true,
                            fillColor: isDark ? AppTheme.cardDark : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 22),

              // Botón Guardar
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isGuardando ? null : _guardarProducto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                    elevation: 3,
                    shadowColor: AppTheme.brandPrimary.withValues(alpha: 0.35),
                  ),
                  icon: _isGuardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.checkCheck, size: 20),
                  label: Text(
                    _isGuardando ? 'GUARDANDO...' : 'REGISTRAR PRODUCTO',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
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

  Widget _buildFotoProductoCard(bool isDark, Color borderColor) {
    final hasImg = _imagenUrl != null && _imagenUrl!.trim().isNotEmpty;
    final catNombre = _categoriaSeleccionadaNombre;
    final esOficialSugerida = _fotoSugerida != null && _imagenUrl == _fotoSugerida!.imagenUrl;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: esOficialSugerida
              ? AppTheme.brandPrimary.withValues(alpha: 0.5)
              : borderColor,
          width: esOficialSugerida ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Visualizador 1:1 de Estudio
              Stack(
                children: [
                  ProductImageWidget(
                    imagenUrl: _imagenUrl,
                    categoria: catNombre,
                    size: 80,
                    borderRadius: 18,
                    isDark: isDark,
                    padding: 6,
                    onTap: _abrirSelectorFoto,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _abrirSelectorFoto,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF131B2A) : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(LucideIcons.camera, size: 11, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Detalles y Estado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          hasImg ? 'Foto Frontal Asignada' : 'Foto de Estudio Frontal',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        if (esOficialSugerida) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.sparkles, size: 10, color: AppTheme.brandPrimary),
                                const SizedBox(width: 2),
                                Text(
                                  'Oficial',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.brandPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasImg
                          ? (esOficialSugerida
                              ? 'Packshot oficial: ${_fotoSugerida!.nombre}'
                              : 'Formato cuadrado 1:1 para POS y Catálogo')
                          : 'Sugerida automáticamente al escribir o escanear',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Acciones Rápidas
                    Row(
                      children: [
                        InkWell(
                          onTap: _abrirSelectorFoto,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.image, size: 13, color: AppTheme.brandPrimary),
                                const SizedBox(width: 5),
                                Text(
                                  hasImg ? 'Cambiar foto' : 'Elegir del catálogo',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.brandPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (hasImg) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _imagenUrl = null;
                                _imagenModificadaManualmente = true;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.x, size: 13, color: AppTheme.alertRed),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Quitar',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.alertRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Banner de foto sugerida disponible si no está aplicada
          if (_fotoSugerida != null && _imagenUrl != _fotoSugerida!.imagenUrl) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.sparkles, size: 15, color: AppTheme.brandPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sugerencia oficial: ${_fotoSugerida!.nombre}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.brandPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() {
                        _imagenUrl = _fotoSugerida!.imagenUrl;
                        _imagenModificadaManualmente = false;
                      });
                    },
                    child: Text(
                      'Aplicar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _abrirSelectorFoto() {
    CatalogoFotoPickerModal.show(
      context: context,
      initialUrl: _imagenUrl,
      productName: _nombreCtrl.text.trim().isNotEmpty ? _nombreCtrl.text.trim() : null,
      categoryName: _categoriaSeleccionadaNombre,
      onItemSeleccionado: (item) {
        if (item != null) {
          setState(() {
            _fotoSugerida = item;
            if (_codigoBarrasCtrl.text.trim().isEmpty && item.codigosBarras.isNotEmpty) {
              _codigoBarrasCtrl.text = item.codigosBarras.first;
            }
            if (_nombreCtrl.text.trim().isEmpty) {
              _nombreCtrl.text = item.nombre;
            }
            _actualizarSugerenciaCategoria();
          });
        }
      },
      onFotoSeleccionada: (url) {
        setState(() {
          _imagenUrl = url;
          _imagenModificadaManualmente = true;
        });
      },
    );
  }
}
