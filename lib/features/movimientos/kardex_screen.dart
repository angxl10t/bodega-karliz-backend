import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'movimiento_model.dart';
import 'movimiento_service.dart';
import '../productos/producto_service.dart';
import '../ventas/venta_service.dart';
import '../compras/compra_service.dart';
import '../../core/theme.dart';

class KardexScreen extends StatefulWidget {
  const KardexScreen({super.key});

  @override
  State<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  final MovimientoService _movimientoService = MovimientoService();
  final TextEditingController _searchController = TextEditingController();
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

  bool _esAjuste(MovimientoInventario m) {
    final mot = m.motivo.toUpperCase();
    return mot.contains('[MERMA]') ||
        mot.contains('[ROTURA]') ||
        mot.contains('[VENCIMIENTO]') ||
        mot.contains('[CONSUMO_INTERNO]') ||
        mot.contains('[SOBRANTE]') ||
        mot.contains('AJUSTE MANUAL') ||
        mot.contains('[AJUSTE');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtrados = _movimientos.where((m) {
      final matchesText = m.nombreProducto.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          m.motivo.toLowerCase().contains(_filtroTexto.toLowerCase());

      bool matchesTipo = true;
      if (_filtroTipo == 'ENTRADA') {
        matchesTipo = (m.tipoMovimiento.contains('ENTRADA') || m.tipoMovimiento.contains('COMPRA')) &&
            !m.motivo.toUpperCase().contains('ANULACI') &&
            !_esAjuste(m);
      } else if (_filtroTipo == 'SALIDA') {
        matchesTipo = (m.tipoMovimiento.contains('SALIDA') || m.tipoMovimiento.contains('VENTA')) &&
            !_esAjuste(m);
      } else if (_filtroTipo == 'AJUSTE') {
        matchesTipo = _esAjuste(m);
      } else if (_filtroTipo == 'DEVOLUCION') {
        matchesTipo = m.tipoMovimiento.contains('DEVOLUCION') ||
            m.tipoMovimiento.contains('ANULACION') ||
            m.motivo.toUpperCase().contains('ANULACI');
      }
      return matchesText && matchesTipo;
    }).toList();

    final int totalDevoluciones = _movimientos.where((m) =>
        m.tipoMovimiento.contains('DEVOLUCION') ||
        m.tipoMovimiento.contains('ANULACION') ||
        m.motivo.toUpperCase().contains('ANULACI')).length;
    final int totalEntradas = _movimientos.where((m) =>
        (m.tipoMovimiento.contains('ENTRADA') || m.tipoMovimiento.contains('COMPRA')) &&
        !m.motivo.toUpperCase().contains('ANULACI') &&
        !_esAjuste(m)).length;
    final int totalSalidas = _movimientos.where((m) =>
        (m.tipoMovimiento.contains('SALIDA') || m.tipoMovimiento.contains('VENTA')) &&
        !_esAjuste(m)).length;
    final int totalAjustes = _movimientos.where((m) => _esAjuste(m)).length;

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
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
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
          ? const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary))
          : RefreshIndicator(
              onRefresh: _cargarMovimientos,
              color: AppTheme.brandPrimary,
              child: Column(
                children: [
                  // Banner Didáctico
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: const DidacticBanner(
                      title: 'Auditoría en Tiempo Real',
                      description: 'Cada venta en POS resta stock, cada compra suma existencias, cada merma o rotura descuenta por deterioro y las anulaciones restituyen productos.',
                      icon: LucideIcons.fileSpreadsheet,
                    ),
                  ),

                  // Métricas Rápidas
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        _buildKpiChip('Entradas', '$totalEntradas', AppTheme.accentGreen, isDark),
                        const SizedBox(width: 6),
                        _buildKpiChip('Salidas', '$totalSalidas', AppTheme.brandPrimary, isDark),
                        const SizedBox(width: 6),
                        _buildKpiChip('Mermas', '$totalAjustes', const Color(0xFFEA580C), isDark),
                        const SizedBox(width: 6),
                        _buildKpiChip('Devolución', '$totalDevoluciones', AppTheme.infoIndigo, isDark),
                      ],
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
                              hintStyle: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                              prefixIcon: const Icon(LucideIcons.search, size: 18),
                              suffixIcon: _filtroTexto.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(LucideIcons.x, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _filtroTexto = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (val) => setState(() => _filtroTexto = val),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Chips de Tipo
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
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
                              _buildFilterChip('DEVOLUCION', 'Devoluciones / Anulaciones', isDark),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filtrados.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 10),
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
    final Color badgeColor = esFiltro ? AppTheme.brandPrimary : const Color(0xFF0D9488); // Teal
    final IconData icon = esFiltro ? LucideIcons.fileSearch : LucideIcons.fileSpreadsheet;

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
                  color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 20),

              // Didactic Audit Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF101622) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📊', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Control Contable y Fiscal: El Kardex valorizado refleja las existencias exactas y el costo promedio de tu mercadería, blindando tu bodega contra mermas invisibles.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  label: Text(
                    'Restablecer Filtros',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  onPressed: () {
                    setState(() {
                      _filtroTipo = 'TODOS';
                      _filtroTexto = '';
                      _searchController.clear();
                    });
                  },
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: Text(
                    'Actualizar Movimientos',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  onPressed: () => _cargarMovimientos(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiChip(String label, String count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          ),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155), fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _filtroTipo == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? AppTheme.brandPrimary : (isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
      ),
      selectedColor: isDark ? AppTheme.brandPrimary.withValues(alpha: 0.2) : AppTheme.surfaceTint,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.brandPrimary : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) => setState(() => _filtroTipo = key),
    );
  }

  Widget _buildMovimientoTile(MovimientoInventario m, bool isDark) {
    final tipo = m.tipoMovimiento.toUpperCase();
    final bool isDevolucion = tipo.contains('DEVOLUCION') ||
        tipo.contains('ANULACION') ||
        m.motivo.toUpperCase().contains('ANULACI');
    final bool isAjuste = _esAjuste(m);
    final bool isEntrada = !isDevolucion && !isAjuste && (tipo.contains('ENTRADA') || tipo.contains('COMPRA'));

    Color badgeColor;
    IconData icon;
    String sign;

    if (isAjuste) {
      final esSobrante = m.motivo.toUpperCase().contains('[SOBRANTE]') || tipo.contains('ENTRADA');
      badgeColor = esSobrante ? AppTheme.accentGreen : const Color(0xFFEA580C);
      icon = esSobrante ? LucideIcons.packagePlus : LucideIcons.packageMinus;
      sign = esSobrante ? '+' : '-';
    } else if (isEntrada) {
      badgeColor = AppTheme.accentGreen;
      icon = LucideIcons.arrowDownLeft;
      sign = '+';
    } else if (isDevolucion) {
      badgeColor = const Color(0xFF3B82F6);
      icon = LucideIcons.rotateCcw;
      sign = '+';
    } else {
      badgeColor = AppTheme.brandPrimary;
      icon = LucideIcons.arrowUpRight;
      sign = '-';
    }

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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombreProducto,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.motivo.isNotEmpty ? m.motivo : 'Movimiento de inventario',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      fechaStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                      ),
                    ),
                    if (m.usuarioResponsable != null && m.usuarioResponsable!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.userCheck, size: 10, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(
                                m.usuarioResponsable!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppTheme.textDarkMuted : const Color(0xFF334155),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Builder(
              builder: (context) {
                final String cantFormateada = m.cantidad % 1 == 0
                    ? m.cantidad.toInt().toString()
                    : m.cantidad.toStringAsFixed(2);
                return Text(
                  '$sign$cantFormateada u.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
