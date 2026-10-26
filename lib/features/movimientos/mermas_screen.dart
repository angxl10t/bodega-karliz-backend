import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../../core/csv_exporter.dart';
import '../productos/producto_model.dart';
import '../productos/producto_service.dart';
import 'merma_model.dart';
import 'mermas_service.dart';

class MermasScreen extends StatefulWidget {
  const MermasScreen({super.key});

  @override
  State<MermasScreen> createState() => _MermasScreenState();
}

class _MermasScreenState extends State<MermasScreen> {
  final MermasService _mermasService = MermasService();
  final ProductoService _productoService = ProductoService();

  List<MermaRegistro> _mermas = [];
  Map<String, dynamic> _kpis = {};
  bool _isLoading = true;
  String _filtroMotivo = 'TODOS';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    MermasService.mermasRevision.addListener(_onRevisionChanged);
  }

  @override
  void dispose() {
    MermasService.mermasRevision.removeListener(_onRevisionChanged);
    super.dispose();
  }

  void _onRevisionChanged() {
    if (mounted) _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final lista = await _mermasService.obtenerMermas();
    final kpis = await _mermasService.calcularKpisMes();
    if (mounted) {
      setState(() {
        _mermas = lista;
        _kpis = kpis;
        _isLoading = false;
      });
    }
  }

  void _mostrarRegistrarMermaModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RegistrarMermaSheet(
        productoService: _productoService,
        mermasService: _mermasService,
        onMermaRegistrada: _cargarDatos,
      ),
    );
  }

  Future<void> _exportarCsv() async {
    if (_mermas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros de merma para exportar.')),
      );
      return;
    }
    await CsvExporter.descargarOCompartirCsv(
      nombreArchivo: 'cajaya_mermas_${DateTime.now().millisecondsSinceEpoch}.csv',
      contenidoCsv: _generarCsvMermas(_mermas),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Reporte de mermas y pérdidas exportado a CSV con éxito!'),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }

  String _generarCsvMermas(List<MermaRegistro> lista) {
    final buffer = StringBuffer();
    buffer.writeln('IDMerma,Fecha,Producto,Motivo,Cantidad,CostoUnitario,PerdidaTotalSoles,Usuario,Observaciones');
    for (final m in lista) {
      final f = '${m.fecha.day}/${m.fecha.month}/${m.fecha.year} ${m.fecha.hour}:${m.fecha.minute}';
      buffer.writeln(
          '${m.idMerma},"$f","${m.nombreProducto.replaceAll('"', '""')}","${m.motivoLegible}",${m.cantidad},${m.costoUnitario.toStringAsFixed(2)},${m.costoTotal.toStringAsFixed(2)},"${m.usuarioResponsable}","${m.observaciones.replaceAll('"', '""')}"');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    final double totalPerdida = (_kpis['totalPerdidaSoles'] as num?)?.toDouble() ?? 0.0;
    final double totalUnidades = (_kpis['totalUnidades'] as num?)?.toDouble() ?? 0.0;
    final String causaPrincipal = _kpis['causaPrincipal']?.toString() ?? 'Ninguna';

    final filtradas = _filtroMotivo == 'TODOS'
        ? _mermas
        : _mermas.where((m) => m.motivo.toUpperCase() == _filtroMotivo.toUpperCase()).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Mermas y Desmedros',
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
            tooltip: 'Exportar a CSV',
            icon: const Icon(LucideIcons.download, color: AppTheme.accentGreen, size: 20),
            onPressed: _exportarCsv,
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFEA580C),
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.trash2, size: 18),
        label: Text(
          'Registrar Merma',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        onPressed: _mostrarRegistrarMermaModal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary))
          : Column(
              children: [
                // 1. Panel de Métricas de Pérdida Contable
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  color: cardBg,
                  child: Row(
                    children: [
                      // Pérdida Total Soles
                      Expanded(
                        child: _buildKpiBox(
                          titulo: 'Pérdida del Mes',
                          valor: '-S/ ${totalPerdida.toStringAsFixed(2)}',
                          subtitulo: '${totalUnidades.toStringAsFixed(0)} unidades dadas de baja',
                          color: const Color(0xFFEF4444),
                          icon: LucideIcons.trendingDown,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Causa Principal
                      Expanded(
                        child: _buildKpiBox(
                          titulo: 'Causa Principal',
                          valor: causaPrincipal,
                          subtitulo: 'Mayor frecuencia de baja',
                          color: const Color(0xFFEA580C),
                          icon: LucideIcons.pieChart,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Filtros por Motivo de Baja
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: cardBg,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('TODOS', 'Todas las Bajas', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('ROTURA', 'Roturas', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('VENCIMIENTO', 'Vencidos', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('MERMA', 'Deterioro / Merma', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('CONSUMO_INTERNO', 'Consumo Interno', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('ROBO_DESMEDRO', 'Desmedros', isDark),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // 3. Lista de Mermas Registradas
                Expanded(
                  child: filtradas.isEmpty
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
                                    color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.1),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.4 : 0.25),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(LucideIcons.packageCheck, size: 28, color: Color(0xFFF59E0B)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _filtroMotivo != 'TODOS'
                                      ? 'Sin mermas registradas por $_filtroMotivo'
                                      : 'Cero Pérdidas Registradas',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Registra aquí productos vencidos, rotos o de consumo del personal para reflejar el costo contable exacto sin alterar las ventas.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('📋', style: TextStyle(fontSize: 15)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Deducción Contable: Registrar mermas formalmente te permite justificar faltantes de inventario ante SUNAT como desmedro deducible.',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            height: 1.4,
                                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                if (_filtroMotivo != 'TODOS')
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      side: BorderSide(color: borderColor),
                                    ),
                                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                                    label: Text(
                                      'Ver Todas las Bajas',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _filtroMotivo = 'TODOS';
                                      });
                                    },
                                  )
                                else
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.brandPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(LucideIcons.plus, size: 16),
                                    label: Text(
                                      'Registrar Merma o Baja',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
                                    ),
                                    onPressed: _mostrarRegistrarMermaModal,
                                  ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                          itemCount: filtradas.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final m = filtradas[index];
                            return _buildMermaCard(m, isDark, cardBg, borderColor);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiBox({
    required String titulo,
    required String valor,
    required String subtitulo,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _filtroMotivo == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _filtroMotivo = key);
      },
      selectedColor: const Color(0xFFEA580C).withValues(alpha: 0.2),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? const Color(0xFFEA580C) : (isDark ? Colors.white70 : AppTheme.textDark),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFFEA580C) : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
      ),
    );
  }

  Widget _buildMermaCard(MermaRegistro m, bool isDark, Color cardBg, Color borderColor) {
    Color chipColor;
    IconData chipIcon;

    switch (m.motivo.toUpperCase()) {
      case 'ROTURA':
        chipColor = const Color(0xFFDC2626);
        chipIcon = LucideIcons.packageX;
        break;
      case 'VENCIMIENTO':
        chipColor = const Color(0xFFD97706);
        chipIcon = LucideIcons.calendarClock;
        break;
      case 'CONSUMO_INTERNO':
        chipColor = const Color(0xFF7C3AED);
        chipIcon = LucideIcons.cupSoda;
        break;
      case 'ROBO_DESMEDRO':
        chipColor = const Color(0xFF6B7280);
        chipIcon = LucideIcons.alertTriangle;
        break;
      case 'MERMA':
      default:
        chipColor = const Color(0xFFEA580C);
        chipIcon = LucideIcons.trash2;
        break;
    }

    final fechaStr = '${m.fecha.day.toString().padLeft(2, '0')}/${m.fecha.month.toString().padLeft(2, '0')}/${m.fecha.year} ${m.fecha.hour.toString().padLeft(2, '0')}:${m.fecha.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: chipColor.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, size: 12, color: chipColor),
                    const SizedBox(width: 4),
                    Text(
                      m.motivoLegible,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: chipColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '-S/ ${m.costoTotal.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            m.nombreProducto,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Baja: ${m.cantidad.toStringAsFixed(m.cantidad.truncateToDouble() == m.cantidad ? 0 : 2)} un.  (Costo un.: S/ ${m.costoUnitario.toStringAsFixed(2)})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTheme.textDark,
                ),
              ),
            ],
          ),
          if (m.observaciones.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Obs: ${m.observaciones}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(LucideIcons.user, size: 11, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                m.usuarioResponsable,
                style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppTheme.textMuted),
              ),
              const Spacer(),
              Text(
                fechaStr,
                style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal Sheet para registrar una nueva baja / merma
class _RegistrarMermaSheet extends StatefulWidget {
  final ProductoService productoService;
  final MermasService mermasService;
  final VoidCallback onMermaRegistrada;

  const _RegistrarMermaSheet({
    required this.productoService,
    required this.mermasService,
    required this.onMermaRegistrada,
  });

  @override
  State<_RegistrarMermaSheet> createState() => _RegistrarMermaSheetState();
}

class _RegistrarMermaSheetState extends State<_RegistrarMermaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _costoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  List<Producto> _catalogo = [];
  Producto? _productoSeleccionado;
  String _motivo = 'ROTURA';
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _motivos = [
    {'id': 'ROTURA', 'label': 'Rotura / Envase Roto', 'icon': LucideIcons.packageX, 'color': Color(0xFFDC2626)},
    {'id': 'VENCIMIENTO', 'label': 'Vencido / Caducado', 'icon': LucideIcons.calendarClock, 'color': Color(0xFFD97706)},
    {'id': 'MERMA', 'label': 'Merma / Deterioro', 'icon': LucideIcons.trash2, 'color': Color(0xFFEA580C)},
    {'id': 'CONSUMO_INTERNO', 'label': 'Consumo Interno', 'icon': LucideIcons.cupSoda, 'color': Color(0xFF7C3AED)},
    {'id': 'ROBO_DESMEDRO', 'label': 'Desmedro / Pérdida', 'icon': LucideIcons.alertTriangle, 'color': Color(0xFF6B7280)},
  ];

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _cantidadCtrl.dispose();
    _costoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogo() async {
    final prods = await widget.productoService.getProductos();
    if (mounted) {
      setState(() {
        _catalogo = prods;
        _isLoading = false;
      });
    }
  }

  void _seleccionarProducto(Producto p) {
    setState(() {
      _productoSeleccionado = p;
      _costoCtrl.text = p.costoUnitarioEstimado.toStringAsFixed(2);
    });
  }

  Future<void> _escanearCodigo() async {
    final codigo = await KarlizBarcodeScannerModal.scan(context);
    if (codigo != null && codigo.isNotEmpty) {
      final match = _catalogo.firstWhere(
        (p) => p.codigo == codigo || p.codigoBarras == codigo,
        orElse: () => Producto(codigo: '', nombre: '', precioVenta: 0, stockActual: 0),
      );
      if (match.codigo.isNotEmpty) {
        _seleccionarProducto(match);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se encontró producto con código $codigo')),
          );
        }
      }
    }
  }

  Future<void> _guardarMerma() async {
    if (!_formKey.currentState!.validate() || _productoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un producto válido.')),
      );
      return;
    }

    final cant = double.tryParse(_cantidadCtrl.text.trim()) ?? 0.0;
    final costo = double.tryParse(_costoCtrl.text.trim()) ?? _productoSeleccionado!.costoUnitarioEstimado;

    if (cant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad debe ser mayor a 0.')),
      );
      return;
    }

    if (cant > _productoSeleccionado!.stockActual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock insuficiente. Stock actual: ${_productoSeleccionado!.stockActual.toStringAsFixed(0)} un.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final ok = await widget.mermasService.registrarMerma(
      producto: _productoSeleccionado!,
      cantidad: cant,
      motivo: _motivo,
      costoUnitario: costo,
      observaciones: _obsCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        HapticFeedback.heavyImpact();
        widget.onMermaRegistrada();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Baja por merma registrada exitosamente para "${_productoSeleccionado!.nombre}".'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al registrar la merma en el sistema.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary))
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Barra de agarre
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Cabecera
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.trash2, color: Color(0xFFEA580C), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registrar Baja de Mercadería',
                                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Descuenta del inventario y registra la pérdida contable',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Cuerpo scrolleable
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Selección de Producto
                          Text('1. Producto a dar de baja:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5)),
                          const SizedBox(height: 8),
                          if (_productoSeleccionado == null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'Buscar por nombre o código...',
                                      prefixIcon: const Icon(LucideIcons.search, size: 16),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                    ),
                                    onChanged: (val) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: AppTheme.brandPrimary),
                                  tooltip: 'Escanear Código de Barras',
                                  icon: const Icon(LucideIcons.scanBarcode, size: 18),
                                  onPressed: _escanearCodigo,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Lista de coincidencias
                            SizedBox(
                              height: 140,
                              child: ListView(
                                children: _catalogo
                                    .where((p) =>
                                        p.nombre.toLowerCase().contains(_searchCtrl.text.toLowerCase()) ||
                                        p.codigo.toLowerCase().contains(_searchCtrl.text.toLowerCase()))
                                    .take(5)
                                    .map(
                                      (p) => ListTile(
                                        dense: true,
                                        leading: ProductImageWidget(
                                          imagenUrl: p.imagenUrl,
                                          categoria: p.nombreCategoria,
                                          size: 36,
                                        ),
                                        title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        subtitle: Text('Stock: ${p.stockActual.toStringAsFixed(0)} un. • S/ ${p.precioVenta.toStringAsFixed(2)}'),
                                        onTap: () => _seleccionarProducto(p),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.brandPrimary, width: 1.4),
                              ),
                              child: Row(
                                children: [
                                  ProductImageWidget(
                                    imagenUrl: _productoSeleccionado!.imagenUrl,
                                    categoria: _productoSeleccionado!.nombreCategoria,
                                    size: 44,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _productoSeleccionado!.nombre,
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Stock actual: ${_productoSeleccionado!.stockActual.toStringAsFixed(0)} un.  •  Venta: S/ ${_productoSeleccionado!.precioVenta.toStringAsFixed(2)}',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _productoSeleccionado = null),
                                    child: const Text('Cambiar'),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // 2. Motivo de Baja
                          Text('2. Motivo de la baja:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _motivos.map((m) {
                              final isSel = _motivo == m['id'];
                              final color = m['color'] as Color;
                              return ChoiceChip(
                                avatar: Icon(m['icon'] as IconData, size: 14, color: isSel ? Colors.white : color),
                                label: Text(m['label'] as String),
                                selected: isSel,
                                selectedColor: color,
                                labelStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark),
                                ),
                                onSelected: (val) {
                                  if (val) setState(() => _motivo = m['id'] as String);
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 18),

                          // 3. Cantidad y Costo
                          Text('3. Cantidad y Valorización Contable:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cantidadCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Cantidad a descontar',
                                    hintText: '1',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _costoCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Costo unitario (S/)',
                                    hintText: '3.50',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Cálculo de pérdida total
                          Builder(builder: (_) {
                            final cant = double.tryParse(_cantidadCtrl.text.trim()) ?? 0.0;
                            final cost = double.tryParse(_costoCtrl.text.trim()) ?? 0.0;
                            final total = cant * cost;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.calculator, color: Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 8),
                                  Text('Pérdida Total Contable:', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  Text(
                                    '-S/ ${total.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 18),

                          // 4. Observaciones
                          Text('4. Observaciones (Opcional):', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _obsCtrl,
                            decoration: InputDecoration(
                              hintText: 'Ej. Se quebró al desempacar la caja en almacén',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Barra Inferior de Confirmación
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.check, size: 18),
                        label: Text(
                          _isSaving ? 'REGISTRANDO...' : 'CONFIRMAR BAJA DE INVENTARIO',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        onPressed: (_isSaving || _productoSeleccionado == null) ? null : _guardarMerma,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
