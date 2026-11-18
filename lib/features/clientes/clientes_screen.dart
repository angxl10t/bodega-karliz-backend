import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/csv_exporter.dart';
import '../../core/theme.dart';
import '../../core/debouncer.dart';
import '../home/bodega_service.dart';
import 'cliente_model.dart';
import 'cliente_service.dart';
import 'nuevo_cliente_sheet.dart';
import 'registrar_abono_sheet.dart';
import 'estado_cuenta_modal.dart';
import 'garantia_botella_model.dart';
import 'garantia_botella_service.dart';
import 'nueva_garantia_sheet.dart';
import 'devolver_botella_dialog.dart';
import '../../core/widgets/tab_deferred_refresh.dart';

class ClientesScreen extends StatefulWidget {
  final int initialTabIndex;
  final ValueListenable<int>? activeTabNotifier;
  final int? tabIndex;

  const ClientesScreen({
    super.key,
    this.initialTabIndex = 0,
    this.activeTabNotifier,
    this.tabIndex,
  });

  /// Notificador reactivo para permitir que otras pantallas (como DashboardScreen o POS)
  /// cambien suavemente de pestaña entre Libreta de Fiados (0) y Garantía de Botellas (1).
  static final ValueNotifier<int> tabRequestNotifier = ValueNotifier<int>(0);

