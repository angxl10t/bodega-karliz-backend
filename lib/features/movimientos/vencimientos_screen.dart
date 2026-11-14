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
import '../../core/debouncer.dart';

class VencimientosScreen extends StatefulWidget {
  const VencimientosScreen({super.key});

  @override
  State<VencimientosScreen> createState() => _VencimientosScreenState();
}

class _VencimientosScreenState extends State<VencimientosScreen> {
  final ProductoService _productoService = ProductoService();
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();

  List<Producto> _todosProductos = [];
  bool _isLoading = true;
  String _filtroTexto = '';
  String _filtroSemaforo = 'TODOS'; // 'TODOS', 'CRITICO', 'ATENCION', 'VIGENTE'
  Producto? _productoSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    ProductoService.productosRevision.addListener(_onRevisionChanged);
  }

  @override
  void dispose() {
    ProductoService.productosRevision.removeListener(_onRevisionChanged);
    _searchDebouncer.dispose();
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

        // Mantener selección sincronizada si el producto aún existe
        if (_productoSeleccionado != null) {
          final idx = _todosProductos.indexWhere(
            (p) =>
                (p.idProducto != null &&
                    p.idProducto == _productoSeleccionado!.idProducto) ||
                p.codigo == _productoSeleccionado!.codigo,
          );
          if (idx != -1) {
            _productoSeleccionado = _todosProductos[idx];
          } else {
            _productoSeleccionado = null;
          }
        }
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
            content: Text(
              'Vencimiento de "${p.nombre}" actualizado al ${picked.day}/${picked.month}/${picked.year}',
            ),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );
        _cargarProductos();
      }
    }
  }

  Future<void> _mostrarDialogoRemate(Producto p) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final precioSugerido = double.parse(
      (p.precioVenta * 0.75).toStringAsFixed(2),
    );
    final recuperable = precioSugerido * p.stockActual;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.tag,
                color: Color(0xFFD97706),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Remate Preventivo FEFO (-25%)',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aplica un descuento preventivo del 25% para acelerar la rotación del lote antes de su caducidad y recuperar el capital mayorista.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.cardDarkSunken
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Precio Regular:',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      ),
                      Text(
                        'S/ ${p.precioVenta.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Precio Remate (-25%):',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                      Text(
                        'S/ ${precioSugerido.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Capital Recuperable:',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      ),
                      Text(
                        'S/ ${recuperable.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(LucideIcons.check, size: 16),
            label: const Text(
              'APLICAR REMATE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final actualizado = p.copyWith(precioVenta: precioSugerido);
      final ok = await _productoService.actualizarProducto(actualizado);
      if (ok && mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Precio de remate S/ ${precioSugerido.toStringAsFixed(2)} aplicado a "${p.nombre}"',
            ),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
          ),
        );
        _cargarProductos();
      }
    }
  }

  void _imprimirRotuloOferta(Producto p) {
    final precioRemate = (p.precioVenta * 0.75).toStringAsFixed(2);
    final fecha = p.fechaVencimiento != null
        ? '${p.fechaVencimiento!.day.toString().padLeft(2, '0')}/${p.fechaVencimiento!.month.toString().padLeft(2, '0')}/${p.fechaVencimiento!.year}'
        : 'N/A';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.printer, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rótulo FEFO: "${p.nombre}" | Oferta S/ $precioRemate | Lote: $fecha enviado a impresora térmica.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.brandPrimary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _escanearCodigo() async {
    final codigo = await KarlizBarcodeScannerModal.scan(context);
    if (codigo != null && codigo.isNotEmpty) {
      setState(() {
        _searchDebouncer.cancel();
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
    final vencidos = _todosProductos
        .where((p) => (p.diasParaVencer ?? 999) <= 0)
        .toList();
    final criticos = _todosProductos
        .where(
          (p) =>
              (p.diasParaVencer ?? 999) > 0 && (p.diasParaVencer ?? 999) <= 7,
        )
        .toList();
    final enRiesgo = _todosProductos
        .where(
          (p) =>
              (p.diasParaVencer ?? 999) > 7 && (p.diasParaVencer ?? 999) <= 30,
        )
        .toList();
    final vigentes = _todosProductos
        .where((p) => (p.diasParaVencer ?? 999) > 30)
        .toList();

    double valorVencidoSoles = vencidos.fold(
      0.0,
      (acc, p) => acc + (p.stockActual * p.precioVenta),
    );
    double valorCriticoSoles = criticos.fold(
      0.0,
      (acc, p) => acc + (p.stockActual * p.precioVenta),
    );
    double valorRiesgoSoles = enRiesgo.fold(
      0.0,
      (acc, p) => acc + (p.stockActual * p.precioVenta),
    );

    // Filtrado de lista
    final filtrados = _todosProductos.where((p) {
      final matchesText =
          p.nombre.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          p.codigo.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          (p.codigoBarras ?? '').contains(_filtroTexto);

      bool matchesSemaforo = true;
      if (_filtroSemaforo == 'VENCIDOS') {
        matchesSemaforo = (p.diasParaVencer ?? 999) <= 0;
      } else if (_filtroSemaforo == 'CRITICO' ||
          _filtroSemaforo == 'CRITICOS') {
        matchesSemaforo =
            (p.diasParaVencer ?? 999) > 0 && (p.diasParaVencer ?? 999) <= 7;
      } else if (_filtroSemaforo == 'ATENCION') {
        matchesSemaforo =
            (p.diasParaVencer ?? 999) > 7 && (p.diasParaVencer ?? 999) <= 30;
      } else if (_filtroSemaforo == 'VIGENTE' ||
          _filtroSemaforo == 'VIGENTES') {
        matchesSemaforo = (p.diasParaVencer ?? 999) > 30;
      }

      return matchesText && matchesSemaforo;
    }).toList();

    // Ordenar: primero los más próximos a vencer o vencidos (FEFO)
    filtrados.sort((a, b) {
      final da = a.diasParaVencer ?? 9999;
      final db = b.diasParaVencer ?? 9999;
      return da.compareTo(db);
    });

    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                tooltip: 'Regresar',
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        titleSpacing: canPop ? 0 : 16,
        title: Text(
          'Control de Vencimientos',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
            icon: const Icon(
              LucideIcons.scanBarcode,
              color: AppTheme.brandPrimary,
            ),
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
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.brandPrimary),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) {
                  return _buildVencimientosDesktop(
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    vencidos: vencidos,
                    criticos: criticos,
                    enRiesgo: enRiesgo,
                    vigentes: vigentes,
                    valorVencidoSoles: valorVencidoSoles,
                    valorCriticoSoles: valorCriticoSoles,
                    valorRiesgoSoles: valorRiesgoSoles,
                    filtrados: filtrados,
                  );
                }
                return _buildVencimientosMobile(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  vencidos: vencidos,
                  criticos: criticos,
                  enRiesgo: enRiesgo,
                  vigentes: vigentes,
                  valorVencidoSoles: valorVencidoSoles,
                  valorCriticoSoles: valorCriticoSoles,
                  valorRiesgoSoles: valorRiesgoSoles,
                  filtrados: filtrados,
                );
              },
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // VISTA MÓVIL (< 900px): CONSERVA 100% EL COMPORTAMIENTO Y EXPERIENCIA ORIGINAL
  // ---------------------------------------------------------------------------
  Widget _buildVencimientosMobile({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required List<Producto> vencidos,
    required List<Producto> criticos,
    required List<Producto> enRiesgo,
    required List<Producto> vigentes,
    required double valorVencidoSoles,
    required double valorCriticoSoles,
    required double valorRiesgoSoles,
    required List<Producto> filtrados,
  }) {
    return Column(
      children: [
        // 1. Panel Superior de Métricas Semáforo FIFO
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: cardBg,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: _buildKpiCard(
                    titulo: 'Vencidos (≤ 0d)',
                    cantidad: vencidos.length,
                    montoSoles: valorVencidoSoles,
                    color: const Color(0xFFDC2626),
                    icon: LucideIcons.alertOctagon,
                    isSelected: _filtroSemaforo == 'VENCIDOS',
                    onTap: () {
                      setState(() {
                        _filtroSemaforo = _filtroSemaforo == 'VENCIDOS'
                            ? 'TODOS'
                            : 'VENCIDOS';
                      });
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: _buildKpiCard(
                    titulo: 'Críticos (1-7d)',
                    cantidad: criticos.length,
                    montoSoles: valorCriticoSoles,
                    color: const Color(0xFFEA580C),
                    icon: LucideIcons.zap,
                    isSelected: _filtroSemaforo == 'CRITICOS',
                    onTap: () {
                      setState(() {
                        _filtroSemaforo = _filtroSemaforo == 'CRITICOS'
                            ? 'TODOS'
                            : 'CRITICOS';
                      });
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: _buildKpiCard(
                    titulo: 'Rotación (8-30d)',
                    cantidad: enRiesgo.length,
                    montoSoles: valorRiesgoSoles,
                    color: const Color(0xFFD97706),
                    icon: LucideIcons.rotateCw,
                    isSelected: _filtroSemaforo == 'ATENCION',
                    onTap: () {
                      setState(() {
                        _filtroSemaforo = _filtroSemaforo == 'ATENCION'
                            ? 'TODOS'
                            : 'ATENCION';
                      });
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: _buildKpiCard(
                    titulo: 'Vigentes (> 30d)',
                    cantidad: vigentes.length,
                    montoSoles: null,
                    color: AppTheme.accentGreen,
                    icon: LucideIcons.shieldCheck,
                    isSelected: _filtroSemaforo == 'VIGENTES',
                    onTap: () {
                      setState(() {
                        _filtroSemaforo = _filtroSemaforo == 'VIGENTES'
                            ? 'TODOS'
                            : 'VIGENTES';
                      });
                    },
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.brandPrimary.withValues(
              alpha: isDark ? 0.14 : 0.08,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.brandPrimary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.arrowDownUp,
                size: 14,
                color: AppTheme.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Criterio FIFO Activo: Los productos más próximos a vencer aparecen primero para priorizar su rotación al frente de góndola.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
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
                    color: isDark
                        ? AppTheme.cardDarkSunken
                        : const Color(0xFFF1F5F9),
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
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppTheme.getAdaptiveHintText(isDark),
                      ),
                      prefixIcon: const Icon(
                        LucideIcons.search,
                        size: 16,
                        color: AppTheme.brandPrimary,
                      ),
                      suffixIcon: _filtroTexto.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 14),
                              onPressed: () {
                                _searchCtrl.clear();
                                _searchDebouncer.cancel();
                                setState(() => _filtroTexto = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
              ),
              const SizedBox(width: 8),
              if (_filtroSemaforo != 'TODOS')
                ActionChip(
                  avatar: const Icon(LucideIcons.x, size: 14),
                  label: Text(
                    _filtroSemaforo,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => setState(() => _filtroSemaforo = 'TODOS'),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // 3. Lista de Productos con Semáforo
        Expanded(
          child: filtrados.isEmpty
              ? _buildEmptyState(isDark: isDark, borderColor: borderColor)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = filtrados[index];
                    return _buildProductoVencimientoCard(
                      p,
                      isDark,
                      cardBg,
                      borderColor,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // VISTA DESKTOP (≥ 900px): COCKPIT FEFO DE ALTA DENSIDAD EN 2 COLUMNAS
  // ---------------------------------------------------------------------------
  Widget _buildVencimientosDesktop({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required List<Producto> vencidos,
    required List<Producto> criticos,
    required List<Producto> enRiesgo,
    required List<Producto> vigentes,
    required double valorVencidoSoles,
    required double valorCriticoSoles,
    required double valorRiesgoSoles,
    required List<Producto> filtrados,
  }) {
    // Sincronizar selección actual
    final seleccionado =
        _productoSeleccionado ??
        (filtrados.isNotEmpty ? filtrados.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Rejilla Superior de 4 KPIs Semáforo FEFO de Ancho Completo
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  titulo: 'Vencidos (≤ 0d)',
                  cantidad: vencidos.length,
                  montoSoles: valorVencidoSoles,
                  color: const Color(0xFFDC2626),
                  icon: LucideIcons.alertOctagon,
                  isSelected: _filtroSemaforo == 'VENCIDOS',
                  onTap: () {
                    setState(() {
                      _filtroSemaforo = _filtroSemaforo == 'VENCIDOS'
                          ? 'TODOS'
                          : 'VENCIDOS';
                    });
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  titulo: 'Críticos (1-7d)',
                  cantidad: criticos.length,
                  montoSoles: valorCriticoSoles,
                  color: const Color(0xFFEA580C),
                  icon: LucideIcons.zap,
                  isSelected: _filtroSemaforo == 'CRITICOS',
                  onTap: () {
                    setState(() {
                      _filtroSemaforo = _filtroSemaforo == 'CRITICOS'
                          ? 'TODOS'
                          : 'CRITICOS';
                    });
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  titulo: 'Rotación (8-30d)',
                  cantidad: enRiesgo.length,
                  montoSoles: valorRiesgoSoles,
                  color: const Color(0xFFD97706),
                  icon: LucideIcons.rotateCw,
                  isSelected: _filtroSemaforo == 'ATENCION',
                  onTap: () {
                    setState(() {
                      _filtroSemaforo = _filtroSemaforo == 'ATENCION'
                          ? 'TODOS'
                          : 'ATENCION';
                    });
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  titulo: 'Vigentes (> 30d)',
                  cantidad: vigentes.length,
                  montoSoles: null,
                  color: AppTheme.accentGreen,
                  icon: LucideIcons.shieldCheck,
                  isSelected: _filtroSemaforo == 'VIGENTES',
                  onTap: () {
                    setState(() {
                      _filtroSemaforo = _filtroSemaforo == 'VIGENTES'
                          ? 'TODOS'
                          : 'VIGENTES';
                    });
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),

        // 2. Cockpit Dividido en 2 Columnas Sincronizadas
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna Izquierda (Flex 7): Tabla Contable FEFO
                Expanded(
                  flex: 7,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Barra Superior de Controles y Buscador
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.cardDarkSunken
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: TextField(
                                    controller: _searchCtrl,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Buscar lote por producto, código o código de barras...',
                                      hintStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppTheme.getAdaptiveHintText(
                                          isDark,
                                        ),
                                      ),
                                      prefixIcon: const Icon(
                                        LucideIcons.search,
                                        size: 16,
                                        color: AppTheme.brandPrimary,
                                      ),
                                      suffixIcon: _filtroTexto.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                LucideIcons.x,
                                                size: 14,
                                              ),
                                              onPressed: () {
                                                _searchCtrl.clear();
                                                _searchDebouncer.cancel();
                                                setState(
                                                  () => _filtroTexto = '',
                                                );
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                    ),
                                    onChanged: (val) =>
                                        _searchDebouncer.run(() {
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
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Escanear con Cámara / Lector',
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.brandPrimary
                                      .withValues(alpha: isDark ? 0.2 : 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: AppTheme.brandPrimary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  LucideIcons.scanBarcode,
                                  size: 18,
                                  color: AppTheme.brandPrimary,
                                ),
                                onPressed: _escanearCodigo,
                              ),
                              if (_filtroSemaforo != 'TODOS') ...[
                                const SizedBox(width: 8),
                                ActionChip(
                                  avatar: const Icon(LucideIcons.x, size: 14),
                                  label: Text(
                                    _filtroSemaforo,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () =>
                                      setState(() => _filtroSemaforo = 'TODOS'),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Encabezados de la Tabla Contable
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.cardDarkSunken
                                : const Color(0xFFF8FAFC),
                            border: Border(
                              top: BorderSide(color: borderColor),
                              bottom: BorderSide(color: borderColor),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 135,
                                child: Text(
                                  'ESTADO FEFO',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'PRODUCTO & CATEGORÍA',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'VENCIMIENTO / LOTE',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'STOCK & VALOR',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 28),
                            ],
                          ),
                        ),

                        // Cuerpo de la Tabla
                        Expanded(
                          child: filtrados.isEmpty
                              ? _buildEmptyState(
                                  isDark: isDark,
                                  borderColor: borderColor,
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: filtrados.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, idx) {
                                    final p = filtrados[idx];
                                    final isSelected =
                                        seleccionado?.idProducto != null &&
                                            p.idProducto ==
                                                seleccionado?.idProducto ||
                                        p.codigo == seleccionado?.codigo;

                                    return _buildDesktopRow(
                                      p: p,
                                      isSelected: isSelected,
                                      isDark: isDark,
                                      borderColor: borderColor,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Columna Derecha (Flex 5): Inspector Lateral & Acciones de Merma / Remate
                Expanded(
                  flex: 5,
                  child: _buildDesktopRightInspector(
                    p: seleccionado,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FILA DE TABLA CONTABLE (DESKTOP)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopRow({
    required Producto p,
    required bool isSelected,
    required bool isDark,
    required Color borderColor,
  }) {
    final dias = p.diasParaVencer ?? 999;
    final semaforo = p.semaforoVencimiento;

    Color badgeColor;
    String badgeTexto;
    IconData badgeIcon;

    if (semaforo == SemaforoVencimiento.critico) {
      badgeColor = const Color(0xFFEF4444);
      badgeIcon = LucideIcons.alertOctagon;
      badgeTexto = dias < 0
          ? 'VENCIDO (-${-dias}d)'
          : (dias == 0 ? '¡HOY!' : 'EN $dias DÍAS');
    } else if (semaforo == SemaforoVencimiento.atencion) {
      badgeColor = const Color(0xFFF59E0B);
      badgeIcon = LucideIcons.alertTriangle;
      badgeTexto = 'EN $dias DÍAS';
    } else if (semaforo == SemaforoVencimiento.vigente) {
      badgeColor = AppTheme.accentGreen;
      badgeIcon = LucideIcons.checkCircle;
      badgeTexto = 'VIGENTE ($dias d)';
    } else {
      badgeColor = const Color(0xFF3B82F6);
      badgeIcon = LucideIcons.calendar;
      badgeTexto = '$dias DÍAS';
    }

    final fechaStr = p.fechaVencimiento != null
        ? '${p.fechaVencimiento!.day.toString().padLeft(2, '0')}/${p.fechaVencimiento!.month.toString().padLeft(2, '0')}/${p.fechaVencimiento!.year}'
        : 'Sin fecha';

    return InkWell(
      onTap: () {
        setState(() => _productoSeleccionado = p);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.brandPrimary.withValues(alpha: isDark ? 0.20 : 0.08)
              : (isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.brandPrimary : borderColor,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Badge Estado FEFO
            SizedBox(
              width: 135,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 12, color: badgeColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          badgeTexto,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
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
            ),
            const SizedBox(width: 8),

            // Producto & Categoría
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  ProductImageWidget(
                    imagenUrl: p.imagenUrl,
                    categoria: p.nombreCategoria,
                    size: 38,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nombre,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.nombreCategoria ?? 'General'} • Cod: ${p.codigo}',
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
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Fecha Vencimiento / Lote
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 13,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      fechaStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Stock & Valor
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.stockActual.toStringAsFixed(0)} un.',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'S/ ${(p.stockActual * p.precioVenta).toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Flecha / indicador de selección
            Icon(
              isSelected ? LucideIcons.checkCircle2 : LucideIcons.chevronRight,
              size: 16,
              color: isSelected
                  ? AppTheme.brandPrimary
                  : (isDark ? Colors.white30 : Colors.black26),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INSPECTOR LATERAL DERECHO (DESKTOP)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopRightInspector({
    required Producto? p,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    if (p == null) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.calendarClock,
                size: 48,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              const SizedBox(height: 12),
              Text(
                'Selecciona un lote del inventario',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Podrás inspeccionar el análisis financiero de caducidad, simular precios de remate preventivo o dar de baja por merma.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dias = p.diasParaVencer ?? 999;
    final semaforo = p.semaforoVencimiento;

    Color badgeColor;
    String badgeTitulo;
    String recomendacion;
    IconData badgeIcon;

    if (semaforo == SemaforoVencimiento.critico) {
      badgeColor = const Color(0xFFEF4444);
      badgeIcon = LucideIcons.alertOctagon;
      badgeTitulo = dias < 0
          ? 'LOTE VENCIDO HACE ${-dias} DÍAS'
          : (dias == 0
                ? '¡EL LOTE VENCE HOY!'
                : '¡CRÍTICO! VENCE EN $dias DÍAS');
      recomendacion = dias <= 0
          ? 'MERCADERÍA VENCIDA: Retirar inmediatamente de góndola para evitar multas de fiscalización y registrar la merma en el sistema.'
          : 'RIESGO ELEVADO: Aplica un remate preventivo (-25%) hoy mismo o coordina devolución con el proveedor antes del vencimiento.';
    } else if (semaforo == SemaforoVencimiento.atencion) {
      badgeColor = const Color(0xFFF59E0B);
      badgeIcon = LucideIcons.alertTriangle;
      badgeTitulo = 'ROTACIÓN PREVENTIVA ($dias DÍAS)';
      recomendacion = 'CRITERIO FEFO: Ubicar al frente del anaquel y de las cajas para acelerar su salida antes de los lotes más nuevos.';
    } else if (semaforo == SemaforoVencimiento.vigente) {
      badgeColor = AppTheme.accentGreen;
      badgeIcon = LucideIcons.checkCircle;
      badgeTitulo = 'LOTE VIGENTE Y SALUDABLE ($dias DÍAS)';
      recomendacion = 'Vigencia óptima. Mantener almacenamiento en condiciones adecuadas y continuar control regular de lotes.';
    } else {
      badgeColor = const Color(0xFF3B82F6);
      badgeIcon = LucideIcons.calendar;
      badgeTitulo = 'CONTROL REGULAR ($dias DÍAS)';
      recomendacion = 'Rotación estándar según flujo habitual de clientes.';
    }

    final fechaStr = p.fechaVencimiento != null
        ? '${p.fechaVencimiento!.day.toString().padLeft(2, '0')}/${p.fechaVencimiento!.month.toString().padLeft(2, '0')}/${p.fechaVencimiento!.year}'
        : 'Sin fecha';

    final capitalRiesgo = p.stockActual * p.precioVenta;
    final costoEstimado = p.precioCosto != null
        ? 'S/ ${p.precioCosto!.toStringAsFixed(2)}'
        : 'S/ ${(p.precioVenta * 0.70).toStringAsFixed(2)} (est.)';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Packshot Grande, Título, Código y Categoría
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductImageWidget(
                  imagenUrl: p.imagenUrl,
                  categoria: p.nombreCategoria,
                  size: 68,
                  borderRadius: 14,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (p.nombreCategoria ?? 'General').toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.nombre,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textDark,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cod: ${p.codigo} ${p.codigoBarras != null ? '• Barras: ${p.codigoBarras}' : ''}',
                        style: GoogleFonts.jetBrainsMono(
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
              ],
            ),

            const SizedBox(height: 14),

            // Card de Estado FEFO & Cuenta Regresiva
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: isDark ? 0.16 : 0.09),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(badgeIcon, size: 16, color: badgeColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          badgeTitulo,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white70,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Lote: $fechaStr',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recomendacion,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      height: 1.4,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Rejilla de Métricas Financieras (4 Cajas)
            Text(
              'EXPEDIENTE FINANCIERO DEL LOTE',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildFinancialTile(
                    label: 'Stock Físico',
                    value: '${p.stockActual.toStringAsFixed(0)} un.',
                    color: isDark ? Colors.white : AppTheme.textDark,
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFinancialTile(
                    label: 'Precio Regular',
                    value: 'S/ ${p.precioVenta.toStringAsFixed(2)}',
                    color: AppTheme.brandPrimary,
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildFinancialTile(
                    label: 'Costo Mayorista',
                    value: costoEstimado,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFinancialTile(
                    label: 'Capital en Riesgo',
                    value: 'S/ ${capitalRiesgo.toStringAsFixed(2)}',
                    color: dias <= 7
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFD97706),
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Acciones Operativas y Protocolo FEFO
            Text(
              'ACCIONES DE GESTIÓN & LIQUIDACIÓN',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),

            // 1. Botón Actualizar Lote / Fecha
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  foregroundColor: AppTheme.brandPrimary,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.calendarClock, size: 16),
                label: Text(
                  'Actualizar Fecha de Lote',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => _actualizarFechaVencimiento(p),
              ),
            ),
            const SizedBox(height: 8),

            // 2. Botón Remate Preventivo (-25%)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.tag, size: 16),
                label: Text(
                  'Calcular Remate Preventivo (-25%)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () => _mostrarDialogoRemate(p),
              ),
            ),
            const SizedBox(height: 8),

            // 3. Botón Dar de Baja por Caducidad / Merma
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: Text(
                  'Dar de Baja (Ajuste de Merma)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () {
                  AjusteStockSheet.show(context, p, _cargarProductos);
                },
              ),
            ),
            const SizedBox(height: 8),

            // 4. Botón Imprimir Rótulo de Oferta
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  foregroundColor: isDark
                      ? Colors.white70
                      : const Color(0xFF475569),
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.printer, size: 15),
                label: Text(
                  'Imprimir Rótulo de Góndola',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => _imprimirRotuloOferta(p),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper para cajita financiera en Inspector Desktop
  Widget _buildFinancialTile({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KPI CARD (USADO TANTO EN MÓVIL COMO EN DESKTOP)
  // ---------------------------------------------------------------------------
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
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : color.withValues(alpha: isDark ? 0.10 : 0.06),
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
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (montoSoles != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'S/ ${montoSoles.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CARD INDIVIDUAL PARA MÓVIL
  // ---------------------------------------------------------------------------
  Widget _buildProductoVencimientoCard(
    Producto p,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    final dias = p.diasParaVencer ?? 999;
    final semaforo = p.semaforoVencimiento;

    Color badgeColor;
    String badgeTexto;
    IconData badgeIcon;

    if (semaforo == SemaforoVencimiento.critico) {
      badgeColor = const Color(0xFFEF4444);
      badgeIcon = LucideIcons.alertOctagon;
      badgeTexto = dias < 0
          ? 'VENCIDO (-${-dias}d)'
          : (dias == 0 ? '¡VENCE HOY!' : '¡EN $dias DÍAS!');
    } else if (semaforo == SemaforoVencimiento.atencion) {
      badgeColor = const Color(0xFFF59E0B);
      badgeIcon = LucideIcons.alertTriangle;
      badgeTexto = 'EN $dias DÍAS (OFERTA)';
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 12, color: badgeColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          badgeTexto,
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
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 12,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    fechaStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textDark,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          'Stock: ${p.stockActual.toStringAsFixed(0)} un.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Text(
                          '•  Valor: S/ ${(p.stockActual * p.precioVenta).toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF334155),
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
                    side: BorderSide(
                      color: isDark
                          ? AppTheme.borderDark
                          : AppTheme.borderLight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(LucideIcons.calendarClock, size: 14),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Actualizar Lote',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(LucideIcons.trash2, size: 14),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Dar de Baja',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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

  // ---------------------------------------------------------------------------
  // ESTADO VACÍO (USADO EN AMBAS VISTAS)
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState({required bool isDark, required Color borderColor}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGreen.withValues(
                  alpha: isDark ? 0.2 : 0.1,
                ),
                border: Border.all(
                  color: AppTheme.accentGreen.withValues(
                    alpha: isDark ? 0.4 : 0.25,
                  ),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.shieldCheck,
                  size: 30,
                  color: AppTheme.accentGreen,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _filtroSemaforo == 'CRITICO'
                  ? '¡Excelente! Cero productos críticos'
                  : (_filtroSemaforo == 'ATENCION'
                        ? 'Sin productos por vencer en 15 a 30 días'
                        : (_filtroTexto.isNotEmpty
                              ? 'Sin coincidencias para "$_filtroTexto"'
                              : '¡Sin alertas de caducidad!')),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _filtroSemaforo == 'CRITICO'
                  ? 'No tienes mercadería con vencimiento menor a 7 días. Todo tu inventario perecible está protegido.'
                  : 'Todos los productos evaluados en esta categoría cuentan con fecha de vigencia saludable.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                height: 1.45,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.cardDarkSunken
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.lightbulb,
                    size: 15,
                    color: isDark
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estrategia FEFO: Colocar los lotes con fecha más próxima al frente de la góndola minimiza mermas en lácteos, embutidos y panadería.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        height: 1.4,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_filtroSemaforo != 'TODOS' || _filtroTexto.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: borderColor),
                ),
                icon: const Icon(LucideIcons.rotateCcw, size: 14),
                label: Text(
                  'Ver Todo el Semáforo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _searchDebouncer.cancel();
                    _filtroSemaforo = 'TODOS';
                    _filtroTexto = '';
                    _searchCtrl.clear();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on DateTime {
  DateTime plusDays(int days) => add(Duration(days: days));
}
