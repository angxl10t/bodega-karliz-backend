import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'venta_model.dart';
import 'venta_service.dart';
import '../auth/auth_service.dart';
import '../home/configuracion_ticket_modal.dart';
import '../../core/configuracion_ticket_service.dart';
import '../../core/thermal_ticket_service.dart';
import '../../core/theme.dart';
import '../../core/csv_exporter.dart';
import '../../core/widgets/briefing_turno_modal.dart';

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
  final TextEditingController _conteoFisicoController = TextEditingController();
  String _busquedaVenta = '';
  String _userRol = 'CAJERO';
  bool get _esAdmin => _userRol.toUpperCase() == 'ADMIN' || _userRol.toUpperCase() == 'SUPERADMIN';
  double? _efectivoContado;
  String _nombreBodega = 'CajaYa POS';
  String _rucBodega = '';
  String _direccionBodega = '';
  String _telefonoBodega = '';
  String _lemaBodega = '';
  String _username = 'Cajero';

  DateTime _fechaSeleccionada = DateTime.now();
  bool _filtrarVentasPorFecha = false;
  String _filtroEstadoVenta = 'TODAS'; // 'TODAS', 'COMPLETADAS', 'ANULADAS'

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
    _conteoFisicoController.dispose();
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
      final auth = AuthService();
      final arqueoHoyFuture = _ventaService.getArqueoCompleto(_fechaSeleccionada);
      final ventasFuture = _ventaService.getVentas();
      final historialFuture = _ventaService.getHistorialCierres(dias: 30);
      final rolFuture = auth.getUserRole();
      final nombreBodegaFuture = auth.getNombreBodega();
      final usernameFuture = auth.getUsername();
      final rucFuture = auth.getRucBodega();
      final direccionFuture = auth.getDireccionBodega();
      final telefonoFuture = auth.getTelefonoBodega();
      final lemaFuture = auth.getLemaComercial();

      final results = await Future.wait([
        arqueoHoyFuture,
        ventasFuture,
        historialFuture,
        rolFuture,
        nombreBodegaFuture,
        usernameFuture,
        rucFuture,
        direccionFuture,
        telefonoFuture,
        lemaFuture,
      ]);

      final arqueoHoy = results[0] as CierreCaja?;
      final ventas = results[1] as List<VentaRegistro>;
      var historial = results[2] as List<CierreCaja>;
      final rol = results[3] as String;
      final nombreBodega = (results[4] as String?) ?? 'CajaYa POS';
      final username = (results[5] as String?) ?? 'Cajero';
      final ruc = (results[6] as String?) ?? '';
      final direccion = (results[7] as String?) ?? '';
      final telefono = (results[8] as String?) ?? '';
      final lema = (results[9] as String?) ?? '';

      if (historial.isEmpty && ventas.isNotEmpty) {
        historial = _calcularHistorialDesdeVentas(ventas);
      }

      if (mounted) {
        setState(() {
          _cierreHoy = arqueoHoy;
          _ventas = ventas;
          _historialCierres = historial;
          _cierreCaja = arqueoHoy ?? _obtenerCierreParaFecha(_fechaSeleccionada, arqueoHoy, historial, ventas);
          _userRol = rol;
          _nombreBodega = nombreBodega;
          _username = username;
          _rucBodega = ruc;
          _direccionBodega = direccion;
          _telefonoBodega = telefono;
          _lemaBodega = lema;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _seleccionarFecha(DateTime fecha) async {
    setState(() {
      _fechaSeleccionada = fecha;
      _conteoFisicoController.clear();
      _efectivoContado = null;
    });
    final arqueo = await _ventaService.getArqueoCompleto(fecha);
    if (mounted) {
      setState(() {
        _cierreCaja = arqueo ?? _obtenerCierreParaFecha(fecha, _cierreHoy, _historialCierres, _ventas);
      });
    }
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

  Future<void> _exportarVentasCsv() async {
    final ventasAExportar = _filtrarVentasPorFecha
        ? _ventas.where((v) {
            final f = v.fechaVenta;
            return f != null && _esMismoDia(f, _fechaSeleccionada);
          }).toList()
        : _ventas;

    if (ventasAExportar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay ventas registradas para exportar.')),
      );
      return;
    }

    final now = DateTime.now();
    final fechaStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final nombreArchivo = 'ventas_cajaya_$fechaStr.csv';
    final csv = CsvExporter.generarCsvVentas(ventasAExportar);
    await CsvExporter.descargarOCompartirCsv(
      nombreArchivo: nombreArchivo,
      contenidoCsv: csv,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb
              ? '¡Reporte descargado como $nombreArchivo!'
              : '¡Reporte de ventas exportado y copiado al portapapeles!'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _compartirArqueoWhatsApp() async {
    final c = _cierreCaja;
    final totalVendido = c?.totalVentas ?? 0.0;
    final totalEfectivo = c?.totalEfectivo ?? 0.0;
    final totalYape = c?.totalYape ?? 0.0;
    final totalPlin = c?.totalPlin ?? 0.0;
    final totalTarjeta = c?.totalTarjeta ?? 0.0;
    final totalCredito = c?.totalCredito ?? 0.0;
    final cantidadVentas = c?.cantidadVentas ?? 0;
    final fondoInicial = c?.fondoInicial ?? 0.0;
    final totalEgresos = c?.totalEgresos ?? 0.0;
    final totalAbonosEf = c?.totalAbonosEfectivo ?? 0.0;
    final totalAbonosDig = c?.totalAbonosDigitales ?? 0.0;
    final totalAbonosCobrados = c?.totalAbonosCobrados ?? 0.0;
    final cantidadAbonos = c?.cantidadAbonos ?? 0;
    final totalEsperado = c?.totalEfectivoEsperado ?? (fondoInicial + totalEfectivo + totalAbonosEf - totalEgresos);

    String estadoDif = 'PENDIENTE DE CONTEO';
    if (_efectivoContado != null) {
      final dif = _efectivoContado! - totalEsperado;
      if (dif.abs() < 0.01) {
        estadoDif = 'CUADRADO PERFECTO (S/ 0.00)';
      } else if (dif < -0.01) {
        estadoDif = 'FALTANTE: -S/ ${(-dif).toStringAsFixed(2)}';
      } else {
        estadoDif = 'SOBRANTE: +S/ ${dif.toStringAsFixed(2)}';
      }
    }

    final msg = StringBuffer();
    msg.writeln('📊 *ARQUEO DE CAJA - CAJAYA CLOUD POS*');
    msg.writeln('🏪 *Bodega:* $_nombreBodega');
    msg.writeln('📅 *Fecha:* ${_formatearFechaCompleta(_fechaSeleccionada)}');
    msg.writeln('👤 *Cajero:* $_username');
    msg.writeln('------------------------------------------');
    msg.writeln('💵 *FLUJO DE EFECTIVO:*');
    msg.writeln('• Base Inicial (Sencillo): S/ ${fondoInicial.toStringAsFixed(2)}');
    msg.writeln('• (+) Ventas Efectivo: S/ ${totalEfectivo.toStringAsFixed(2)}');
    if (totalAbonosEf > 0) {
      msg.writeln('• (+) Cobro Fiados (Efectivo): S/ ${totalAbonosEf.toStringAsFixed(2)} ($cantidadAbonos abonos)');
    }
    msg.writeln('• (-) Egresos Caja Chica: S/ ${totalEgresos.toStringAsFixed(2)}');
    msg.writeln('• (=) Efectivo Esperado: S/ ${totalEsperado.toStringAsFixed(2)}');
    if (_efectivoContado != null) {
      msg.writeln('• Efectivo Real Contado: S/ ${_efectivoContado!.toStringAsFixed(2)}');
      msg.writeln('• 📌 *Diferencia:* $estadoDif');
    }
    msg.writeln('------------------------------------------');
    msg.writeln('📱 *CANALES DIGITALES:*');
    msg.writeln('• Yape: S/ ${totalYape.toStringAsFixed(2)}');
    msg.writeln('• Plin: S/ ${totalPlin.toStringAsFixed(2)}');
    msg.writeln('• Tarjetas: S/ ${totalTarjeta.toStringAsFixed(2)}');
    if (totalAbonosDig > 0) {
      msg.writeln('• Cobro Fiados por Yape/Plin: S/ ${totalAbonosDig.toStringAsFixed(2)}');
    }
    if (totalCredito > 0) {
      msg.writeln('• Fiados / Crédito Otorgado: S/ ${totalCredito.toStringAsFixed(2)}');
    }
    msg.writeln('------------------------------------------');
    msg.writeln('💰 *TOTAL RECAUDADO:* S/ ${totalVendido.toStringAsFixed(2)} ($cantidadVentas ventas)');
    if (totalAbonosCobrados > 0) {
      msg.writeln('🤝 *Cobranza de Deudas:* S/ ${totalAbonosCobrados.toStringAsFixed(2)} ($cantidadAbonos abonos)');
    }

    final encoded = Uri.encodeComponent(msg.toString());
    final url = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp en este dispositivo.')),
        );
      }
    }
  }

  Future<void> _mostrarModalFondoInicial() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController(
      text: (_cierreCaja?.fondoInicial ?? 0.0) > 0
          ? _cierreCaja!.fondoInicial.toStringAsFixed(2)
          : '50.00',
    );

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.banknote, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Fondo Inicial de Caja',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
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
              'Ingresa el monto de sencillo o base con el que se abrió la gaveta al inicio de la jornada:',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.brandPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Monto Base (S/)',
                prefixText: 'S/ ',
                prefixStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.brandPrimary),
                filled: true,
                fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Guardar Base', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      final monto = double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 0.0;
      final ok = await _ventaService.registrarFondoInicial(monto, fecha: _fechaSeleccionada);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fondo inicial de caja actualizado con éxito.'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
          _cargarDatos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar el fondo inicial.'),
              backgroundColor: AppTheme.alertRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _mostrarModalRegistrarEgreso() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final montoCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    String categoria = 'BOLSAS';
    const categorias = ['BOLSAS', 'PANADERIA', 'HIELO', 'LIMPIEZA', 'PROVEEDOR', 'VARIOS'];

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.arrowDownRight, color: Color(0xFFE11D48), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Registrar Egreso de Caja',
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
                  'Registra salidas menores de efectivo del cajón para mantener el arqueo cuadrado:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE11D48),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Monto a retirar (S/)',
                    prefixText: 'S/ ',
                    prefixStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFFE11D48)),
                    filled: true,
                    fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Categoría de Gasto:',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categorias.map((cat) {
                    final sel = categoria == cat;
                    return ChoiceChip(
                      label: Text(cat, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700)),
                      selected: sel,
                      selectedColor: const Color(0xFFE11D48).withValues(alpha: 0.2),
                      onSelected: (_) => setModalState(() => categoria = cat),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motivoCtrl,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Motivo o Detalle',
                    hintText: 'Ej. 50 bolsas plásticas grandes, hielo...',
                    filled: true,
                    fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Registrar Egreso', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmado == true) {
      final monto = double.tryParse(montoCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
      if (monto <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El monto debe ser mayor a cero.')),
          );
        }
        return;
      }
      final motivo = motivoCtrl.text.trim().isNotEmpty ? motivoCtrl.text.trim() : 'Gasto de caja chica ($categoria)';
      final ok = await _ventaService.registrarEgreso(monto: monto, motivo: motivo, categoriaGasto: categoria);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Egreso de S/ ${monto.toStringAsFixed(2)} registrado correctamente.'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
          _cargarDatos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al registrar el egreso en el servidor.'),
              backgroundColor: AppTheme.alertRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _anularEgreso(EgresoCajaItem egreso) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        title: Text('¿Anular Egreso?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text(
          'Se anulará el egreso de S/ ${egreso.monto.toStringAsFixed(2)} ("${egreso.motivo}"). El dinero se restituirá al efectivo esperado.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      final ok = await _ventaService.anularEgreso(egreso.idEgreso);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Egreso anulado con éxito.'), backgroundColor: AppTheme.accentGreen),
          );
          _cargarDatos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al anular el egreso.'), backgroundColor: AppTheme.alertRed),
          );
        }
      }
    }
  }

  Widget _buildMiniFlujoCard({
    required String titulo,
    required double monto,
    required Color color,
    required bool isDark,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B29) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (actionLabel != null && onAction != null)
                InkWell(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      actionLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'S/ ${monto.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiferenciaBadge(double dif, bool isDark) {
    final bool cuadrado = dif.abs() < 0.01;
    final bool faltante = dif < -0.01;
    final Color color = cuadrado
        ? AppTheme.accentGreen
        : (faltante ? AppTheme.alertRed : const Color(0xFF2563EB));
    final IconData icon = cuadrado
        ? LucideIcons.checkCircle2
        : (faltante ? LucideIcons.alertTriangle : LucideIcons.info);

    final String texto = cuadrado
        ? '¡CAJA CUADRADA PERFECTA! (S/ 0.00)'
        : (faltante
            ? 'FALTANTE EN CAJA: -S/ ${(-dif).toStringAsFixed(2)}'
            : 'SOBRANTE EN CAJA: +S/ ${dif.toStringAsFixed(2)}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
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

  Widget _buildArqueoYCuadreCard(bool isDark) {
    final fondo = _cierreCaja?.fondoInicial ?? 0.0;
    final efectivoVentas = _cierreCaja?.totalEfectivo ?? 0.0;
    final egresos = _cierreCaja?.totalEgresos ?? 0.0;
    final abonosEf = _cierreCaja?.totalAbonosEfectivo ?? 0.0;
    final cantAbonos = _cierreCaja?.cantidadAbonos ?? 0;
    final esperado = _cierreCaja?.totalEfectivoEsperado ?? (fondo + efectivoVentas + abonosEf - egresos);
    final contado = _efectivoContado;
    final diferencia = (contado != null) ? (contado - esperado) : null;
    final listaEgresos = _cierreCaja?.egresos ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.scale, color: AppTheme.brandPrimary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arqueo de Turno & Cuadre',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Fondo de caja, gastos menores y cuadre físico',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.send, color: AppTheme.accentGreen, size: 20),
                tooltip: 'Enviar Arqueo por WhatsApp',
                onPressed: _compartirArqueoWhatsApp,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMiniFlujoCard(
                  titulo: 'Base Inicial',
                  monto: fondo,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                  actionLabel: 'Editar',
                  onAction: _mostrarModalFondoInicial,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniFlujoCard(
                  titulo: '(+) Ventas Ef.',
                  monto: efectivoVentas,
                  color: AppTheme.accentGreen,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniFlujoCard(
                  titulo: '(-) Egresos',
                  monto: egresos,
                  color: const Color(0xFFE11D48),
                  isDark: isDark,
                  actionLabel: '+ Egreso',
                  onAction: _mostrarModalRegistrarEgreso,
                ),
              ),
            ],
          ),
          if (abonosEf > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F231D) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.accentGreen.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.banknote, color: AppTheme.accentGreen, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cobranza de Fiados en Efectivo ($cantAbonos)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  Text(
                    '+S/ ${abonosEf.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (listaEgresos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B29) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Egresos Menores del Turno (${listaEgresos.length})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                      Text(
                        '-S/ ${egresos.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...listaEgresos.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            e.categoriaGasto,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.motivo,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '-S/ ${e.monto.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        if (_esAdmin) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _anularEgreso(e),
                            child: const Icon(LucideIcons.x, size: 14, color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F2327) : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.brandPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EFECTIVO ESPERADO EN GAVETA',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brandPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Base + Ventas Efectivo - Egresos',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                Text(
                  'S/ ${esperado.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.brandPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _conteoFisicoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Dinero contado en cajón (S/)',
                    labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                    hintText: '0.00',
                    prefixText: 'S/ ',
                    prefixStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.brandPrimary),
                    suffixIcon: IconButton(
                      tooltip: 'Contar billetes y monedas',
                      icon: const Icon(LucideIcons.calculator, size: 20, color: AppTheme.brandPrimary),
                      onPressed: () => _mostrarCalculadoraConteoBilletes(esperado),
                    ),
                    filled: true,
                    fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (val) {
                    final parsed = double.tryParse(val.replaceAll(',', '.'));
                    setState(() => _efectivoContado = parsed);
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(LucideIcons.send, size: 16),
                label: Text(
                  'WhatsApp',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                onPressed: _compartirArqueoWhatsApp,
              ),
            ],
          ),
          if (diferencia != null) ...[
            const SizedBox(height: 12),
            _buildDiferenciaBadge(diferencia, isDark),
          ],
        ],
      ),
    );
  }

  void _mostrarCalculadoraConteoBilletes(double esperado) {
    final Map<double, int> conteo = {
      200.0: 0,
      100.0: 0,
      50.0: 0,
      20.0: 0,
      10.0: 0,
      5.0: 0,
      2.0: 0,
      1.0: 0,
      0.50: 0,
      0.20: 0,
      0.10: 0,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final double total = conteo.entries.fold(0.0, (acc, e) => acc + (e.key * e.value));
            final double dif = total - esperado;

            Color difColor = AppTheme.textMuted;
            String difLabel = 'Exacto (S/ 0.00)';
            IconData difIcon = LucideIcons.checkCheck;

            if (dif.abs() < 0.01) {
              difColor = AppTheme.accentGreen;
              difLabel = 'Cuadre Exacto (S/ 0.00)';
              difIcon = LucideIcons.badgeCheck;
            } else if (dif > 0) {
              difColor = const Color(0xFF0284C7);
              difLabel = 'Sobrante (+ S/ ${dif.toStringAsFixed(2)})';
              difIcon = LucideIcons.trendingUp;
            } else {
              difColor = AppTheme.alertRed;
              difLabel = 'Faltante (- S/ ${dif.abs().toStringAsFixed(2)})';
              difIcon = LucideIcons.trendingDown;
            }

            return Container(
              height: MediaQuery.of(dialogCtx).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.brandPrimary.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(LucideIcons.calculator, size: 20, color: AppTheme.brandPrimary),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Desglose de Efectivo',
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                                Text(
                                  'Conteo físico de billetes y monedas',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              for (final k in conteo.keys) {
                                conteo[k] = 0;
                              }
                            });
                          },
                          child: Text(
                            'Limpiar',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
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
                              'TOTAL CONTADO',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'S/ ${total.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppTheme.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: difColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: difColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(difIcon, size: 14, color: difColor),
                              const SizedBox(width: 5),
                              Text(
                                difLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: difColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'BILLETES',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                        ...[200.0, 100.0, 50.0, 20.0, 10.0].map((d) => _buildDenominacionRow(
                              valor: d,
                              cantidad: conteo[d] ?? 0,
                              esBillete: true,
                              isDark: isDark,
                              onChanged: (nuevaCant) {
                                setModalState(() {
                                  conteo[d] = nuevaCant;
                                });
                              },
                            )),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'MONEDAS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                        ...[5.0, 2.0, 1.0, 0.50, 0.20, 0.10].map((d) => _buildDenominacionRow(
                              valor: d,
                              cantidad: conteo[d] ?? 0,
                              esBillete: false,
                              isDark: isDark,
                              onChanged: (nuevaCant) {
                                setModalState(() {
                                  conteo[d] = nuevaCant;
                                });
                              },
                            )),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDarkSunken : Colors.white,
                      border: Border(
                        top: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(LucideIcons.check, size: 18),
                        label: Text(
                          'Aplicar S/ ${total.toStringAsFixed(2)} al Arqueo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _conteoFisicoController.text = total.toStringAsFixed(2);
                            _efectivoContado = total;
                          });
                          Navigator.pop(sheetCtx);
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                content: Text('¡Conteo físico de S/ ${total.toStringAsFixed(2)} registrado en caja!'),
                                backgroundColor: AppTheme.accentGreen,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDenominacionRow({
    required double valor,
    required int cantidad,
    required bool esBillete,
    required bool isDark,
    required ValueChanged<int> onChanged,
  }) {
    final double subtotal = valor * cantidad;
    final String label = valor >= 1.0 ? 'S/ ${valor.toStringAsFixed(0)}' : 'S/ ${valor.toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cantidad > 0
              ? AppTheme.brandPrimary.withValues(alpha: isDark ? 0.4 : 0.3)
              : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: esBillete
                  ? const Color(0xFF059669).withValues(alpha: isDark ? 0.2 : 0.1)
                  : const Color(0xFFD97706).withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: esBillete ? const Color(0xFF059669) : const Color(0xFFD97706),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.minus, size: 14),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: cantidad > 0 ? () => onChanged(cantidad - 1) : null,
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 34),
                  alignment: Alignment.center,
                  child: Text(
                    '$cantidad',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.plus, size: 14),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => onChanged(cantidad + 1),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'S/ ${subtotal.toStringAsFixed(2)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: subtotal > 0
                  ? (isDark ? Colors.white : AppTheme.brandPrimary)
                  : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarAnulacion(VentaRegistro venta) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motivoCtrl = TextEditingController();
    ({bool confirmar, String motivo})? resultado;
    try {
      resultado = await showDialog<({bool confirmar, String motivo})>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
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
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8F9FB),
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
                    color: isDark ? Colors.white : const Color(0xFF334155),
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
                    fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
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
          content: Text(result.errorMessage ?? 'Error al conectar con el servicio de comprobantes'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    final tabBar = TabBar(
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
    );

    return Scaffold(
      appBar: canPop
          ? AppBar(
              titleSpacing: 16,
              elevation: 0,
              backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
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
              actions: [
                IconButton(
                  tooltip: 'Consejos de Turno & Arqueo',
                  icon: const Icon(LucideIcons.sparkles, size: 20),
                  onPressed: () => BriefingTurnoModal.show(context),
                ),
              ],
              bottom: tabBar,
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: isDark ? AppTheme.cardDark : Colors.white,
                child: tabBar,
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
    final totalCredito = c?.totalCredito ?? 0.0;
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
                // Filtros Rápidos de Fecha (Hoy, Ayer, Anteayer, Calendario)
                _buildFiltrosFecha(isDark),
                const SizedBox(height: 14),

                // Notificación si se está viendo un día pasado
                if (!esHoy) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9),
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
                          color: isDark ? Colors.white : AppTheme.textDark,
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
                        if (totalCredito > 0)
                          _buildCanalPagoTile(
                            width: tileWidth,
                            titulo: 'Crédito / Fiados',
                            monto: totalCredito,
                            icon: LucideIcons.handCoins,
                            color: const Color(0xFFD97706),
                            isDark: isDark,
                            descripcion: 'Pendiente de cobro en Libreta',
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // SECCIÓN: ARQUEO DE TURNO & CUADRE DE CAJA
                _buildArqueoYCuadreCard(isDark),
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
                              color: isDark ? Colors.white : AppTheme.textDark,
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
              color: selected ? Colors.white : (isDark ? Colors.white : AppTheme.textDark),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : (isDark ? Colors.white : AppTheme.textDark),
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
      if (_filtroEstadoVenta == 'COMPLETADAS' && v.isAnulada) return false;
      if (_filtroEstadoVenta == 'ANULADAS' && !v.isAnulada) return false;

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
                            : (isDark ? Colors.white : AppTheme.textDark),
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
                                : (isDark ? Colors.white : AppTheme.textDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(LucideIcons.fileSpreadsheet, size: 14, color: AppTheme.accentGreen),
                  label: Text(
                    'Exportar CSV',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  onPressed: _exportarVentasCsv,
                ),
              ],
            ),
          ),

          // Filtro por Estado: Todas / Completadas / Anuladas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                _buildEstadoVentaChip('TODAS', 'Todas', ventasFiltradasPorDia.length, null, isDark),
                const SizedBox(width: 8),
                _buildEstadoVentaChip('COMPLETADAS', 'Completadas', ventasFiltradasPorDia.where((v) => !v.isAnulada).length, AppTheme.accentGreen, isDark),
                const SizedBox(width: 8),
                _buildEstadoVentaChip('ANULADAS', 'Anuladas', ventasFiltradasPorDia.where((v) => v.isAnulada).length, AppTheme.alertRed, isDark),
              ],
            ),
          ),

          // Buscador de Ventas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF5F6F8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dual-ring glowing icon badge
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.brandPrimary.withValues(alpha: isDark ? 0.15 : 0.08),
                            border: Border.all(
                              color: AppTheme.brandPrimary.withValues(alpha: isDark ? 0.35 : 0.22),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.brandPrimary.withValues(alpha: isDark ? 0.22 : 0.10),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              LucideIcons.receiptText,
                              size: 38,
                              color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _busquedaVenta.isNotEmpty
                              ? 'Sin resultados para "$_busquedaVenta"'
                              : (_filtrarVentasPorFecha
                                  ? 'Sin ventas en ${_formatearFechaCorta(_fechaSeleccionada)}'
                                  : 'No hay ventas registradas'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: Text(
                            _busquedaVenta.isNotEmpty
                                ? 'Prueba verificando el número de comprobante o el nombre del cliente.'
                                : 'Cada venta cobrada en caja se registrará aquí con su desglose de productos, vuelto y reimpresión de comprobante.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        // Didactic Tip Card
                        Container(
                          constraints: const BoxConstraints(maxWidth: 380),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.lightbulb, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tip de Caja: Los arqueos diarios guardan el histórico exacto de cada turno para evitar diferencias al fin de mes.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildEstadoVentaChip(String key, String label, int count, Color? accent, bool isDark) {
    final isSelected = _filtroEstadoVenta == key;
    final color = accent ?? AppTheme.brandPrimary;
    return InkWell(
      onTap: () => setState(() => _filtroEstadoVenta = key),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.28 : 0.12)
              : (isDark ? AppTheme.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (accent != null) ...[
              Container(width: 6, height: 6, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 5),
            ],
            Text(
              '$label ($count)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : (isDark ? Colors.white : AppTheme.textDark),
              ),
            ),
          ],
        ),
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
                  _buildMetodoPagoBadge(v.metodoPago, v.isAnulada, isDark),
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
              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
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
                              color: isDark ? Colors.white : AppTheme.textDark,
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
                color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8F9FB),
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
                              color: isDark ? Colors.white : AppTheme.textDark,
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

          // Pie con Total y Botones de Acción (Ticket térmico, Reenvío SUNAT y Anulación)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!v.isAnulada)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(LucideIcons.printer, size: 14),
                      label: Text(
                        'Ticket',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => _mostrarTicketVentaDialog(v),
                    ),
                  if (_esAdmin && !v.isAnulada)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.alertRed,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(LucideIcons.undo2, size: 14),
                      label: Text(
                        'Anular',
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          'Stock devuelto',
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

  Widget _buildMetodoPagoBadge(String metodo, bool isAnulada, bool isDark) {
    if (isAnulada) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDarkHighlight : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderLight.withValues(alpha: 0.3)),
        ),
        child: Text(
          metodo,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
      );
    }

    final m = metodo.toUpperCase();
    final Color fg;
    final Color bg;
    final IconData icon;

    if (m.contains('YAPE')) {
      fg = const Color(0xFF7C3AED);
      bg = fg.withValues(alpha: isDark ? 0.22 : 0.12);
      icon = LucideIcons.smartphone;
    } else if (m.contains('PLIN')) {
      fg = const Color(0xFF0284C7);
      bg = fg.withValues(alpha: isDark ? 0.22 : 0.12);
      icon = LucideIcons.zap;
    } else if (m.contains('EFECTIVO')) {
      fg = const Color(0xFF059669);
      bg = fg.withValues(alpha: isDark ? 0.22 : 0.12);
      icon = LucideIcons.banknote;
    } else if (m.contains('CREDITO') || m.contains('FIADO')) {
      fg = const Color(0xFFD97706);
      bg = fg.withValues(alpha: isDark ? 0.22 : 0.12);
      icon = LucideIcons.bookOpen;
    } else if (m.contains('TARJETA')) {
      fg = const Color(0xFF2563EB);
      bg = fg.withValues(alpha: isDark ? 0.22 : 0.12);
      icon = LucideIcons.creditCard;
    } else {
      fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
      bg = fg.withValues(alpha: isDark ? 0.20 : 0.10);
      icon = LucideIcons.arrowRightLeft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: isDark ? 0.35 : 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            metodo,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarTicketVentaDialog(VentaRegistro v) {
    int anchoSeleccionado = ConfiguracionTicketService.actual.anchoPapel;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final items = v.detalles
                .map((d) => TicketItem(
                      nombre: d.nombreProducto,
                      cantidad: d.cantidad,
                      precioUnitario: d.precioUnitario,
                      subtotal: d.subtotal,
                    ))
                .toList();

            final ticketText = ThermalTicketService.generateReceiptText(
              ticketId: v.idVenta,
              clienteNombre: v.clienteNombre ?? 'Público General',
              clienteDocumento: v.clienteDocumento,
              metodoPago: v.metodoPago,
              items: items,
              total: v.total,
              pagadoCon: v.montoRecibido,
              vuelto: v.vuelto,
              cajero: v.usuarioRegistro ?? _username,
              fecha: v.fechaVenta,
              width: anchoSeleccionado,
              nombreComercio: _nombreBodega,
              rucDni: _rucBodega.isNotEmpty ? _rucBodega : null,
              direccion: _direccionBodega.isNotEmpty ? _direccionBodega : null,
              telefono: _telefonoBodega.isNotEmpty ? _telefonoBodega : null,
              lemaComercial: _lemaBodega.isNotEmpty ? _lemaBodega : null,
              tipoComprobante: v.tipoComprobante,
              serieCorrelativo: v.serieCorrelativo,
              estadoSunat: v.estadoSunat,
              sunatHash: v.sunatHash,
            );

            return Dialog(
              backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.printer, color: AppTheme.brandPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.etiquetaComprobante,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: isDark ? Colors.white : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                'Reimpresión térmica ESC/POS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Selector de Ancho (58mm / 80mm) y acceso a ajustes
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        anchoSeleccionado = ThermalTicketService.width58mm;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: anchoSeleccionado == ThermalTicketService.width58mm
                                            ? (isDark ? AppTheme.brandPrimary : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: anchoSeleccionado == ThermalTicketService.width58mm
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.06),
                                                  blurRadius: 4,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '58 mm (Portátil)',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: anchoSeleccionado == ThermalTicketService.width58mm
                                                ? (isDark ? Colors.white : AppTheme.brandPrimary)
                                                : AppTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        anchoSeleccionado = ThermalTicketService.width80mm;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: anchoSeleccionado == ThermalTicketService.width80mm
                                            ? (isDark ? AppTheme.brandPrimary : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: anchoSeleccionado == ThermalTicketService.width80mm
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.06),
                                                  blurRadius: 4,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '80 mm (Mostrador)',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: anchoSeleccionado == ThermalTicketService.width80mm
                                                ? (isDark ? Colors.white : AppTheme.brandPrimary)
                                                : AppTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Ajustes de Impresora y QR',
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(LucideIcons.settings2, size: 18),
                          onPressed: () {
                            ConfiguracionTicketModal.show(context, onSaved: () {
                              setDialogState(() {
                                anchoSeleccionado = ConfiguracionTicketService.actual.anchoPapel;
                              });
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Previsualización monospacio del ticket estilo papel térmico
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            ticketText,
                            style: GoogleFonts.firaCode(
                              fontSize: 11.5,
                              height: 1.35,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Acciones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                              ),
                            ),
                            icon: const Icon(LucideIcons.copy, size: 16),
                            label: Text(
                              'Copiar',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: ticketText));
                              if (dialogCtx.mounted) {
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  const SnackBar(
                                    content: Text('¡Texto del comprobante copiado al portapapeles!'),
                                    backgroundColor: AppTheme.accentGreen,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brandPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(LucideIcons.printer, size: 16),
                            label: Text(
                              'Imprimir Ticket',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () async {
                              final escPosBytes = ThermalTicketService.generateEscPosBytes(
                                ticketId: v.idVenta,
                                clienteNombre: v.clienteNombre ?? 'Público General',
                                clienteDocumento: v.clienteDocumento,
                                metodoPago: v.metodoPago,
                                items: items,
                                total: v.total,
                                pagadoCon: v.montoRecibido,
                                vuelto: v.vuelto,
                                cajero: v.usuarioRegistro ?? _username,
                                fecha: v.fechaVenta,
                                width: anchoSeleccionado,
                                nombreComercio: _nombreBodega,
                                rucDni: _rucBodega.isNotEmpty ? _rucBodega : null,
                                direccion: _direccionBodega.isNotEmpty ? _direccionBodega : null,
                                telefono: _telefonoBodega.isNotEmpty ? _telefonoBodega : null,
                                lemaComercial: _lemaBodega.isNotEmpty ? _lemaBodega : null,
                                tipoComprobante: v.tipoComprobante,
                                serieCorrelativo: v.serieCorrelativo,
                                estadoSunat: v.estadoSunat,
                                sunatHash: v.sunatHash,
                              );

                              final res = await ThermalTicketService.imprimirTicketDirecto(
                                escPosBytes: escPosBytes,
                                receiptText: ticketText,
                              );

                              if (dialogCtx.mounted) {
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(res.mensaje),
                                    backgroundColor: res.exito ? AppTheme.accentGreen : AppTheme.alertRed,
                                  ),
                                );
                                Navigator.pop(ctx);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
