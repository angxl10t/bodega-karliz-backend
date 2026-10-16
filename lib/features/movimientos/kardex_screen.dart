import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'movimiento_model.dart';
import 'movimiento_service.dart';
import '../../core/theme.dart';

class KardexScreen extends StatefulWidget {
  const KardexScreen({super.key});

  @override
  State<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  final MovimientoService _movimientoService = MovimientoService();
  List<MovimientoInventario> _movimientos = [];
  bool _isLoading = true;
  String _filtroTexto = '';
  String _filtroTipo = 'TODOS';

  @override
  void initState() {
    super.initState();
    _cargarMovimientos();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtrados = _movimientos.where((m) {
      final matchesText = m.nombreProducto.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          m.motivo.toLowerCase().contains(_filtroTexto.toLowerCase());

      bool matchesTipo = true;
      if (_filtroTipo == 'ENTRADA') {
        matchesTipo = (m.tipoMovimiento.contains('ENTRADA') || m.tipoMovimiento.contains('COMPRA')) &&
            !m.motivo.toUpperCase().contains('ANULACI');
      } else if (_filtroTipo == 'SALIDA') {
        matchesTipo = m.tipoMovimiento.contains('SALIDA') || m.tipoMovimiento.contains('VENTA');
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
        !m.motivo.toUpperCase().contains('ANULACI')).length;
    final int totalSalidas = _movimientos.where((m) =>
        m.tipoMovimiento.contains('SALIDA') || m.tipoMovimiento.contains('VENTA')).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
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
            ),
            Text(
              'Auditoría y trazabilidad de entradas/salidas',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
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
                      description: 'Cada venta en POS resta stock, cada compra suma existencias y cada anulación devuelve productos al inventario automáticamente.',
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
                        const SizedBox(width: 8),
                        _buildKpiChip('Salidas', '$totalSalidas', AppTheme.brandPrimary, isDark),
                        const SizedBox(width: 8),
                        _buildKpiChip('Devoluciones', '$totalDevoluciones', AppTheme.infoIndigo, isDark),
                      ],
                    ),
                  ),

                  // Filtros y Buscador
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardDark : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                            ),
                          ),
                          child: TextField(
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Filtrar por producto o motivo...',
                              hintStyle: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 13),
                              prefixIcon: const Icon(LucideIcons.search, size: 18),
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
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.fileSpreadsheet, size: 42, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'Sin movimientos registrados',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isDark ? Colors.white70 : AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                          )
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

  Widget _buildKpiChip(String label, String count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
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
        color: isSelected ? AppTheme.primaryOrange : (isDark ? Colors.white70 : const Color(0xFF475569)),
      ),
      selectedColor: isDark ? AppTheme.primaryOrange.withValues(alpha: 0.2) : AppTheme.peachSurface,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryOrange : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
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
    final bool isEntrada = !isDevolucion && (tipo.contains('ENTRADA') || tipo.contains('COMPRA'));

    Color badgeColor;
    IconData icon;
    String sign;

    if (isEntrada) {
      badgeColor = AppTheme.accentGreen;
      icon = LucideIcons.arrowDownLeft;
      sign = '+';
    } else if (isDevolucion) {
      badgeColor = const Color(0xFF3B82F6);
      icon = LucideIcons.rotateCcw;
      sign = '+';
    } else {
      badgeColor = AppTheme.primaryOrange;
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
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fechaStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$sign${m.cantidad.toStringAsFixed(0)} u.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
