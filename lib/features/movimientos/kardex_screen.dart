import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'movimiento_model.dart';
import 'movimiento_service.dart';
import '../productos/producto_service.dart';
import '../ventas/venta_service.dart';
import '../compras/compra_service.dart';
import '../../core/theme.dart';
import '../../core/debouncer.dart';

class KardexScreen extends StatefulWidget {
  const KardexScreen({super.key});

  @override
  State<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  final MovimientoService _movimientoService = MovimientoService();
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();
  List<MovimientoInventario> _movimientos = [];
  bool _isLoading = true;
  String _filtroTexto = '';
  String _filtroTipo = 'TODOS';
  MovimientoInventario? _movimientoSeleccionado;

  @override
  void initState() {
    super.initState();
    ProductoService.productosRevision.addListener(_onRevisionChanged);
    VentaService.ventasRevision.addListener(_onRevisionChanged);
    CompraService.comprasRevision.addListener(_onRevisionChanged);
    _cargarMovimientos();
  }

  @override
  void dispose() {
    ProductoService.productosRevision.removeListener(_onRevisionChanged);
    VentaService.ventasRevision.removeListener(_onRevisionChanged);
    CompraService.comprasRevision.removeListener(_onRevisionChanged);
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onRevisionChanged() {
    if (mounted) {
      _cargarMovimientos();
    }
  }

  Future<void> _cargarMovimientos() async {
    setState(() => _isLoading = true);
    final lista = await _movimientoService.getMovimientos();
    if (mounted) {
      setState(() {
        _movimientos = lista;
        _isLoading = false;
        if (_movimientoSeleccionado == null && lista.isNotEmpty) {
          _movimientoSeleccionado = lista.first;
        } else if (_movimientoSeleccionado != null &&
            !lista.any(
              (m) => m.idMovimiento == _movimientoSeleccionado!.idMovimiento,
            ) &&
            lista.isNotEmpty) {
          _movimientoSeleccionado = lista.first;
        }
      });
    }
  }

  bool _esCambioPrecio(MovimientoInventario m) {
    final t = m.tipoMovimiento.toUpperCase();
    final mot = m.motivo.toUpperCase();
    return t.contains('PRECIO') ||
        t.contains('COSTO') ||
        mot.contains('CAMBIO DE PRECIO') ||
        mot.contains('PRECIO DE VENTA') ||
        mot.contains('CAMBIO DE COSTO') ||
        mot.contains('INICIAL DE COSTO');
  }

  bool _esCambioDatos(MovimientoInventario m) {
    if (_esCambioPrecio(m)) return false;
    final t = m.tipoMovimiento.toUpperCase();
    final mot = m.motivo.toUpperCase();
    return t.contains('NOMBRE') ||
        t.contains('CATEGORIA') ||
        t.contains('MARCA') ||
        t.contains('CODIGO') ||
        t.contains('VENCIMIENTO') ||
        t.contains('EDICION') ||
        t.contains('ADMIN') ||
        mot.contains('CAMBIO DE DESCRIPCI') ||
        mot.contains('CAMBIO DE NOMBRE') ||
        mot.contains('CAMBIO DE CATEGOR') ||
        mot.contains('CAMBIO DE MARCA') ||
        mot.contains('CAMBIO DE CÓDIGO') ||
        mot.contains('CÓDIGO DE BARRAS') ||
        mot.contains('ACTUALIZACIÓN DE VENCIMIENTO') ||
        mot.contains('ASIGNACIÓN DE VENCIMIENTO');
  }

  bool _esAjuste(MovimientoInventario m) {
    if (_esCambioPrecio(m) || _esCambioDatos(m)) return false;
    final mot = m.motivo.toUpperCase();
    final t = m.tipoMovimiento.toUpperCase();
    return mot.contains('[MERMA]') ||
        mot.contains('[ROTURA]') ||
        mot.contains('[VENCIMIENTO]') ||
        mot.contains('[CONSUMO_INTERNO]') ||
        mot.contains('[SOBRANTE]') ||
        mot.contains('AJUSTE MANUAL') ||
        mot.contains('[AJUSTE') ||
        t.contains('AJUSTE');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtrados = _movimientos.where((m) {
      final matchesText =
          m.nombreProducto.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          m.motivo.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          (m.usuarioResponsable?.toLowerCase().contains(
                _filtroTexto.toLowerCase(),
              ) ??
              false);

      bool matchesTipo = true;
      if (_filtroTipo == 'ENTRADA') {
        matchesTipo =
            (m.tipoMovimiento.contains('ENTRADA') ||
                m.tipoMovimiento.contains('COMPRA')) &&
            !m.motivo.toUpperCase().contains('ANULACI') &&
            !_esAjuste(m) &&
            !_esCambioPrecio(m) &&
            !_esCambioDatos(m);
      } else if (_filtroTipo == 'SALIDA') {
        matchesTipo =
            (m.tipoMovimiento.contains('SALIDA') ||
                m.tipoMovimiento.contains('VENTA')) &&
            !_esAjuste(m) &&
            !_esCambioPrecio(m) &&
            !_esCambioDatos(m);
      } else if (_filtroTipo == 'AJUSTE') {
        matchesTipo = _esAjuste(m);
      } else if (_filtroTipo == 'PRECIO') {
        matchesTipo = _esCambioPrecio(m);
      } else if (_filtroTipo == 'EDICION') {
        matchesTipo = _esCambioDatos(m);
      } else if (_filtroTipo == 'DEVOLUCION') {
        matchesTipo =
            m.tipoMovimiento.contains('DEVOLUCION') ||
            m.tipoMovimiento.contains('ANULACION') ||
            m.motivo.toUpperCase().contains('ANULACI');
      }
      return matchesText && matchesTipo;
    }).toList();

    final int totalDevoluciones = _movimientos
        .where(
          (m) =>
              m.tipoMovimiento.contains('DEVOLUCION') ||
              m.tipoMovimiento.contains('ANULACION') ||
              m.motivo.toUpperCase().contains('ANULACI'),
        )
        .length;
    final int totalEntradas = _movimientos
        .where(
          (m) =>
              (m.tipoMovimiento.contains('ENTRADA') ||
                  m.tipoMovimiento.contains('COMPRA')) &&
              !m.motivo.toUpperCase().contains('ANULACI') &&
              !_esAjuste(m) &&
              !_esCambioPrecio(m) &&
              !_esCambioDatos(m),
        )
        .length;
    final int totalSalidas = _movimientos
        .where(
          (m) =>
              (m.tipoMovimiento.contains('SALIDA') ||
                  m.tipoMovimiento.contains('VENTA')) &&
              !_esAjuste(m) &&
              !_esCambioPrecio(m) &&
              !_esCambioDatos(m),
        )
        .length;
    final int totalAjustes = _movimientos.where((m) => _esAjuste(m)).length;
    final int totalPrecios = _movimientos
        .where((m) => _esCambioPrecio(m))
        .length;
    final int totalEdiciones = _movimientos
        .where((m) => _esCambioDatos(m))
        .length;

    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                tooltip: 'Regresar',
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        titleSpacing: canPop ? 0 : 16,
        elevation: 0,
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kardex de Inventario',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Auditoría y trazabilidad de entradas, salidas y mermas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 19),
            tooltip: 'Actualizar Kardex',
            onPressed: _cargarMovimientos,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.brandPrimary),
            )
          : RefreshIndicator(
              onRefresh: _cargarMovimientos,
              color: AppTheme.brandPrimary,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final seleccionado =
                      _movimientoSeleccionado ??
                      (filtrados.isNotEmpty ? filtrados.first : null);

                  if (isWide) {
                    return _buildKardexDesktop(
                      isDark,
                      filtrados,
                      totalEntradas,
                      totalSalidas,
                      totalAjustes,
                      totalPrecios,
                      totalEdiciones,
                      totalDevoluciones,
                      seleccionado,
                    );
                  }
                  return _buildKardexMobile(
                    isDark,
                    filtrados,
                    totalEntradas,
                    totalSalidas,
                    totalAjustes,
                    totalPrecios,
                    totalEdiciones,
                    totalDevoluciones,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildKardexMobile(
    bool isDark,
    List<MovimientoInventario> filtrados,
    int totalEntradas,
    int totalSalidas,
    int totalAjustes,
    int totalPrecios,
    int totalEdiciones,
    int totalDevoluciones,
  ) {
    return Column(
      children: [
        // Banner Didáctico
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: const DidacticBanner(
            title: 'Auditoría Integral de Kardex',
            description: 'Rastrea en tiempo real ventas, compras, mermas de stock y auditoría administrativa de cambios de precios, nombres y catálogo con sus respectivas insignias.',
            icon: LucideIcons.fileSpreadsheet,
          ),
        ),

        // Métricas Rápidas
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildKpiChip(
                  'Entradas',
                  '$totalEntradas',
                  AppTheme.accentGreen,
                  isDark,
                  width: 85,
                ),
                const SizedBox(width: 6),
                _buildKpiChip(
                  'Salidas',
                  '$totalSalidas',
                  AppTheme.brandPrimary,
                  isDark,
                  width: 85,
                ),
                const SizedBox(width: 6),
                _buildKpiChip(
                  'Mermas',
                  '$totalAjustes',
                  AppTheme.alertRed,
                  isDark,
                  width: 85,
                ),
                const SizedBox(width: 6),
                _buildKpiChip(
                  'Precios',
                  '$totalPrecios',
                  const Color(0xFF8B5CF6),
                  isDark,
                  width: 85,
                ),
                const SizedBox(width: 6),
                _buildKpiChip(
                  'Ediciones',
                  '$totalEdiciones',
                  const Color(0xFF0284C7),
                  isDark,
                  width: 85,
                ),
                const SizedBox(width: 6),
                _buildKpiChip(
                  'Devolución',
                  '$totalDevoluciones',
                  AppTheme.infoIndigo,
                  isDark,
                  width: 88,
                ),
              ],
            ),
          ),
        ),

