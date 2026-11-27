import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'producto_model.dart';
import 'producto_service.dart';
import 'nuevo_producto_sheet.dart';
import 'editar_producto_sheet.dart';
import 'sugerencias_precio_modal.dart';
import '../movimientos/kardex_screen.dart';
import '../movimientos/ajuste_stock_sheet.dart';
import '../movimientos/vencimientos_screen.dart';
import '../movimientos/mermas_screen.dart';
import '../movimientos/auditoria_ciega_screen.dart';
import '../../core/widgets/plan_upgrade_modal.dart';
import '../../core/widgets/pago_yape_modal.dart';
import '../dashboard/dashboard_bi_screen.dart';
import '../home/bodega_service.dart';
import '../auth/auth_service.dart';
import '../marketing/kit_marketing_barrio_modal.dart';
import '../../core/secure_storage_service.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme.dart';
import '../../core/widgets/adaptive_modal.dart';
import '../../core/category_helper.dart';
import '../../core/csv_exporter.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../core/permisos_cajero_service.dart';
import '../../core/widgets/solicitar_pin_dialog.dart';
import '../../core/widgets/tab_deferred_refresh.dart';

class ProductosScreen extends StatefulWidget {
  final ValueListenable<int>? activeTabNotifier;
  final int? tabIndex;

