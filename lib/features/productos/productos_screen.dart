import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'producto_model.dart';
import 'producto_service.dart';
import 'nuevo_producto_sheet.dart';
import 'editar_producto_sheet.dart';
import '../movimientos/kardex_screen.dart';
import '../movimientos/ajuste_stock_sheet.dart';
import '../home/bodega_service.dart';
import '../auth/auth_service.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../../core/theme.dart';
import '../../core/category_helper.dart';
import '../../core/csv_exporter.dart';
import '../../core/widgets/product_image_widget.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final ProductoService _productoService = ProductoService();
  final BodegaService _bodegaService = BodegaService();
  BodegaInfo? _bodegaInfo;
  List<Producto> _todosProductos = [];
  List<Producto> _productosFiltrados = [];
  bool _isLoading = true;
  String _filtroTexto = '';
  String _selectedCategoria = 'Todos';
  String _estadoStockFiltro = 'todos'; // 'todos', 'bajo_stock', 'con_stock'
  String _userRol = 'CAJERO';
  bool get _esAdmin => _userRol.toUpperCase() == 'ADMIN' || _userRol.toUpperCase() == 'SUPERADMIN';

  final TextEditingController _searchController = TextEditingController();

  List<Producto> get _safeTodos => _todosProductos;
  List<Producto> get _safeFiltrados => _productosFiltrados;

  List<String> _categoriasDisponibles = ['Todos'];
  Map<String, int> _categoriaCounts = {'Todos': 0};

  void _recalcularCategorias() {
    final Map<String, int> counts = {'Todos': _safeTodos.length};
    final Set<String> cats = {};
    for (final p in _safeTodos) {
      final c = p.nombreCategoria?.trim();
      final catKey = (c != null && c.isNotEmpty) ? c : 'General';
      cats.add(catKey);
      counts[catKey] = (counts[catKey] ?? 0) + 1;
    }
    final sortedCats = cats.toList()..sort();
    _categoriasDisponibles = ['Todos', ...sortedCats];
    _categoriaCounts = counts;
  }

  int _getCountForCategoria(String cat) {
    return _categoriaCounts[cat] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _todosProductos = [];
    _productosFiltrados = [];
    ProductoService.productosRevision.addListener(_onProductosRevisionChanged);
    _inicializarDatos();
  }

  @override
  void dispose() {
    ProductoService.productosRevision.removeListener(_onProductosRevisionChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onProductosRevisionChanged() {
    if (mounted) {
      _cargarProductos(forceRefresh: true);
    }
  }

  Future<void> _inicializarDatos() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        AuthService().getUserRole(),
        _productoService.getProductos(forceRefresh: false),
        _bodegaService.obtenerMiBodega(),
      ]);
      if (mounted) {
        final rol = results[0] as String;
        final prods = results[1] as List<Producto>;
        final bInfo = results[2] as BodegaInfo?;
        setState(() {
          _userRol = rol;
          _todosProductos = List<Producto>.from(prods);
          _bodegaInfo = bInfo;
          _recalcularCategorias();
          _aplicarFiltros();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarProductos({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _productoService.getProductos(forceRefresh: forceRefresh),
      _bodegaService.obtenerMiBodega(),
    ]);
    if (mounted) {
      final productos = results[0] as List<Producto>;
      final bInfo = results[1] as BodegaInfo?;
      setState(() {
        _todosProductos = List<Producto>.from(productos);
        _bodegaInfo = bInfo;
        _recalcularCategorias();
        _aplicarFiltros();
        _isLoading = false;
      });
    }
  }

  void _aplicarFiltros() {
    final items = _safeTodos;
    final query = _filtroTexto.trim().toLowerCase();
    setState(() {
      _productosFiltrados = items.where((p) {
        // 1. Filtro por texto / búsqueda (Nombre, Código SKU, Código de Barras, Marca, Categoría)
        if (query.isNotEmpty) {
          final nombreMatch = p.nombre.toLowerCase().contains(query);
          final codMatch = p.codigo.toLowerCase().contains(query);
          final barcodeMatch = (p.codigoBarras ?? '').toLowerCase().contains(query);
          final marcaMatch = (p.marca ?? '').toLowerCase().contains(query);
          final catMatch = (p.nombreCategoria ?? '').toLowerCase().contains(query);
          if (!nombreMatch && !codMatch && !barcodeMatch && !marcaMatch && !catMatch) return false;
        }

        // 2. Filtro por Categoría seleccionada
        if (_selectedCategoria != 'Todos') {
          final cat = p.nombreCategoria?.trim() ?? 'General';
          if (cat != _selectedCategoria) return false;
        }

        // 3. Filtro por Estado de Stock (basado en el stock mínimo configurado para cada producto)
        final double umbralMinimo = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
        if (_estadoStockFiltro == 'bajo_stock') {
          return p.stockActual <= umbralMinimo;
        } else if (_estadoStockFiltro == 'con_stock') {
          return p.stockActual > umbralMinimo;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _escanearCodigoParaBuscar() async {
    final code = await KarlizBarcodeScannerModal.scan(
      context,
      title: 'Buscar Producto por Código',
      subtitle: 'Enfoque el código de barras para localizar el artículo',
    );
    if (code != null && code.isNotEmpty) {
      setState(() {
        _searchController.text = code;
        _filtroTexto = code;
        _aplicarFiltros();
      });
    }
  }

  Future<void> _exportarCsv() async {
    if (_safeTodos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos en inventario para exportar.')),
      );
      return;
    }
    final now = DateTime.now();
    final fechaStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final nombreArchivo = 'catalogo_productos_$fechaStr.csv';
    final csv = CsvExporter.generarCsvProductos(_safeTodos);
    await CsvExporter.descargarOCompartirCsv(
      nombreArchivo: nombreArchivo,
      contenidoCsv: csv,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb
              ? '¡Catálogo descargado como $nombreArchivo!'
              : '¡Catálogo exportado y copiado al portapapeles!'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;

    final items = _safeTodos;
    final int bajoStockCount = items.where((p) {
      final double umbralMinimo = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
      return p.stockActual <= umbralMinimo;
    }).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => _cargarProductos(forceRefresh: true),
        color: AppTheme.brandPrimary,
        child: Column(
          children: [
            // 1. Cabecera Compacta Integrada (Título + Resumen Minimalista + Acciones de Alto Nivel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: cardBg,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Stock & Inventario',
                          style: GoogleFonts.outfit(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${items.length} items',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: AppTheme.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              bajoStockCount > 0 ? '$bajoStockCount por agotar' : 'Stock saludable',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: bajoStockCount > 0
                                    ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                    : AppTheme.accentGreen,
                              ),
                            ),
                            if (_bodegaInfo != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: AppTheme.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildCuotaPlanBadge(isDark),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Botón Kardex como herramienta de auditoría de alto nivel
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const KardexScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.fileSpreadsheet, size: 14, color: AppTheme.brandPrimary),
                            const SizedBox(width: 5),
                            Text(
                              'Kardex',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Botón Exportar Catálogo CSV
                  const SizedBox(width: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _exportarCsv();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.download, size: 13, color: AppTheme.accentGreen),
                            const SizedBox(width: 4),
                            Text(
                              'CSV',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (_esAdmin) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          NuevoProductoSheet.show(context, _cargarProductos);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.plus, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Nuevo',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 2. Toolbar Unificada (Buscador + Carrusel Único de Filtros)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              color: cardBg,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Buscar por nombre, código o marca...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textMuted,
                                fontSize: 12.5,
                              ),
                              prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppTheme.brandPrimary),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_filtroTexto.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(LucideIcons.x, size: 15),
                                      onPressed: () {
                                        _searchController.clear();
                                        _filtroTexto = '';
                                        _aplicarFiltros();
                                      },
                                    ),
                                  IconButton(
                                    tooltip: 'Escanear con Cámara / Láser',
                                    icon: const Icon(LucideIcons.scanBarcode, size: 17, color: AppTheme.brandPrimary),
                                    onPressed: _escanearCodigoParaBuscar,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (val) {
                              _filtroTexto = val;
                              _aplicarFiltros();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Contador de resultados
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${_safeFiltrados.length} / ${_safeTodos.length}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 3. UN SOLO NIVEL DE FILTROS (Sin doble carrusel)
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Chip de Alerta Prioritaria: Por Agotar
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (_estadoStockFiltro == 'bajo_stock') {
                                  _estadoStockFiltro = 'todos';
                                } else {
                                  _estadoStockFiltro = 'bajo_stock';
                                }
                                _aplicarFiltros();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _estadoStockFiltro == 'bajo_stock'
                                    ? const Color(0xFFD97706)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _estadoStockFiltro == 'bajo_stock'
                                      ? const Color(0xFFD97706)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  width: 1.0,
                                ),
                                boxShadow: _estadoStockFiltro == 'bajo_stock'
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFD97706).withValues(alpha: 0.28),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.alertCircle,
                                    size: 13,
                                    color: _estadoStockFiltro == 'bajo_stock'
                                        ? Colors.white
                                        : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Por Agotar ($bajoStockCount)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: _estadoStockFiltro == 'bajo_stock' ? FontWeight.w800 : FontWeight.w700,
                                      color: _estadoStockFiltro == 'bajo_stock'
                                          ? Colors.white
                                          : (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Separador Vertical Sutil
                        Center(
                          child: Container(
                            width: 1,
                            height: 18,
                            color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Chips de Categorías
                        ..._categoriasDisponibles.map((cat) {
                          final isSelected = _selectedCategoria == cat;
                          final catIcon = CategoryHelper.getIcon(cat);
                          final catColor = CategoryHelper.getColor(cat, isDark);
                          final count = _getCountForCategoria(cat);

                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _selectedCategoria = cat;
                                    _aplicarFiltros();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.brandPrimary
                                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.brandPrimary
                                          : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                                      width: isSelected ? 1.4 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (cat != 'Todos') ...[
                                        Icon(
                                          catIcon,
                                          size: 13,
                                          color: isSelected ? Colors.white : catColor,
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(
                                        cat,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.25)
                                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected ? Colors.white : AppTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Línea divisoria suave
            Container(
              height: 1,
              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
            ),

            // 4. Catálogo de Productos Adaptativo (82% del espacio recuperado)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary))
                  : RefreshIndicator(
                      onRefresh: () => _cargarProductos(forceRefresh: true),
                      color: AppTheme.brandPrimary,
                      child: _safeFiltrados.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: _buildEmptyState(isDark),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth > 700) {
                                  return GridView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 380,
                                      mainAxisExtent: 116,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: _safeFiltrados.length,
                                    itemBuilder: (context, index) {
                                      return _buildProductCard(_safeFiltrados[index], isDark);
                                    },
                                  );
                                } else {
                                  return ListView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    itemCount: _safeFiltrados.length,
                                    itemBuilder: (context, index) {
                                      return _buildProductCard(_safeFiltrados[index], isDark);
                                    },
                                  );
                                }
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _esAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(LucideIcons.plus, size: 20),
              label: Text(
                'Nuevo Producto',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onPressed: () {
                final esBasico = _bodegaInfo?.plan.toUpperCase() == 'BASICO';
                final total = _todosProductos.length;
                final limite = _bodegaInfo?.limiteProductos ?? 150;
                if (esBasico && total >= limite) {
                  _mostrarModalLimitePlanBasico(context);
                } else {
                  NuevoProductoSheet.show(context, _cargarProductos);
                }
              },
            )
          : null,
    );
  }

  Widget _buildProductCard(Producto p, bool isDark) {
    final double umbralMinimo = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
    final bool stockCritico = p.stockActual <= (umbralMinimo * 0.5);
    final bool stockBajo = p.stockActual > (umbralMinimo * 0.5) && p.stockActual <= umbralMinimo;
    final Color badgeColor = stockCritico
        ? (isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48))
        : (stockBajo
            ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
            : AppTheme.accentGreen);
    final String estadoTexto = stockCritico
        ? 'Crítico'
        : (stockBajo ? 'Bajo' : 'Óptimo');

    final catColor = CategoryHelper.getColor(p.nombreCategoria, isDark);
    final catIcon = CategoryHelper.getIcon(p.nombreCategoria);
    final categoriaNombre = p.nombreCategoria?.trim() ?? 'General';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _mostrarDetalleProducto(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Packshot de Estudio Frontal o Icono de Categoría
                ProductImageWidget(
                  imagenUrl: p.imagenUrl,
                  categoria: p.nombreCategoria,
                  size: 46,
                  borderRadius: 14,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),

                // Datos del Producto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fila 1: Nombre + Precio
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              p.nombre,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'S/ ${p.precioVenta.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppTheme.textDark,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Fila 2: Metadatos limpios y tipográficos (SKU + Marca + Barcode)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'SKU: ${p.codigo}',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                            if (p.marca != null && p.marca!.isNotEmpty)
                              TextSpan(
                                text: '  •  ${p.marca!}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            if (p.codigoBarras != null && p.codigoBarras!.isNotEmpty && p.codigoBarras != p.codigo)
                              TextSpan(
                                text: '  •  ${p.codigoBarras!}',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.white38 : AppTheme.textMuted,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Fila 3: Indicador de Stock Destacado + Categoría
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: isDark ? 0.16 : 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      '${p.stockActual % 1 == 0 ? p.stockActual.toInt().toString() : p.stockActual.toStringAsFixed(2)} u. ($estadoTexto)',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: badgeColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            flex: 2,
                            child: Text(
                              categoriaNombre.toUpperCase(),
                              textAlign: TextAlign.end,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white38 : AppTheme.textMuted,
                                letterSpacing: 0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleProducto(Producto p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final catColor = CategoryHelper.getColor(p.nombreCategoria, isDark);
    final catIcon = CategoryHelper.getIcon(p.nombreCategoria);
    final categoriaNombre = p.nombreCategoria?.trim() ?? 'General';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      backgroundColor: cardBg,
      builder: (ctx) {
        final double valorTotal = p.stockActual * p.precioVenta;
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
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
              Row(
                children: [
                  // Packshot de Estudio Frontal o Icono de Categoría
                  ProductImageWidget(
                    imagenUrl: p.imagenUrl,
                    categoria: p.nombreCategoria,
                    size: 58,
                    borderRadius: 18,
                    isDark: isDark,
                    padding: 6,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nombre,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: isDark ? 0.18 : 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoriaNombre.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: catColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'SKU: ${p.codigo}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            if (p.marca != null && p.marca!.isNotEmpty)
                              Text(
                                'Marca: ${p.marca}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (p.codigoBarras != null && p.codigoBarras!.isNotEmpty && p.codigoBarras != p.codigo)
                              Text(
                                'EAN: ${p.codigoBarras}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (p.controlaVencimiento)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.amber.shade700.withValues(alpha: 0.5),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.calendarClock, size: 10, color: Colors.amber.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Perecible / Vencimiento',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF101622) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Precio Venta', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'S/ ${p.precioVenta.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.brandPrimary),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 38, color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Stock Actual', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            '${p.stockActual % 1 == 0 ? p.stockActual.toInt().toString() : p.stockActual.toStringAsFixed(2)} unid.',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textDark),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 38, color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Valor Stock', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'S/ ${valorTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.accentGreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.brandPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(LucideIcons.fileSpreadsheet, size: 16),
                  label: Text(
                    'Ver Historial de Movimientos (Kardex)',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const KardexScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_esAdmin) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          side: const BorderSide(color: Color(0xFFEA580C), width: 1.2),
                          foregroundColor: const Color(0xFFEA580C),
                        ),
                        icon: const Icon(LucideIcons.scale, size: 15),
                        label: Text(
                          'AJUSTAR',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          AjusteStockSheet.show(context, p, _cargarProductos);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          side: const BorderSide(color: AppTheme.brandPrimary, width: 1.2),
                          foregroundColor: AppTheme.brandPrimary,
                        ),
                        icon: const Icon(LucideIcons.pencil, size: 15),
                        label: Text(
                          'EDITAR',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          EditarProductoSheet.show(context, p, _cargarProductos);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: Text('LISTO', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final hasActiveFilters = _filtroTexto.isNotEmpty ||
        _selectedCategoria != 'Todos' ||
        _estadoStockFiltro != 'todos';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.packageSearch, size: 40, color: AppTheme.brandPrimary),
            ),
            const SizedBox(height: 18),
            Text(
              'No se encontraron productos',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasActiveFilters
                  ? 'No hay productos que coincidan con la categoría o filtros aplicados.'
                  : 'No hay productos registrados en el inventario.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 18),
            if (hasActiveFilters) ...[
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _searchController.clear();
                    _filtroTexto = '';
                    _selectedCategoria = 'Todos';
                    _estadoStockFiltro = 'todos';
                    _aplicarFiltros();
                  });
                },
                icon: const Icon(LucideIcons.filterX, size: 16),
                label: Text(
                  'Restablecer Filtros y Ver Todos',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextButton.icon(
              onPressed: _cargarProductos,
              icon: const Icon(LucideIcons.refreshCw, size: 15),
              label: Text(
                'Sincronizar Inventario',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuotaPlanBadge(bool isDark) {
    final info = _bodegaInfo;
    if (info == null) return const SizedBox.shrink();
    final isBasico = info.plan.toUpperCase() == 'BASICO';
    final limite = info.limiteProductos ?? 150;
    final total = _todosProductos.length;
    final alcanzado = isBasico && total >= limite;
    final porLlenar = isBasico && total >= (limite - 10) && !alcanzado;

    final Color badgeColor = alcanzado
        ? AppTheme.alertRed
        : (porLlenar ? const Color(0xFFD97706) : AppTheme.brandPrimary);

    return InkWell(
      onTap: isBasico ? () => _mostrarModalLimitePlanBasico(context) : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: isDark ? 0.22 : 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isBasico ? (alcanzado ? LucideIcons.triangleAlert : LucideIcons.package) : LucideIcons.sparkles,
              size: 11,
              color: badgeColor,
            ),
            const SizedBox(width: 4),
            Text(
              isBasico ? '$total/$limite' : 'PRO Ilimitado',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: badgeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarModalLimitePlanBasico(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
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
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.crown, color: AppTheme.brandPrimary, size: 28),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Límite de Catálogo - Plan BÁSICO',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Has alcanzado el límite de 150 productos activos para el Plan BÁSICO. Pasa al Plan PRO para desbloquear todo el potencial de tu negocio:',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101622) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  _buildVentajaPro('🚀 Catálogo y Productos Ilimitados', 'Registra todos los SKUs que necesites sin restricciones.', isDark),
                  const SizedBox(height: 10),
                  _buildVentajaPro('👥 Múltiples Cajeros con PIN', 'Crea usuarios independientes para cada turno y terminal.', isDark),
                  const SizedBox(height: 10),
                  _buildVentajaPro('🧾 Facturación Electrónica SUNAT', 'Emite Boletas y Facturas electrónicas oficiales en vivo.', isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Entendido',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVentajaPro(String titulo, String subtitulo, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.circleCheck, color: AppTheme.accentGreen, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              Text(
                subtitulo,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