        // Filtros y Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDarkSunken : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
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
                    hintText: 'Filtrar por producto, motivo o usuario...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.getAdaptiveHintText(isDark),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _filtroTexto.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchDebouncer.cancel();
                              _searchController.clear();
                              setState(() => _filtroTexto = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (val) => _searchDebouncer.run(() {
                    if (mounted) {
                      setState(() => _filtroTexto = val);
                    }
                  }),
                  onSubmitted: (val) {
                    _searchDebouncer.cancel();
                    setState(() => _filtroTexto = val);
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Chips de Tipo
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('TODOS', 'Todos', isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('ENTRADA', 'Entradas (Compras)', isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('SALIDA', 'Salidas (Ventas)', isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('AJUSTE', 'Mermas y Ajustes', isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('PRECIO', 'Cambios de Precio', isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('EDICION', 'Edición de Catálogo', isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      'DEVOLUCION',
                      'Devoluciones / Anulaciones',
                      isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lista de Movimientos
        Expanded(
          child: filtrados.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final m = filtrados[idx];
                    return _buildMovimientoTile(m, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildKardexDesktop(
    bool isDark,
    List<MovimientoInventario> filtrados,
    int totalEntradas,
    int totalSalidas,
    int totalAjustes,
    int totalPrecios,
    int totalEdiciones,
    int totalDevoluciones,
    MovimientoInventario? seleccionado,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Rejilla Superior de 6 KPIs en Pantalla Completa
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: _buildMetricsGridDesktop(
            isDark,
            totalEntradas,
            totalSalidas,
            totalAjustes,
            totalPrecios,
            totalEdiciones,
            totalDevoluciones,
          ),
        ),

        // 2. Cockpit en 2 Columnas Sincronizadas
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna Izquierda (Flex 7): Buscador, Filtros y Tabla Contable
                Expanded(
                  flex: 7,
                  child: _buildPanelTablaMovimientosDesktop(
                    isDark,
                    filtrados,
                    seleccionado,
                  ),
                ),
                const SizedBox(width: 14),

                // Columna Derecha (Flex 5): Inspector Lateral y Control de Fugas
                Expanded(
                  flex: 5,
                  child: _buildPanelInspectorLateralDesktop(
                    isDark,
                    seleccionado,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGridDesktop(
    bool isDark,
    int totalEntradas,
    int totalSalidas,
    int totalAjustes,
    int totalPrecios,
    int totalEdiciones,
    int totalDevoluciones,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCardDesktop(
            label: 'Entradas',
            count: '$totalEntradas',
            color: AppTheme.accentGreen,
            icon: LucideIcons.arrowDownLeft,
            subtitulo: 'Compras de stock',
            tipoFiltro: 'ENTRADA',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCardDesktop(
            label: 'Salidas',
            count: '$totalSalidas',
            color: AppTheme.brandPrimary,
            icon: LucideIcons.arrowUpRight,
            subtitulo: 'Ventas en caja POS',
            tipoFiltro: 'SALIDA',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCardDesktop(
            label: 'Mermas',
            count: '$totalAjustes',
            color: AppTheme.alertRed,
            icon: LucideIcons.packageMinus,
            subtitulo: 'Roturas y vencidos',
            tipoFiltro: 'AJUSTE',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCardDesktop(
            label: 'Precios',
            count: '$totalPrecios',
            color: const Color(0xFF8B5CF6),
            icon: LucideIcons.tag,
            subtitulo: 'Auditados Admin',
            tipoFiltro: 'PRECIO',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCardDesktop(
            label: 'Catálogo',
            count: '$totalEdiciones',
            color: const Color(0xFF0284C7),
            icon: LucideIcons.filePenLine,
            subtitulo: 'Datos y códigos',
            tipoFiltro: 'EDICION',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKpiCardDesktop(
            label: 'Devolución',
            count: '$totalDevoluciones',
            color: AppTheme.infoIndigo,
            icon: LucideIcons.rotateCcw,
            subtitulo: 'Anulaciones POS',
            tipoFiltro: 'DEVOLUCION',
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCardDesktop({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
    required String subtitulo,
    required String tipoFiltro,
    required bool isDark,
  }) {
    final isSelected = _filtroTipo == tipoFiltro;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _filtroTipo = isSelected ? 'TODOS' : tipoFiltro;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.18 : 0.08)
                : (isDark ? AppTheme.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
              width: isSelected ? 1.8 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 15),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                count,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelTablaMovimientosDesktop(
    bool isDark,
    List<MovimientoInventario> filtrados,
    MovimientoInventario? seleccionado,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila de Búsqueda y Filtros
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
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
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar por producto, motivo o usuario responsable...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: AppTheme.getAdaptiveHintText(isDark),
                        fontSize: 12.5,
                      ),
                      prefixIcon: const Icon(LucideIcons.search, size: 17),
                      suffixIcon: _filtroTexto.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 15),
                              onPressed: () {
                                _searchDebouncer.cancel();
                                _searchController.clear();
                                setState(() => _filtroTexto = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) => _searchDebouncer.run(() {
                      if (mounted) setState(() => _filtroTexto = val);
                    }),
                    onSubmitted: (val) {
                      _searchDebouncer.cancel();
                      setState(() => _filtroTexto = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.cardDarkSunken
                      : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                tooltip: 'Actualizar movimientos',
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                onPressed: _cargarMovimientos,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chips de filtro rápido por tipo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('TODOS', 'Todos', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('ENTRADA', 'Compras', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('SALIDA', 'Ventas', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('AJUSTE', 'Mermas', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('PRECIO', 'Precios', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('EDICION', 'Catálogo', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('DEVOLUCION', 'Devoluciones', isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Cabecera Fija de la Tabla Contable
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 55,
                  child: Text(
                    'HORA',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    'PRODUCTO & MOTIVO SUSTENTATORIO',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: Text(
                    'INSIGNIA',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 85,
                  child: Text(
                    'VARIACIÓN',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: Text(
                    'RESPONSABLE',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Cuerpo de Filas
          Expanded(
            child: filtrados.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 4),
                    itemBuilder: (context, idx) {
                      final m = filtrados[idx];
                      final isSelected =
                          seleccionado?.idMovimiento == m.idMovimiento;
                      return _buildMovimientoRowDesktop(
                        m: m,
                        isDark: isDark,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => _movimientoSeleccionado = m);
                        },
                      );
                    },
                  ),
          ),

          // Footer informativo
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mostrando ${filtrados.length} de ${_movimientos.length} movimientos',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                ),
              ),
              Row(
                children: [
                  _buildColorLegend('Compra', AppTheme.accentGreen, isDark),
                  const SizedBox(width: 8),
                  _buildColorLegend('Venta', AppTheme.brandPrimary, isDark),
                  const SizedBox(width: 8),
                  _buildColorLegend('Merma', AppTheme.alertRed, isDark),
                  const SizedBox(width: 8),
                  _buildColorLegend('Precio', const Color(0xFF8B5CF6), isDark),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorLegend(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            color: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildMovimientoRowDesktop({
    required MovimientoInventario m,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final detalle = _calcularDetalleVisual(m);
    final horaStr = m.fechaMovimiento != null
        ? '${m.fechaMovimiento!.hour.toString().padLeft(2, '0')}:${m.fechaMovimiento!.minute.toString().padLeft(2, '0')}'
        : '--:--';

    final cantFormateada = m.cantidad % 1 == 0
        ? m.cantidad.toInt().toString()
        : m.cantidad.toStringAsFixed(2);

    final String variacionTexto;
    if (detalle.esAuditoriaAdmin) {
      variacionTexto = 'Auditado';
    } else if (detalle.badgeText.startsWith('+')) {
      variacionTexto = '+$cantFormateada u.';
    } else {
      variacionTexto = '-$cantFormateada u.';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.brandPrimary.withValues(alpha: isDark ? 0.2 : 0.08)
                : (isDark ? AppTheme.cardDarkSunken : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppTheme.brandPrimary
                  : (isDark ? AppTheme.borderDark : const Color(0xFFF1F5F9)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // 1. Hora
              SizedBox(
                width: 55,
                child: Text(
                  horaStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Producto & Motivo
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nombreProducto,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.motivo.isNotEmpty
                          ? m.motivo
                          : 'Movimiento de inventario',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 3. Insignia Semántica
              SizedBox(
                width: 110,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: detalle.color.withValues(
                        alpha: isDark ? 0.22 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: detalle.color.withValues(
                          alpha: isDark ? 0.45 : 0.25,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(detalle.badgeIcon, size: 11, color: detalle.color),
                        const SizedBox(width: 4),
                        Text(
                          detalle.badgeText,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: detalle.color,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 4. Variación de Stock
              SizedBox(
                width: 85,
                child: Text(
                  variacionTexto,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: detalle.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 5. Responsable
              SizedBox(
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      LucideIcons.user,
                      size: 11,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        m.usuarioResponsable ?? 'Sistema',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelInspectorLateralDesktop(
    bool isDark,
    MovimientoInventario? seleccionado,
  ) {
    if (seleccionado == null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.mousePointerClick,
                size: 36,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                'Selecciona un movimiento',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Haz clic en cualquier fila del listado para inspeccionar su auditoría profunda.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardFichaAuditoria(isDark, seleccionado),
          const SizedBox(height: 14),
          _buildCardControlMermas(isDark),
        ],
      ),
    );
  }

  Widget _buildCardFichaAuditoria(bool isDark, MovimientoInventario m) {
    final detalle = _calcularDetalleVisual(m);
    final fechaCompletaStr = m.fechaMovimiento != null
        ? '${m.fechaMovimiento!.day.toString().padLeft(2, '0')}/${m.fechaMovimiento!.month.toString().padLeft(2, '0')}/${m.fechaMovimiento!.year} ${m.fechaMovimiento!.hour.toString().padLeft(2, '0')}:${m.fechaMovimiento!.minute.toString().padLeft(2, '0')}:${m.fechaMovimiento!.second.toString().padLeft(2, '0')}'
        : 'Reciente';

    final cantFormateada = m.cantidad % 1 == 0
        ? m.cantidad.toInt().toString()
        : m.cantidad.toStringAsFixed(2);

    final esCambioPrecio = _esCambioPrecio(m);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera Inspector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: detalle.color.withValues(
                        alpha: isDark ? 0.22 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: detalle.color.withValues(
                          alpha: isDark ? 0.45 : 0.25,
                        ),
                      ),
                    ),
                    child: Icon(detalle.icon, color: detalle.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ficha de Auditoría',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Trazabilidad en tiempo real',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.cardDarkSunken
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                ),
                child: Text(
                  '#MOV-${m.idMovimiento}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Nombre de Producto
          Text(
            'PRODUCTO AUDITADO',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            m.nombreProducto,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),

          // Tarjeta de Detalle si es Auditoría de Precio
          if (esCambioPrecio) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6)
                    .withValues(alpha: isDark ? 0.18 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF8B5CF6)
                      .withValues(alpha: isDark ? 0.4 : 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.tag,
                    color: Color(0xFF8B5CF6),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actualización de Precios / Costos',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                        Text(
                          m.motivo,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Variación Cuantitativa
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIPO DE MOVIMIENTO',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.tipoMovimiento,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: detalle.color,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'CANTIDAD AFECTADA',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalle.esAuditoriaAdmin
                          ? '0 u. (Dato)'
                          : '$cantFormateada unidades',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: detalle.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Motivo Sustentatorio
          Text(
            'MOTIVO / DOCUMENTO SUSTENTATORIO',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
              ),
            ),
            child: Text(
              m.motivo.isNotEmpty
                  ? m.motivo
                  : 'Sin motivo específico registrado.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Metadatos Fiscales
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Usuario Auditor:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      m.usuarioResponsable ?? 'Sistema Automático',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fecha y Hora:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      fechaCompletaStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Botones de Acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: isDark
                          ? AppTheme.borderDark
                          : AppTheme.borderLight,
                    ),
                  ),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: 'MOV-${m.idMovimiento}'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'ID MOV-${m.idMovimiento} copiado al portapapeles',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.copy, size: 14),
                  label: Text(
                    'Copiar ID',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.text = m.nombreProducto;
                      _filtroTexto = m.nombreProducto;
                    });
                  },
                  icon: const Icon(LucideIcons.history, size: 14),
                  label: Text(
                    'Historial Producto',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardControlMermas(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.shieldAlert,
                    color: AppTheme.alertRed,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Control de Fugas & Mermas',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Activo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.alertRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Cada ajuste por [ROTURA], [VENCIMIENTO] o [CONSUMO_INTERNO] se audita con responsable y fecha para proteger la rentabilidad de la bodega.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              height: 1.4,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final bool esFiltro = _filtroTexto.isNotEmpty || _filtroTipo != 'TODOS';
    final Color badgeColor = esFiltro
        ? AppTheme.brandPrimary
        : const Color(0xFF0D9488); // Teal
    final IconData icon = esFiltro
        ? LucideIcons.fileSearch
        : LucideIcons.fileSpreadsheet;

    final String title = esFiltro
        ? 'Sin movimientos para este filtro'
        : 'Kardex de Inventario Automatizado';

    final String subtitle = esFiltro
        ? 'No se encontraron operaciones de inventario con los criterios o texto ingresados.'
        : 'Cada venta en caja POS, recepción de compra, ajuste por merma o anulación se audita aquí en tiempo real.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dual-Ring Badge
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: isDark ? 0.35 : 0.22),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.14),
                    ),
                    child: Icon(icon, size: 24, color: badgeColor),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 20),

              // Didactic Audit Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF101622)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.barChart3,
                      size: 16,
                      color: AppTheme.brandPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Control Contable y Fiscal: El Kardex valorizado refleja las existencias exactas y el costo promedio de tu mercadería, blindando tu bodega contra mermas invisibles.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              if (esFiltro)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: isDark
                          ? AppTheme.borderDark
                          : AppTheme.borderLight,
                    ),
                  ),
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  label: Text(
                    'Restablecer Filtros',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _filtroTipo = 'TODOS';
                      _filtroTexto = '';
                      _searchDebouncer.cancel();
                      _searchController.clear();
                    });
                  },
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: Text(
                    'Actualizar Movimientos',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => _cargarMovimientos(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiChip(
    String label,
    String count,
    Color color,
    bool isDark, {
    double? width,
  }) {
    final chip = Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (width != null) {
      return chip;
    }
    return Expanded(child: chip);
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _filtroTipo == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected
            ? AppTheme.brandPrimary
            : (isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
      ),
      selectedColor: isDark
          ? AppTheme.brandPrimary.withValues(alpha: 0.2)
          : AppTheme.surfaceTint,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      side: BorderSide(
        color: isSelected
            ? AppTheme.brandPrimary
            : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) => setState(() => _filtroTipo = key),
    );
  }

  ({
    Color color,
    IconData icon,
    String badgeText,
    IconData badgeIcon,
    bool esAuditoriaAdmin,
  })
  _calcularDetalleVisual(MovimientoInventario m) {
    final tipo = m.tipoMovimiento.toUpperCase();
    final mot = m.motivo.toUpperCase();

    // 1. Auditoría de Precios
    if (tipo == 'CAMBIO_PRECIO' || mot.contains('PRECIO DE VENTA')) {
      return (
        color: const Color(0xFF8B5CF6), // Violeta
        icon: LucideIcons.tag,
        badgeText: 'PRECIO',
        badgeIcon: LucideIcons.tag,
        esAuditoriaAdmin: true,
      );
    }

    if (tipo == 'CAMBIO_COSTO' || mot.contains('COSTO DE COMPRA')) {
      return (
        color: const Color(0xFFD97706), // Ámbar cálido
        icon: LucideIcons.coins,
        badgeText: 'COSTO',
        badgeIcon: LucideIcons.coins,
        esAuditoriaAdmin: true,
      );
    }

    // 2. Auditoría de Edición de Catálogo
    if (tipo == 'CAMBIO_NOMBRE' ||
        mot.contains('NOMBRE/DESCRIPCIÓN') ||
        mot.contains('CAMBIO DE NOMBRE')) {
      return (
        color: const Color(0xFF0284C7), // Azul cielo
        icon: LucideIcons.filePenLine,
        badgeText: 'DETALLE',
        badgeIcon: LucideIcons.filePenLine,
        esAuditoriaAdmin: true,
      );
    }

    if (tipo == 'CAMBIO_CATEGORIA' ||
        mot.contains('CATEGORÍA') ||
        mot.contains('CATEGORIA')) {
      return (
        color: const Color(0xFF6366F1), // Índigo
        icon: LucideIcons.layoutGrid,
        badgeText: 'CATEGORÍA',
        badgeIcon: LucideIcons.layoutGrid,
        esAuditoriaAdmin: true,
      );
    }

    if (tipo == 'CAMBIO_MARCA' || mot.contains('MARCA')) {
      return (
        color: const Color(0xFFEC4899), // Rosa Magenta
        icon: LucideIcons.sparkles,
        badgeText: 'MARCA',
        badgeIcon: LucideIcons.sparkles,
        esAuditoriaAdmin: true,
      );
    }

    if (tipo == 'CAMBIO_CODIGO' ||
        mot.contains('CÓDIGO DE BARRAS') ||
        mot.contains('CODIGO DE BARRAS')) {
      return (
        color: const Color(0xFF0EA5E9), // Azul Cian
        icon: LucideIcons.scanBarcode,
        badgeText: 'CÓDIGO',
        badgeIcon: LucideIcons.scanBarcode,
        esAuditoriaAdmin: true,
      );
    }

    if (tipo == 'CAMBIO_VENCIMIENTO' ||
        (mot.contains('VENCIMIENTO') && m.cantidad == 0 && !_esAjuste(m))) {
      return (
        color: const Color(0xFFEA580C), // Naranja intenso
        icon: LucideIcons.calendarClock,
        badgeText: 'VENCE',
        badgeIcon: LucideIcons.calendarClock,
        esAuditoriaAdmin: true,
      );
    }

    if (_esCambioDatos(m)) {
      return (
        color: const Color(0xFF0284C7),
        icon: LucideIcons.sliders,
        badgeText: 'CATÁLOGO',
        badgeIcon: LucideIcons.sliders,
        esAuditoriaAdmin: true,
      );
    }

    // 3. Movimientos Físicos de Stock
    final bool isDevolucion =
        tipo.contains('DEVOLUCION') ||
        tipo.contains('ANULACION') ||
        mot.contains('ANULACI');
    final bool isAjuste = _esAjuste(m);
    final bool isEntrada =
        !isDevolucion &&
        !isAjuste &&
        (tipo.contains('ENTRADA') || tipo.contains('COMPRA'));

    final String cantFormateada = m.cantidad % 1 == 0
        ? m.cantidad.toInt().toString()
        : m.cantidad.toStringAsFixed(2);

    if (isAjuste) {
      final esSobrante = mot.contains('[SOBRANTE]') || tipo.contains('ENTRADA');
      return (
        color: esSobrante ? AppTheme.accentGreen : AppTheme.alertRed,
        icon: esSobrante ? LucideIcons.packagePlus : LucideIcons.packageMinus,
        badgeText: '${esSobrante ? '+' : '-'}$cantFormateada u.',
        badgeIcon: esSobrante
            ? LucideIcons.packagePlus
            : LucideIcons.packageMinus,
        esAuditoriaAdmin: false,
      );
    }

    if (isEntrada) {
      return (
        color: AppTheme.accentGreen,
        icon: LucideIcons.arrowDownLeft,
        badgeText: '+$cantFormateada u.',
        badgeIcon: LucideIcons.arrowDownLeft,
        esAuditoriaAdmin: false,
      );
    }

    if (isDevolucion) {
      return (
        color: const Color(0xFF3B82F6),
        icon: LucideIcons.rotateCcw,
        badgeText: '+$cantFormateada u.',
        badgeIcon: LucideIcons.rotateCcw,
        esAuditoriaAdmin: false,
      );
    }

    // Por defecto: Salida / Venta en caja POS (flecha diagonal hacia la derecha)
    return (
      color: AppTheme.brandPrimary,
      icon: LucideIcons.arrowUpRight,
      badgeText: '-$cantFormateada u.',
      badgeIcon: LucideIcons.arrowUpRight,
      esAuditoriaAdmin: false,
    );
  }

  Widget _buildMovimientoTile(MovimientoInventario m, bool isDark) {
    final detalle = _calcularDetalleVisual(m);

    final fechaStr = m.fechaMovimiento != null
        ? '${m.fechaMovimiento!.day.toString().padLeft(2, '0')}/${m.fechaMovimiento!.month.toString().padLeft(2, '0')} ${m.fechaMovimiento!.hour.toString().padLeft(2, '0')}:${m.fechaMovimiento!.minute.toString().padLeft(2, '0')}'
        : 'Reciente';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono principal identificador (diferenciado de la flecha de stock)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: detalle.color.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: detalle.color.withValues(alpha: isDark ? 0.35 : 0.22),
                width: 1,
              ),
            ),
            child: Icon(detalle.icon, color: detalle.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.nombreProducto,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  m.motivo.isNotEmpty ? m.motivo : 'Movimiento de inventario',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      fechaStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                      ),
                    ),
                    if (m.usuarioResponsable != null &&
                        m.usuarioResponsable!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.userCheck,
                                size: 10,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  m.usuarioResponsable!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppTheme.textDarkMuted
                                        : const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
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
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Insignia lateral derecha
          if (detalle.esAuditoriaAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: detalle.color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: detalle.color.withValues(alpha: isDark ? 0.45 : 0.25),
                  width: 1.1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(detalle.badgeIcon, size: 11, color: detalle.color),
                  const SizedBox(width: 4),
                  Text(
                    detalle.badgeText,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: detalle.color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: detalle.color.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: detalle.color.withValues(alpha: isDark ? 0.35 : 0.2),
                  width: 1.1,
                ),
              ),
              child: Text(
                detalle.badgeText,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: detalle.color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
