import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/secure_storage_service.dart';
import '../../core/theme.dart';
import '../../core/thermal_ticket_service.dart';
import 'boleta_consolidada_service.dart';

class BoletaConsolidadaModal extends StatefulWidget {
  final VoidCallback? onRegistrado;

  const BoletaConsolidadaModal({super.key, this.onRegistrado});

  static Future<void> show(BuildContext context, {VoidCallback? onRegistrado}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BoletaConsolidadaModal(onRegistrado: onRegistrado),
    );
  }

  @override
  State<BoletaConsolidadaModal> createState() => _BoletaConsolidadaModalState();
}

class _BoletaConsolidadaModalState extends State<BoletaConsolidadaModal> {
  final _service = BoletaConsolidadaService();
  final _formKey = GlobalKey<FormState>();

  DateTime _fechaSeleccionada = DateTime.now();
  ResumenVentasMenores? _resumen;
  List<BoletaConsolidadaRecord> _historial = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPrinting = false;
  bool _mostrarHistorial = false;
  String? _errorMessage;

  // Controladores de formulario
  late TextEditingController _serieCtrl;
  late TextEditingController _montoCtrl;
  late TextEditingController _operacionesCtrl;
  late TextEditingController _observacionesCtrl;
  String _tipoEmision = 'TALONARIO_FISICO';

  // Datos de la bodega para impresión térmica
  String _nombreBodega = 'CajaYa POS';
  String? _rucBodega;
  String? _direccionBodega;
  String? _telefonoBodega;
  String? _lemaBodega;

  @override
  void initState() {
    super.initState();
    _serieCtrl = TextEditingController(text: '001-000001');
    _montoCtrl = TextEditingController(text: '0.00');
    _operacionesCtrl = TextEditingController(text: '0');
    _observacionesCtrl = TextEditingController();

    _cargarDatosBodega();
    _cargarDatosFecha();
  }