  static void cambiarPestana(int tabIndex) {
    tabRequestNotifier.value = tabIndex;
  }

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen>
    with
        SingleTickerProviderStateMixin,
        TabDeferredRefreshMixin<ClientesScreen> {
  late TabController _tabController;
  final ClienteService _clienteService = ClienteService();
  final GarantiaBotellaService _garantiaService = GarantiaBotellaService();
  final BodegaService _bodegaService = BodegaService();

  @override
  ValueListenable<int>? get tabVisibilityNotifier => widget.activeTabNotifier;

  @override
  int? get assignedTabIndex => widget.tabIndex;

  @override
  void onDeferredTabRefresh() => _cargarDatos(forceRefresh: true);

  List<Cliente> _clientes = [];
  ResumenCreditos? _resumen;
  BodegaInfo? _bodegaInfo;

  List<GarantiaBotella> _garantias = [];
  ResumenGarantias? _resumenGarantias;

  bool _isLoading = true;
  String _filtroTexto = '';
  String _filtroEstado = 'todos'; // 'todos', 'deudores', 'al_dia'

  String _filtroTextoGarantias = '';
  String _filtroEstadoGarantias =
      'PENDIENTE'; // 'PENDIENTE', 'DEVUELTO', 'TODAS'

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _searchCtrlGarantias = TextEditingController();
  final Debouncer _clientesDebouncer = Debouncer();
  final Debouncer _garantiasDebouncer = Debouncer();

  @override
  void initState() {
    super.initState();
    initTabVisibilityListener();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    ClientesScreen.tabRequestNotifier.addListener(_onTabRequest);
    ClienteService.clientesRevision.addListener(_onRevisionChanged);
    GarantiaBotellaService.garantiasRevision.addListener(_onRevisionChanged);
    _cargarDatos();
  }

  void _onTabRequest() {
    final target = ClientesScreen.tabRequestNotifier.value;
    if (mounted && target >= 0 && target < _tabController.length) {
      if (_tabController.index != target) {
        _tabController.animateTo(target);
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    disposeTabVisibilityListener();
    ClientesScreen.tabRequestNotifier.removeListener(_onTabRequest);
    _tabController.dispose();
    ClienteService.clientesRevision.removeListener(_onRevisionChanged);
    GarantiaBotellaService.garantiasRevision.removeListener(_onRevisionChanged);
    _clientesDebouncer.dispose();
    _garantiasDebouncer.dispose();
    _searchCtrl.dispose();
    _searchCtrlGarantias.dispose();
    super.dispose();
  }

  void _onRevisionChanged() {
    runWhenTabVisible(() => _cargarDatos(forceRefresh: true));
  }

  Future<void> _cargarDatos({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _clienteService.getClientes(forceRefresh: forceRefresh),
        _clienteService.getResumenCreditos(),
        _bodegaService.obtenerMiBodega(),
        _garantiaService.getGarantias(forceRefresh: forceRefresh),
        _garantiaService.getResumenGarantias(),
      ]);

      if (mounted) {
        setState(() {
          _clientes = results[0] as List<Cliente>;
          _resumen = results[1] as ResumenCreditos?;
          _bodegaInfo = results[2] as BodegaInfo?;
          _garantias = results[3] as List<GarantiaBotella>;
          _resumenGarantias = results[4] as ResumenGarantias?;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Cliente> get _clientesFiltrados {
    final q = _filtroTexto.trim().toLowerCase();
    return _clientes.where((c) {
      // 1. Filtro por texto
      if (q.isNotEmpty) {
        final matchNom = c.nombreCompleto.toLowerCase().contains(q);
        final matchDoc = (c.documento ?? '').toLowerCase().contains(q);
        final matchTel = (c.telefono ?? '').toLowerCase().contains(q);
        if (!matchNom && !matchDoc && !matchTel) return false;
      }

      // 2. Filtro por estado
      if (_filtroEstado == 'deudores') {
        return c.tieneDeuda;
      } else if (_filtroEstado == 'al_dia') {
        return !c.tieneDeuda;
      } else if (_filtroEstado == 'caseritos') {
        return c.esCaserito;
      }
      return true;
    }).toList();
  }

  void _abrirNuevoCliente([Cliente? c]) {
    HapticFeedback.lightImpact();
    NuevoClienteSheet.show(
      context,
      cliente: c,
      onGuardado: () => _cargarDatos(forceRefresh: true),
    );
  }

  void _abrirRegistrarAbono(Cliente c) {
    HapticFeedback.selectionClick();
    RegistrarAbonoSheet.show(
      context,
      cliente: c,
      nombreBodega: _bodegaInfo?.nombreComercial ?? 'CajaYa POS',
      onAbonoExitoso: () => _cargarDatos(forceRefresh: true),
    );
  }

  void _abrirEstadoCuenta(Cliente c) {
    HapticFeedback.lightImpact();
    EstadoCuentaModal.show(
      context,
      cliente: c,
      nombreBodega: _bodegaInfo?.nombreComercial ?? 'CajaYa POS',
    );
  }

  void _enviarWhatsAppRecordatorio(Cliente c) async {
    HapticFeedback.mediumImpact();
    final ok = await ClienteService.abrirWhatsAppRecordatorio(
      cliente: c,
      nombreBodega: _bodegaInfo?.nombreComercial ?? 'CajaYa POS',
      numeroYape: _bodegaInfo?.telefono,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El cliente no tiene un teléfono válido registrado'),
        ),
      );
    }
  }

  Future<void> _exportarCsv() async {
    if (_clientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay clientes registrados en la libreta para exportar.',
          ),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final fechaStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final nombreArchivo = 'libreta_fiados_$fechaStr.csv';
    final csv = CsvExporter.generarCsvClientes(_clientes);
    await CsvExporter.descargarOCompartirCsv(
      nombreArchivo: nombreArchivo,
      contenidoCsv: csv,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? '¡Libreta de fiados descargada como $nombreArchivo!'
                : '¡Libreta de fiados exportada y copiada al portapapeles!',
          ),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  void _confirmarEliminarCliente(Cliente c) {
    if (c.tieneDeuda) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No puede eliminar a ${c.nombreCompleto} porque mantiene una deuda pendiente de S/ ${c.saldoDeudor.toStringAsFixed(2)}.',
          ),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dar de Baja Cliente'),
        content: Text(
          '¿Está seguro de dar de baja a "${c.nombreCompleto}" de la libreta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _clienteService.eliminarCliente(c.idCliente!);
                _cargarDatos(forceRefresh: true);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  List<GarantiaBotella> get _garantiasFiltradas {
    final q = _filtroTextoGarantias.trim().toLowerCase();
    return _garantias.where((g) {
      if (q.isNotEmpty) {
        final matchNom = g.nombrePersona.toLowerCase().contains(q);
        final matchTel = (g.telefono ?? '').toLowerCase().contains(q);
        final matchTipo = g.tipoBotella.toLowerCase().contains(q);
        if (!matchNom && !matchTel && !matchTipo) return false;
      }
      if (_filtroEstadoGarantias == 'PENDIENTE') {
        return g.estaPendiente;
      } else if (_filtroEstadoGarantias == 'DEVUELTO') {
        return g.estaDevuelto;
      }
      return true;
    }).toList();
  }

  void _abrirNuevaGarantia() {
    HapticFeedback.lightImpact();
    NuevaGarantiaSheet.show(
      context,
      clientesDisponibles: _clientes,
      onGuardado: () => _cargarDatos(forceRefresh: true),
    );
  }

  void _abrirDevolverBotella(GarantiaBotella g) {
    HapticFeedback.selectionClick();
    DevolverBotellaDialog.show(
      context,
      garantia: g,
      onDevuelto: () => _cargarDatos(forceRefresh: true),
    );
  }

  void _confirmarEliminarGarantia(GarantiaBotella g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Registro'),
        content: Text(
          '¿Está seguro de eliminar el registro de garantía de botellas para "${g.nombrePersona}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _garantiaService.eliminarGarantia(g.idGarantia);
                _cargarDatos(forceRefresh: true);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 720;
    final isNarrow = screenWidth < 500;

    final totalPorCobrar = _resumen?.totalSaldoDeudor ?? 0.0;
    final vecinosDeudores = _resumen?.clientesConDeuda ?? 0;
    final cobradoMes = _resumen?.totalAbonosMes ?? 0.0;
    final totalVecinos = _clientes.length;
    final vecinosAlDia = (totalVecinos - vecinosDeudores).clamp(
      0,
      totalVecinos,
    );
    final creditoTotal = _clientes.fold<double>(
      0.0,
      (acc, c) => acc + c.limiteCredito,
    );
    final botellasPendientes =
        _resumenGarantias?.botellasPendientes ??
        _garantias
            .where((g) => g.estaPendiente)
            .fold<int>(0, (acc, g) => acc + g.botellasRestantes);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      appBar: canPop
          ? AppBar(
              titleSpacing: 16,
              elevation: 0,
              backgroundColor: cardBg,
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fiados y Garantías de Botellas',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'Cuentas por cobrar y control de envases retornables',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Exportar CSV',
                  icon: const Icon(LucideIcons.download, size: 18),
                  onPressed: _exportarCsv,
                ),
                IconButton(
                  tooltip: 'Refrescar',
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  onPressed: () => _cargarDatos(forceRefresh: true),
                ),
              ],
            )
          : null,
      floatingActionButton: isWide
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _tabController.index == 0
                  ? AppTheme.brandPrimary
                  : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: Icon(
                _tabController.index == 0
                    ? LucideIcons.userPlus
                    : LucideIcons.bottleWine,
                size: 18,
              ),
              label: Text(
                _tabController.index == 0 ? 'Nuevo Vecino' : 'Dejar Botellas',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                if (_tabController.index == 0) {
                  _abrirNuevoCliente();
                } else {
                  _abrirNuevaGarantia();
                }
              },
            ),
      body: RefreshIndicator(
        onRefresh: () => _cargarDatos(forceRefresh: true),
        color: AppTheme.brandPrimary,
        child: Column(
          children: [
            // 1. Cabecera Compacta Integrada (cuando está embebido en HomeScreen)
            if (!canPop)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: cardBg,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _tabController.index == 0
                                ? 'Libreta de Fiados'
                                : 'Garantía de Botellas',
                            style: GoogleFonts.outfit(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (_tabController.index == 0)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '$totalVecinos vecinos',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : AppTheme.textMuted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  vecinosDeudores > 0
                                      ? '$vecinosDeudores con saldo'
                                      : 'Todos al día',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: vecinosDeudores > 0
                                        ? (isDark
                                              ? const Color(0xFFF87171)
                                              : AppTheme.alertRed)
                                        : AppTheme.accentGreen,
                                  ),
                                ),
                              ],
                            )
                          else
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${_garantias.length} registros',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : AppTheme.textMuted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  botellasPendientes > 0
                                      ? '$botellasPendientes envases pendientes'
                                      : 'Sin envases pendientes',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: botellasPendientes > 0
                                        ? const Color(0xFF2563EB)
                                        : AppTheme.accentGreen,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Botón Exportar CSV
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _exportarCsv();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 7 : 9,
                            vertical: 6.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.cardDarkElevated
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.borderDark
                                  : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.download,
                                size: 13,
                                color: AppTheme.accentGreen,
                              ),
                              if (!isNarrow) ...[
                                const SizedBox(width: 4),
                                Text(
                                  'CSV',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Botón Refrescar
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _cargarDatos(forceRefresh: true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.cardDarkElevated
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.borderDark
                                  : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            LucideIcons.refreshCw,
                            size: 13,
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    // Botón + Acción según pestaña activa (solo en pantallas anchas, en móvil está el FAB)
                    if (isWide) ...[
                      const SizedBox(width: 6),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (_tabController.index == 0) {
                              _abrirNuevoCliente();
                            } else {
                              _abrirNuevaGarantia();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6.5,
                            ),
                            decoration: BoxDecoration(
                              color: _tabController.index == 0
                                  ? AppTheme.brandPrimary
                                  : const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (_tabController.index == 0
                                              ? AppTheme.brandPrimary
                                              : const Color(0xFF2563EB))
                                          .withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _tabController.index == 0
                                      ? LucideIcons.userPlus
                                      : LucideIcons.bottleWine,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _tabController.index == 0
                                      ? 'Nuevo'
                                      : 'Dejar Botellas',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Selector de Pestaña: Libreta de Fiados vs Garantía de Botellas
            _buildTabBar(isDark, isNarrow, totalVecinos, botellasPendientes),

            // Contenido según Pestaña
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabFiados(
                    isDark: isDark,
                    cardBg: cardBg,
                    isWide: isWide,
                    totalPorCobrar: totalPorCobrar,
                    vecinosDeudores: vecinosDeudores,
                    cobradoMes: cobradoMes,
                    vecinosAlDia: vecinosAlDia,
                    creditoTotal: creditoTotal,
                  ),
                  _buildTabGarantias(
                    isDark: isDark,
                    cardBg: cardBg,
                    isWide: isWide,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(
    bool isDark,
    bool isNarrow,
    int totalVecinos,
    int botellasPendientes,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        mouseCursor: SystemMouseCursors.click,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        onTap: (_) => HapticFeedback.selectionClick(),
        indicator: BoxDecoration(
          color: _tabController.index == 0
              ? AppTheme.brandPrimary
              : const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color:
                  (_tabController.index == 0
                          ? AppTheme.brandPrimary
                          : const Color(0xFF2563EB))
                      .withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF475569),
        labelStyle: GoogleFonts.outfit(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        labelPadding: EdgeInsets.zero,
        tabs: [
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.bookUser, size: 14),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    isNarrow
                        ? 'Fiados ($totalVecinos)'
                        : 'Libreta de Fiados ($totalVecinos)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.bottleWine, size: 14),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    isNarrow
                        ? 'Botellas ($botellasPendientes)'
                        : 'Garantía Botellas ($botellasPendientes)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabFiados({
    required bool isDark,
    required Color cardBg,
    required bool isWide,
    required double totalPorCobrar,
    required int vecinosDeudores,
    required double cobradoMes,
    required int vecinosAlDia,
    required double creditoTotal,
  }) {
    final clientesFiltrados = _clientesFiltrados;
    return Column(
      children: [
        _buildKpisSection(
          isDark: isDark,
          totalPorCobrar: totalPorCobrar,
          vecinosDeudores: vecinosDeudores,
          cobradoMes: cobradoMes,
          vecinosAlDia: vecinosAlDia,
          creditoTotal: creditoTotal,
        ),
        _buildToolbar(isDark, cardBg, isWide, vecinosDeudores, vecinosAlDia),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : clientesFiltrados.isEmpty
              ? _buildEmptyState(isDark)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 720) {
                      return GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 480,
                              mainAxisExtent: 308,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                        itemCount: clientesFiltrados.length,
                        itemBuilder: (context, idx) {
                          final c = clientesFiltrados[idx];
                          return _buildClienteCard(c, isDark);
                        },
                      );
                    } else {
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: clientesFiltrados.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final c = clientesFiltrados[idx];
                          return _buildClienteCard(c, isDark);
                        },
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTabGarantias({
    required bool isDark,
    required Color cardBg,
    required bool isWide,
  }) {
    final garantiasFiltradas = _garantiasFiltradas;
    return Column(
      children: [
        _buildKpisGarantias(isDark),
        _buildToolbarGarantias(isDark, cardBg, isWide),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : garantiasFiltradas.isEmpty
              ? _buildEmptyStateGarantias(isDark)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 720) {
                      return GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 480,
                              mainAxisExtent: 308,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                        itemCount: garantiasFiltradas.length,
                        itemBuilder: (context, idx) {
                          final g = garantiasFiltradas[idx];
                          return _buildGarantiaCard(g, isDark);
                        },
                      );
                    } else {
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: garantiasFiltradas.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final g = garantiasFiltradas[idx];
                          return _buildGarantiaCard(g, isDark);
                        },
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildKpisGarantias(bool isDark) {
    final totalCustodia = _resumenGarantias?.totalDineroCustodia ?? 0.0;
    final botellasPend = _resumenGarantias?.botellasPendientes ?? 0;
    final personasPend = _resumenGarantias?.personasPendientes ?? 0;
    final devueltoMes = _resumenGarantias?.totalDevueltoMes ?? 0.0;

    final card1 = _buildKpiCard(
      isDark: isDark,
      icon: LucideIcons.handCoins,
      title: 'Dinero en Custodia',
      value: 'S/ ${totalCustodia.toStringAsFixed(2)}',
      subtitle: 'Garantía en caja',
      accentColor: AppTheme.accentGreen,
    );

    final card2 = _buildKpiCard(
      isDark: isDark,
      icon: LucideIcons.bottleWine,
      title: 'Botellas Fuera',
      value: '$botellasPend botellas',
      subtitle: 'Por devolver',
      accentColor: AppTheme.warningAmber,
    );

    final card3 = _buildKpiCard(
      isDark: isDark,
      icon: LucideIcons.users,
      title: 'Personas Activas',
      value: '$personasPend personas',
      subtitle: 'Con envases pendientes',
      accentColor: const Color(0xFF2563EB),
    );

    final card4 = _buildKpiCard(
      isDark: isDark,
      icon: LucideIcons.packageCheck,
      title: 'Devuelto Mes',
      value: 'S/ ${devueltoMes.toStringAsFixed(2)}',
      subtitle: '${_resumenGarantias?.botellasDevueltasMes ?? 0} recuperadas',
      accentColor: AppTheme.accentGreen,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return Row(
              children: [
                Expanded(child: card1),
                const SizedBox(width: 10),
                Expanded(child: card2),
                const SizedBox(width: 10),
                Expanded(child: card3),
                const SizedBox(width: 10),
                Expanded(child: card4),
              ],
            );
          } else {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: card1),
                    const SizedBox(width: 8),
                    Expanded(child: card2),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: card3),
                    const SizedBox(width: 8),
                    Expanded(child: card4),
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildToolbarGarantias(bool isDark, Color cardBg, bool isWide) {
    final pendientesCount = _garantias.where((g) => g.estaPendiente).length;
    final devueltasCount = _garantias.where((g) => g.estaDevuelto).length;

    final chips = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFiltroGarantiaChip(
            'PENDIENTE',
            'Pendientes ($pendientesCount)',
            isDark,
          ),
          _buildFiltroGarantiaChip(
            'DEVUELTO',
            'Devueltas ($devueltasCount)',
            isDark,
          ),
          _buildFiltroGarantiaChip('TODAS', 'Todas', isDark),
        ],
      ),
    );

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            Expanded(child: _buildSearchTextFieldGarantias(isDark)),
            const SizedBox(width: 10),
            chips,
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(LucideIcons.bottleWine, size: 15),
              label: Text(
                'Dejar Botellas',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: _abrirNuevaGarantia,
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        child: Column(
          children: [
            _buildSearchTextFieldGarantias(isDark),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: chips,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSearchTextFieldGarantias(bool isDark) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
        ),
      ),
      child: TextField(
        controller: _searchCtrlGarantias,
        onChanged: (val) => _garantiasDebouncer.run(() {
          if (mounted) setState(() => _filtroTextoGarantias = val);
        }),
        onSubmitted: (val) {
          _garantiasDebouncer.cancel();
          setState(() => _filtroTextoGarantias = val);
        },
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppTheme.textDark,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar persona, teléfono o botella...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: AppTheme.getAdaptiveHintText(isDark),
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 16,
            color: AppTheme.getAdaptiveHintText(isDark),
          ),
          suffixIcon: _filtroTextoGarantias.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 15),
                  onPressed: () {
                    _garantiasDebouncer.cancel();
                    _searchCtrlGarantias.clear();
                    setState(() => _filtroTextoGarantias = '');
                  },
                )
              : null,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFiltroGarantiaChip(String clave, String label, bool isDark) {
    final isSelected = _filtroEstadoGarantias == clave;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filtroEstadoGarantias = clave);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildGarantiaCard(GarantiaBotella g, bool isDark) {
    final isPendiente = g.estaPendiente;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPendiente
              ? const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.4 : 0.3)
              : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
          width: isPendiente ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4.5,
                color: isPendiente
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF16A34A),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  (isPendiente
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF16A34A))
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isPendiente
                                  ? LucideIcons.bottleWine
                                  : LucideIcons.packageCheck,
                              size: 18,
                              color: isPendiente
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.nombrePersona,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (g.telefono != null &&
                                    g.telefono!.isNotEmpty)
                                  Text(
                                    'Tel: ${g.telefono}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isPendiente
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF16A34A))
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isPendiente
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isPendiente ? 'PENDIENTE' : 'DEVUELTO',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: isPendiente
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.borderDark
                                : const Color(0xFFF1F5F9),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${g.cantidadBotellas} ${g.cantidadBotellas == 1 ? "botella" : "botellas"} • ${g.tipoBotella}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                  ),
                                  if (g.botellasDevueltas > 0 && isPendiente)
                                    Text(
                                      '(${g.botellasDevueltas} entregadas, quedan ${g.botellasRestantes})',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        color: const Color(0xFF16A34A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (g.notas != null && g.notas!.isNotEmpty)
                                    Text(
                                      g.notas!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppTheme.getAdaptiveMutedText(
                                          isDark,
                                        ),
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isPendiente
                                      ? 'Dinero en Custodia:'
                                      : 'Dinero Devuelto:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.getAdaptiveMutedText(
                                      isDark,
                                    ),
                                  ),
                                ),
                                Text(
                                  'S/ ${(isPendiente ? g.montoRestante : g.montoDevuelto).toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isPendiente
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF2563EB),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.calendar,
                            size: 12,
                            color: AppTheme.getAdaptiveMutedText(isDark),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            g.fechaRegistro != null
                                ? '${g.fechaRegistro!.day.toString().padLeft(2, "0")}/${g.fechaRegistro!.month.toString().padLeft(2, "0")} ${g.fechaRegistro!.hour.toString().padLeft(2, "0")}:${g.fechaRegistro!.minute.toString().padLeft(2, "0")}'
                                : 'Hoy',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              color: AppTheme.getAdaptiveMutedText(isDark),
                            ),
                          ),
                          if (g.fechaDevolucion != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: AppTheme.getAdaptiveMutedText(isDark),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              LucideIcons.check,
                              size: 12,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Devuelto: ${g.fechaDevolucion!.day.toString().padLeft(2, "0")}/${g.fechaDevolucion!.month.toString().padLeft(2, "0")}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: const Color(0xFF16A34A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              LucideIcons.trash2,
                              size: 15,
                              color: Color(0xFFEF4444),
                            ),
                            tooltip: 'Eliminar Registro',
                            onPressed: () => _confirmarEliminarGarantia(g),
                          ),
                        ],
                      ),
                      if (isPendiente) ...[
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(
                              LucideIcons.packageCheck,
                              size: 15,
                            ),
                            label: Text(
                              'Devolver Botella(s) y Entregar S/ ${g.montoRestante.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: () => _abrirDevolverBotella(g),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateGarantias(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2563EB)
                      .withValues(alpha: isDark ? 0.15 : 0.08),
                  border: Border.all(
                    color: const Color(0xFF2563EB)
                        .withValues(alpha: isDark ? 0.35 : 0.22),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2563EB)
                          .withValues(alpha: isDark ? 0.25 : 0.14),
                    ),
                    child: const Icon(
                      LucideIcons.bottleWine,
                      size: 26,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Control de Garantías de Botellas',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Registra a las personas que dejan dinero en custodia por botellas de vidrio de cerveza o gaseosa. Al devolver el envase, se le reintegra su dinero con un solo toque.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : AppTheme.textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(
                  'Registrar Primera Garantía',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: _abrirNuevaGarantia,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpisSection({
    required bool isDark,
    required double totalPorCobrar,
    required int vecinosDeudores,
    required double cobradoMes,
    required int vecinosAlDia,
    required double creditoTotal,
  }) {
    final cardPorCobrar = _buildKpiCard(
      isDark: isDark,
      icon: LucideIcons.handCoins,
      title: 'Por Cobrar',
      value: 'S/ ${totalPorCobrar.toStringAsFixed(2)}',
      subtitle: '$vecinosDeudores vecinos con saldo',
      accentColor: AppTheme.alertRed,
    );

    final cardCobradoMes = _buildKpiCard(
      isDark: isDark,
      icon: LucideIcons.checkCheck,
      title: 'Cobrado Mes',
      value: 'S/ ${cobradoMes.toStringAsFixed(2)}',
      subtitle: 'Recuperado a la fecha',
      accentColor: AppTheme.accentGreen,
    );

    final cardVecinosAlDia = _buildKpiCard(
      isDark: isDark,
      icon: LucideIcons.shieldCheck,
      title: 'Vecinos al Día',
      value: '$vecinosAlDia vecinos',
      subtitle:
          '${_clientes.isNotEmpty ? ((vecinosAlDia / _clientes.length) * 100).toStringAsFixed(0) : 100}% de la cartera',
      accentColor: const Color(0xFF2563EB),
    );

    final cardCreditoTotal = _buildKpiCard(
      isDark: isDark,
      icon: LucideIcons.wallet,
      title: 'Crédito Total',
      value: 'S/ ${creditoTotal.toStringAsFixed(0)}',
      subtitle: 'Límite vecinal activo',
      accentColor: const Color(0xFF6366F1),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return Row(
              children: [
                Expanded(child: cardPorCobrar),
                const SizedBox(width: 10),
                Expanded(child: cardCobradoMes),
                const SizedBox(width: 10),
                Expanded(child: cardVecinosAlDia),
                const SizedBox(width: 10),
                Expanded(child: cardCreditoTotal),
              ],
            );
          } else {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: cardPorCobrar),
                    const SizedBox(width: 8),
                    Expanded(child: cardCobradoMes),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: cardVecinosAlDia),
                    const SizedBox(width: 8),
                    Expanded(child: cardCreditoTotal),
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildKpiCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
  }) {
    final effectiveAccent = isDark
        ? (accentColor == AppTheme.alertRed ||
                  accentColor == const Color(0xFFEF4444)
              ? const Color(0xFFF87171)
              : accentColor == AppTheme.accentGreen ||
                    accentColor == const Color(0xFF10B981) ||
                    accentColor == const Color(0xFF16A34A) ||
                    accentColor == const Color(0xFF059669)
              ? const Color(0xFF34D399)
              : accentColor == AppTheme.brandPrimary ||
                    accentColor == const Color(0xFF2563EB)
              ? const Color(0xFF60A5FA)
              : accentColor == const Color(0xFF7C3AED) ||
                    accentColor == const Color(0xFF6366F1) ||
                    accentColor == const Color(0xFF6D28D9)
              ? const Color(0xFFA78BFA)
              : accentColor == AppTheme.warningAmber ||
                    accentColor == const Color(0xFFF59E0B) ||
                    accentColor == const Color(0xFFD97706)
              ? const Color(0xFFFBBF24)
              : accentColor)
        : accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: effectiveAccent.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: effectiveAccent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.outfit(
                fontSize: 18.5,
                fontWeight: FontWeight.w900,
                color: (accentColor == AppTheme.alertRed)
                    ? (isDark ? const Color(0xFFF87171) : AppTheme.alertRed)
                    : (accentColor == AppTheme.accentGreen ||
                          accentColor == const Color(0xFF16A34A))
                    ? (isDark ? const Color(0xFF34D399) : AppTheme.accentGreen)
                    : (isDark ? Colors.white : AppTheme.textDark),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    bool isDark,
    Color cardBg,
    bool isWide,
    int vecinosDeudores,
    int vecinosAlDia,
  ) {
    final vecinosCaseritos = _clientes.where((c) => c.esCaserito).length;

    final chips = [
      _buildFiltroChip('todos', 'Todos (${_clientes.length})', isDark),
      _buildFiltroChip(
        'deudores',
        'Con Deuda ($vecinosDeudores)',
        isDark,
        dotColor: AppTheme.alertRed,
      ),
      _buildFiltroChip(
        'al_dia',
        'Al Día ($vecinosAlDia)',
        isDark,
        dotColor: AppTheme.accentGreen,
      ),
      if (vecinosCaseritos > 0)
        _buildFiltroChip(
          'caseritos',
          'Caseritos ($vecinosCaseritos)',
          isDark,
          icon: LucideIcons.star,
          iconColor: const Color(0xFFEAB308),
        ),
    ];

    if (isWide) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: Row(
          children: [
            Expanded(child: _buildSearchTextField(isDark)),
            const SizedBox(width: 12),
            ...chips.expand((w) => [w, const SizedBox(width: 6)]).toList()
              ..removeLast(),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        child: Column(
          children: [
            _buildSearchTextField(isDark),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    chips.expand((w) => [w, const SizedBox(width: 6)]).toList()
                      ..removeLast(),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSearchTextField(bool isDark) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
        ),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => _clientesDebouncer.run(() {
          if (mounted) setState(() => _filtroTexto = val);
        }),
        onSubmitted: (val) {
          _clientesDebouncer.cancel();
          setState(() => _filtroTexto = val);
        },
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppTheme.textDark,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, DNI o teléfono...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: AppTheme.getAdaptiveHintText(isDark),
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 16,
            color: AppTheme.getAdaptiveHintText(isDark),
          ),
          suffixIcon: _filtroTexto.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 15),
                  onPressed: () {
                    _searchCtrl.clear();
                    _clientesDebouncer.cancel();
                    setState(() => _filtroTexto = '');
                  },
                )
              : null,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFiltroChip(
    String clave,
    String label,
    bool isDark, {
    Color? dotColor,
    IconData? icon,
    Color? iconColor,
  }) {
    final isSelected = _filtroEstado == clave;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filtroEstado = clave);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? AppTheme.brandPrimary.withValues(alpha: 0.25)
                    : AppTheme.brandPrimary.withValues(alpha: 0.1))
              : (isDark ? AppTheme.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.brandPrimary
                : (isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.4 : 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6.5,
                height: 6.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 5.5),
            ] else if (icon != null) ...[
              Icon(icon, size: 12, color: iconColor ?? AppTheme.brandPrimary),
              const SizedBox(width: 5.5),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? const Color(0xFF60A5FA) : AppTheme.brandPrimary)
                    : (isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final esBusqueda = _filtroTexto.isNotEmpty;
    final soloConDeuda = _filtroEstado == 'deudores';
    final soloCaseritos = _filtroEstado == 'caseritos';

    final Color badgeColor = soloConDeuda
        ? AppTheme.accentGreen
        : soloCaseritos
        ? const Color(0xFFEAB308)
        : (esBusqueda ? AppTheme.brandPrimary : const Color(0xFFD97706));

    final IconData icon = soloConDeuda
        ? LucideIcons.badgeCheck
        : soloCaseritos
        ? LucideIcons.star
        : (esBusqueda ? LucideIcons.searchX : LucideIcons.bookOpen);

    final String title = esBusqueda
        ? 'Sin resultados para "$_filtroTexto"'
        : soloConDeuda
        ? '¡Excelente! Nadie tiene deudas pendientes'
        : soloCaseritos
        ? 'No tienes vecinos marcados como Caseritos'
        : 'Tu Libreta de Fiados Inteligente';

    final String subtitle = esBusqueda
        ? 'Verifica que el nombre, DNI o celular esté bien escrito o limpia la búsqueda.'
        : soloConDeuda
        ? 'Todos los fiados y compras al crédito han sido cancelados. La cartera de cobranzas está 100% al día.'
        : soloCaseritos
        ? 'Marca a tus vecinos más frecuentes como "Caseritos" al registrarlos o editarlos para ubicarlos al instante.'
        : 'Lleva el control de los vecinos de confianza, sus límites de crédito y comprobantes de abono para que nunca pierdas capital.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dual-Ring Badge con resplandor
              Container(
                width: 76,
                height: 76,
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.14),
                    ),
                    child: Icon(icon, size: 26, color: badgeColor),
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
                  letterSpacing: -0.2,
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
                  color: AppTheme.getAdaptiveMutedText(isDark),
                ),
              ),
              const SizedBox(height: 20),