  const ProductosScreen({super.key, this.activeTabNotifier, this.tabIndex});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen>
    with TabDeferredRefreshMixin<ProductosScreen> {
  final ProductoService _productoService = ProductoService();
  final BodegaService _bodegaService = BodegaService();

  @override
  ValueListenable<int>? get tabVisibilityNotifier => widget.activeTabNotifier;

  @override
  int? get assignedTabIndex => widget.tabIndex;

  @override
  void onDeferredTabRefresh() => _cargarProductos(forceRefresh: true);
  BodegaInfo? _bodegaInfo;
  String? _savedSlug;

  bool get _esGastronomico {
    final giro = (_bodegaInfo?.giroNegocio ?? '').toUpperCase();
    return giro == 'POLLERIA' ||
        giro == 'CHIFA' ||
        giro == 'FASTFOOD' ||
        giro.contains('FAST') ||
        giro == 'RESTAURANTE';
  }

  List<Producto> _todosProductos = [];
  List<Producto> _productosFiltrados = [];
  bool _isLoading = true;
  String _filtroTexto = '';
  String _selectedCategoria = 'Todos';
  String _estadoStockFiltro =
      'todos'; // 'todos', 'bajo_stock', 'critico', 'con_stock', 'vencen_pronto'
  String _criterioOrden = 'nombre'; // 'nombre', 'stock_asc', 'stock_desc', 'precio_desc', 'margen_desc', 'fifo'
  bool _modoCatalogoWeb = false;
  String _userRol = 'CAJERO';
  int _sugerenciasPendientes = 0;
  bool get _esAdmin =>
      _userRol.toUpperCase() == 'ADMIN' ||
      _userRol.toUpperCase() == 'SUPERADMIN';

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Producto> get _safeTodos => _todosProductos;
  List<Producto> get _safeFiltrados => _productosFiltrados;

  double get _capitalInvertido {
    double total = 0;
    for (final p in _safeTodos) {
      total += p.stockActual * p.costoUnitarioEstimado;
    }
    return total;
  }

  double get _ventaProyectada {
    double total = 0;
    for (final p in _safeTodos) {
      total += p.stockActual * p.precioVenta;
    }
    return total;
  }

  double get _margenGlobalPromedio {
    final v = _ventaProyectada;
    final c = _capitalInvertido;
    if (v <= 0) return 0.0;
    return ((v - c) / v) * 100.0;
  }

  List<String> _categoriasDisponibles = ['Todos'];
  Map<String, int> _categoriaCounts = {'Todos': 0};

  void _recalcularCategorias() {
    final Map<String, int> counts = {'Todos': _safeTodos.length};
    final Set<String> cats = {};
    for (final p in _safeTodos) {
      final catKey = CategoryHelper.normalize(p.nombreCategoria);
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
    initTabVisibilityListener();
    BodegaService.sugerenciasPendientesNotifier.addListener(
      _onSugerenciasNotifierChanged,
    );
    _todosProductos = [];
    _productosFiltrados = [];
    ProductoService.productosRevision.addListener(_onProductosRevisionChanged);
    PermisosCajeroService.permisosRevision.addListener(_onPermisosChanged);
    _inicializarDatos();
  }

  @override
  void dispose() {
    BodegaService.sugerenciasPendientesNotifier.removeListener(
      _onSugerenciasNotifierChanged,
    );
    disposeTabVisibilityListener();
    _searchDebounce?.cancel();
    ProductoService.productosRevision.removeListener(
      _onProductosRevisionChanged,
    );
    PermisosCajeroService.permisosRevision.removeListener(_onPermisosChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onPermisosChanged() {
    if (mounted) setState(() {});
  }

  void _onProductosRevisionChanged() {
    runWhenTabVisible(() => _cargarProductos(forceRefresh: true));
  }

  void _onSugerenciasNotifierChanged() {
    if (mounted) {
      setState(() {
        _sugerenciasPendientes =
            BodegaService.sugerenciasPendientesNotifier.value;
      });
    }
  }

  Future<void> _verificarSugerencias() async {
    try {
      final count = await _bodegaService.contarMisSugerenciasPendientes();
      if (mounted) {
        setState(() => _sugerenciasPendientes = count);
      }
    } catch (_) {}
  }

  Future<void> _inicializarDatos() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        AuthService().getUserRole(),
        _productoService.getProductos(forceRefresh: false),
        _bodegaService.obtenerMiBodega(),
        SecureStorageService.read('tienda_slug'),
      ]);
      _verificarSugerencias();
      if (mounted) {
        final rol = results[0] as String;
        final prods = results[1] as List<Producto>;
        final bInfo = results[2] as BodegaInfo?;
        final sSlug = results[3] as String?;
        setState(() {
          _userRol = rol;
          _todosProductos = List<Producto>.from(prods);
          _bodegaInfo = bInfo;
          _savedSlug = sSlug;
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
    _verificarSugerencias();
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
          final barcodeMatch = (p.codigoBarras ?? '').toLowerCase().contains(
            query,
          );
          final marcaMatch = (p.marca ?? '').toLowerCase().contains(query);
          final catMatch = (p.nombreCategoria ?? '').toLowerCase().contains(
            query,
          );
          if (!nombreMatch &&
              !codMatch &&
              !barcodeMatch &&
              !marcaMatch &&
              !catMatch)
            return false;
        }

        // 2. Filtro por Categoría seleccionada
        if (_selectedCategoria != 'Todos') {
          final cat = CategoryHelper.normalize(p.nombreCategoria);
          if (cat != _selectedCategoria) return false;
        }

        // 3. Filtro por Estado de Stock / Vencimiento
        final double umbralMinimo = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
        if (_estadoStockFiltro == 'bajo_stock') {
          return p.stockActual > (umbralMinimo * 0.5) &&
              p.stockActual <= umbralMinimo;
        } else if (_estadoStockFiltro == 'critico') {
          return p.stockActual <= (umbralMinimo * 0.5);
        } else if (_estadoStockFiltro == 'vencen_pronto' ||
            _estadoStockFiltro == 'fifo') {
          return p.controlaVencimiento &&
              (p.semaforoVencimiento == SemaforoVencimiento.critico ||
                  p.semaforoVencimiento == SemaforoVencimiento.atencion);
        } else if (_estadoStockFiltro == 'con_stock') {
          return p.stockActual > umbralMinimo;
        }
        return true;
      }).toList();

      _productosFiltrados.sort((a, b) {
        if (_criterioOrden == 'stock_asc') {
          final cmp = a.stockActual.compareTo(b.stockActual);
          if (cmp != 0) return cmp;
        } else if (_criterioOrden == 'stock_desc') {
          final cmp = b.stockActual.compareTo(a.stockActual);
          if (cmp != 0) return cmp;
        } else if (_criterioOrden == 'precio_desc') {
          final cmp = b.precioVenta.compareTo(a.precioVenta);
          if (cmp != 0) return cmp;
        } else if (_criterioOrden == 'margen_desc') {
          final mA = a.precioVenta > 0
              ? (a.precioVenta - a.costoUnitarioEstimado) / a.precioVenta
              : 0.0;
          final mB = b.precioVenta > 0
              ? (b.precioVenta - b.costoUnitarioEstimado) / b.precioVenta
              : 0.0;
          final cmp = mB.compareTo(mA);
          if (cmp != 0) return cmp;
        } else if (_criterioOrden == 'fifo' ||
            _estadoStockFiltro == 'vencen_pronto' ||
            _estadoStockFiltro == 'fifo') {
          final aExp = a.controlaVencimiento && a.fechaVencimiento != null;
          final bExp = b.controlaVencimiento && b.fechaVencimiento != null;
          if (aExp && !bExp) return -1;
          if (!aExp && bExp) return 1;
          if (aExp && bExp) {
            final cmp = a.fechaVencimiento!.compareTo(b.fechaVencimiento!);
            if (cmp != 0) return cmp;
          }
        }
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
    });
  }

  Future<void> _escanearCodigoParaBuscar() async {
    final code = await KarlizBarcodeScannerModal.scan(
      context,
      title: 'Buscar Producto por Código',
      subtitle: 'Enfoque el código de barras para localizar el artículo',
    );
    if (!mounted) return;
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
        const SnackBar(
          content: Text('No hay productos en inventario para exportar.'),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final fechaStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final nombreArchivo = 'catalogo_productos_$fechaStr.csv';
    final csv = CsvExporter.generarCsvProductos(_safeTodos);
    await CsvExporter.descargarOCompartirCsv(
      nombreArchivo: nombreArchivo,
      contenidoCsv: csv,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? '¡Catálogo descargado como $nombreArchivo!'
                : '¡Catálogo exportado y copiado al portapapeles!',
          ),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 600;
    final isMobileFullScroll =
        !ResponsiveLayout.isPhysicalTablet(context) &&
        (ResponsiveLayout.isMobile(context) ||
            MediaQuery.sizeOf(context).height < 520);

    final items = _safeTodos;
    final int bajoStockCount = items.where((p) {
      final double umbralMinimo = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
      return p.stockActual > (umbralMinimo * 0.5) &&
          p.stockActual <= umbralMinimo;
    }).length;
    final int criticoCount = items.where((p) {
      final double umbralMinimo = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
      return p.stockActual <= (umbralMinimo * 0.5);
    }).length;
    final int vencenProntoCount = items
        .where(
          (p) =>
              p.controlaVencimiento &&
              p.semaforoVencimiento == SemaforoVencimiento.critico,
        )
        .length;
    final int totalAlertasStock = bajoStockCount + criticoCount;

    final topSections = <Widget>[
      // 1. Cabecera Compacta Integrada (Título + Resumen Minimalista + Acciones de Alto Nivel)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: cardBg,
        child: Row(
          children: [
            if (ModalRoute.of(context)?.canPop ?? false) ...[
              IconButton(
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Regresar',
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _esGastronomico ? 'Carta & Menú' : 'Stock & Inventario',
                    style: GoogleFonts.outfit(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${items.length} ${_esGastronomico ? "platos/ítems" : "items"}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getAdaptiveMutedText(isDark),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.getAdaptiveMutedText(isDark),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          totalAlertasStock > 0
                              ? '$totalAlertasStock ${_esGastronomico ? "insumos por agotar" : "por agotar"}'
                              : (_esGastronomico
                                    ? 'Carta disponible'
                                    : 'Stock saludable'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: totalAlertasStock > 0
                                ? (isDark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFD97706))
                                : AppTheme.accentGreen,
                          ),
                        ),
                        if (_bodegaInfo != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppTheme.getAdaptiveMutedText(isDark),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildCuotaPlanBadge(isDark),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menú Integral de Inventario y Auditoría
            PopupMenuButton<String>(
              tooltip: 'Herramientas de Inventario',
              offset: const Offset(0, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDark ? AppTheme.cardDarkElevated : Colors.white,
              elevation: 8,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrowScreen ? 7 : 10,
                  vertical: 6.5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.cardDarkHighlight
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.borderDarkElevated
                        : const Color(0xFFCBD5E1),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          LucideIcons.boxes,
                          size: 14,
                          color: AppTheme.brandPrimary,
                        ),
                        if (!_esGastronomico &&
                            _safeTodos.any(
                              (p) =>
                                  p.controlaVencimiento &&
                                  p.semaforoVencimiento ==
                                      SemaforoVencimiento.critico,
                            ))
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!isNarrowScreen) ...[
                      const SizedBox(width: 5),
                      Text(
                        'Inventario',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Icon(
                      LucideIcons.chevronDown,
                      size: 12,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
              onSelected: (val) async {
                HapticFeedback.selectionClick();
                if (val == 'vencimientos') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VencimientosScreen(),
                    ),
                  ).then((_) => _cargarProductos());
                } else if (val == 'mermas') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MermasScreen()),
                  ).then((_) => _cargarProductos());
                } else if (val == 'auditoria') {
                  final esBasico = _bodegaInfo?.plan.toUpperCase() != 'PRO';
                  if (esBasico) {
                    PlanUpgradeModal.show(
                      context,
                      featureName: 'Auditoría Rápida por Pasillo',
                      featureDescription: 'Realiza conteos físicos aleatorios de 5 minutos por góndola o pasillo sin mostrar el stock real al personal, detectando mermas y robo hormiga a tiempo.',
                      icon: LucideIcons.clipboardCheck,
                      onPlanUpdated: _cargarProductos,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AuditoriaCiegaScreen(),
                      ),
                    ).then((_) => _cargarProductos());
                  }
                } else if (val == 'hueso') {
                  final esBasico = _bodegaInfo?.plan.toUpperCase() != 'PRO';
                  if (esBasico) {
                    PlanUpgradeModal.show(
                      context,
                      featureName: 'Detector de Productos Hueso',
                      featureDescription: 'Identifica qué productos llevan más de 30 días sin ventas para armar combos, liquidar ofertas y recuperar tu capital de trabajo inmovilizado en góndola.',
                      icon: LucideIcons.archive,
                      onPlanUpdated: _cargarProductos,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const DashboardBiScreen(initialTabRotacion: 1),
                      ),
                    ).then((_) => _cargarProductos());
                  }
                } else if (val == 'kardex') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KardexScreen()),
                  );
                } else if (val == 'sugerencias') {
                  await SugerenciasPrecioModal.show(
                    context,
                    onActualizado: () {
                      _cargarProductos(forceRefresh: true);
                      _verificarSugerencias();
                    },
                  );
                  _cargarProductos(forceRefresh: true);
                  _verificarSugerencias();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'sugerencias',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          size: 15,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Sugerencias de Precios',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                                if (_sugerenciasPendientes > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$_sugerenciasPendientes',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              'Propuestas del SuperAdmin para tus productos',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_esGastronomico) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'vencimientos',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            LucideIcons.calendarClock,
                            size: 15,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Control de Vencimientos',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                'Monitoreo preventivo por lotes',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                PopupMenuItem(
                  value: 'mermas',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.trash2,
                          size: 15,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _esGastronomico
                                  ? 'Mermas de Cocina'
                                  : 'Registro de Mermas',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                            Text(
                              _esGastronomico
                                  ? 'Desperdicios y sobrantes de cocina'
                                  : 'Bajas por rotura o caducidad',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_esGastronomico)
                  PopupMenuItem(
                    value: 'auditoria',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            LucideIcons.clipboardCheck,
                            size: 15,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Auditoría Rápida por Pasillo',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          ((_bodegaInfo?.plan.toUpperCase() !=
                                                      'PRO')
                                                  ? const Color(0xFFD97706)
                                                  : const Color(0xFF10B981))
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_bodegaInfo?.plan.toUpperCase() !=
                                            'PRO') ...[
                                          const Icon(
                                            LucideIcons.lock,
                                            size: 8,
                                            color: Color(0xFFD97706),
                                          ),
                                          const SizedBox(width: 2),
                                        ],
                                        Text(
                                          'PRO',
                                          style: GoogleFonts.outfit(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            color:
                                                (_bodegaInfo?.plan
                                                        .toUpperCase() !=
                                                    'PRO')
                                                ? const Color(0xFFD97706)
                                                : const Color(0xFF059669),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '5 min de conteo físico contra robo hormiga',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'hueso',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppTheme.brandDark.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.archive,
                          size: 15,
                          color: AppTheme.brandDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Detector de Productos Hueso',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        ((_bodegaInfo?.plan.toUpperCase() !=
                                                    'PRO')
                                                ? const Color(0xFFD97706)
                                                : const Color(0xFF10B981))
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_bodegaInfo?.plan.toUpperCase() !=
                                          'PRO') ...[
                                        const Icon(
                                          LucideIcons.lock,
                                          size: 8,
                                          color: Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 2),
                                      ],
                                      Text(
                                        'PRO',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color:
                                              (_bodegaInfo?.plan
                                                      .toUpperCase() !=
                                                  'PRO')
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Alerta de dinero atrapado y stock sin rotar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'kardex',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.fileSpreadsheet,
                          size: 15,
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Kardex de Movimientos',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                            Text(
                              'Historial detallado de entradas y salidas',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrowScreen ? 7 : 9,
                    vertical: 6.5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.cardDarkElevated
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.borderDark
                          : const Color(0xFFCBD5E1),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.download,
                        size: 13,
                        color: AppTheme.accentGreen,
                      ),
                      if (!isNarrowScreen) ...[
                        const SizedBox(width: 4),
                        Text(
                          'CSV',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            if ((_esAdmin || PermisosCajeroService.puedeModificarPrecios) &&
                !isNarrowScreen) ...[
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final esBasico =
                        _bodegaInfo?.plan.toUpperCase() == 'BASICO';
                    final total = _todosProductos.length;
                    final limite = _bodegaInfo?.limiteProductos ?? 150;
                    if (esBasico && total >= limite) {
                      _mostrarModalLimitePlanBasico(context);
                    } else {
                      NuevoProductoSheet.show(context, _cargarProductos);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrowScreen ? 8 : 11,
                      vertical: 6.5,
                    ),
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
                        const Icon(
                          LucideIcons.plus,
                          size: 14,
                          color: Colors.white,
                        ),
                        if (!isNarrowScreen) ...[
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),

      // 2. Selector de Modo: Gestión Stock vs Catálogo Web
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: cardBg,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _buildModeSelector(isDark),
        ),
      ),

      // 3. Cockpit Financiero de Capital o Banner de Catálogo Web
      if (!_modoCatalogoWeb) ...[
        _buildInventoryCockpit(context, isDark, bajoStockCount, criticoCount),
        _buildWarehouseSubmodulesBar(isDark),
      ] else
        _buildWebCatalogBanner(context, isDark),

      ValueListenableBuilder<int>(
        valueListenable: BodegaService.sugerenciasPendientesNotifier,
        builder: (context, pendientes, _) {
          if (pendientes <= 0) return const SizedBox.shrink();
          return _buildSugerenciasBanner(context, isDark, pendientes);
        },
      ),

      _buildFifoAlertBanner(context, isDark),

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
                      color: isDark
                          ? AppTheme.cardDarkSunken
                          : const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.borderDark
                            : const Color(0xFFE2E8F0),
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
                          color: AppTheme.getAdaptiveHintText(isDark),
                          fontSize: 12.5,
                        ),
                        prefixIcon: const Icon(
                          LucideIcons.search,
                          size: 16,
                          color: AppTheme.brandPrimary,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_filtroTexto.isNotEmpty)
                              IconButton(
                                icon: const Icon(LucideIcons.x, size: 15),
                                onPressed: () {
                                  _searchDebounce?.cancel();
                                  _searchController.clear();
                                  _filtroTexto = '';
                                  _aplicarFiltros();
                                },
                              ),
                            IconButton(
                              tooltip: 'Escanear con Cámara / Láser',
                              icon: const Icon(
                                LucideIcons.scanBarcode,
                                size: 17,
                                color: AppTheme.brandPrimary,
                              ),
                              onPressed: _escanearCodigoParaBuscar,
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      onChanged: (val) {
                        _searchDebounce?.cancel();
                        if (val.isEmpty) {
                          _filtroTexto = '';
                          _aplicarFiltros();
                          return;
                        }
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 180),
                          () {
                            if (!mounted) return;
                            _filtroTexto = val;
                            _aplicarFiltros();
                          },
                        );
                      },
                      onSubmitted: (val) {
                        _searchDebounce?.cancel();
                        _filtroTexto = val;
                        _aplicarFiltros();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Menú de Ordenamiento
                _buildSortMenu(context, isDark),
                const SizedBox(width: 8),

                // Contador de resultados
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.cardDarkHighlight
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.borderDarkElevated
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${_safeFiltrados.length} / ${_safeTodos.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textDark,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 3. Carrusel Único de Filtros Calma Visual
            _buildFilterCarousel(
              isDark,
              bajoStockCount,
              criticoCount,
              vencenProntoCount,
            ),
          ],
        ),
      ),

      // Línea divisoria suave
      Container(
        height: 1,
        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => _cargarProductos(forceRefresh: true),
        color: AppTheme.brandPrimary,
        child: isMobileFullScroll
            ? CustomScrollView(
                key: const ValueKey('productos_mobile_custom_scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: topSections,
                    ),
                  ),
                  if (_isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                    )
                  else if (_safeFiltrados.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState(isDark))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 88),
                      sliver: SliverList.builder(
                        itemCount: _safeFiltrados.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(
                            _safeFiltrados[index],
                            isDark,
                          );
                        },
                      ),
                    ),
                ],
              )
            : Column(
                key: const ValueKey('productos_fixed_header_layout'),
                children: [
                  ...topSections,
                  // 4. Catálogo de Productos Adaptativo (82% del espacio recuperado)
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.brandPrimary,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () =>
                                _cargarProductos(forceRefresh: true),
                            color: AppTheme.brandPrimary,
                            child: _safeFiltrados.isEmpty
                                ? SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: _buildEmptyState(isDark),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      if (constraints.maxWidth > 700) {
                                        return GridView.builder(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          padding: const EdgeInsets.all(16),
                                          gridDelegate:
                                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                                maxCrossAxisExtent: 380,
                                                mainAxisExtent: 122,
                                                crossAxisSpacing: 12,
                                                mainAxisSpacing: 12,
                                              ),
                                          itemCount: _safeFiltrados.length,
                                          itemBuilder: (context, index) {
                                            return _buildProductCard(
                                              _safeFiltrados[index],
                                              isDark,
                                            );
                                          },
                                        );
                                      } else {
                                        return ListView.builder(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          itemCount: _safeFiltrados.length,
                                          itemBuilder: (context, index) {
                                            return _buildProductCard(
                                              _safeFiltrados[index],
                                              isDark,
                                            );
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
      floatingActionButton:
          (_esAdmin || PermisosCajeroService.puedeModificarPrecios)
          ? FloatingActionButton.extended(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(LucideIcons.plus, size: 20),
              label: Text(
                'Nuevo Producto',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
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

  Widget _buildModeSelector(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFCBD5E1),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _buildModeButton(
              label: '📦 Gestión Stock',
              isSelected: !_modoCatalogoWeb,
              onTap: () {
                if (_modoCatalogoWeb) {
                  HapticFeedback.selectionClick();
                  setState(() => _modoCatalogoWeb = false);
                }
              },
              isDark: isDark,
            ),
          ),
          Flexible(
            child: _buildModeButton(
              label: '🌐 Catálogo Web',
              isSelected: _modoCatalogoWeb,
              onTap: () {
                if (!_modoCatalogoWeb) {
                  HapticFeedback.selectionClick();
                  setState(() => _modoCatalogoWeb = true);
                }
              },
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryCockpit(
    BuildContext context,
    bool isDark,
    int bajoStockCount,
    int criticoCount,
  ) {
    final capital = _capitalInvertido;
    final venta = _ventaProyectada;
    final margen = _margenGlobalPromedio;
    final totalAlertas = bajoStockCount + criticoCount;
    final totalOptimos = _safeTodos.length - totalAlertas;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final card1 = _buildCockpitCard(
          isDark: isDark,
          title: 'CAPITAL INVERTIDO',
          value: 'S/ ${capital.toStringAsFixed(2)}',
          subtitle: 'En ${_safeTodos.length} productos activos',
          icon: LucideIcons.coins,
          iconColor: const Color(0xFF6366F1),
          iconBg: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
        );
        final card2 = _buildCockpitCard(
          isDark: isDark,
          title: 'VENTA PROYECTADA',
          value: 'S/ ${venta.toStringAsFixed(2)}',
          subtitle: 'Potencial de facturación',
          icon: LucideIcons.trendingUp,
          iconColor: AppTheme.accentGreen,
          iconBg: AppTheme.accentGreen.withValues(alpha: isDark ? 0.2 : 0.1),
        );
        final card3 = _buildCockpitCard(
          isDark: isDark,
          title: 'SALUD DEL INVENTARIO',
          value: '${margen.toStringAsFixed(1)}% margen',
          subtitle: totalAlertas > 0
              ? '$totalAlertas en alerta • $totalOptimos óptimos'
              : 'Todo el stock en nivel óptimo',
          icon: LucideIcons.shieldCheck,
          iconColor: totalAlertas > 0
              ? const Color(0xFFD97706)
              : AppTheme.accentGreen,
          iconBg:
              (totalAlertas > 0
                      ? const Color(0xFFD97706)
                      : AppTheme.accentGreen)
                  .withValues(alpha: isDark ? 0.2 : 0.1),
        );

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                Expanded(child: card1),
                const SizedBox(width: 12),
                Expanded(child: card2),
                const SizedBox(width: 12),
                Expanded(child: card3),
              ],
            ),
          );
        } else {
          return SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                SizedBox(width: 230, child: card1),
                const SizedBox(width: 10),
                SizedBox(width: 230, child: card2),
                const SizedBox(width: 10),
                SizedBox(width: 250, child: card3),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildCockpitCard({
    required bool isDark,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textDark,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseSubmodulesBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (!_esGastronomico) ...[
              _buildWarehouseChip(
                icon: LucideIcons.calendarClock,
                label: 'Vencimientos FIFO',
                color: const Color(0xFFD97706),
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VencimientosScreen(),
                    ),
                  ).then((_) => _cargarProductos());
                },
              ),
              const SizedBox(width: 8),
            ],
            _buildWarehouseChip(
              icon: LucideIcons.trash2,
              label: _esGastronomico ? 'Mermas de Cocina' : 'Mermas & Bajas',
              color: const Color(0xFFEF4444),
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MermasScreen()),
                ).then((_) => _cargarProductos());
              },
            ),
            const SizedBox(width: 8),
            _buildWarehouseChip(
              icon: LucideIcons.fileSpreadsheet,
              label: 'Kardex Auditoría',
              color: const Color(0xFF64748B),
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KardexScreen()),
                );
              },
            ),
            if (!_esGastronomico) ...[
              const SizedBox(width: 8),
              _buildWarehouseChip(
                icon: LucideIcons.clipboardCheck,
                label: 'Auditoría Ciega',
                color: AppTheme.brandPrimary,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  final esBasico = _bodegaInfo?.plan.toUpperCase() != 'PRO';
                  if (esBasico) {
                    PlanUpgradeModal.show(
                      context,
                      featureName: 'Auditoría Rápida por Pasillo',
                      featureDescription: 'Realiza conteos físicos aleatorios de 5 minutos por góndola o pasillo sin mostrar el stock real al personal.',
                      icon: LucideIcons.clipboardCheck,
                      onPlanUpdated: _cargarProductos,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AuditoriaCiegaScreen(),
                      ),
                    ).then((_) => _cargarProductos());
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebCatalogBanner(BuildContext context, bool isDark) {
    final catalogUrl = KitMarketingBarrioModal.buildUrlCatalogo(
      slugOrId: _savedSlug,
      nombreBodega: _bodegaInfo?.nombreComercial,
      bodegaId: _bodegaInfo?.idBodega,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;

        final copyBtn = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: catalogUrl));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Enlace de catálogo copiado al portapapeles!'),
                  backgroundColor: AppTheme.accentGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDarkSunken : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.copy,
                    size: 13,
                    color: AppTheme.brandPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Copiar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final qrBtn = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              KitMarketingBarrioModal.show(
                context,
                nombreBodega: _bodegaInfo?.nombreComercial ?? 'Mi Bodega',
                telefono: _bodegaInfo?.telefono,
                bodegaId: _bodegaInfo?.idBodega,
                giroNegocio: _bodegaInfo?.giroNegocio,
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.qrCode, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'QR / Compartir',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.cardDarkHighlight
                : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppTheme.brandPrimary.withValues(alpha: 0.35)
                  : const Color(0xFFBFDBFE),
              width: 1.0,
            ),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.globe,
                            color: AppTheme.brandPrimary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Catálogo Digital & WhatsApp Activo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                catalogUrl,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.brandPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: copyBtn),
                        const SizedBox(width: 8),
                        Expanded(child: qrBtn),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.globe,
                        color: AppTheme.brandPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catálogo Digital & WhatsApp Activo',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            catalogUrl,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.brandPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    copyBtn,
                    const SizedBox(width: 6),
                    qrBtn,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSortMenu(BuildContext context, bool isDark) {
    String labelActual = 'A - Z';
    if (_criterioOrden == 'stock_asc') labelActual = 'Menor Stock';
    if (_criterioOrden == 'stock_desc') labelActual = 'Mayor Stock';
    if (_criterioOrden == 'precio_desc') labelActual = 'Mayor Precio';
    if (_criterioOrden == 'margen_desc') labelActual = 'Mayor Margen %';
    if (_criterioOrden == 'fifo') labelActual = 'Vencimientos';

    return PopupMenuButton<String>(
      tooltip: 'Ordenar productos',
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? AppTheme.cardDarkElevated : Colors.white,
      elevation: 6,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? AppTheme.borderDarkElevated
                : const Color(0xFFCBD5E1),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.arrowUpDown,
              size: 13,
              color: AppTheme.brandPrimary,
            ),
            const SizedBox(width: 5),
            Text(
              labelActual,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              LucideIcons.chevronDown,
              size: 12,
              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
            ),
          ],
        ),
      ),
      onSelected: (val) {
        HapticFeedback.selectionClick();
        setState(() {
          _criterioOrden = val;
          _aplicarFiltros();
        });
      },
      itemBuilder: (ctx) => [
        _buildSortMenuItem(
          'nombre',
          'A - Z (Alfabético)',
          LucideIcons.arrowDownAZ,
          isDark,
        ),
        _buildSortMenuItem(
          'stock_asc',
          'Menor Stock primero',
          LucideIcons.arrowUp10,
          isDark,
        ),
        _buildSortMenuItem(
          'stock_desc',
          'Mayor Stock primero',
          LucideIcons.arrowDown10,
          isDark,
        ),
        _buildSortMenuItem(
          'precio_desc',
          'Mayor Precio primero',
          LucideIcons.badgeDollarSign,
          isDark,
        ),
        _buildSortMenuItem(
          'margen_desc',
          'Mayor Margen %',
          LucideIcons.badgePercent,
          isDark,
        ),
        _buildSortMenuItem(
          'fifo',
          'Próximos a Vencer (FIFO)',
          LucideIcons.calendarClock,
          isDark,
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(
    String value,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _criterioOrden == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: isSelected
                ? AppTheme.brandPrimary
                : (isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? AppTheme.brandPrimary
                  : (isDark ? Colors.white : AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCarousel(
    bool isDark,
    int bajoStockCount,
    int criticoCount,
    int vencenProntoCount,
  ) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Todos
          _buildCalmaFilterChip(
            label: 'Todos',
            count: _safeTodos.length,
            isSelected:
                _estadoStockFiltro == 'todos' && _selectedCategoria == 'Todos',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _estadoStockFiltro = 'todos';
                _selectedCategoria = 'Todos';
                _aplicarFiltros();
              });
            },
            isDark: isDark,
          ),
          const SizedBox(width: 6),

          // Por Agotar (Ámbar)
          _buildCalmaFilterChip(
            label: 'Por Agotar',
            count: bajoStockCount,
            dotColor: const Color(0xFFD97706),
            isSelected: _estadoStockFiltro == 'bajo_stock',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _estadoStockFiltro = _estadoStockFiltro == 'bajo_stock'
                    ? 'todos'
                    : 'bajo_stock';
                _aplicarFiltros();
              });
            },
            isDark: isDark,
          ),
          const SizedBox(width: 6),

          // Críticos (Rojo/Rose)
          _buildCalmaFilterChip(
            label: 'Críticos',
            count: criticoCount,
            dotColor: const Color(0xFFE11D48),
            isSelected: _estadoStockFiltro == 'critico',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _estadoStockFiltro = _estadoStockFiltro == 'critico'
                    ? 'todos'
                    : 'critico';
                _aplicarFiltros();
              });
            },
            isDark: isDark,
          ),

          // Vencen Pronto (Violeta/Púrpura)
          if (!_esGastronomico &&
              (vencenProntoCount > 0 ||
                  _estadoStockFiltro == 'vencen_pronto')) ...[
            const SizedBox(width: 6),
            _buildCalmaFilterChip(
              label: 'Vencen Pronto',
              count: vencenProntoCount,
              dotColor: const Color(0xFF7C3AED),
              isSelected: _estadoStockFiltro == 'vencen_pronto',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _estadoStockFiltro = _estadoStockFiltro == 'vencen_pronto'
                      ? 'todos'
                      : 'vencen_pronto';
                  _aplicarFiltros();
                });
              },
              isDark: isDark,
            ),
          ],

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

          // Categorías
          ..._categoriasDisponibles.where((c) => c != 'Todos').map((cat) {
            final isSelected = _selectedCategoria == cat;
            final catIcon = CategoryHelper.getIcon(cat);
            final count = _getCountForCategoria(cat);

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildCalmaFilterChip(
                label: cat,
                count: count,
                icon: catIcon,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedCategoria = isSelected ? 'Todos' : cat;
                    _aplicarFiltros();
                  });
                },
                isDark: isDark,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCalmaFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color? dotColor,
    IconData? icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDark
                      ? AppTheme.cardDarkHighlight
                      : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.2 : 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: 12,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF475569)),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : AppTheme.textDark),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isDark
                            ? AppTheme.cardDarkElevated
                            : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Producto p, bool isDark) {
    final double umbralMinimo = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
    final bool stockCritico = p.stockActual <= (umbralMinimo * 0.5);
    final bool stockBajo =
        p.stockActual > (umbralMinimo * 0.5) && p.stockActual <= umbralMinimo;
    final Color badgeColor = stockCritico
        ? (isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48))
        : (stockBajo
              ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
              : AppTheme.accentGreen);
    final String estadoTexto = stockCritico
        ? 'Crítico'
        : (stockBajo ? 'Por Agotar' : 'Óptimo');

    final double costo = p.costoUnitarioEstimado;
    final double margen = p.precioVenta > 0
        ? ((p.precioVenta - costo) / p.precioVenta) * 100.0
        : 0.0;
    final stockFormatted = p.stockActual % 1 == 0
        ? p.stockActual.toInt().toString()
        : p.stockActual.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            _mostrarDetalleProducto(p);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Packshot de Estudio Frontal (72 px) LIMPIO sin botón redundante (i)
                ProductImageWidget(
                  imagenUrl: p.imagenUrl,
                  nombre: p.nombre,
                  codigoBarras: p.codigoBarras,
                  categoria: p.nombreCategoria,
                  size: 72,
                  borderRadius: 14,
                  isDark: isDark,
                  padding: 4,
                ),
                const SizedBox(width: 12),

                // Datos del Producto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fila 1: Nombre + Precio Venta
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              p.nombre,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
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
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Fila 2: Metadatos limpios (SKU • Marca • Margen %)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'SKU: ${p.codigo}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF475569),
                              ),
                            ),
                            if (p.marca != null && p.marca!.isNotEmpty)
                              TextSpan(
                                text: '  •  ${p.marca!}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.getAdaptiveMutedText(isDark),
                                ),
                              ),
                            TextSpan(
                              text: '  •  Margen ${margen.toStringAsFixed(1)}%',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: margen >= 25
                                    ? AppTheme.accentGreen
                                    : (margen >= 15
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFFE11D48)),
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),

                      // Fila 3: Semáforo de Stock + Acción Auditada / Modo Web
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Pill de Stock con semáforo
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(
                                  alpha: isDark ? 0.16 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5.5,
                                    height: 5.5,
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      '$stockFormatted u. ($estadoTexto)',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: badgeColor,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
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

                          // Acción según Modo: "Ajustar" (Stock) o "En Catálogo Web" (Web)
                          if (_modoCatalogoWeb)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withValues(
                                  alpha: isDark ? 0.18 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.accentGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.check,
                                    size: 10,
                                    color: AppTheme.accentGreen,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'En Catálogo',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_esAdmin ||
                              PermisosCajeroService.puedeModificarPrecios)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  AjusteStockSheet.show(
                                    context,
                                    p,
                                    _cargarProductos,
                                  );
                                },
                                borderRadius: BorderRadius.circular(7),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.cardDarkHighlight
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: isDark
                                          ? AppTheme.borderDarkElevated
                                          : const Color(0xFFCBD5E1),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.scale,
                                        size: 11,
                                        color: AppTheme.brandPrimary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Ajustar',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (!_esGastronomico &&
                          p.controlaVencimiento &&
                          p.fechaVencimiento != null) ...[
                        const SizedBox(height: 3),
                        _buildProductCardFifoBadge(p, isDark),
                      ],
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
    final catColor = CategoryHelper.getColor(p.nombreCategoria, isDark);
    final categoriaNombre = p.nombreCategoria?.trim() ?? 'General';

    AdaptiveModal.show(
      context: context,
      maxWidth: 580,
      builder: (ctx) {
        final isWide = ResponsiveLayout.isTabletOrLarger(ctx);
        return Align(
          alignment: isWide ? Alignment.center : Alignment.bottomCenter,
          heightFactor: isWide ? 1.0 : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 580,
              maxHeight:
                  MediaQuery.of(context).size.height * (isWide ? 0.88 : 0.90),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDarkElevated : Colors.white,
                borderRadius: isWide
                    ? BorderRadius.circular(24)
                    : const BorderRadius.vertical(top: Radius.circular(32)),
                border: isDark
                    ? Border.all(color: AppTheme.borderDarkElevated, width: 1.2)
                    : Border.all(
                        color: isWide
                            ? AppTheme.borderLight
                            : Colors.transparent,
                        width: 1.0,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
                    blurRadius: isWide ? 30 : 20,
                    offset: isWide ? const Offset(0, 10) : const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    22,
                    isWide ? 20 : 16,
                    22,
                    28 + (isWide ? 0 : MediaQuery.of(ctx).viewInsets.bottom),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isWide) ...[
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.borderDarkElevated
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Packshot de Estudio Frontal en Gran Detalle (130 px)
                          ProductImageWidget(
                            imagenUrl: p.imagenUrl,
                            nombre: p.nombre,
                            codigoBarras: p.codigoBarras,
                            categoria: p.nombreCategoria,
                            size: 130,
                            borderRadius: 24,
                            isDark: isDark,
                            padding: 8,
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
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: catColor.withValues(
                                          alpha: isDark ? 0.18 : 0.1,
                                        ),
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFCBD5E1),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'SKU: ${p.codigo}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    if (p.marca != null && p.marca!.isNotEmpty)
                                      Text(
                                        'Marca: ${p.marca}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppTheme.getAdaptiveMutedText(
                                            isDark,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (p.codigoBarras != null &&
                                        p.codigoBarras!.isNotEmpty &&
                                        p.codigoBarras != p.codigo)
                                      Text(
                                        'EAN: ${p.codigoBarras}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppTheme.getAdaptiveMutedText(
                                            isDark,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    if (p.controlaVencimiento)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.amber.shade700
                                                .withValues(alpha: 0.5),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.calendarClock,
                                              size: 10,
                                              color: Colors.amber.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Perecible / Vencimiento',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? Colors.amber.shade300
                                                        : Colors.amber.shade900,
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
                          const SizedBox(width: 6),
                          IconButton(
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(32, 32),
                            ),
                            icon: Icon(
                              LucideIcons.x,
                              size: 18,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            tooltip: 'Cerrar Detalle',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Grilla Financiera Calma Visual (Venta, Costo, Margen)
                      Builder(
                        builder: (context) {
                          final double costoUnit = p.costoUnitarioEstimado;
                          final double margenUnit = p.precioVenta > 0
                              ? ((p.precioVenta - costoUnit) / p.precioVenta) *
                                    100.0
                              : 0.0;
                          final double valorCosto = p.stockActual * costoUnit;
                          final double valorVenta =
                              p.stockActual * p.precioVenta;
                          final double umbralMin = p.stockMinimo > 0
                              ? p.stockMinimo
                              : 5.0;
                          final bool esCritico =
                              p.stockActual <= (umbralMin * 0.5);
                          final bool esBajo =
                              p.stockActual > (umbralMin * 0.5) &&
                              p.stockActual <= umbralMin;
                          final Color semaforoStock = esCritico
                              ? (isDark
                                    ? const Color(0xFFFB7185)
                                    : const Color(0xFFE11D48))
                              : (esBajo
                                    ? (isDark
                                          ? const Color(0xFFFBBF24)
                                          : const Color(0xFFD97706))
                                    : AppTheme.accentGreen);
                          final String textoStock = esCritico
                              ? 'Crítico'
                              : (esBajo ? 'Por Agotar' : 'Óptimo');

                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.cardDarkSunken
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark
                                        ? AppTheme.borderDark
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'PRECIO VENTA',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: isDark
                                                  ? AppTheme.textDarkSecondary
                                                  : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'S/ ${p.precioVenta.toStringAsFixed(2)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.brandPrimary,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: isDark
                                          ? AppTheme.borderDark
                                          : const Color(0xFFCBD5E1),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'COSTO COMPRA',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: isDark
                                                  ? AppTheme.textDarkSecondary
                                                  : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'S/ ${costoUnit.toStringAsFixed(2)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppTheme.textDark,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: isDark
                                          ? AppTheme.borderDark
                                          : const Color(0xFFCBD5E1),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'MARGEN BRUTO',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: isDark
                                                  ? AppTheme.textDarkSecondary
                                                  : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${margenUnit.toStringAsFixed(1)}%',
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: margenUnit >= 25
                                                  ? AppTheme.accentGreen
                                                  : (margenUnit >= 15
                                                        ? const Color(
                                                            0xFFD97706,
                                                          )
                                                        : const Color(
                                                            0xFFE11D48,
                                                          )),
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Tarjeta de Stock & Capital Inmovilizado
                              Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.cardDarkHighlight
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? AppTheme.borderDarkElevated
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      runSpacing: 4,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: semaforoStock,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Stock Físico:',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? Colors.white
                                                        : AppTheme.textDark,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${p.stockActual % 1 == 0 ? p.stockActual.toInt().toString() : p.stockActual.toStringAsFixed(2)} unid. ($textoStock)',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: semaforoStock,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          'Capital Invertido: S/ ${valorCosto.toStringAsFixed(2)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppTheme.textDarkSecondary
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                        Text(
                                          'Venta Proyectada: S/ ${valorVenta.toStringAsFixed(2)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppTheme.textDarkSecondary
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Nota de Política de Auditoría (No informal + / -)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandPrimary.withValues(
                                    alpha: isDark ? 0.12 : 0.06,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.brandPrimary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      LucideIcons.shieldCheck,
                                      size: 14,
                                      color: AppTheme.brandPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'La recepción de compras se registra mediante Compras con factura o guía. Para corregir diferencias de conteo físico, use el botón de Ajustar Stock con auditoría al Kardex.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: isDark
                                              ? const Color(0xFF93C5FD)
                                              : const Color(0xFF1E40AF),
                                          height: 1.3,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (!_esGastronomico && p.controlaVencimiento) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (p.diasParaVencer != null &&
                                    p.diasParaVencer! <= 0)
                                ? const Color(0xFFEF4444)
                                      .withValues(alpha: isDark ? 0.15 : 0.08)
                                : (p.diasParaVencer != null &&
                                      p.diasParaVencer! <= 7)
                                ? const Color(0xFFEA580C)
                                      .withValues(alpha: isDark ? 0.15 : 0.08)
                                : const Color(0xFFD97706)
                                      .withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  (p.diasParaVencer != null &&
                                      p.diasParaVencer! <= 0)
                                  ? const Color(0xFFEF4444)
                                        .withValues(alpha: 0.35)
                                  : (p.diasParaVencer != null &&
                                        p.diasParaVencer! <= 7)
                                  ? const Color(0xFFEA580C)
                                        .withValues(alpha: 0.35)
                                  : const Color(0xFFD97706)
                                        .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    (p.diasParaVencer != null &&
                                            p.diasParaVencer! <= 0)
                                        ? LucideIcons.alertOctagon
                                        : (p.diasParaVencer != null &&
                                              p.diasParaVencer! <= 7)
                                        ? LucideIcons.zap
                                        : LucideIcons.rotateCw,
                                    size: 16,
                                    color:
                                        (p.diasParaVencer != null &&
                                            p.diasParaVencer! <= 0)
                                        ? const Color(0xFFEF4444)
                                        : (p.diasParaVencer != null &&
                                              p.diasParaVencer! <= 7)
                                        ? const Color(0xFFEA580C)
                                        : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p.fechaVencimiento != null
                                          ? 'Lote FIFO • Vence: ${p.fechaVencimiento!.day}/${p.fechaVencimiento!.month}/${p.fechaVencimiento!.year} (${p.diasParaVencer != null && p.diasParaVencer! <= 0 ? "Vencido hace ${p.diasParaVencer!.abs()}d" : "En ${p.diasParaVencer} días"})'
                                          : 'Control FIFO activo (Sin fecha registrada)',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  if (_esAdmin ||
                                      PermisosCajeroService
                                          .puedeModificarPrecios)
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        final now = DateTime.now();
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              p.fechaVencimiento ??
                                              now.add(const Duration(days: 30)),
                                          firstDate: now.subtract(
                                            const Duration(days: 365),
                                          ),
                                          lastDate: now.add(
                                            const Duration(days: 365 * 3),
                                          ),
                                          helpText: 'ACTUALIZAR FECHA VENCIMIENTO / LOTE FIFO',
                                          confirmText: 'GUARDAR',
                                          cancelText: 'CANCELAR',
                                        );
                                        if (picked != null) {
                                          final actualizado = p.copyWith(
                                            fechaVencimiento: picked,
                                          );
                                          final ok = await _productoService
                                              .actualizarProducto(actualizado);
                                          if (ok && mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Lote FIFO de "${p.nombre}" actualizado al ${picked.day}/${picked.month}/${picked.year}',
                                                ),
                                                backgroundColor:
                                                    AppTheme.accentGreen,
                                              ),
                                            );
                                            _cargarProductos();
                                          }
                                        }
                                      },
                                      child: const Text(
                                        'Rotar / Fecha',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (p.diasParaVencer != null &&
                                        p.diasParaVencer! <= 0)
                                    ? '⚠️ REGLA FIFO: Retirar inmediatamente de exhibición para evitar multas sanitarias. Registrar merma o devolución a proveedor.'
                                    : (p.diasParaVencer != null &&
                                          p.diasParaVencer! <= 7)
                                    ? '⚡ REGLA FIFO: Salida prioritaria urgente. Exhibir al frente del mostrador o crear descuento express para liquidar el stock.'
                                    : '📦 REGLA FIFO: Rotación en repisa. Colocar este lote adelante de los productos que vencen más tarde.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.brandPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(
                            LucideIcons.fileSpreadsheet,
                            size: 16,
                          ),
                          label: Text(
                            'Ver Historial de Movimientos (Kardex)',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const KardexScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (_esAdmin ||
                              PermisosCajeroService.puedeModificarPrecios) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  side: const BorderSide(
                                    color: AppTheme.brandDark,
                                    width: 1.2,
                                  ),
                                  foregroundColor: AppTheme.brandDark,
                                ),
                                icon: const Icon(LucideIcons.scale, size: 15),
                                label: Text(
                                  'AJUSTAR',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  AjusteStockSheet.show(
                                    context,
                                    p,
                                    _cargarProductos,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  side: const BorderSide(
                                    color: AppTheme.brandPrimary,
                                    width: 1.2,
                                  ),
                                  foregroundColor: AppTheme.brandPrimary,
                                ),
                                icon: const Icon(LucideIcons.pencil, size: 15),
                                label: Text(
                                  'EDITAR',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  if (AuthService.esCajero &&
                                      !PermisosCajeroService
                                          .puedeModificarPrecios) {
                                    final auth =
                                        await SolicitarPinDialog.mostrar(
                                          context,
                                          titulo: 'Modo Cajero Protegido',
                                          mensaje: 'Se requiere PIN de Administrador para modificar precios o catálogo.',
                                        );
                                    if (!auth) return;
                                  }
                                  if (!mounted) return;
                                  EditarProductoSheet.show(
                                    context,
                                    p,
                                    _cargarProductos,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: AppTheme.brandPrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              icon: const Icon(LucideIcons.check, size: 16),
                              label: Text(
                                'LISTO',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final hasActiveFilters =
        _filtroTexto.isNotEmpty ||
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
              child: const Icon(
                LucideIcons.packageSearch,
                size: 40,
                color: AppTheme.brandPrimary,
              ),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF334155),
              ),
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
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 10),
            ] else if (_esAdmin) ...[
              ElevatedButton.icon(
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
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(
                  'Registrar Primer Producto',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 13,
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextButton.icon(
              onPressed: _cargarProductos,
              icon: const Icon(LucideIcons.refreshCw, size: 15),
              label: Text(
                'Sincronizar Inventario',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? AppTheme.brandLight
                    : AppTheme.brandPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
              isBasico
                  ? (alcanzado
                        ? LucideIcons.triangleAlert
                        : LucideIcons.package)
                  : LucideIcons.sparkles,
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
    AdaptiveModal.show(
      context: context,
      maxWidth: 520,
      builder: (ctx) {
        final isWide = ResponsiveLayout.isTabletOrLarger(ctx);
        return Align(
          alignment: isWide ? Alignment.center : Alignment.bottomCenter,
          heightFactor: isWide ? 1.0 : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDarkElevated : Colors.white,
                borderRadius: isWide
                    ? BorderRadius.circular(24)
                    : const BorderRadius.vertical(top: Radius.circular(32)),
                border: isDark
                    ? Border.all(color: AppTheme.borderDarkElevated, width: 1.2)
                    : Border.all(
                        color: isWide
                            ? AppTheme.borderLight
                            : Colors.transparent,
                        width: 1.0,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
                    blurRadius: isWide ? 30 : 20,
                    offset: isWide ? const Offset(0, 10) : const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(24, isWide ? 20 : 18, 24, 28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isWide) ...[
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.borderDarkElevated
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(32, 32),
                        ),
                        icon: Icon(
                          LucideIcons.x,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.crown,
                          color: AppTheme.brandPrimary,
                          size: 28,
                        ),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.cardDarkSunken
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.borderDark
                              : AppTheme.borderLight,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildVentajaPro(
                            'Catálogo y Productos Ilimitados',
                            'Registra todos los SKUs que necesites sin tope de 150 items.',
                            isDark,
                          ),
                          const SizedBox(height: 10),
                          _buildVentajaPro(
                            'Mi Bodega Online (WhatsApp)',
                            'Catálogo digital con link propio para pedidos de clientes por chat.',
                            isDark,
                          ),
                          const SizedBox(height: 10),
                          _buildVentajaPro(
                            'Detector de Productos Hueso',
                            'Alertas de mercadería sin rotación en 30 días para liberar capital.',
                            isDark,
                          ),
                          const SizedBox(height: 10),
                          _buildVentajaPro(
                            'Auditoría Rápida por Pasillo',
                            'Conteo físico anti-robo en solo 5 minutos por estante.',
                            isDark,
                          ),
                          const SizedBox(height: 10),
                          _buildVentajaPro(
                            'Termómetro de Meta Diaria & Horas Punta',
                            'Seguimiento de ventas y afluencia de clientes en tiempo real.',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        PagoYapeModal.show(
                          context,
                          planInicial: 'PRO',
                          onPlanUpdated: _cargarProductos,
                        );
                      },
                      icon: const Icon(LucideIcons.sparkles, size: 18),
                      label: Text(
                        'Mejorar a Plan PRO con Yape / Plin (S/ 100 /mes)',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Continuar con límite de 150 (Plan Básico)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVentajaPro(String titulo, String subtitulo, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          LucideIcons.circleCheck,
          color: AppTheme.accentGreen,
          size: 16,
        ),
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSugerenciasBanner(
    BuildContext context,
    bool isDark, [
    int? countOverride,
  ]) {
    final count = countOverride ?? _sugerenciasPendientes;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2E1065).withValues(alpha: 0.6)
            : const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: Color(0xFF7C3AED), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tienes $count sugerencia(s) de precios y catálogo del SuperAdmin.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFDDD6FE)
                    : const Color(0xFF5B21B6),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.arrowUpRight, size: 14),
            label: const Text(
              'Revisar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              await SugerenciasPrecioModal.show(
                context,
                onActualizado: () {
                  _cargarProductos(forceRefresh: true);
                  _verificarSugerencias();
                },
              );
              _cargarProductos(forceRefresh: true);
              _verificarSugerencias();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFifoAlertBanner(BuildContext context, bool isDark) {
    final vencidos = _safeTodos
        .where(
          (p) =>
              p.controlaVencimiento &&
              p.fechaVencimiento != null &&
              (p.diasParaVencer ?? 999) <= 0,
        )
        .length;
    final criticos = _safeTodos
        .where(
          (p) =>
              p.controlaVencimiento &&
              p.fechaVencimiento != null &&
              (p.diasParaVencer ?? 999) > 0 &&
              (p.diasParaVencer ?? 999) <= 7,
        )
        .length;
    final atencion = _safeTodos
        .where(
          (p) =>
              p.controlaVencimiento &&
              p.fechaVencimiento != null &&
              (p.diasParaVencer ?? 999) > 7 &&
              (p.diasParaVencer ?? 999) <= 30,
        )
        .length;
    final totalRiesgo = vencidos + criticos + atencion;
    if (totalRiesgo == 0) return const SizedBox.shrink();

    final isFifoActivo = _criterioOrden == 'fifo';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? (vencidos > 0
                  ? const Color(0xFF450A0A).withValues(alpha: 0.6)
                  : const Color(0xFF422006).withValues(alpha: 0.5))
            : (vencidos > 0
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFFFFBEB)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vencidos > 0
              ? const Color(0xFFEF4444).withValues(alpha: 0.45)
              : const Color(0xFFF59E0B).withValues(alpha: 0.45),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:
                      (vencidos > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  vencidos > 0
                      ? LucideIcons.alertTriangle
                      : LucideIcons.calendarClock,
                  color: vencidos > 0
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFD97706),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rotación FIFO: $totalRiesgo producto(s) en seguimiento',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? Colors.white
                        : (vencidos > 0
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF92400E)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _criterioOrden = isFifoActivo ? 'nombre' : 'fifo';
                    _aplicarFiltros();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isFifoActivo
                        ? (vencidos > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFD97706))
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: vencidos > 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFD97706),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFifoActivo
                            ? LucideIcons.check
                            : LucideIcons.arrowUpDown,
                        size: 12,
                        color: isFifoActivo
                            ? Colors.white
                            : (vencidos > 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFifoActivo ? 'FIFO Activo' : 'Ordenar FIFO',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isFifoActivo
                              ? Colors.white
                              : (vencidos > 0
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (vencidos > 0)
                _buildFifoPill(
                  label: '$vencidos Vencidos',
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VencimientosScreen(),
                      ),
                    ).then((_) => _cargarProductos());
                  },
                ),
              if (criticos > 0)
                _buildFifoPill(
                  label: '$criticos Críticos (≤ 7d)',
                  color: const Color(0xFFEA580C),
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VencimientosScreen(),
                      ),
                    ).then((_) => _cargarProductos());
                  },
                ),
              if (atencion > 0)
                _buildFifoPill(
                  label: '$atencion Rotación (≤ 30d)',
                  color: const Color(0xFFD97706),
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VencimientosScreen(),
                      ),
                    ).then((_) => _cargarProductos());
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFifoPill({
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
            Icon(LucideIcons.chevronRight, size: 11, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCardFifoBadge(Producto p, bool isDark) {
    final dias = p.diasParaVencer ?? 999;
    final Color color = dias <= 0
        ? const Color(0xFFEF4444)
        : (dias <= 7 ? const Color(0xFFEA580C) : const Color(0xFFD97706));
    final IconData icon = dias <= 0
        ? LucideIcons.alertOctagon
        : (dias <= 7 ? LucideIcons.zap : LucideIcons.rotateCw);
    final String label = dias < 0
        ? 'VENCIDO hace ${dias.abs()}d (FIFO: Retirar)'
        : (dias == 0
              ? 'VENCE HOY (FIFO: Retirar)'
              : (dias <= 7
                    ? 'Vence en ${dias}d (FIFO: Liquidar)'
                    : (dias <= 30
                          ? 'Vence en ${dias}d (FIFO: Rotar)'
                          : 'Vence: ${p.fechaVencimiento!.day}/${p.fechaVencimiento!.month}/${p.fechaVencimiento!.year}')));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