  @override
  void dispose() {
    _serieCtrl.dispose();
    _montoCtrl.dispose();
    _operacionesCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosBodega() async {
    final results = await Future.wait([
      SecureStorageService.read('nombre_bodega'),
      SecureStorageService.read('ruc_bodega'),
      SecureStorageService.read('direccion_bodega'),
      SecureStorageService.read('telefono_bodega'),
      SecureStorageService.read('lema_comercial'),
    ]);
    final nombre = results[0];
    final ruc = results[1];
    final dir = results[2];
    final tel = results[3];
    final lema = results[4];

    if (mounted) {
      setState(() {
        if (nombre != null && nombre.isNotEmpty) _nombreBodega = nombre;
        _rucBodega = ruc;
        _direccionBodega = dir;
        _telefonoBodega = tel;
        _lemaBodega = lema;
      });
    }
  }

  Future<void> _cargarDatosFecha() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final (resumen, historial) = await (
        _service.obtenerSugerencia(fecha: _fechaSeleccionada),
        _service.listarHistorial(limit: 20),
      ).wait;

      if (mounted) {
        setState(() {
          _resumen = resumen;
          _historial = historial;
          _isLoading = false;

          if (resumen.yaRegistrada) {
            _serieCtrl.text = resumen.serieCorrelativo ?? '001-000001';
            _montoCtrl.text = (resumen.montoRegistrado ?? 0.0).toStringAsFixed(
              2,
            );
            _operacionesCtrl.text =
                (resumen.cantidadOperacionesRegistradas ?? 1).toString();
            _tipoEmision = resumen.tipoEmision ?? 'TALONARIO_FISICO';
            _observacionesCtrl.text = resumen.observaciones ?? '';
          } else {
            _serieCtrl.text = _sugerirSerieCorrelativo();
            _montoCtrl.text = resumen.montoSugerido.toStringAsFixed(2);
            _operacionesCtrl.text = resumen.cantidadOperacionesSugeridas
                .toString();
            _tipoEmision = 'TALONARIO_FISICO';
            _observacionesCtrl.text =
                'Consolidado de ${resumen.cantidadOperacionesSugeridas} ventas de mostrador <= S/ 5.00';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _sugerirSerieCorrelativo() {
    if (_historial.isNotEmpty) {
      final ultimo = _historial.first.serieCorrelativo.trim();
      final partes = ultimo.split('-');
      if (partes.length == 2) {
        final serie = partes[0];
        final numCorrelativo = int.tryParse(partes[1]);
        if (numCorrelativo != null) {
          final nuevoNum = (numCorrelativo + 1).toString().padLeft(
            partes[1].length,
            '0',
          );
          return '$serie-$nuevoNum';
        }
      }
    }
    return '001-000001';
  }

  void _cambiarFecha(int dias) {
    setState(() {
      _fechaSeleccionada = _fechaSeleccionada.add(Duration(days: dias));
    });
    _cargarDatosFecha();
  }

  Future<void> _seleccionarFechaCalendario() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('es', 'PE'),
    );
    if (picked != null && picked != _fechaSeleccionada) {
      setState(() => _fechaSeleccionada = picked);
      _cargarDatosFecha();
    }
  }

  Future<void> _guardarRegistro({bool imprimirAlTerminar = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final operaciones = int.tryParse(_operacionesCtrl.text) ?? 1;
    final serie = _serieCtrl.text.trim().toUpperCase();

    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El monto consolidado debe ser mayor a S/ 0.00'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final resultado = await _service.registrarBoletaConsolidada(
        fecha: _fechaSeleccionada,
        montoTotal: monto,
        cantidadOperaciones: operaciones,
        serieCorrelativo: serie,
        tipoEmision: _tipoEmision,
        observaciones: _observacionesCtrl.text.trim().isNotEmpty
            ? _observacionesCtrl.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Boleta Consolidada $serie registrada exitosamente (S/ ${monto.toStringAsFixed(2)})',
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }

      widget.onRegistrado?.call();

      if (imprimirAlTerminar) {
        await _imprimirTicketRespaldo(resultado);
      }

      await _cargarDatosFecha();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _imprimirTicketRespaldo([
    BoletaConsolidadaRecord? registro,
  ]) async {
    setState(() => _isPrinting = true);
    try {
      final serie =
          registro?.serieCorrelativo ?? _serieCtrl.text.trim().toUpperCase();
      final monto =
          registro?.montoTotal ??
          (double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0.0);
      final ops =
          registro?.cantidadOperaciones ??
          (int.tryParse(_operacionesCtrl.text) ?? 1);
      final tipo = registro?.tipoEmision ?? _tipoEmision;
      final obs =
          registro?.observaciones ??
          (_observacionesCtrl.text.trim().isNotEmpty
              ? _observacionesCtrl.text.trim()
              : null);
      final regFecha = registro?.fechaRegistro ?? DateTime.now();

      final result = await ThermalTicketService.imprimirBoletaConsolidada(
        serieCorrelativo: serie,
        fechaEmision: _fechaSeleccionada,
        montoTotal: monto,
        cantidadOperaciones: ops,
        tipoEmision: tipo,
        observaciones: obs,
        fechaRegistro: regFecha,
        nombreComercio: _nombreBodega,
        rucDni: _rucBodega,
        direccion: _direccionBodega,
        telefono: _telefonoBodega,
        lemaComercial: _lemaBodega,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.mensaje),
            backgroundColor: result.exito
                ? AppTheme.accentGreen
                : AppTheme.alertRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al imprimir: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141724) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1E2436)
        : const Color(0xFFE2E8F0);

    final d = _fechaSeleccionada;
    final fechaLabel =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final esHoy =
        d.year == DateTime.now().year &&
        d.month == DateTime.now().month &&
        d.day == DateTime.now().day;

    return Dialog(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 780),
        child: Column(
          children: [
            // Header del Modal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.receiptText,
                      color: AppTheme.accentGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Boleta Consolidada Diaria',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Ventas <= S/ 5.00 sin comprobante • Res. SUNAT 007-99',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.getAdaptiveMutedText(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 20),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),

            // Selector de Fecha Dinámico
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? const Color(0xFF0F121C) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft, size: 18),
                    tooltip: 'Día anterior',
                    onPressed: () => _cambiarFecha(-1),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _seleccionarFechaCalendario,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              LucideIcons.calendar,
                              size: 16,
                              color: AppTheme.brandPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              esHoy ? '$fechaLabel (Hoy)' : fechaLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.chevronRight, size: 18),
                    tooltip: 'Día siguiente',
                    onPressed: esHoy ? null : () => _cambiarFecha(1),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: AppTheme.brandPrimary,
                    ),
                    icon: Icon(
                      _mostrarHistorial
                          ? LucideIcons.receipt
                          : LucideIcons.history,
                      size: 16,
                    ),
                    label: Text(
                      _mostrarHistorial ? 'Formulario' : 'Historial',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      setState(() => _mostrarHistorial = !_mostrarHistorial);
                    },
                  ),
                ],
              ),
            ),

            // Contenido Scrolleable
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.brandPrimary,
                      ),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.alertTriangle,
                            size: 40,
                            color: AppTheme.alertRed,
                          ),
                          const SizedBox(height: 12),
                          Text(_errorMessage!),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _cargarDatosFecha,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : _mostrarHistorial
                  ? _buildVistaHistorial(isDark, borderColor)
                  : _buildVistaRegistro(isDark, borderColor),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista del Formulario y Sugerencia del Día
  Widget _buildVistaRegistro(bool isDark, Color borderColor) {
    final resumen = _resumen;
    final yaRegistrada = resumen?.yaRegistrada == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Estado de la fecha seleccionada
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: yaRegistrada
                    ? AppTheme.accentGreen.withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: yaRegistrada
                      ? AppTheme.accentGreen.withValues(alpha: 0.4)
                      : Colors.amber.shade700.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    yaRegistrada
                        ? LucideIcons.checkCircle2
                        : LucideIcons.alertCircle,
                    color: yaRegistrada
                        ? AppTheme.accentGreen
                        : Colors.amber.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          yaRegistrada
                              ? 'Boleta Consolidada Registrada para esta fecha'
                              : 'Boleta Consolidada Pendiente para esta fecha',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: yaRegistrada
                                ? AppTheme.accentGreen
                                : Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          yaRegistrada
                              ? 'Boleta N° ${resumen!.serieCorrelativo} por S/ ${resumen.montoRegistrado?.toStringAsFixed(2)} (${resumen.cantidadOperacionesRegistradas} ventas). Cumple con SUNAT.'
                              : 'Según el Reglamento de Comprobantes de Pago de SUNAT, al terminar la jornada debes emitir una boleta que sume todas las compras menores o iguales a S/ 5.00 que no pidieron boleta.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Tarjeta con Sugerencia Calculada Automáticamente
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.sparkles,
                        size: 16,
                        color: AppTheme.brandPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cálculo Automático de Ventas en Mostrador <= S/ 5.00',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2436)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tickets emitidos <= S/ 5.00',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppTheme.getAdaptiveMutedText(isDark),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${resumen?.cantidadOperacionesSugeridas ?? 0} ventas',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.brandPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2436)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monto Total Acumulado',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppTheme.getAdaptiveMutedText(isDark),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'S/ ${(resumen?.montoSugerido ?? 0.0).toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Formulario de Emisión / Registro
            Text(
              'Datos de la Boleta Consolidada',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),

            // Selector Tipo de Emisión
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        setState(() => _tipoEmision = 'TALONARIO_FISICO'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _tipoEmision == 'TALONARIO_FISICO'
                            ? AppTheme.brandPrimary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _tipoEmision == 'TALONARIO_FISICO'
                              ? AppTheme.brandPrimary
                              : borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.bookOpen,
                            size: 16,
                            color: _tipoEmision == 'TALONARIO_FISICO'
                                ? AppTheme.brandPrimary
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Talonario Físico (Papel)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: _tipoEmision == 'TALONARIO_FISICO'
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _tipoEmision == 'TALONARIO_FISICO'
                                  ? AppTheme.brandPrimary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        setState(() => _tipoEmision = 'DIGITAL_CAJAYA'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _tipoEmision == 'DIGITAL_CAJAYA'
                            ? AppTheme.brandPrimary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _tipoEmision == 'DIGITAL_CAJAYA'
                              ? AppTheme.brandPrimary
                              : borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.printer,
                            size: 16,
                            color: _tipoEmision == 'DIGITAL_CAJAYA'
                                ? AppTheme.brandPrimary
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Digital CajaYa',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: _tipoEmision == 'DIGITAL_CAJAYA'
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _tipoEmision == 'DIGITAL_CAJAYA'
                                  ? AppTheme.brandPrimary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Campos de Serie, Monto y Operaciones
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _serieCtrl,
                    decoration: InputDecoration(
                      labelText: 'N° Boleta / Serie-Número',
                      hintText: '001-000456',
                      prefixIcon: const Icon(LucideIcons.hash, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingrese el número de boleta'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monto Total (S/)',
                      prefixIcon: const Icon(LucideIcons.coins, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      final numVal = double.tryParse(v.replaceAll(',', '.'));
                      if (numVal == null || numVal <= 0)
                        return 'Monto inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _operacionesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Cant. Ventas',
                      prefixIcon: const Icon(LucideIcons.layers, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      final numVal = int.tryParse(v);
                      if (numVal == null || numVal <= 0) return 'Mín. 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Campo de Observaciones / Notas
            TextFormField(
              controller: _observacionesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notas / Observaciones (Opcional)',
                hintText:
                    'Ej. Consolidado de ventas de mostrador del turno tarde',
                prefixIcon: const Icon(LucideIcons.fileText, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),

            // Botones de Acción
            Row(
              children: [
                if (yaRegistrada)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.printer, size: 18),
                      label: Text(
                        'Imprimir Respaldo',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                      ),
                      onPressed: _isPrinting
                          ? null
                          : () => _imprimirTicketRespaldo(),
                    ),
                  ),
                if (yaRegistrada) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(LucideIcons.checkCheck, size: 18),
                    label: Text(
                      yaRegistrada ? 'Actualizar Registro' : 'Registrar Boleta',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _isSaving ? null : () => _guardarRegistro(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Vista de Historial de Boletas Consolidadas Anteriores
  Widget _buildVistaHistorial(bool isDark, Color borderColor) {
    if (_historial.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.history,
                size: 40,
                color: AppTheme.getAdaptiveMutedText(isDark),
              ),
              const SizedBox(height: 12),
              Text(
                'Aún no hay boletas consolidadas registradas',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Registra tu primera boleta diaria para mantener tu sustento fiscal ante SUNAT.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppTheme.getAdaptiveMutedText(isDark),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _historial.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final b = _historial[index];
        final fd = b.fechaEmision;
        final fdStr =
            '${fd.day.toString().padLeft(2, '0')}/${fd.month.toString().padLeft(2, '0')}/${fd.year}';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.fileCheck2,
                  color: AppTheme.accentGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Boleta N° ${b.serieCorrelativo}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: b.tipoEmision == 'TALONARIO_FISICO'
                                ? Colors.blue.withValues(alpha: 0.12)
                                : Colors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            b.tipoEmision == 'TALONARIO_FISICO'
                                ? 'FÍSICO'
                                : 'DIGITAL',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: b.tipoEmision == 'TALONARIO_FISICO'
                                  ? Colors.blue.shade700
                                  : Colors.teal.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Fecha de Ventas: $fdStr • ${b.cantidadOperaciones} ventas consolidadas',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/ ${b.montoTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(LucideIcons.printer, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Reimprimir respaldo térmico',
                    onPressed: () => _imprimirTicketRespaldo(b),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
