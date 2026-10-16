import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
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
  String? _categoriaDetectadaAuto;
  bool _categoriaModificadaManualmente = false;

  static final Map<String, List<String>> _diccionarioKeywords = {
    'LMP': [
      'detergente', 'lejia', 'lavavajilla', 'ayudin', 'sapolio', 'clorox',
      'suavitel', 'poett', 'escoba', 'esponja', 'desinfectante', 'trapeador',
      'limpiador', 'bolsa de basura', 'jabon de lavar', 'vanish', 'ariel',
      'bolivar', 'opal', r'\bace\b'
    ],
    'CPD': [
      'colino', 'colinos', 'colgate', 'kolynos', 'crema dental', 'pasta dental',
      'dentifrico', 'cepillo dental', 'shampoo', 'champu', r'\bjabon\b', 'camay',
      'dove', 'sedal', 'pantene', 'head & shoulders', 'rexona', 'papel higienico',
      'toalla higienica', 'kotex', 'nosotras', 'preservativo', 'prestobarba', 'gillette'
    ],
    'LAC': [
      'leche', 'yogur', 'yogurt', 'mantequilla', 'margarina', 'manty',
      'condensada', 'evaporada', 'chocolatada', 'pura vida', 'danlac'
    ],
    'EMB': [
      'hot dog', 'hotdog', 'salchicha', 'jamon', 'jamonada', 'tocino',
      'chorizo', 'mortadela', 'cabanossi', 'san fernando', 'braedt', 'queso edam', 'queso fresco'
    ],
    'SNK': [
      'papa', 'papas', 'lays', 'doritos', 'chizito', 'chizitos', 'piqueo',
      'cuates', 'chifle', 'mani', 'cheetos', 'cheese tris', 'tortees',
      'snax', 'karinto', 'frutos secos', 'habas', 'nachos'
    ],
    'GSE': [
      'gaseosa', 'inka kola', 'coca cola', 'fanta', 'sprite', 'guarana',
      r'\bagua\b', 'san luis', 'cielo', 'san mateo', 'sporade', 'gatorade',
      'cifrut', 'frugos', 'pulp', 'red bull', 'monster', 'volt',
      'energizante', 'rehidratante', 'jugo'
    ],
    'ALC': [
      'cerveza', 'pilsen', 'cusquena', 'cristal', 'corona', 'stella',
      'heineken', r'\bvino\b', 'tabernero', 'borgona', 'pisco', 'queirolo',
      r'\bron\b', 'cartavio', 'whisky', 'vodka', 'tequila', r'\bgin\b', 'licor'
    ],
    'ABA': [
      'fideo', 'fideos', 'tallarin', 'spaghetti', 'codito', 'canuto',
      'lavaggi', 'don vittorio', 'arroz', 'costeno', 'faraon', 'azucar',
      'paramonga', r'\bsal\b', 'emsal', 'aceite', 'primor', 'cocinero',
      'atun', 'conserva', 'fanny', 'tuco', 'sibarita', 'mayonesa',
      'alacena', 'mostaza', 'ketchup', 'tari', 'vinagre', 'sillao', 'ajinomoto'
    ],
    'HLD': [
      'helado', 'donofrio', 'peziduri', 'frio rico', 'sin parar',
      'jet', 'bombones', 'paleta', 'artika'
    ],
    'GLS': [
      'chocolate', 'sublime', 'triangulo', 'cua cua', 'dona pepa',
      'princesa', 'galleta', 'casino', 'margarita', 'tentacion',
      'oreo', 'caramelo', 'chicle', 'halls'
    ],
    'CIG': [
      'cigarro', 'cigarrillo', 'lucky', 'lucky strike', 'hamilton',
      'pall mall', 'malboro', 'marlboro', 'tabaco', 'fosforo', 'encendedor',
      'tokai', 'llama'
    ],
    'PAN': [
      r'\bpan\b', 'bimbo', 'molde', 'mermelada', 'cafe', 'nescafe',
      'altomayo', 'avena', '3 ositos', r'\bte\b', 'manzanilla',
      'herbi', 'infusion', 'cocoa', 'winter'
    ],
  };

  static String _normalizarTexto(String texto) {
    var out = texto.toLowerCase().trim();
    out = out.replaceAll('á', 'a')
             .replaceAll('é', 'e')
             .replaceAll('í', 'i')
             .replaceAll('ó', 'o')
             .replaceAll('ú', 'u')
             .replaceAll('ñ', 'n');
    return out;
  }

  String _getPrefixForCategory(String nombre) {
    final clean = _normalizarTexto(nombre);
    if (clean.contains('gaseosa') || (clean.contains('bebida') && !clean.contains('alcoh'))) {
      return 'GSE';
    } else if (clean.contains('alcoh') || clean.contains('cerveza') || clean.contains('licor')) {
      return 'ALC';
    } else if (clean.contains('snack') || clean.contains('piqueo')) {
      return 'SNK';
    } else if (clean.contains('lacteo') || clean.contains('leche')) {
      return 'LAC';
    } else if (clean.contains('embutido') || clean.contains('fiambrer')) {
      return 'EMB';
    } else if (clean.contains('abarrote') || clean.contains('fideo')) {
      return 'ABA';
    } else if (clean.contains('helado') || clean.contains('postre')) {
      return 'HLD';
    } else if (clean.contains('golosina') || clean.contains('chocolate')) {
      return 'GLS';
    } else if (clean.contains('dental') || clean.contains('personal') || clean.contains('colino')) {
      return 'CPD';
    } else if (clean.contains('limpieza') || clean.contains('hogar') || clean.contains('detergente')) {
      return 'LMP';
    } else if (clean.contains('cigar') || clean.contains('tabaco')) {
      return 'CIG';
    } else if (clean.contains('panader') || clean.contains('desayuno') || clean.contains('pan')) {
      return 'PAN';
    }
    final norm = clean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (norm.length >= 3) {
      return norm.substring(0, 3);
    }
    return '${norm}GEN'.substring(0, 3);
  }

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
    final prefix = _getPrefixForCategory(cat.nombre);
    final nextCodigo = _calcularSiguienteCodigo(prefix);
    _codigoCtrl.text = nextCodigo;
  }

  Categoria? _detectarCategoria(String nombre) {
    final norm = _normalizarTexto(nombre);

    for (final entry in _diccionarioKeywords.entries) {
      final pfx = entry.key;
      final kws = entry.value;

      bool coincide = false;
      for (final kw in kws) {
        if (kw.startsWith(r'\b')) {
          if (RegExp(kw).hasMatch(norm)) {
            coincide = true;
            break;
          }
        } else if (norm.contains(kw)) {
          coincide = true;
          break;
        }
      }

      if (coincide) {
        final catMatch = _categorias.firstWhere(
          (c) => _getPrefixForCategory(c.nombre) == pfx,
          orElse: () => _categorias.first,
        );
        return catMatch;
      }
    }
    return null;
  }

  void _onNombreChanged() {
    final texto = _nombreCtrl.text.trim();
    if (texto.isEmpty || _categorias.isEmpty) return;

    if (!_categoriaModificadaManualmente) {
      final cat = _detectarCategoria(texto);
      if (cat != null && cat.idCategoria != _idCategoriaSeleccionada) {
        setState(() {
          _idCategoriaSeleccionada = cat.idCategoria;
          _categoriaDetectadaAuto = cat.nombre;
          _actualizarCodigoSegunCategoria();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _nombreCtrl.addListener(_onNombreChanged);
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _nombreCtrl.removeListener(_onNombreChanged);
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _codigoBarrasCtrl.dispose();
    _marcaCtrl.dispose();
    _precioCtrl.dispose();
    _stockCtrl.dispose();
    _stockMinCtrl.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceTintDark : AppTheme.peachSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.folderPlus, color: AppTheme.primaryOrange, size: 20),
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
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
            filled: true,
            fillColor: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
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
              backgroundColor: AppTheme.primaryOrange,
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
  }

  Future<void> _guardarProducto() async {
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

    setState(() => _isGuardando = true);

    final barcodeClean = _codigoBarrasCtrl.text.trim().replaceAll(RegExp(r'[\r\n\t]'), '');
    final nuevo = Producto(
      idCategoria: _idCategoriaSeleccionada ?? 1,
      codigo: _codigoCtrl.text.trim(),
      codigoBarras: barcodeClean.isNotEmpty ? barcodeClean : null,
      marca: _marcaCtrl.text.trim().isNotEmpty ? _marcaCtrl.text.trim() : null,
      nombre: _nombreCtrl.text.trim(),
      precioVenta: precio,
      stockActual: stock,
      stockMinimo: stockMin,
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
              // Asa superior del modal
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

              // Cabecera del modal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceTintDark : AppTheme.peachSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.plusCircle, color: AppTheme.primaryOrange, size: 22),
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
                            color: AppTheme.textMuted,
                          ),
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
              const SizedBox(height: 20),

              // Campo Nombre
              Text(
                'Nombre del Producto *',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
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
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppTheme.primaryOrange,
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
                const LinearProgressIndicator(color: AppTheme.primaryOrange)
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
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
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
                        side: const BorderSide(color: AppTheme.primaryOrange, width: 1.2),
                        foregroundColor: AppTheme.primaryOrange,
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
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _precioCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixIcon: const Icon(LucideIcons.circleDollarSign, size: 18, color: AppTheme.primaryOrange),
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
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
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
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Requerido' : null,
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
                        color: AppTheme.primaryOrange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _mostrarOpcionesAvanzadas ? 'Ocultar campos opcionales' : 'Más opciones (Marca, Código de barras)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryOrange,
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
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
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
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
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
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
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
                ),
              ],

              const SizedBox(height: 22),

              // Botón Guardar
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isGuardando ? null : _guardarProducto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                    elevation: 3,
                    shadowColor: AppTheme.primaryOrange.withValues(alpha: 0.35),
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
}
