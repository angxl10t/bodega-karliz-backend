import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'venta_model.dart';
import 'venta_service.dart';
import '../auth/auth_service.dart';
import '../../core/theme.dart';

class CajaVentasScreen extends StatefulWidget {
  const CajaVentasScreen({super.key});

  @override
  State<CajaVentasScreen> createState() => _CajaVentasScreenState();
}

class _CajaVentasScreenState extends State<CajaVentasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VentaService _ventaService = VentaService();

  CierreCaja? _cierreCaja;
  CierreCaja? _cierreHoy;
  List<CierreCaja> _historialCierres = [];
  List<VentaRegistro> _ventas = [];
  bool _isLoading = true;
  final TextEditingController _busquedaController = TextEditingController();
  String _busquedaVenta = '';
  String _userRol = 'CAJERO';
  bool get _esAdmin => _userRol.toUpperCase() == 'ADMIN' || _userRol.toUpperCase() == 'SUPERADMIN';

  DateTime _fechaSeleccionada = DateTime.now();
  bool _filtrarVentasPorFecha = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    VentaService.ventasRevision.addListener(_onVentasRevisionChanged);
    _cargarDatos();
  }

  @override
  void dispose() {
    VentaService.ventasRevision.removeListener(_onVentasRevisionChanged);
    _tabController.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  void _onVentasRevisionChanged() {
    if (mounted) {
      _cargarDatos();
    }
  }

  bool _esMismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _nombreDiaSemana(DateTime f) {
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return dias[f.weekday - 1];
  }

  String _nombreMes(DateTime f) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Setiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return meses[f.month - 1];
  }

  String _formatearFechaCorta(DateTime f) {
    const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'];
    return '${f.day} ${meses[f.month - 1]}';
  }

  String _formatearFechaCompleta(DateTime f) {
    final ahora = DateTime.now();
    if (_esMismoDia(f, ahora)) return 'Hoy - ${_formatearFechaCorta(f)}';
    if (_esMismoDia(f, ahora.subtract(const Duration(days: 1)))) {
      return 'Ayer - ${_nombreDiaSemana(f)} ${_formatearFechaCorta(f)}';
    }
    return '${_nombreDiaSemana(f)}, ${f.day} de ${_nombreMes(f)} ${f.year}';
  }

  List<CierreCaja> _calcularHistorialDesdeVentas(List<VentaRegistro> ventas) {
    final Map<String, List<VentaRegistro>> mapa = {};
    for (final v in ventas) {
      final f = v.fechaVenta ?? DateTime.now();
      final clave = "${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}";
      mapa.putIfAbsent(clave, () => []).add(v);
    }

    final List<CierreCaja> resultado = [];
    final clavesOrdenadas = mapa.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final clave in clavesOrdenadas) {
      final ventasDia = mapa[clave]!;
      double totVentas = 0;
      double totEfectivo = 0;
      double totEfectivoRecibido = 0;
      double totVueltoEntregado = 0;
      double totYape = 0;
      double totPlin = 0;
      double totTarjeta = 0;
      int validasCount = 0;

      for (final v in ventasDia) {
        // Exclusión contable rigurosa: ventas anuladas no suman dinero en caja
        if (v.isAnulada) continue;

        validasCount++;
        totVentas += v.total;
        final m = v.metodoPago.toLowerCase();
        if (m.contains('yape')) {
          totYape += v.total;
        } else if (m.contains('plin')) {
          totPlin += v.total;
        } else if (m.contains('tarjeta') || m.contains('pos') || m.contains('card')) {
          totTarjeta += v.total;
        } else {
          totEfectivo += v.total;
          totEfectivoRecibido += (v.montoRecibido ?? v.total);
          totVueltoEntregado += (v.vuelto ?? 0.0);
        }
      }

      final partes = clave.split('-');
      final fecha = DateTime(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));

      resultado.add(CierreCaja(
        totalVentas: totVentas,
        totalEfectivo: totEfectivo,
        totalEfectivoRecibido: totEfectivoRecibido,
        totalVueltoEntregado: totVueltoEntregado,
        totalYape: totYape,
        totalPlin: totPlin,
        totalTarjeta: totTarjeta,
        cantidadVentas: validasCount,
        fecha: fecha,
      ));
    }
    return resultado;
  }

  CierreCaja _obtenerCierreParaFecha(
    DateTime fecha,
    CierreCaja? cierreHoy,
    List<CierreCaja> historial,
    List<VentaRegistro> ventas,
  ) {
    if (_esMismoDia(fecha, DateTime.now()) && cierreHoy != null) {
      return cierreHoy;
    }

    for (final c in historial) {
      if (c.fecha != null && _esMismoDia(c.fecha!, fecha)) {
        return c;
      }
    }

    final ventasDia = ventas.where((v) {
      final f = v.fechaVenta;
      return f != null && _esMismoDia(f, fecha);
    }).toList();

    if (ventasDia.isNotEmpty) {
      double totVentas = 0;
      double totEfectivo = 0;
      double totEfectivoRecibido = 0;
      double totVueltoEntregado = 0;
      double totYape = 0;
      double totPlin = 0;
      double totTarjeta = 0;
      int validasCount = 0;

      for (final v in ventasDia) {
        // Exclusión contable rigurosa: ventas anuladas no suman dinero en caja
        if (v.isAnulada) continue;

        validasCount++;
        totVentas += v.total;
        final m = v.metodoPago.toLowerCase();
        if (m.contains('yape')) {
          totYape += v.total;
        } else if (m.contains('plin')) {
          totPlin += v.total;
        } else if (m.contains('tarjeta') || m.contains('pos') || m.contains('card')) {
          totTarjeta += v.total;
        } else {
          totEfectivo += v.total;
          totEfectivoRecibido += (v.montoRecibido ?? v.total);
          totVueltoEntregado += (v.vuelto ?? 0.0);
        }
      }

      return CierreCaja(
        totalVentas: totVentas,
        totalEfectivo: totEfectivo,
        totalEfectivoRecibido: totEfectivoRecibido,
        totalVueltoEntregado: totVueltoEntregado,
        totalYape: totYape,
        totalPlin: totPlin,
        totalTarjeta: totTarjeta,
        cantidadVentas: validasCount,
        fecha: fecha,
      );
    }

    return CierreCaja(
      totalVentas: 0.0,
      totalEfectivo: 0.0,
      totalEfectivoRecibido: 0.0,
      totalVueltoEntregado: 0.0,
      totalYape: 0.0,
      totalPlin: 0.0,
      totalTarjeta: 0.0,
      cantidadVentas: 0,
      fecha: fecha,
    );
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      final cierreHoyFuture = _ventaService.getCierreCajaHoy();
      final ventasFuture = _ventaService.getVentas();
      final historialFuture = _ventaService.getHistorialCierres(dias: 30);

      final rolFuture = AuthService().getUserRole();

      final results = await Future.wait([cierreHoyFuture, ventasFuture, historialFuture, rolFuture]);

      final cierreHoy = results[0] as CierreCaja?;
      final ventas = results[1] as List<VentaRegistro>;
      var historial = results[2] as List<CierreCaja>;
      final rol = results[3] as String;

      if (historial.isEmpty && ventas.isNotEmpty) {
        historial = _calcularHistorialDesdeVentas(ventas);
      }

      if (mounted) {
        setState(() {
          _cierreHoy = cierreHoy;
          _ventas = ventas;
          _historialCierres = historial;
          _cierreCaja = _obtenerCierreParaFecha(_fechaSeleccionada, cierreHoy, historial, ventas);
          _userRol = rol;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _seleccionarFecha(DateTime fecha) {
    setState(() {
      _fechaSeleccionada = fecha;
      _cierreCaja = _obtenerCierreParaFecha(fecha, _cierreHoy, _historialCierres, _ventas);
    });
  }

  Future<void> _abrirSelectorFecha() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = today.subtract(const Duration(days: 365));
    final lastDate = today;
    DateTime safeInitial = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day);
    if (safeInitial.isAfter(lastDate)) safeInitial = lastDate;
    if (safeInitial.isBefore(firstDate)) safeInitial = firstDate;

    final seleccionada = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppTheme.brandPrimary,
                    onPrimary: Colors.white,
                    surface: AppTheme.cardDark,
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppTheme.brandPrimary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppTheme.textDark,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (seleccionada != null) {
      _seleccionarFecha(seleccionada);
    }
  }

  void _mostrarAvisoAccesoRestringidoCajero() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(LucideIcons.shieldAlert, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Por seguridad contable, los cajeros solo pueden consultar el arqueo del turno actual (Hoy).',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.alertRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _verBoletasDelDia(DateTime f) {
    setState(() {
      _fechaSeleccionada = f;
      _filtrarVentasPorFecha = true;
    });
    _tabController.animateTo(1);
  }

  Future<void> _confirmarAnulacion(VentaRegistro venta) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motivoCtrl = TextEditingController();
    ({bool confirmar, String motivo})? resultado;
    try {
      resultado = await showDialog<({bool confirmar, String motivo})>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.alertTriangle, color: AppTheme.alertRed, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Anular Venta #${venta.idVenta}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Estás seguro de que deseas anular esta venta de S/ ${venta.total.toStringAsFixed(2)}?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF101622) : const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.refreshCw, size: 14, color: AppTheme.brandPrimary),
                          const SizedBox(width: 6),
                          Text(
                            'Restauración Automática de Stock',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Los ${venta.detalles.length} productos serán devueltos inmediatamente al inventario y se registrará la auditoría en el Kardex.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                if (venta.esSunat && (venta.estadoSunat ?? '').toUpperCase().contains('ACEPTADO')) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.alertTriangle, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esta Boleta ya fue aceptada por SUNAT. Al anularla en CajaYa, recuerda generar su respectiva Nota de Crédito en el portal SUNAT para regularizarla fiscalmente.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Motivo o justificación:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: motivoCtrl,
                  maxLines: 2,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Ej. Error en cobro, cliente desistió, duplicado...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF101622) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, (confirmar: false, motivo: '')),
              child: Text(
                'Cancelar',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.alertRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => Navigator.pop(ctx, (confirmar: true, motivo: motivoCtrl.text.trim())),
              child: Text(
                'Anular Venta',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    } finally {
      motivoCtrl.dispose();
    }

    if (resultado?.confirmar == true) {
      final res = await _ventaService.anularVentaConDetalle(
        venta.idVenta,
        motivo: resultado!.motivo.isNotEmpty ? resultado.motivo : null,
      );
      if (mounted) {
        if (res.ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Venta #${venta.idVenta} anulada con éxito. Stock restablecido.'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
          _cargarDatos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.error ?? 'Error al anular la venta en el servidor'),
              backgroundColor: AppTheme.alertRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _reintentarSunat(VentaRegistro venta) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Reenviando ${venta.etiquetaComprobante} a SUNAT...'),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    final result = await _ventaService.reintentarSunat(venta.idVenta);
    if (!mounted) return;

    messenger.hideCurrentSnackBar();
    if (result.success && result.venta != null) {
      final v = result.venta!;
      final estado = (v.estadoSunat ?? '').toUpperCase();
      final esAceptado = estado.contains('ACEPTADO');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            esAceptado
                ? '¡${v.serieCorrelativo ?? "#${v.idVenta}"} aceptado por SUNAT!'
                : (v.sunatMensaje ?? 'Estado SUNAT: $estado'),
          ),
          backgroundColor: esAceptado ? AppTheme.accentGreen : const Color(0xFFF59E0B),
        ),
      );
      _cargarDatos();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Error al conectar con la pasarela de facturación SUNAT'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arqueo de Caja & Ventas',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            Text(
              'Corte del día, histórico de jornadas y auditoría',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.brandPrimary,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.brandPrimary,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(LucideIcons.banknote, size: 18), text: 'Cierre del Día'),
            Tab(icon: Icon(LucideIcons.history, size: 18), text: 'Historial de Ventas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCierreTab(isDark),
                _buildHistorialTab(isDark),
              ],
            ),
    );
  }

  Widget _buildCierreTab(bool isDark) {
    final c = _cierreCaja;
    final totalVendido = c?.totalVentas ?? 0.0;
    final totalEfectivo = c?.totalEfectivo ?? 0.0;
    final totalEfectivoRecibido = c?.totalEfectivoRecibido ?? totalEfectivo;
    final totalVueltoEntregado = c?.totalVueltoEntregado ?? 0.0;
    final totalYape = c?.totalYape ?? 0.0;
    final totalPlin = c?.totalPlin ?? 0.0;
    final totalTarjeta = c?.totalTarjeta ?? 0.0;
    final cantidadVentas = c?.cantidadVentas ?? 0;
    final esHoy = _esMismoDia(_fechaSeleccionada, DateTime.now());

    final diasPasados = _historialCierres
        .where((item) => item.fecha != null && !_esMismoDia(item.fecha!, DateTime.now()))
        .toList();

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: AppTheme.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner Didáctico
                const DidacticBanner(
                  title: 'Cuadre de Dinero & Histórico',
                  description: 'Compara el Efectivo en Caja con tu cajón físico. Selecciona días pasados para auditar cortes anteriores de tu negocio.',
                  icon: LucideIcons.calculator,
                ),
                const SizedBox(height: 14),

                // Filtros Rápidos de Fecha (Hoy, Ayer, Anteayer, Calendario)
                _buildFiltrosFecha(isDark),
                const SizedBox(height: 14),

                // Notificación si se está viendo un día pasado
                if (!esHoy) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.history, size: 18, color: AppTheme.brandPrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auditoría de Cierre Pasado',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                _formatearFechaCompleta(_fechaSeleccionada),
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            backgroundColor: AppTheme.brandPrimary.withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(LucideIcons.arrowLeft, size: 14, color: AppTheme.brandPrimary),
                          label: Text(
                            'Volver a Hoy',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.brandPrimary,
                            ),
                          ),
                          onPressed: () => _seleccionarFecha(DateTime.now()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Tarjeta Principal de Cierre del Día
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: esHoy
                                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE0E7FF)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                if (esHoy) ...[
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accentGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Caja Abierta Hoy',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(LucideIcons.checkCheck, size: 13, color: Color(0xFF4338CA)),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Cierre Concluido',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        esHoy
                            ? 'TOTAL RECAUDADO EN EL DÍA'
                            : 'TOTAL RECAUDADO (${_formatearFechaCorta(_fechaSeleccionada).toUpperCase()})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: totalVendido),
                        duration: const Duration(milliseconds: 750),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) => Text(
                          'S/ ${val.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: AppTheme.brandPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$cantidadVentas ventas registradas',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : AppTheme.textDark,
                        ),
                      ),
                      if (!esHoy && cantidadVentas > 0) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(LucideIcons.receipt, size: 14, color: AppTheme.brandPrimary),
                          label: Text(
                            'Ver Boletas de este Día',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.brandPrimary,
                            ),
                          ),
                          onPressed: () => _verBoletasDelDia(_fechaSeleccionada),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Título de Métodos
                Text(
                  'Desglose por Canal de Pago',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                // Tarjetas de Desglose
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double tileWidth = constraints.maxWidth >= 750
                        ? (constraints.maxWidth - 10) / 2
                        : constraints.maxWidth;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildCanalPagoTile(
                          width: tileWidth,
                          titulo: 'Efectivo en Caja',
                          monto: totalEfectivo,
                          icon: LucideIcons.banknote,
                          color: AppTheme.accentGreen,
                          isDark: isDark,
                          descripcion: totalVueltoEntregado > 0
                              ? 'Cobrado: S/ ${totalEfectivoRecibido.toStringAsFixed(2)} • Vuelto: -S/ ${totalVueltoEntregado.toStringAsFixed(2)}'
                              : 'Dinero físico en cajón (Neto)',
                        ),
                        _buildCanalPagoTile(
                          width: tileWidth,
                          titulo: 'Yape Móvil',
                          monto: totalYape,
                          icon: LucideIcons.smartphone,
                          color: const Color(0xFF7C3AED),
                          isDark: isDark,
                          descripcion: 'Pagos recibidos por código QR',
                        ),
                        _buildCanalPagoTile(
                          width: tileWidth,
                          titulo: 'Plin',
                          monto: totalPlin,
                          icon: LucideIcons.smartphone,
                          color: const Color(0xFF0284C7),
                          isDark: isDark,
                          descripcion: 'Transferencias interbancarias',
                        ),
                        _buildCanalPagoTile(
                          width: tileWidth,
                          titulo: 'Tarjetas / POS',
                          monto: totalTarjeta,
                          icon: LucideIcons.creditCard,
                          color: const Color(0xFF2563EB),
                          isDark: isDark,
                          descripcion: 'Cobros débito / crédito',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // SECCIÓN: HISTÓRICO DE DÍAS ANTERIORES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Histórico de Días Anteriores',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Auditoría y cierres pasados de tu bodega',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${diasPasados.length} jornadas',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (diasPasados.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(!_esAdmin ? LucideIcons.shieldCheck : LucideIcons.calendarX2, size: 32, color: !_esAdmin ? AppTheme.brandPrimary : AppTheme.textMuted),
                          const SizedBox(height: 10),
                          Text(
                            !_esAdmin ? 'Modo Cajero: Turno Actual Activo' : 'No hay jornadas anteriores registradas',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            !_esAdmin
                                ? 'Por seguridad contable, la auditoría y cierre de días anteriores está reservada para el Administrador de la tienda.'
                                : 'Las ventas de los días anteriores se guardan automáticamente para su consulta.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: diasPasados.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final item = diasPasados[idx];
                      final esSeleccionado = item.fecha != null && _esMismoDia(item.fecha!, _fechaSeleccionada);
                      return _buildCardDiaHistorico(item, esSeleccionado, isDark);
                    },
                  ),

                const SizedBox(height: 24),

                // Botón de Actualizar Corte
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.surfaceTint,
                      foregroundColor: AppTheme.brandPrimary,
                      elevation: 0,
                      side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderTint),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(LucideIcons.refreshCw, size: 17),
                    label: Text(
                      'ACTUALIZAR CIERRE DE CAJA',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    onPressed: _cargarDatos,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltrosFecha(bool isDark) {
    final hoy = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));
    final anteayer = hoy.subtract(const Duration(days: 2));

    final esHoy = _esMismoDia(_fechaSeleccionada, hoy);
    final esAyer = _esMismoDia(_fechaSeleccionada, ayer);
    final esAnteayer = _esMismoDia(_fechaSeleccionada, anteayer);
    final esOtro = !esHoy && !esAyer && !esAnteayer;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChipFecha(
            label: 'Hoy',
            selected: esHoy,
            icon: LucideIcons.calendar,
            onTap: () => _seleccionarFecha(hoy),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildChipFecha(
            label: 'Ayer',
            selected: esAyer,
            icon: _esAdmin ? LucideIcons.calendarClock : LucideIcons.lock,
            onTap: _esAdmin ? () => _seleccionarFecha(ayer) : _mostrarAvisoAccesoRestringidoCajero,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildChipFecha(
            label: _nombreDiaSemana(anteayer),
            selected: esAnteayer,
            icon: _esAdmin ? LucideIcons.history : LucideIcons.lock,
            onTap: _esAdmin ? () => _seleccionarFecha(anteayer) : _mostrarAvisoAccesoRestringidoCajero,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildChipFecha(
            label: esOtro ? _formatearFechaCorta(_fechaSeleccionada) : 'Elegir Fecha',
            selected: esOtro,
            icon: _esAdmin ? LucideIcons.calendarSearch : LucideIcons.lock,
            onTap: _esAdmin ? _abrirSelectorFecha : _mostrarAvisoAccesoRestringidoCajero,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildChipFecha({
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandPrimary : (isDark ? AppTheme.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.brandPrimary : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDiaHistorico(CierreCaja item, bool esSeleccionado, bool isDark) {
    final fecha = item.fecha ?? DateTime.now();

    return InkWell(
      onTap: () => _seleccionarFecha(fecha),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: esSeleccionado
              ? (isDark ? const Color(0xFF132A2B) : AppTheme.surfaceTint)
              : (isDark ? AppTheme.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: esSeleccionado
                ? AppTheme.brandPrimary
                : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
            width: esSeleccionado ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icono / Bloque de fecha
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: esSeleccionado
                        ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        fecha.day.toString().padLeft(2, '0'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: esSeleccionado ? AppTheme.brandPrimary : (isDark ? Colors.white : AppTheme.textDark),
                          height: 1.0,
                        ),
                      ),
                      Text(
                        _formatearFechaCorta(fecha).split(' ').last.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: esSeleccionado ? AppTheme.brandPrimary : AppTheme.textMuted,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatearFechaCompleta(fecha),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (esSeleccionado)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.brandPrimary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Viendo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.cantidadVentas} transacciones concluidas',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'S/ ${item.totalVentas.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.brandPrimary,
                      ),
                    ),
                    Text(
                      'Recaudado',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mini badges de canales de pago para este día
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildMiniCanalBadge(
                  label: 'Efectivo',
                  monto: item.totalEfectivo,
                  color: AppTheme.accentGreen,
                  isDark: isDark,
                ),
                _buildMiniCanalBadge(
                  label: 'Yape',
                  monto: item.totalYape,
                  color: const Color(0xFF7C3AED),
                  isDark: isDark,
                ),
                if (item.totalPlin > 0)
                  _buildMiniCanalBadge(
                    label: 'Plin',
                    monto: item.totalPlin,
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                  ),
                if (item.totalTarjeta > 0)
                  _buildMiniCanalBadge(
                    label: 'Tarjeta',
                    monto: item.totalTarjeta,
                    color: const Color(0xFFEA580C),
                    isDark: isDark,
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Botones de acción del día
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.receipt, size: 13, color: AppTheme.brandPrimary),
                  label: Text(
                    'Ver Boletas',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brandPrimary,
                    ),
                  ),
                  onPressed: () => _verBoletasDelDia(fecha),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    esSeleccionado ? LucideIcons.check : LucideIcons.eye,
                    size: 13,
                    color: AppTheme.brandPrimary,
                  ),
                  label: Text(
                    esSeleccionado ? 'Corte Activo' : 'Cargar Cierre',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brandPrimary,
                    ),
                  ),
                  onPressed: () => _seleccionarFecha(fecha),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCanalBadge({
    required String label,
    required double monto,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Text(
        '$label: S/ ${monto.toStringAsFixed(2)}',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCanalPagoTile({
    required String titulo,
    required double monto,
    required IconData icon,
    required Color color,
    required bool isDark,
    required String descripcion,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Text(
                  descripcion,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: monto),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) => Text(
              'S/ ${val.toStringAsFixed(2)}',
              style: GoogleFonts.outfit(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppTheme.textDark,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialTab(bool isDark) {
    final ventasFiltradasPorDia = _filtrarVentasPorFecha
        ? _ventas.where((v) {
            final f = v.fechaVenta;
            return f != null && _esMismoDia(f, _fechaSeleccionada);
          }).toList()
        : _ventas;

    final filtradas = ventasFiltradasPorDia.where((v) {
      final doc = v.clienteDocumento ?? '';
      final nom = v.clienteNombre ?? '';
      final q = _busquedaVenta.toLowerCase();
      return nom.toLowerCase().contains(q) || doc.contains(q) || v.idVenta.toString().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: AppTheme.brandPrimary,
      child: Column(
        children: [
          // Barra de Filtro de Fecha para Boletas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _filtrarVentasPorFecha = false),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_filtrarVentasPorFecha
                          ? AppTheme.brandPrimary
                          : (isDark ? AppTheme.cardDark : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_filtrarVentasPorFecha
                            ? AppTheme.brandPrimary
                            : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                    ),
                    child: Text(
                      'Todas (${_ventas.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !_filtrarVentasPorFecha
                            ? Colors.white
                            : (isDark ? Colors.white70 : AppTheme.textDark),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _filtrarVentasPorFecha = true),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _filtrarVentasPorFecha
                          ? AppTheme.brandPrimary
                          : (isDark ? AppTheme.cardDark : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _filtrarVentasPorFecha
                            ? AppTheme.brandPrimary
                            : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.calendar, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          _esMismoDia(_fechaSeleccionada, DateTime.now())
                              ? 'Solo Hoy'
                              : _formatearFechaCorta(_fechaSeleccionada),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _filtrarVentasPorFecha
                                ? Colors.white
                                : (isDark ? Colors.white70 : AppTheme.textDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Buscador de Ventas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _busquedaController,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar por venta #ID, cliente o DNI...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 13),
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  suffixIcon: _busquedaVenta.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _busquedaController.clear();
                            setState(() => _busquedaVenta = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => setState(() => _busquedaVenta = val),
              ),
            ),
          ),

          // Lista de Ventas
          Expanded(
            child: filtradas.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 350,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.receipt, size: 40, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              _filtrarVentasPorFecha
                                  ? 'No hay boletas en ${_formatearFechaCorta(_fechaSeleccionada)}'
                                  : 'No hay ventas registradas',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark ? Colors.white70 : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtradas.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final v = filtradas[idx];
                      return _buildVentaCard(v, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVentaCard(VentaRegistro v, bool isDark) {
    final fechaStr = v.fechaVenta != null
        ? '${v.fechaVenta!.day.toString().padLeft(2, '0')}/${v.fechaVenta!.month.toString().padLeft(2, '0')} ${v.fechaVenta!.hour.toString().padLeft(2, '0')}:${v.fechaVenta!.minute.toString().padLeft(2, '0')}'
        : 'Reciente';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: v.isAnulada
              ? AppTheme.alertRed.withValues(alpha: isDark ? 0.35 : 0.25)
              : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: v.isAnulada
                          ? AppTheme.alertRed.withValues(alpha: isDark ? 0.2 : 0.1)
                          : (isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      v.isAnulada ? LucideIcons.ban : LucideIcons.receipt,
                      color: v.isAnulada ? AppTheme.alertRed : AppTheme.brandPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            v.etiquetaComprobante,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          if (v.esSunat) ...[
                            const SizedBox(width: 6),
                            () {
                              final estado = (v.estadoSunat ?? 'ACEPTADO').toUpperCase();
                              final Color bg;
                              final Color fg;
                              final String label;

                              if (estado == 'ACEPTADO') {
                                bg = AppTheme.accentGreen.withValues(alpha: 0.15);
                                fg = AppTheme.accentGreen;
                                label = 'SUNAT OK';
                              } else if (estado == 'ACEPTADO_BETA') {
                                bg = const Color(0xFF0D9488).withValues(alpha: 0.15);
                                fg = const Color(0xFF0D9488);
                                label = 'SUNAT BETA';
                              } else if (estado == 'RECHAZADO') {
                                bg = AppTheme.alertRed.withValues(alpha: 0.15);
                                fg = AppTheme.alertRed;
                                label = 'RECHAZADO';
                              } else {
                                bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
                                fg = const Color(0xFFF59E0B);
                                label = 'PENDIENTE';
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: fg,
                                  ),
                                ),
                              );
                            }(),
                          ],
                        ],
                      ),
                      Text(
                        fechaStr,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (v.isAnulada) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.ban, color: AppTheme.alertRed, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'ANULADA',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.alertRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      v.metodoPago,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: v.isAnulada ? AppTheme.textMuted : AppTheme.brandPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Cliente: ${v.clienteNombre ?? 'Público General'} ${v.clienteDocumento != null ? '(${v.clienteDocumento})' : ''}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),

          // Banner informativo de anulación y justificación si está anulada
          if (v.isAnulada) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, color: AppTheme.alertRed, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anulada por ${v.usuarioAnulacion ?? "Administrador"}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.alertRed,
                          ),
                        ),
                        if (v.motivoAnulacion != null && v.motivoAnulacion!.isNotEmpty)
                          Text(
                            'Motivo: "${v.motivoAnulacion}"',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : AppTheme.textDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Items desplegables
          if (v.detalles.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101622) : const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: v.detalles.map((d) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${d.cantidad.toStringAsFixed(0)}x ${d.nombreProducto}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : AppTheme.textDark,
                            ),
                          ),
                        ),
                        Text(
                          'S/ ${d.subtotal.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),

          // Pie con Total y Botón Anular Venta (Exclusivo Administrador y solo si no está anulada)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_esAdmin && !v.isAnulada)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.alertRed,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(LucideIcons.undo2, size: 15),
                      label: Text(
                        'Anular Venta',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => _confirmarAnulacion(v),
                    ),
                  if (_esAdmin && v.esSunat && !v.isAnulada && 
                      (v.estadoSunat == 'PENDIENTE_ENVIO' || v.estadoSunat == 'RECHAZADO' || v.estadoSunat == 'ERROR_ENVIO' || v.estadoSunat == null)) ...[
                    const SizedBox(width: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(LucideIcons.send, size: 14),
                      label: Text(
                        'Reenviar SUNAT',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => _reintentarSunat(v),
                    ),
                  ],
                  if (v.isAnulada)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.rotateCcw, size: 13, color: AppTheme.accentGreen),
                        const SizedBox(width: 5),
                        Text(
                          'Stock devuelto a bodega',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Row(
                children: [
                  Text(
                    v.isAnulada ? 'Total anulado: ' : 'Total: ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    'S/ ${v.total.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      decoration: v.isAnulada ? TextDecoration.lineThrough : null,
                      color: v.isAnulada ? AppTheme.textMuted : AppTheme.brandPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
