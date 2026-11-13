import 'package:flutter/material.dart';
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
              child: Column(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                            color: isDark
                                ? AppTheme.cardDarkSunken
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.borderDark
                                  : AppTheme.borderLight,
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
                              hintText:
                                  'Filtrar por producto, motivo o usuario...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: AppTheme.getAdaptiveHintText(isDark),
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                LucideIcons.search,
                                size: 18,
                              ),
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
                              _buildFilterChip(
                                'ENTRADA',
                                'Entradas (Compras)',
                                isDark,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                'SALIDA',
                                'Salidas (Ventas)',
                                isDark,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                'AJUSTE',
                                'Mermas y Ajustes',
                                isDark,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                'PRECIO',
                                'Cambios de Precio',
                                isDark,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                'EDICION',
                                'Edición de Catálogo',
                                isDark,
                              ),
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
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final m = filtrados[idx];
                              return _buildMovimientoTile(m, isDark);
                            },
                          ),
                  ),
                ],
              ),
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
                      const SizedBox(width: 8),
                      Container(
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
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
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
