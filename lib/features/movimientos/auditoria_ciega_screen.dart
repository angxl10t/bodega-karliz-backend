import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../../core/karliz_sound_service.dart';
import '../../core/csv_exporter.dart';
import '../productos/producto_service.dart';
import 'auditoria_ciega_model.dart';
import 'movimiento_service.dart';

class AuditoriaCiegaScreen extends StatefulWidget {
  const AuditoriaCiegaScreen({super.key});

  @override
  State<AuditoriaCiegaScreen> createState() => _AuditoriaCiegaScreenState();
}

class _AuditoriaCiegaScreenState extends State<AuditoriaCiegaScreen> {
  final ProductoService _productoService = ProductoService();
  final MovimientoService _movimientoService = MovimientoService();
  final TextEditingController _searchCtrl = TextEditingController();

  AuditoriaSesion? _sesion;
  bool _isLoading = true;
  bool _modoConciliacionRevelado = false;
  bool _isAplicandoAjuste = false;
  String _filtroTexto = '';
  String _filtroDiscrepancia = 'TODOS'; // 'TODOS', 'FALTANTES', 'SOBRANTES', 'EXACTOS'

  @override
  void initState() {
    super.initState();
    _iniciarSesionAuditoria();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesionAuditoria() async {
    setState(() => _isLoading = true);
    final prods = await _productoService.getProductos();

    final items = prods.map((p) {
      return AuditoriaItem(
        idProducto: p.idProducto ?? 0,
        nombreProducto: p.nombre,
        codigoBarras: p.codigoBarras,
        codigo: p.codigo,
        categoria: p.nombreCategoria,
        precioVenta: p.precioVenta,
        precioCosto: p.costoUnitarioEstimado,
        imagenUrl: p.imagenUrl,
        stockSistema: p.stockActual,
        conteoFisico: 0.0,
      );
    }).toList();

    if (mounted) {
      setState(() {
        _sesion = AuditoriaSesion(
          idAuditoria: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          titulo: 'Auditoría Ciega de Góndola',
          fechaInicio: DateTime.now(),
          usuarioResponsable: 'ADMIN',
          items: items,
        );
        _isLoading = false;
      });
    }
  }

  void _incrementarConteo(AuditoriaItem item, double delta) {
    setState(() {
      item.conteoFisico = (item.conteoFisico + delta).clamp(0.0, 99999.0);
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _escanearCodigo() async {
    final codigo = await KarlizBarcodeScannerModal.scan(context);
    if (codigo != null && codigo.isNotEmpty) {
      if (_sesion == null) return;
      final match = _sesion!.items.firstWhere(
        (it) => it.codigo == codigo || it.codigoBarras == codigo,
        orElse: () => AuditoriaItem(
          idProducto: 0,
          nombreProducto: '',
          codigo: '',
          precioVenta: 0,
          precioCosto: 0,
          stockSistema: 0,
        ),
      );

      if (match.idProducto > 0) {
        _incrementarConteo(match, 1.0);
        await KarlizSoundService.instance.playBarcodeBeep();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('+1 en "${match.nombreProducto}" (Total: ${match.conteoFisico.toStringAsFixed(0)})'),
              duration: const Duration(milliseconds: 1400),
              backgroundColor: AppTheme.brandPrimary,
            ),
          );
        }
      } else {
        await KarlizSoundService.instance.playErrorBeep();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Código "$codigo" no coincide con ningún producto en catálogo.'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  void _finalizarConteoYRevelar() {
    if (_sesion == null) return;

    final totalContados = _sesion!.totalItemsAuditados;
    if (totalContados == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no has registrado ningún conteo de unidades físicas.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Cerrar Toma de Inventario?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text(
          'Se compararán las $totalContados unidades contadas físicamente contra el stock teórico del sistema y se revelará el balance de sobrantes y faltantes.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continuar Contando')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _modoConciliacionRevelado = true;
                _sesion!.fechaCierre = DateTime.now();
                _sesion!.estado = 'FINALIZADA';
              });
              HapticFeedback.heavyImpact();
            },
            child: const Text('Ver Discrepancias'),
          ),
        ],
      ),
    );
  }

  Future<void> _aplicarRegularizacionAlSistema() async {
    if (_sesion == null) return;

    final discrepantes = _sesion!.items.where((it) => !it.esCuadreExacto && it.conteoFisico > 0).toList();
    if (discrepantes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay discrepancias que regularizar. El inventario está exactamente cuadrado.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Regularizar Stock del Sistema?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text(
          'Se ajustará el stock del sistema en ${discrepantes.length} productos para que coincida exactamente con el conteo físico, registrando los movimientos en el Kardex.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aplicar Ajustes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isAplicandoAjuste = true);

    int exitosos = 0;
    for (final it in discrepantes) {
      final diff = it.diferencia;
      final tipo = diff > 0 ? 'SOBRANTE' : 'MERMA';
      final ok = await _movimientoService.registrarAjuste(
        idProducto: it.idProducto,
        cantidad: diff.abs(),
        tipoAjuste: tipo,
        motivo: '[AUDITORÍA CIEGA] Ajuste a conteo físico: ${it.stockSistema.toStringAsFixed(0)} -> ${it.conteoFisico.toStringAsFixed(0)}',
      );
      if (ok) exitosos++;
    }

    if (mounted) {
      setState(() {
        _isAplicandoAjuste = false;
        _sesion!.estado = 'REGULARIZADA';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Stock del sistema regularizado con éxito ($exitosos/${discrepantes.length} productos actualizados)!'),
          backgroundColor: AppTheme.accentGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _exportarCsv() async {
    if (_sesion == null) return;
    final buffer = StringBuffer();
    buffer.writeln('Producto,Codigo,Categoria,StockSistema,ConteoFisico,Diferencia,Estado,PrecioVenta,DiscrepanciaValorizadaSoles');

    for (final it in _sesion!.items.where((it) => it.conteoFisico > 0)) {
      final estado = it.esCuadreExacto ? 'CUADRE_EXACTO' : (it.esFaltante ? 'FALTANTE' : 'SOBRANTE');
      buffer.writeln(
          '"${it.nombreProducto.replaceAll('"', '""')}",${it.codigo},"${it.categoria ?? ''}",${it.stockSistema},${it.conteoFisico},${it.diferencia},$estado,${it.precioVenta.toStringAsFixed(2)},${it.valorDiscrepancia.toStringAsFixed(2)}');
    }

    await CsvExporter.descargarOCompartirCsv(
      nombreArchivo: 'auditoria_ciega_${DateTime.now().millisecondsSinceEpoch}.csv',
      contenidoCsv: buffer.toString(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Reporte de auditoría exportado a CSV con éxito!'),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    if (_isLoading || _sesion == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary)),
      );
    }

    final filtrados = _sesion!.items.where((it) {
      final matchesText = it.nombreProducto.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          it.codigo.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          (it.codigoBarras ?? '').contains(_filtroTexto);

      if (!_modoConciliacionRevelado) return matchesText;

      bool matchesDisc = true;
      if (_filtroDiscrepancia == 'FALTANTES') {
        matchesDisc = it.esFaltante;
      } else if (_filtroDiscrepancia == 'SOBRANTES') {
        matchesDisc = it.esSobrante;
      } else if (_filtroDiscrepancia == 'EXACTOS') {
        matchesDisc = it.esCuadreExacto && it.conteoFisico > 0;
      }

      return matchesText && matchesDisc;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _modoConciliacionRevelado ? 'Conciliación de Inventario' : 'Toma de Inventario Físico',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            Text(
              _modoConciliacionRevelado ? 'Reporte de Faltantes y Sobrantes' : 'Modo Ciego • Stock del sistema oculto',
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
            ),
          ],
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
            tooltip: 'Escanear Código de Barras (+1)',
            icon: const Icon(LucideIcons.scanBarcode, color: AppTheme.brandPrimary),
            onPressed: _escanearCodigo,
          ),
          if (_modoConciliacionRevelado) ...[
            IconButton(
              tooltip: 'Exportar a CSV',
              icon: const Icon(LucideIcons.download, color: AppTheme.accentGreen, size: 20),
              onPressed: _exportarCsv,
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          child: _modoConciliacionRevelado
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.brandPrimary,
                          side: const BorderSide(color: AppTheme.brandPrimary, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => setState(() => _modoConciliacionRevelado = false),
                        child: const Text('Volver al Conteo'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _isAplicandoAjuste
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.checkCheck, size: 18),
                        label: Text(
                          _isAplicandoAjuste ? 'Ajustando...' : 'Regularizar Stock',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        onPressed: _isAplicandoAjuste ? null : _aplicarRegularizacionAlSistema,
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(LucideIcons.eye, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'FINALIZAR Y VER DISCREPANCIAS (${_sesion!.totalItemsAuditados} CONTADOS)',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                    onPressed: _finalizarConteoYRevelar,
                  ),
                ),
        ),
      ),
      body: Column(
        children: [
          // Banner Superior
          if (!_modoConciliacionRevelado)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.15 : 0.08),
              child: Row(
                children: [
                  const Icon(LucideIcons.eyeOff, color: Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modo Ciego Activo: Cuenta las unidades reales en góndola. El stock teórico se revelará al finalizar.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF3B82F6)),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Métricas de Conciliación
            Container(
              padding: const EdgeInsets.all(16),
              color: cardBg,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          'Cuadre Exacto',
                          '${_sesion!.totalCuadreExacto}',
                          'Sin diferencia',
                          AppTheme.accentGreen,
                          LucideIcons.checkCircle2,
                          isDark,
                          isSelected: _filtroDiscrepancia == 'EXACTOS',
                          onTap: () {
                            setState(() {
                              _filtroDiscrepancia = _filtroDiscrepancia == 'EXACTOS' ? 'TODOS' : 'EXACTOS';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(
                          'Faltantes (-)',
                          '${_sesion!.totalFaltantes}',
                          '-S/ ${_sesion!.valorPerdidaFaltantes.toStringAsFixed(2)}',
                          const Color(0xFFEF4444),
                          LucideIcons.alertOctagon,
                          isDark,
                          isSelected: _filtroDiscrepancia == 'FALTANTES',
                          onTap: () {
                            setState(() {
                              _filtroDiscrepancia = _filtroDiscrepancia == 'FALTANTES' ? 'TODOS' : 'FALTANTES';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(
                          'Sobrantes (+)',
                          '${_sesion!.totalSobrantes}',
                          '+S/ ${_sesion!.valorExcedenteSobrantes.toStringAsFixed(2)}',
                          const Color(0xFF3B82F6),
                          LucideIcons.packagePlus,
                          isDark,
                          isSelected: _filtroDiscrepancia == 'SOBRANTES',
                          onTap: () {
                            setState(() {
                              _filtroDiscrepancia = _filtroDiscrepancia == 'SOBRANTES' ? 'TODOS' : 'SOBRANTES';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Buscador
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            color: cardBg,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? Colors.white : AppTheme.textDark),
                      decoration: InputDecoration(
                        hintText: 'Buscar en catálogo para contar...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
              ],
            ),
          ),

          const Divider(height: 1),

          // Lista de ítems
          Expanded(
            child: filtrados.isEmpty
                ? Center(
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
                              color: (_modoConciliacionRevelado ? const Color(0xFF0284C7) : AppTheme.brandPrimary)
                                  .withValues(alpha: isDark ? 0.2 : 0.1),
                              border: Border.all(
                                color: (_modoConciliacionRevelado ? const Color(0xFF0284C7) : AppTheme.brandPrimary)
                                    .withValues(alpha: isDark ? 0.4 : 0.25),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                _modoConciliacionRevelado ? LucideIcons.fileCheck2 : LucideIcons.scanLine,
                                size: 28,
                                color: _modoConciliacionRevelado ? const Color(0xFF0284C7) : AppTheme.brandPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _modoConciliacionRevelado
                                ? (_filtroDiscrepancia == 'FALTANTES'
                                    ? '¡Excelente! Sin productos faltantes'
                                    : (_filtroDiscrepancia == 'SOBRANTES'
                                        ? 'Sin productos sobrantes'
                                        : 'Sin discrepancias en este filtro'))
                                : (_filtroTexto.isNotEmpty
                                    ? 'Sin coincidencias para "$_filtroTexto"'
                                    : 'Inicia el Conteo Físico en Góndola'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _modoConciliacionRevelado
                                ? 'El conteo físico de los colaboradores coincide exactamente con el inventario esperado del sistema.'
                                : 'Escanea el código de barras o busca productos por nombre para anotar las unidades reales contadas.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              height: 1.45,
                              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF101622) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🛡️', style: TextStyle(fontSize: 15)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Auditoría Ciega: Al ocultar el stock del sistema, se previene que el personal invente conteos, detectando fugas de mercadería y robos hormiga.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      height: 1.4,
                                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_filtroDiscrepancia != 'TODOS' || _filtroTexto.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: borderColor),
                              ),
                              icon: const Icon(LucideIcons.rotateCcw, size: 14),
                              label: Text(
                                'Ver Todos los Ítems',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              onPressed: () {
                                setState(() {
                                  _filtroDiscrepancia = 'TODOS';
                                  _filtroTexto = '';
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtrados.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final it = filtrados[index];
                return _buildAuditoriaItemCard(it, isDark, cardBg, borderColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String count,
    String sub,
    Color color,
    IconData icon,
    bool isDark, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isSelected ? 0.25 : (isDark ? 0.15 : 0.08)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: isSelected ? 0.9 : 0.3),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: color),
                  const Spacer(),
                  Text(
                    count,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textDark)),
              Text(sub, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuditoriaItemCard(AuditoriaItem it, bool isDark, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _modoConciliacionRevelado
              ? (it.esCuadreExacto
                  ? AppTheme.accentGreen.withValues(alpha: 0.4)
                  : (it.esFaltante ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFF3B82F6).withValues(alpha: 0.4)))
              : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImageWidget(
                imagenUrl: it.imagenUrl,
                categoria: it.categoria,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.nombreProducto,
                      style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${it.codigo}  •  S/ ${it.precioVenta.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Si estamos en conciliación revelada, mostrar la comparación
          if (_modoConciliacionRevelado) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sistema:', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                      Text('${it.stockSistema.toStringAsFixed(0)} un.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Físico Contado:', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155))),
                      Text('${it.conteoFisico.toStringAsFixed(0)} un.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            it.esCuadreExacto ? 'CUADRADO' : (it.esFaltante ? 'FALTANTE (-${it.diferencia.abs().toStringAsFixed(0)})' : 'SOBRANTE (+${it.diferencia.toStringAsFixed(0)})'),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: it.esCuadreExacto
                                  ? AppTheme.accentGreen
                                  : (it.esFaltante ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${it.valorDiscrepancia >= 0 ? "+" : ""}S/ ${it.valorDiscrepancia.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: it.esCuadreExacto
                                  ? AppTheme.accentGreen
                                  : (it.esFaltante ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Controles de conteo físico en modo ciego
            Row(
              children: [
                Text(
                  'Conteo Físico:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textDark),
                ),
                const Spacer(),
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.minus, size: 14),
                  onPressed: it.conteoFisico > 0 ? () => _incrementarConteo(it, -1.0) : null,
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 42),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Center(
                    child: Text(
                      it.conteoFisico.toStringAsFixed(0),
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.brandPrimary),
                    ),
                  ),
                ),
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.plus, size: 14),
                  onPressed: () => _incrementarConteo(it, 1.0),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('+5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _incrementarConteo(it, 5.0),
                ),
                const SizedBox(width: 4),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('+10', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _incrementarConteo(it, 10.0),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
