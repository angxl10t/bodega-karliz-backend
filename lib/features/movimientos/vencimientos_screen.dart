import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../productos/producto_model.dart';
import '../productos/producto_service.dart';
import 'ajuste_stock_sheet.dart';

class VencimientosScreen extends StatefulWidget {
  const VencimientosScreen({super.key});

  @override
  State<VencimientosScreen> createState() => _VencimientosScreenState();
}

class _VencimientosScreenState extends State<VencimientosScreen> {
  final ProductoService _productoService = ProductoService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Producto> _todosProductos = [];
  bool _isLoading = true;
  String _filtroTexto = '';
  String _filtroSemaforo = 'TODOS'; // 'TODOS', 'CRITICO', 'ATENCION', 'VIGENTE'

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    ProductoService.productosRevision.addListener(_onRevisionChanged);
  }

  @override
  void dispose() {
    ProductoService.productosRevision.removeListener(_onRevisionChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onRevisionChanged() {
    if (mounted) _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() => _isLoading = true);
    final lista = await _productoService.getProductos();
    if (mounted) {
      setState(() {
        _todosProductos = lista.where((p) => p.controlaVencimiento).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _actualizarFechaVencimiento(Producto p) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: p.fechaVencimiento ?? now.plusDays(30),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      helpText: 'SELECCIONA FECHA DE VENCIMIENTO / LOTE',
      confirmText: 'GUARDAR',
      cancelText: 'CANCELAR',
    );

    if (picked != null) {
      final actualizado = p.copyWith(fechaVencimiento: picked);
      final ok = await _productoService.actualizarProducto(actualizado);
      if (ok && mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vencimiento de "${p.nombre}" actualizado al ${picked.day}/${picked.month}/${picked.year}'),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );
        _cargarProductos();
      }
    }
  }

  Future<void> _escanearCodigo() async {
    final codigo = await KarlizBarcodeScannerModal.scan(context);
    if (codigo != null && codigo.isNotEmpty) {
      setState(() {
        _searchCtrl.text = codigo;
        _filtroTexto = codigo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    // Métricas para KPIs
    final criticos = _todosProductos.where((p) => p.semaforoVencimiento == SemaforoVencimiento.critico).toList();
    final enRiesgo = _todosProductos.where((p) => p.semaforoVencimiento == SemaforoVencimiento.atencion).toList();
    final vigentes = _todosProductos.where((p) => p.semaforoVencimiento == SemaforoVencimiento.vigente).toList();

    double valorCriticoSoles = criticos.fold(0.0, (acc, p) => acc + (p.stockActual * p.precioVenta));
    double valorRiesgoSoles = enRiesgo.fold(0.0, (acc, p) => acc + (p.stockActual * p.precioVenta));

    // Filtrado de lista
    final filtrados = _todosProductos.where((p) {
      final matchesText = p.nombre.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          p.codigo.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          (p.codigoBarras ?? '').contains(_filtroTexto);

      bool matchesSemaforo = true;
      if (_filtroSemaforo == 'CRITICO') {
        matchesSemaforo = p.semaforoVencimiento == SemaforoVencimiento.critico;
      } else if (_filtroSemaforo == 'ATENCION') {
        matchesSemaforo = p.semaforoVencimiento == SemaforoVencimiento.atencion;
      } else if (_filtroSemaforo == 'VIGENTE') {
        matchesSemaforo = p.semaforoVencimiento == SemaforoVencimiento.vigente;
      }

      return matchesText && matchesSemaforo;
    }).toList();

    // Ordenar: primero los más próximos a vencer o vencidos
    filtrados.sort((a, b) {
      final da = a.diasParaVencer ?? 9999;
      final db = b.diasParaVencer ?? 9999;
      return da.compareTo(db);
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Control de Vencimientos',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: cardBg,
        foregroundColor: isDark ? Colors.white : AppTheme.textDark,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
        actions: [
          IconButton(
            tooltip: 'Escanear Código de Barras',
            icon: const Icon(LucideIcons.scanBarcode, color: AppTheme.brandPrimary),
            onPressed: _escanearCodigo,
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _cargarProductos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary))
          : Column(
              children: [
                // 1. Panel Superior de Métricas Semáforo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: cardBg,
                  child: Row(
                    children: [
                      // Crítico (< 7 días o vencido)
                      Expanded(
                        child: _buildKpiCard(
                          titulo: 'Críticos (< 7d)',
                          cantidad: criticos.length,
                          montoSoles: valorCriticoSoles,
                          color: const Color(0xFFEF4444),
                          icon: LucideIcons.alertTriangle,
                          isSelected: _filtroSemaforo == 'CRITICO',
                          onTap: () {
                            setState(() {
                              _filtroSemaforo = _filtroSemaforo == 'CRITICO' ? 'TODOS' : 'CRITICO';
                            });
                          },
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // En Riesgo (15 a 30 días - poner en oferta)
                      Expanded(
                        child: _buildKpiCard(
                          titulo: 'En Riesgo (15-30d)',
                          cantidad: enRiesgo.length,
                          montoSoles: valorRiesgoSoles,
                          color: const Color(0xFFF59E0B),
                          icon: LucideIcons.tag,
                          isSelected: _filtroSemaforo == 'ATENCION',
                          onTap: () {
                            setState(() {
                              _filtroSemaforo = _filtroSemaforo == 'ATENCION' ? 'TODOS' : 'ATENCION';
                            });
                          },
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Vigentes (> 60 días)
                      Expanded(
                        child: _buildKpiCard(
                          titulo: 'Vigentes (> 60d)',
                          cantidad: vigentes.length,
                          montoSoles: null,
                          color: AppTheme.accentGreen,
                          icon: LucideIcons.shieldCheck,
                          isSelected: _filtroSemaforo == 'VIGENTE',
                          onTap: () {
                            setState(() {
                              _filtroSemaforo = _filtroSemaforo == 'VIGENTE' ? 'TODOS' : 'VIGENTE';
                            });
                          },
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Buscador y Filtro Rápido
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  color: cardBg,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF101622) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Filtrar por nombre o código...',
                              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppTheme.textMuted),
                              prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppTheme.brandPrimary),
                              suffixIcon: _filtroTexto.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(LucideIcons.x, size: 14),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _filtroTexto = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (val) => setState(() => _filtroTexto = val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_filtroSemaforo != 'TODOS')
                        ActionChip(
                          avatar: const Icon(LucideIcons.x, size: 14),
                          label: Text(_filtroSemaforo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => setState(() => _filtroSemaforo = 'TODOS'),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // 3. Lista de Productos con Semáforo
                Expanded(
                  child: filtrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.checkCircle2, size: 48, color: AppTheme.accentGreen.withValues(alpha: 0.6)),
                              const SizedBox(height: 12),
                              Text(
                                '¡Sin alertas de caducidad en este filtro!',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Todos los productos evaluados se encuentran en buen estado.',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtrados.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final p = filtrados[index];
                            return _buildProductoVencimientoCard(p, isDark, cardBg, borderColor);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiCard({
    required String titulo,
    required int cantidad,
    required double? montoSoles,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: isDark ? 0.25 : 0.15) : color.withValues(alpha: isDark ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const Spacer(),
                Text(
                  '$cantidad',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : AppTheme.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (montoSoles != null)
              Text(
                'S/ ${montoSoles.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductoVencimientoCard(Producto p, bool isDark, Color cardBg, Color borderColor) {
    final dias = p.diasParaVencer ?? 999;
    final semaforo = p.semaforoVencimiento;

    Color badgeColor;
    String badgeTexto;
    IconData badgeIcon;

    if (semaforo == SemaforoVencimiento.critico) {
      badgeColor = const Color(0xFFEF4444);
      badgeIcon = LucideIcons.alertOctagon;
      badgeTexto = dias < 0 ? 'VENCIDO HACE ${-dias} DÍAS' : (dias == 0 ? '¡VENCE HOY!' : '¡VENCE EN $dias DÍAS!');
    } else if (semaforo == SemaforoVencimiento.atencion) {
      badgeColor = const Color(0xFFF59E0B);
      badgeIcon = LucideIcons.alertTriangle;
      badgeTexto = 'VENCE EN $dias DÍAS (OFERTA / REMATE)';
    } else if (semaforo == SemaforoVencimiento.vigente) {
      badgeColor = AppTheme.accentGreen;
      badgeIcon = LucideIcons.checkCircle;
      badgeTexto = 'VIGENTE ($dias DÍAS)';
    } else {
      badgeColor = const Color(0xFF3B82F6);
      badgeIcon = LucideIcons.calendar;
      badgeTexto = 'NORMAL ($dias DÍAS)';
    }

    final fechaStr = p.fechaVencimiento != null
        ? '${p.fechaVencimiento!.day.toString().padLeft(2, '0')}/${p.fechaVencimiento!.month.toString().padLeft(2, '0')}/${p.fechaVencimiento!.year}'
        : 'Sin fecha';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: semaforo == SemaforoVencimiento.critico
              ? const Color(0xFFEF4444).withValues(alpha: 0.5)
              : borderColor,
          width: semaforo == SemaforoVencimiento.critico ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila Superior: Badge Semáforo y Fecha
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      badgeTexto,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(LucideIcons.calendar, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    fechaStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Centro: Packshot, Nombre, Categoría y Stock
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImageWidget(
                imagenUrl: p.imagenUrl,
                categoria: p.nombreCategoria,
                size: 54,
                borderRadius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'Stock: ${p.stockActual.toStringAsFixed(0)} un.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  Valor: S/ ${(p.stockActual * p.precioVenta).toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Fila de Acciones Rápidas
          Row(
            children: [
              // Botón Actualizar Fecha / Lote
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.brandPrimary,
                    side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(LucideIcons.calendarClock, size: 14),
                  label: const Text('Actualizar Lote', style: TextStyle(fontSize: 11.5)),
                  onPressed: () => _actualizarFechaVencimiento(p),
                ),
              ),
              const SizedBox(width: 8),

              // Botón Dar de Baja / Registrar Merma
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(LucideIcons.trash2, size: 14),
                  label: const Text('Dar de Baja', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    AjusteStockSheet.show(context, p, _cargarProductos);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on DateTime {
  DateTime plusDays(int days) => add(Duration(days: days));
}