              // Caja didáctica "Tip de Negocio" para la bodega
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
                    Icon(
                      LucideIcons.lightbulb,
                      size: 16,
                      color: isDark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        soloConDeuda
                            ? 'Tip de Finanzas: Un balance en cero te da liquidez inmediata para negociar mejores precios al por mayor con tus proveedores de abarrotes.'
                            : soloCaseritos
                            ? 'Tip de Fidelización: Tus caseritos compran hasta 3 veces más seguido. Dales prioridad o anótalos con notas especiales de pago.'
                            : 'Tip de Bodega: Fiar con límite de S/ 50 a S/ 100 fideliza al vecino del barrio. Puedes imprimirle su ticket térmico con el saldo pendiente tras cada compra.',
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

              // Botón de acción principal
              if (esBusqueda)
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
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: Text(
                    'Limpiar Búsqueda',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    _clientesDebouncer.cancel();
                    setState(() => _filtroTexto = '');
                  },
                )
              else if (soloConDeuda || soloCaseritos)
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
                  icon: const Icon(LucideIcons.users, size: 16),
                  label: Text(
                    'Ver Todos los Vecinos',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => setState(() => _filtroEstado = 'todos'),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.userPlus, size: 16),
                  label: Text(
                    'Registrar Primer Vecino',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  onPressed: () => _abrirNuevoCliente(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClienteCard(Cliente c, bool isDark) {
    final tieneDeuda = c.tieneDeuda;
    final tieneTelefono = c.telefono != null && c.telefono!.trim().isNotEmpty;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tieneDeuda
              ? (isDark
                    ? const Color(0xFF7F1D1D).withValues(alpha: 0.6)
                    : const Color(0xFFFECACA))
              : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
          width: tieneDeuda ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra lateral semántica discreta
              Container(
                width: 4.5,
                color: tieneDeuda ? AppTheme.alertRed : AppTheme.accentGreen,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fila 1: Avatar con Pip + Nombre + Semáforo + Menú
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: tieneDeuda
                                      ? (isDark
                                            ? const Color(0xFF451A1A)
                                            : const Color(0xFFFEE2E2))
                                      : (isDark
                                            ? const Color(0xFF1E293B)
                                            : AppTheme.brandPrimary.withValues(
                                                alpha: 0.1,
                                              )),
                                  border: Border.all(
                                    color: tieneDeuda
                                        ? (isDark
                                              ? const Color(0xFF7F1D1D)
                                              : const Color(0xFFFECACA))
                                        : (isDark
                                              ? AppTheme.borderDark
                                              : const Color(0xFFBFDBFE)),
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  c.nombreCompleto.isNotEmpty
                                      ? c.nombreCompleto
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : 'V',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: tieneDeuda
                                        ? (isDark
                                              ? const Color(0xFFF87171)
                                              : AppTheme.alertRed)
                                        : AppTheme.brandPrimary,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c.colorRiesgo,
                                    border: Border.all(
                                      color: isDark
                                          ? AppTheme.cardDark
                                          : Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        c.nombreCompleto,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (c.esCaserito) ...[
                                      const SizedBox(width: 5),
                                      const Icon(
                                        LucideIcons.star,
                                        size: 13,
                                        color: Color(0xFFEAB308),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (c.documento != null &&
                                        c.documento!.isNotEmpty)
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            WidgetSpan(
                                              alignment:
                                                  PlaceholderAlignment.middle,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 3,
                                                ),
                                                child: Icon(
                                                  LucideIcons.idCard,
                                                  size: 12,
                                                  color: isDark
                                                      ? AppTheme
                                                            .textDarkSecondary
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                            TextSpan(
                                              text: c.documento!,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? AppTheme
                                                              .textDarkSecondary
                                                        : const Color(
                                                            0xFF475569,
                                                          ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (tieneTelefono)
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            WidgetSpan(
                                              alignment:
                                                  PlaceholderAlignment.middle,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 3,
                                                ),
                                                child: Icon(
                                                  LucideIcons.phone,
                                                  size: 12,
                                                  color: isDark
                                                      ? AppTheme
                                                            .textDarkSecondary
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                            TextSpan(
                                              text: c.telefono!,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? AppTheme
                                                              .textDarkSecondary
                                                        : const Color(
                                                            0xFF475569,
                                                          ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Badge Semáforo de Riesgo
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: c.colorRiesgo.withValues(
                                alpha: isDark ? 0.2 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: c.colorRiesgo.withValues(
                                  alpha: isDark ? 0.35 : 0.25,
                                ),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: c.colorRiesgo,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  tieneDeuda ? c.etiquetaRiesgo : 'Al Día',
                                  maxLines: 1,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: c.colorRiesgo,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              LucideIcons.moreVertical,
                              size: 16,
                            ),
                            padding: EdgeInsets.zero,
                            onSelected: (val) {
                              if (val == 'editar') _abrirNuevoCliente(c);
                              if (val == 'historial') _abrirEstadoCuenta(c);
                              if (val == 'eliminar')
                                _confirmarEliminarCliente(c);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'historial',
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.fileSpreadsheet, size: 16),
                                    SizedBox(width: 8),
                                    Text('Estado de Cuenta'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'editar',
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.pencil, size: 16),
                                    SizedBox(width: 8),
                                    Text('Editar Datos'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'eliminar',
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.trash2,
                                      size: 16,
                                      color: AppTheme.alertRed,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Dar de Baja',
                                      style: TextStyle(
                                        color: AppTheme.alertRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Cockpit Financiero Interno de la Tarjeta
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.borderDark
                                : const Color(0xFFF1F5F9),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Saldo Deudor:',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'S/ ${c.saldoDeudor.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: tieneDeuda
                                        ? (isDark
                                              ? const Color(0xFFF87171)
                                              : AppTheme.alertRed)
                                        : AppTheme.accentGreen,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Micro-barra de progreso de crédito
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: c.porcentajeCreditoUsado,
                                minHeight: 4.5,
                                backgroundColor: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  c.porcentajeCreditoUsado > 0.85
                                      ? AppTheme.alertRed
                                      : (c.porcentajeCreditoUsado > 0.5
                                            ? Colors.amber
                                            : AppTheme.accentGreen),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Límite: S/ ${c.limiteCredito.toStringAsFixed(0)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF64748B),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Disp: S/ ${c.creditoDisponible.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.creditoDisponible < 20
                                          ? AppTheme.alertRed
                                          : AppTheme.accentGreen,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (c.notas != null && c.notas!.trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF131D31)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.messageSquare,
                                size: 11,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  c.notas!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Fila de Botones de Acción
                      Row(
                        children: [
                          // Botón Cobrar / Abonar
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tieneDeuda
                                      ? AppTheme.accentGreen
                                      : AppTheme.brandPrimary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () => _abrirRegistrarAbono(c),
                                icon: const Icon(
                                  LucideIcons.circleDollarSign,
                                  size: 14,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tieneDeuda
                                        ? 'Cobrar / Abonar'
                                        : 'Abonar Saldo',
                                    maxLines: 1,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Botón WhatsApp (si tiene teléfono y deuda)
                          if (tieneTelefono && tieneDeuda) ...[
                            SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                onPressed: () => _enviarWhatsAppRecordatorio(c),
                                icon: const Icon(
                                  LucideIcons.messageSquare,
                                  size: 14,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'WhatsApp',
                                    maxLines: 1,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Botón Ver Estado de Cuenta
                          SizedBox(
                            height: 38,
                            width: 38,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isDark
                                        ? AppTheme.borderDark
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              icon: const Icon(
                                LucideIcons.fileSpreadsheet,
                                size: 15,
                              ),
                              tooltip: 'Ver Historial / Estado de Cuenta',
                              onPressed: () => _abrirEstadoCuenta(c),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
