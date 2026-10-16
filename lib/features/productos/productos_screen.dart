import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'producto_model.dart';
import 'producto_service.dart';
import 'nuevo_producto_sheet.dart';
import 'editar_producto_sheet.dart';
import '../movimientos/kardex_screen.dart';
import '../auth/auth_service.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../../core/theme.dart';
import '../../core/category_helper.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final ProductoService _productoService = ProductoService();
  List<Producto> _todosProductos = [];
  List<Producto> _productosFiltrados = [];
  bool _isLoading = true;
  String _filtroTexto = '';
  String _selectedCategoria = 'Todos';
  String _estadoStockFiltro = 'todos'; // 'todos', 'bajo_stock', 'con_stock'
  String _userRol = 'CAJERO';

  final TextEditingController _searchController = TextEditingController();

  List<Producto> get _safeTodos => _todosProductos;
  List<Producto> get _safeFiltrados => _productosFiltrados;

  List<String> get _categoriasDisponibles {
    final Set<String> cats = {};
    for (final p in _safeTodos) {
      final c = p.nombreCategoria?.trim();
      if (c != null && c.isNotEmpty) {
        cats.add(c);
      }
    }
    final list = cats.toList()..sort();
    return ['Todos', ...list];
  }

  int _getCountForCategoria(String cat) {
    if (cat == 'Todos') return _safeTodos.length;
    return _safeTodos.where((p) => (p.nombreCategoria?.trim() ?? 'General') == cat).length;
  }

  @override
  void initState() {
    super.initState();
    _todosProductos = [];
    _productosFiltrados = [];
    ProductoService.productosRevision.addListener(_onProductosRevisionChanged);
    _cargarRol();
    _cargarProductos();
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

  Future<void> _cargarRol() async {
    final rol = await AuthService().getUserRole();
    if (mounted) setState(() => _userRol = rol);
  }

  Future<void> _cargarProductos({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final productos = await _productoService.getProductos(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _todosProductos = List<Producto>.from(productos);
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

        // 3. Filtro por Estado de Stock
        if (_estadoStockFiltro == 'bajo_stock') {
          return p.stockActual <= 10;
        } else if (_estadoStockFiltro == 'con_stock') {
          return p.stockActual > 10;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;

    final items = _safeTodos;
    final int bajoStockCount = items.where((p) => p.stockActual <= 10).length;
    final double stockTotal = items.fold(0.0, (acc, p) => acc + p.stockActual);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _cargarProductos,
        color: AppTheme.brandPrimary,
        child: Column(
          children: [
            // Resumen de Métricas / KPI Cards
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              color: cardBg,
              child: Row(
                children: [
                  _buildKpiCard(
                    title: 'Total Items',
                    value: '${_todosProductos.length}',
                    icon: LucideIcons.boxes,
                    color: AppTheme.brandPrimary,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _buildKpiCard(
                    title: 'Bajo Stock',
                    value: '$bajoStockCount',
                    icon: LucideIcons.alertTriangle,
                    color: bajoStockCount > 0 ? AppTheme.alertRed : AppTheme.accentGreen,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _buildKpiCard(
                    title: 'Total Unid.',
                    value: stockTotal.toStringAsFixed(0),
                    icon: LucideIcons.package,
                    color: const Color(0xFF64748B),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Barra de Búsqueda y Filtros
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: cardBg,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Buscar por nombre, código o marca...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppTheme.brandPrimary),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_filtroTexto.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(LucideIcons.x, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        _filtroTexto = '';
                                        _aplicarFiltros();
                                      },
                                    ),
                                  IconButton(
                                    tooltip: 'Escanear con Cámara / Láser',
                                    icon: const Icon(LucideIcons.scanBarcode, size: 19, color: AppTheme.brandPrimary),
                                    onPressed: _escanearCodigoParaBuscar,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${_safeFiltrados.length} / ${_safeTodos.length}',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white70 : AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Pestañas de Categoría estilo POS Insignia (con icono temático y conteo)
                  if (_categoriasDisponibles.length > 1) ...[
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categoriasDisponibles.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (context, i) {
                          final cat = _categoriasDisponibles[i];
                          final isSelected = _selectedCategoria == cat;
                          final catIcon = CategoryHelper.getIcon(cat);
                          final catColor = CategoryHelper.getColor(cat, isDark);
                          final count = _getCountForCategoria(cat);

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
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
                                  borderRadius: BorderRadius.circular(14),
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
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      catIcon,
                                      size: 15,
                                      color: isSelected ? Colors.white : catColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withValues(alpha: 0.25)
                                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected ? Colors.white : AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Chips de Filtrado rápido de Stock + Acceso directo al Kardex
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Todo el Stock', 'todos', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('Por Agotar (≤10)', 'bajo_stock', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('Stock Óptimo (>10)', 'con_stock', isDark),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(LucideIcons.fileSpreadsheet, size: 15, color: AppTheme.brandPrimary),
                          label: Text(
                            'Kardex Auditoría',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                            ),
                          ),
                          backgroundColor: isDark ? AppTheme.brandPrimary.withValues(alpha: 0.15) : AppTheme.surfaceTint,
                          side: BorderSide(
                            color: isDark ? AppTheme.brandPrimary.withValues(alpha: 0.4) : AppTheme.borderTint,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const KardexScreen()),
                            );
                          },
                        ),
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

            // Lista o Grid Adaptativa
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
                                      mainAxisExtent: 130,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      floatingActionButton: _userRol == 'ADMIN'
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(LucideIcons.plus, size: 20),
              label: Text(
                'Nuevo Producto',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              onPressed: () => NuevoProductoSheet.show(context, _cargarProductos),
            )
          : null,
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: isDark ? Colors.white60 : AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final bool isSelected = _estadoStockFiltro == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : const Color(0xFF5D626A)),
      ),
      selectedColor: AppTheme.brandPrimary,
      backgroundColor: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
      side: BorderSide(
        color: isSelected
            ? AppTheme.brandPrimary
            : (isDark ? AppTheme.borderDark : const Color(0xFFE5E7EB)),
        width: 1.2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() {
          _estadoStockFiltro = value;
          _aplicarFiltros();
        });
      },
    );
  }

  Widget _buildProductCard(Producto p, bool isDark) {
    final bool stockCritico = p.stockActual <= 5;
    final bool stockBajo = p.stockActual > 5 && p.stockActual <= 10;
    final Color badgeColor = stockCritico
        ? AppTheme.alertRed
        : (stockBajo ? AppTheme.warningAmber : AppTheme.accentGreen);
    final String estadoTexto = stockCritico
        ? 'Crítico'
        : (stockBajo ? 'Bajo' : 'Óptimo');

    final catColor = CategoryHelper.getColor(p.nombreCategoria, isDark);
    final catIcon = CategoryHelper.getIcon(p.nombreCategoria);
    final categoriaNombre = p.nombreCategoria?.trim() ?? 'General';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.2,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _mostrarDetalleProducto(p),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icono Temático por Categoría con Squircle & Gradiente Sutil
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: catColor.withValues(alpha: isDark ? 0.35 : 0.22),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      catIcon,
                      color: catColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Datos del Producto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                          // Precio de Venta Destacado en Outfit
                          Text(
                            'S/ ${p.precioVenta.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Fila 2: Categoría + SKU / Marca
                      Row(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 115),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: isDark ? 0.15 : 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoriaNombre.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: catColor,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.marca != null && p.marca!.isNotEmpty
                                  ? '${p.marca!} • ${p.codigo}'
                                  : p.codigo,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Fila 3: Indicador de Stock con píldora moderna
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: badgeColor.withValues(alpha: isDark ? 0.35 : 0.2),
                                width: 0.8,
                              ),
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
                                Text(
                                  '${p.stockActual.toInt()} u. ($estadoTexto)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
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
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: catColor.withValues(alpha: isDark ? 0.4 : 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(catIcon, color: catColor, size: 26),
                    ),
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
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'SKU: ${p.codigo}${p.marca != null && p.marca!.isNotEmpty ? " • Marca: ${p.marca}" : ""}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w500,
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
                            '${p.stockActual.toStringAsFixed(0)} unid.',
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
                  if (_userRol == 'ADMIN') ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          side: const BorderSide(color: AppTheme.brandPrimary, width: 1.2),
                          foregroundColor: AppTheme.brandPrimary,
                        ),
                        icon: const Icon(LucideIcons.pencil, size: 16),
                        label: Text(
                          'EDITAR',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          EditarProductoSheet.show(context, p, _cargarProductos);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
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
}
