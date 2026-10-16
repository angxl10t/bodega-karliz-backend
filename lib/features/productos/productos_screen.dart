import 'package:flutter/material.dart';
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
  String _categoriaFiltro = 'todos'; // 'todos', 'bajo_stock', 'con_stock'
  String _userRol = 'CAJERO';

  final TextEditingController _searchController = TextEditingController();

  List<Producto> get _safeTodos => _todosProductos;
  List<Producto> get _safeFiltrados => _productosFiltrados;

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
        if (query.isNotEmpty) {
          final nombreMatch = p.nombre.toLowerCase().contains(query);
          final codMatch = p.codigo.toLowerCase().contains(query);
          final barcodeMatch = (p.codigoBarras ?? '').toLowerCase().contains(query);
          if (!nombreMatch && !codMatch && !barcodeMatch) return false;
        }

        if (_categoriaFiltro == 'bajo_stock') {
          return p.stockActual <= 10;
        } else if (_categoriaFiltro == 'con_stock') {
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
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o código...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(LucideIcons.search, size: 19),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_filtroTexto.isNotEmpty)
                              IconButton(
                                icon: const Icon(LucideIcons.x, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _filtroTexto = '';
                                  _aplicarFiltros();
                                },
                              ),
                            IconButton(
                              tooltip: 'Escanear con Cámara',
                              icon: const Icon(LucideIcons.scanBarcode, size: 20, color: AppTheme.brandPrimary),
                              onPressed: _escanearCodigoParaBuscar,
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (val) {
                        _filtroTexto = val;
                        _aplicarFiltros();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Chips de Filtrado rápido + Acceso directo al Kardex
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Todos (${_todosProductos.length})', 'todos', isDark),
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
    final bool isSelected = _categoriaFiltro == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected
            ? AppTheme.primaryOrange
            : (isDark ? Colors.white70 : const Color(0xFF5D626A)),
      ),
      selectedColor: isDark
          ? AppTheme.primaryOrange.withValues(alpha: 0.2)
          : AppTheme.peachSurface,
      backgroundColor: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
      side: BorderSide(
        color: isSelected
            ? AppTheme.primaryOrange
            : (isDark ? AppTheme.borderDark : const Color(0xFFE5E7EB)),
        width: 1.2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() {
          _categoriaFiltro = value;
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
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
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
                // Icono / Avatar del Producto con fondo cálido
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceTintDark : AppTheme.peachSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    LucideIcons.package2,
                    color: AppTheme.primaryOrange,
                    size: 22,
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
                          // Precio de Venta Destacado
                          Text(
                            'S/ ${p.precioVenta.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Badge Código / SKU
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF101622) : const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              p.codigo,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Indicador de Stock con píldora moderna
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(14),
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
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceTintDark : AppTheme.peachSurface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(LucideIcons.package2, color: AppTheme.primaryOrange, size: 26),
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
                        Text(
                          'SKU: ${p.codigo}${p.marca != null && p.marca!.isNotEmpty ? " • Marca: ${p.marca}" : ""}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
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
                          Text('S/ ${p.precioVenta.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryOrange)),
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
                          Text('${p.stockActual.toStringAsFixed(0)} unid.', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textDark)),
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
                          Text('S/ ${valorTotal.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.accentGreen)),
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
                    foregroundColor: const Color(0xFF0D9488),
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
                          side: const BorderSide(color: AppTheme.primaryOrange, width: 1.2),
                          foregroundColor: AppTheme.primaryOrange,
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
                        backgroundColor: AppTheme.primaryOrange,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF171E2B) : AppTheme.peachSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.packageSearch, size: 40, color: AppTheme.primaryOrange),
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
              'Prueba cambiando el término de búsqueda o el filtro.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _cargarProductos,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text(
                'Sincronizar Inventario',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
