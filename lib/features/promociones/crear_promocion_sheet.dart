import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../categorias/categoria_model.dart';
import '../categorias/categoria_service.dart';
import '../../core/marca_detector_service.dart';
import '../productos/producto_model.dart';
import '../productos/producto_service.dart';
import 'promocion_model.dart';
import 'promocion_service.dart';

class CrearPromocionSheet extends StatefulWidget {
  final Promocion? promocionEdit;
  final SugerenciaComboHueso? sugerenciaHueso;
  final VoidCallback onSaved;

  const CrearPromocionSheet({
    super.key,
    this.promocionEdit,
    this.sugerenciaHueso,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    Promocion? promocionEdit,
    SugerenciaComboHueso? sugerenciaHueso,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CrearPromocionSheet(
        promocionEdit: promocionEdit,
        sugerenciaHueso: sugerenciaHueso,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<CrearPromocionSheet> createState() => _CrearPromocionSheetState();
}

class _CrearPromocionSheetState extends State<CrearPromocionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _descuentoCtrl;
  late final TextEditingController _marcaCtrl;
  late final TextEditingController _badgeTextoCtrl;

  String _alcance = 'CATEGORIA'; // CATEGORIA, MARCA, PRODUCTO, COMBO
  String _tipoPromocion = 'PORCENTAJE'; // PORCENTAJE, MONTO_FIJO, DOS_POR_UNO, TRES_POR_DOS, COMBO_HUESO
  String? _categoriaSeleccionada;
  Producto? _productoPrincipal;
  Producto? _productoSecundario;
  String _colorBadge = '#EF4444';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _guardando = false;

  List<Categoria> _categorias = [];
  List<Producto> _productos = [];
  List<MarcaInfo> _marcasDisponibles = [];
  bool _cargandoDatos = true;

  final List<Map<String, String>> _coloresDisponibles = [
    {'label': 'Rojo Fuego', 'hex': '#EF4444'},
    {'label': 'Naranja Brasa', 'hex': '#EA580C'},
    {'label': 'Verde Ahorro', 'hex': '#10B981'},
    {'label': 'Azul FinTech', 'hex': '#2563EB'},
    {'label': 'Púrpura VIP', 'hex': '#8B5CF6'},
  ];

  @override
  void initState() {
    super.initState();

    final edit = widget.promocionEdit;
    final sug = widget.sugerenciaHueso;

    if (edit != null) {
      _tituloCtrl = TextEditingController(text: edit.titulo);
      _descripcionCtrl = TextEditingController(text: edit.descripcion);
      _descuentoCtrl = TextEditingController(
        text: edit.valorDescuento > 0
            ? edit.valorDescuento.toStringAsFixed(0)
            : '',
      );
      _marcaCtrl = TextEditingController(text: edit.marcaObjetivo ?? '');
      _badgeTextoCtrl = TextEditingController(text: edit.badgeTexto);
      _alcance = edit.alcance;
      _tipoPromocion = edit.tipoPromocion;
      _categoriaSeleccionada = edit.categoriaObjetivo;
      _colorBadge = edit.colorBadge;
      if (edit.fechaInicio != null && edit.fechaInicio!.trim().isNotEmpty) {
        _fechaInicio = DateTime.tryParse(edit.fechaInicio!.trim());
      }
      if (edit.fechaFin != null && edit.fechaFin!.trim().isNotEmpty) {
        _fechaFin = DateTime.tryParse(edit.fechaFin!.trim());
      }
    } else if (sug != null) {
      _tituloCtrl = TextEditingController(text: sug.tituloSugerido);
      _descripcionCtrl = TextEditingController(text: sug.descripcionSugerida);
      _descuentoCtrl = TextEditingController(
        text: sug.porcentajeDescuentoSugerido.toStringAsFixed(0),
      );
      _marcaCtrl = TextEditingController();
      _badgeTextoCtrl = TextEditingController(text: sug.badgeSugerido);
      _alcance = 'COMBO';
      _tipoPromocion = 'COMBO_HUESO';
      _colorBadge = '#EA580C';
    } else {
      _tituloCtrl = TextEditingController(text: '¡Super Oferta!');
      _descripcionCtrl = TextEditingController(
        text: 'Descuento especial por tiempo limitado en tu catálogo online.',
      );
      _descuentoCtrl = TextEditingController(text: '15');
      _marcaCtrl = TextEditingController();
      _badgeTextoCtrl = TextEditingController(text: '🔥 OFERTA -15%');
    }

    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final (cats, prods, marcas) = await (
        CategoriaService().getCategorias(),
        ProductoService().getProductos(),
        ProductoService().getMarcas(),
      ).wait;
      if (mounted) {
        setState(() {
          _categorias = cats;
          _productos = prods;
          _marcasDisponibles = marcas;
          if (_categoriaSeleccionada == null && cats.isNotEmpty) {
            _categoriaSeleccionada = cats.first.nombre;
          }

          if (widget.sugerenciaHueso != null) {
            final sug = widget.sugerenciaHueso!;
            _productoPrincipal = prods
                .where((p) => p.idProducto == sug.idProductoHueso)
                .firstOrNull;
            _productoSecundario = prods
                .where((p) => p.idProducto == sug.idProductoEstrella)
                .firstOrNull;
          } else if (widget.promocionEdit != null) {
            final ed = widget.promocionEdit!;
            if (ed.idProductoPrincipal != null) {
              _productoPrincipal = prods
                  .where((p) => p.idProducto == ed.idProductoPrincipal)
                  .firstOrNull;
            }
            if (ed.idProductoSecundario != null) {
              _productoSecundario = prods
                  .where((p) => p.idProducto == ed.idProductoSecundario)
                  .firstOrNull;
            }
          }

          _cargandoDatos = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoDatos = false);
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _descuentoCtrl.dispose();
    _marcaCtrl.dispose();
    _badgeTextoCtrl.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFEF4444);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      if ((_tipoPromocion == 'DOS_POR_UNO' ||
              _tipoPromocion == 'TRES_POR_DOS') &&
          _productoPrincipal == null) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Por favor, selecciona el producto para la promoción.',
            ),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }

      final double valDescuento =
          (_tipoPromocion == 'DOS_POR_UNO' || _tipoPromocion == 'TRES_POR_DOS')
          ? 0.0
          : (double.tryParse(_descuentoCtrl.text.trim()) ?? 0.0);

      String? fInicioStr;
      if (_fechaInicio != null) {
        fInicioStr =
            "${_fechaInicio!.year.toString().padLeft(4, '0')}-${_fechaInicio!.month.toString().padLeft(2, '0')}-${_fechaInicio!.day.toString().padLeft(2, '0')}";
      }
      String? fFinStr;
      if (_fechaFin != null) {
        fFinStr =
            "${_fechaFin!.year.toString().padLeft(4, '0')}-${_fechaFin!.month.toString().padLeft(2, '0')}-${_fechaFin!.day.toString().padLeft(2, '0')}";
      }

      final data = <String, dynamic>{
        'titulo': _tituloCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'tipoPromocion': _tipoPromocion,
        'alcance':
            (_tipoPromocion == 'DOS_POR_UNO' ||
                _tipoPromocion == 'TRES_POR_DOS')
            ? 'PRODUCTO'
            : _alcance,
        'valorDescuento': valDescuento,
        'categoriaObjetivo': _alcance == 'CATEGORIA'
            ? _categoriaSeleccionada
            : null,
        'marcaObjetivo': _alcance == 'MARCA' ? _marcaCtrl.text.trim() : null,
        'idProductoPrincipal':
            (_alcance == 'PRODUCTO' ||
                _alcance == 'COMBO' ||
                _tipoPromocion == 'DOS_POR_UNO' ||
                _tipoPromocion == 'TRES_POR_DOS')
            ? _productoPrincipal?.idProducto
            : null,
        'nombreProductoPrincipal':
            (_alcance == 'PRODUCTO' ||
                _alcance == 'COMBO' ||
                _tipoPromocion == 'DOS_POR_UNO' ||
                _tipoPromocion == 'TRES_POR_DOS')
            ? _productoPrincipal?.nombre
            : null,
        'idProductoSecundario': _alcance == 'COMBO'
            ? _productoSecundario?.idProducto
            : null,
        'nombreProductoSecundario': _alcance == 'COMBO'
            ? _productoSecundario?.nombre
            : null,
        'badgeTexto': _badgeTextoCtrl.text.trim().isNotEmpty
            ? _badgeTextoCtrl.text.trim()
            : '🔥 OFERTA',
        'colorBadge': _colorBadge,
        'fechaInicio': fInicioStr,
        'fechaFin': fFinStr,
        'activo': true,
        'esSugerenciaHueso': widget.sugerenciaHueso != null,
      };

      if (widget.promocionEdit != null) {
        await PromocionService().actualizarPromocion(
          widget.promocionEdit!.idPromocion,
          data,
        );
      } else {
        await PromocionService().crearPromocion(data);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.promocionEdit != null
                  ? '¡Promoción actualizada con éxito!'
                  : '¡Promoción creada y activa en tu catálogo online!',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _parseColor(_colorBadge);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        LucideIcons.tag,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.promocionEdit != null
                                ? 'Editar Promoción PRO'
                                : (widget.sugerenciaHueso != null
                                      ? 'Crear Combo Antiestancamiento'
                                      : 'Nueva Promoción PRO'),
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            'Configura descuentos atractivos para tu catálogo digital online.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Selector de Alcance (Chips)
                Text(
                  'ALCANCE DE LA PROMOCIÓN',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildAlcanceChip(
                      'CATEGORIA',
                      'Por Categoría',
                      LucideIcons.layers,
                      isDark,
                    ),
                    _buildAlcanceChip(
                      'MARCA',
                      'Por Marca',
                      LucideIcons.award,
                      isDark,
                    ),
                    _buildAlcanceChip(
                      'PRODUCTO',
                      'Producto Individual',
                      LucideIcons.package,
                      isDark,
                    ),
                    _buildAlcanceChip(
                      'COMBO',
                      'Combo (2 Productos)',
                      LucideIcons.sparkles,
                      isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Campos dinámicos según el alcance
                if (_alcance == 'CATEGORIA') ...[
                  Text(
                    'CATEGORÍA BENEFICIADA',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_cargandoDatos)
                    const LinearProgressIndicator()
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _categoriaSeleccionada,
                          isExpanded: true,
                          dropdownColor: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          items: _categorias.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.nombre,
                              child: Text(
                                c.nombre,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _categoriaSeleccionada = val;
                              _tituloCtrl.text =
                                  '¡Semana de ${val ?? "Ofertas"}!';
                            });
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],

                if (_alcance == 'MARCA') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MARCA DEL PRODUCTO',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      if (_marcasDisponibles.isNotEmpty)
                        Text(
                          '${_marcasDisponibles.length} marcas en tu tienda',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Autocomplete<MarcaInfo>(
                    initialValue: TextEditingValue(text: _marcaCtrl.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return _marcasDisponibles.take(8);
                      }
                      return _marcasDisponibles.where(
                        (m) => m.nombre.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                      );
                    },
                    displayStringForOption: (m) => m.nombre,
                    onSelected: (MarcaInfo selection) {
                      setState(() {
                        _marcaCtrl.text = selection.nombre;
                        _tituloCtrl.text =
                            '¡Semana ${selection.nombre} con Descuento!';
                      });
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          if (_marcaCtrl.text.isNotEmpty &&
                              controller.text.isEmpty) {
                            controller.text = _marcaCtrl.text;
                          }
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: (value) {
                              if (_marcaCtrl.text != value) {
                                _marcaCtrl.text = value;
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Selecciona o escribe una marca (Ej. Pepsi, Bimbo...)',
                              prefixIcon: const Icon(
                                LucideIcons.award,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                              suffixIcon:
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: controller,
                                    builder: (_, value, _) =>
                                        value.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              size: 16,
                                            ),
                                            onPressed: () {
                                              controller.clear();
                                              _marcaCtrl.clear();
                                            },
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Ingresa o selecciona la marca'
                                : null,
                          );
                        },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(14),
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          child: Container(
                            width: 320,
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    option.nombre,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.brandPrimary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${option.cantidadProductos} prods',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.brandPrimary,
                                      ),
                                    ),
                                  ),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_marcasDisponibles.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _marcasDisponibles.take(6).map((m) {
                          final isSelected =
                              _marcaCtrl.text.trim().toLowerCase() ==
                              m.nombre.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(
                                '${m.nombre} (${m.cantidadProductos})',
                              ),
                              labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : AppTheme.textDark),
                              ),
                              backgroundColor: isSelected
                                  ? AppTheme.brandPrimary
                                  : (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFF1F5F9)),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 0,
                              ),
                              onPressed: () {
                                setState(() {
                                  _marcaCtrl.text = m.nombre;
                                  _tituloCtrl.text =
                                      '¡Semana ${m.nombre} con Descuento!';
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _marcaCtrl,
                    builder: (context, val, _) {
                      final currentMarca = val.text.trim();
                      if (currentMarca.isEmpty) return const SizedBox.shrink();
                      final match = _marcasDisponibles.firstWhere(
                        (m) =>
                            m.nombre.toLowerCase() ==
                            currentMarca.toLowerCase(),
                        orElse: () => MarcaInfo(
                          nombre: currentMarca,
                          cantidadProductos: _productos
                              .where(
                                (p) => MarcaDetectorService.coincideMarca(
                                  currentMarca,
                                  p.marca,
                                  p.nombre,
                                ),
                              )
                              .length,
                        ),
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.checkCircle2,
                              color: Color(0xFF10B981),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                match.cantidadProductos > 0
                                    ? 'Aplica automáticamente a los ${match.cantidadProductos} productos de "${match.nombre}" en tu catálogo online.'
                                    : 'Marca personalizada: se aplicará a productos con marca o nombre "${match.nombre}".',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                if (_alcance == 'PRODUCTO' ||
                    _alcance == 'COMBO' ||
                    _tipoPromocion == 'DOS_POR_UNO' ||
                    _tipoPromocion == 'TRES_POR_DOS') ...[
                  Text(
                    _alcance == 'COMBO'
                        ? 'PRODUCTO 1 (PRINCIPAL / HUESO)'
                        : 'PRODUCTO SELECCIONADO',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildProductSelector(
                    selected: _productoPrincipal,
                    onSelected: (p) => setState(() {
                      _productoPrincipal = p;
                      if (p != null) {
                        if (_tipoPromocion == 'TRES_POR_DOS') {
                          _tituloCtrl.text = '¡Lleva 3 Paga 2 en ${p.nombre}!';
                        } else if (_tipoPromocion == 'DOS_POR_UNO') {
                          _tituloCtrl.text = '¡Promoción 2x1 en ${p.nombre}!';
                        }
                      }
                    }),
                    hint: 'Seleccionar producto...',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                ],

                if (_alcance == 'COMBO') ...[
                  Text(
                    'PRODUCTO 2 (EMPAREJADO / ESTRELLA)',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildProductSelector(
                    selected: _productoSecundario,
                    onSelected: (p) => setState(() => _productoSecundario = p),
                    hint: 'Seleccionar producto de alta rotación...',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                ],

                // Tipo de Promoción y Descuento
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TIPO DE BENEFICIO',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _tipoPromocion,
                                isExpanded: true,
                                dropdownColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'PORCENTAJE',
                                    child: Text('Descuento %'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'MONTO_FIJO',
                                    child: Text('Rebaja en Soles (S/)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'DOS_POR_UNO',
                                    child: Text(
                                      'Promoción 2x1 (Lleva 2 Paga 1)',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'TRES_POR_DOS',
                                    child: Text(
                                      'Promoción 3x2 (Lleva 3 Paga 2)',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'COMBO_HUESO',
                                    child: Text('Combo Especial'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _tipoPromocion = val;
                                      if (val == 'TRES_POR_DOS') {
                                        _alcance = 'PRODUCTO';
                                        _badgeTextoCtrl.text = '🎁 3x2';
                                        if (_productoPrincipal != null) {
                                          _tituloCtrl.text =
                                              '¡Lleva 3 Paga 2 en ${_productoPrincipal!.nombre}!';
                                        } else {
                                          _tituloCtrl.text = '¡Súper Promo 3x2: Lleva 3 y Paga 2!';
                                        }
                                        _descripcionCtrl.text = 'Por la compra de 3 unidades, pagas solo 2 (la tercera unidad te sale GRATIS).';
                                      } else if (val == 'DOS_POR_UNO') {
                                        _alcance = 'PRODUCTO';
                                        _badgeTextoCtrl.text = '🎁 2x1';
                                        if (_productoPrincipal != null) {
                                          _tituloCtrl.text =
                                              '¡Promoción 2x1 en ${_productoPrincipal!.nombre}!';
                                        } else {
                                          _tituloCtrl.text = '¡Súper Promo 2x1: Lleva 2 Paga 1!';
                                        }
                                        _descripcionCtrl.text = 'Por la compra de 2 unidades, pagas solo 1 (la segunda unidad es GRATIS).';
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_tipoPromocion != 'DOS_POR_UNO' &&
                        _tipoPromocion != 'TRES_POR_DOS') ...[
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tipoPromocion == 'PORCENTAJE'
                                  ? 'DESCUENTO %'
                                  : 'REBAJA S/',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _descuentoCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                prefixText: _tipoPromocion == 'PORCENTAJE'
                                    ? '% '
                                    : 'S/ ',
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Requerido'
                                  : null,
                              onChanged: (v) {
                                if (_tipoPromocion == 'PORCENTAJE' &&
                                    v.isNotEmpty) {
                                  _badgeTextoCtrl.text = '🔥 -$v%';
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (_tipoPromocion == 'TRES_POR_DOS') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          color: Color(0xFF2563EB),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'En la promoción 3x2, por cada 3 unidades que compre el cliente en mostrador o catálogo, pagará solo 2 y la tercera se descontará automáticamente en caja.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_tipoPromocion == 'DOS_POR_UNO') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'En la promoción 2x1, por cada 2 unidades que compre el cliente, pagará solo 1 y la segunda será completamente gratis.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Título y Descripción
                Text(
                  'TÍTULO LLAMATIVO EN EL CATÁLOGO',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ej. ¡Semana de Bebidas Heladas!',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa el título'
                      : null,
                ),
                const SizedBox(height: 12),

                Text(
                  'DESCRIPCIÓN DEL BENEFICIO',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descripcionCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ej. 15% de descuento en todas las gaseosas para refrescar tu semana.',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Badge y Color
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ETIQUETA EN LA FOTO',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _badgeTextoCtrl,
                            decoration: InputDecoration(
                              hintText: '🔥 OFERTA',
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COLOR DEL BADGE',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: _coloresDisponibles.map((col) {
                              final c = _parseColor(col['hex']!);
                              final selected = _colorBadge == col['hex'];
                              return InkWell(
                                onTap: () =>
                                    setState(() => _colorBadge = col['hex']!),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: c.withValues(alpha: 0.6),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: selected
                                      ? const Icon(
                                          LucideIcons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // PROGRAMACIÓN DE VIGENCIA (FECHA INICIO Y FIN)
                Text(
                  'PROGRAMACIÓN DE VIGENCIA (FECHA INICIO Y FIN)',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Define desde y hasta qué fecha estará activa la promoción en tu catálogo online (opcional).',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Selector Fecha de Inicio
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _fechaInicio ?? DateTime.now(),
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                            builder: (ctx, child) => Theme(
                              data: isDark
                                  ? ThemeData.dark()
                                  : ThemeData.light(),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _fechaInicio = picked;
                              if (_fechaFin != null &&
                                  _fechaFin!.isBefore(picked)) {
                                _fechaFin = picked.add(const Duration(days: 7));
                              }
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _fechaInicio != null
                                  ? AppTheme.brandPrimary.withValues(alpha: 0.5)
                                  : (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.calendarDays,
                                size: 16,
                                color: _fechaInicio != null
                                    ? AppTheme.brandPrimary
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FECHA INICIO',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _fechaInicio != null
                                          ? '${_fechaInicio!.day.toString().padLeft(2, '0')}/${_fechaInicio!.month.toString().padLeft(2, '0')}/${_fechaInicio!.year}'
                                          : 'Hoy (Inmediato)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (_fechaInicio != null)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _fechaInicio = null),
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 14,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Selector Fecha de Fin
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final initial =
                              _fechaFin ??
                              (_fechaInicio ?? DateTime.now()).add(
                                const Duration(days: 7),
                              );
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: _fechaInicio ?? DateTime(2025),
                            lastDate: DateTime(2030),
                            builder: (ctx, child) => Theme(
                              data: isDark
                                  ? ThemeData.dark()
                                  : ThemeData.light(),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _fechaFin = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _fechaFin != null
                                  ? AppTheme.brandPrimary.withValues(alpha: 0.5)
                                  : (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.calendarClock,
                                size: 16,
                                color: _fechaFin != null
                                    ? AppTheme.brandPrimary
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FECHA FIN',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _fechaFin != null
                                          ? '${_fechaFin!.day.toString().padLeft(2, '0')}/${_fechaFin!.month.toString().padLeft(2, '0')}/${_fechaFin!.year}'
                                          : 'Sin límite (Indefinido)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (_fechaFin != null)
                                GestureDetector(
                                  onTap: () => setState(() => _fechaFin = null),
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 14,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Accesos Rápidos
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        label: const Text('1 Semana'),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide.none,
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        onPressed: () {
                          final now = DateTime.now();
                          setState(() {
                            _fechaInicio = DateTime(
                              now.year,
                              now.month,
                              now.day,
                            );
                            _fechaFin = _fechaInicio!.add(
                              const Duration(days: 7),
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('15 Días'),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide.none,
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        onPressed: () {
                          final now = DateTime.now();
                          setState(() {
                            _fechaInicio = DateTime(
                              now.year,
                              now.month,
                              now.day,
                            );
                            _fechaFin = _fechaInicio!.add(
                              const Duration(days: 15),
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Fin de Mes'),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide.none,
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        onPressed: () {
                          final now = DateTime.now();
                          final ultimoDia = DateTime(
                            now.year,
                            now.month + 1,
                            0,
                          );
                          setState(() {
                            _fechaInicio = DateTime(
                              now.year,
                              now.month,
                              now.day,
                            );
                            _fechaFin = ultimoDia;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      if (_fechaInicio != null || _fechaFin != null)
                        ActionChip(
                          label: const Text('Limpiar Fechas'),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444),
                          ),
                          side: BorderSide.none,
                          backgroundColor: const Color(0xFFEF4444)
                              .withValues(alpha: 0.1),
                          onPressed: () {
                            setState(() {
                              _fechaInicio = null;
                              _fechaFin = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.eye,
                        size: 18,
                        color: AppTheme.brandPrimary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Vista previa en tarjeta:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _badgeTextoCtrl.text.isNotEmpty
                              ? _badgeTextoCtrl.text
                              : '🔥 OFERTA',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Botón Guardar
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(LucideIcons.checkCircle2, size: 18),
                    label: Text(
                      _guardando
                          ? 'Guardando...'
                          : (widget.promocionEdit != null
                                ? 'Actualizar Promoción'
                                : 'Activar en Catálogo Online'),
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: _guardando ? null : _guardar,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlcanceChip(
    String val,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final selected = _alcance == val;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _alcance = val),
      avatar: Icon(
        icon,
        size: 14,
        color: selected ? Colors.white : AppTheme.textMuted,
      ),
      label: Text(label),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected
            ? Colors.white
            : (isDark ? Colors.white70 : AppTheme.textDark),
      ),
      selectedColor: AppTheme.brandPrimary,
      backgroundColor: isDark
          ? const Color(0xFF1E293B)
          : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildProductSelector({
    required Producto? selected,
    required ValueChanged<Producto?> onSelected,
    required String hint,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () async {
        final prod = await showDialog<Producto>(
          context: context,
          builder: (ctx) =>
              _ProductPickerModal(productos: _productos, isDark: isDark),
        );
        if (prod != null) onSelected(prod);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.search, size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected != null
                    ? '${selected.nombre} (S/ ${selected.precioVenta.toStringAsFixed(2)})'
                    : hint,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: selected != null
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: selected != null
                      ? (isDark ? Colors.white : AppTheme.textDark)
                      : AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPickerModal extends StatefulWidget {
  final List<Producto> productos;
  final bool isDark;

  const _ProductPickerModal({required this.productos, required this.isDark});

  @override
  State<_ProductPickerModal> createState() => _ProductPickerModalState();
}

class _ProductPickerModalState extends State<_ProductPickerModal> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.productos.where((p) {
      if (_filtro.isEmpty) return true;
      final q = _filtro.toLowerCase();
      return p.nombre.toLowerCase().contains(q) ||
          p.codigo.toLowerCase().contains(q) ||
          (p.marca?.toLowerCase().contains(q) ?? false);
    }).toList();

    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Seleccionar Producto',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, código o marca...',
                prefixIcon: const Icon(LucideIcons.search, size: 16),
                filled: true,
                fillColor: widget.isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _filtro = v),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text(
                        'No hay productos encontrados',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final p = filtrados[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            p.nombre,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'S/ ${p.precioVenta.toStringAsFixed(2)} • Stock: ${p.stockActual.toInt()} un.',
                            style: GoogleFonts.outfit(fontSize: 11),
                          ),
                          trailing: const Icon(
                            LucideIcons.plus,
                            size: 16,
                            color: AppTheme.brandPrimary,
                          ),
                          onTap: () => Navigator.pop(ctx, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
