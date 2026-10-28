import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/csv_exporter.dart';
import '../../core/theme.dart';
import '../home/bodega_service.dart';
import 'cliente_model.dart';
import 'cliente_service.dart';
import 'nuevo_cliente_sheet.dart';
import 'registrar_abono_sheet.dart';
import 'estado_cuenta_modal.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final ClienteService _clienteService = ClienteService();
  final BodegaService _bodegaService = BodegaService();

  List<Cliente> _clientes = [];
  ResumenCreditos? _resumen;
  BodegaInfo? _bodegaInfo;

  bool _isLoading = true;
  String _filtroTexto = '';
  String _filtroEstado = 'todos'; // 'todos', 'deudores', 'al_dia'

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ClienteService.clientesRevision.addListener(_onRevisionChanged);
    _cargarDatos();
  }

  @override
  void dispose() {
    ClienteService.clientesRevision.removeListener(_onRevisionChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onRevisionChanged() {
    if (mounted) _cargarDatos(forceRefresh: true);
  }

  Future<void> _cargarDatos({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _clienteService.getClientes(forceRefresh: forceRefresh),
        _clienteService.getResumenCreditos(),
        _bodegaService.obtenerMiBodega(),
      ]);

      if (mounted) {
        setState(() {
          _clientes = results[0] as List<Cliente>;
          _resumen = results[1] as ResumenCreditos?;
          _bodegaInfo = results[2] as BodegaInfo?;
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
        const SnackBar(content: Text('El cliente no tiene un teléfono válido registrado')),
      );
    }
  }

  Future<void> _exportarCsv() async {
    if (_clientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes registrados en la libreta para exportar.')),
      );
      return;
    }
    final now = DateTime.now();
    final fechaStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final nombreArchivo = 'libreta_fiados_$fechaStr.csv';
    final csv = CsvExporter.generarCsvClientes(_clientes);
    await CsvExporter.descargarOCompartirCsv(
      nombreArchivo: nombreArchivo,
      contenidoCsv: csv,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb
              ? '¡Libreta de fiados descargada como $nombreArchivo!'
              : '¡Libreta de fiados exportada y copiada al portapapeles!'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  void _confirmarEliminarCliente(Cliente c) {
    if (c.tieneDeuda) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No puede eliminar a ${c.nombreCompleto} porque mantiene una deuda pendiente de S/ ${c.saldoDeudor.toStringAsFixed(2)}.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dar de Baja Cliente'),
        content: Text('¿Está seguro de dar de baja a "${c.nombreCompleto}" de la libreta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _clienteService.eliminarCliente(c.idCliente!);
                _cargarDatos(forceRefresh: true);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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

    final totalPorCobrar = _resumen?.totalSaldoDeudor ?? 0.0;
    final vecinosDeudores = _resumen?.clientesConDeuda ?? 0;
    final cobradoMes = _resumen?.totalAbonosMes ?? 0.0;
    final totalVecinos = _clientes.length;
    final vecinosAlDia = (totalVecinos - vecinosDeudores).clamp(0, totalVecinos);
    final creditoTotal = _clientes.fold<double>(0.0, (acc, c) => acc + c.limiteCredito);

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
                    'Libreta de Fiados',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'Cuentas por cobrar y vecinos de confianza',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
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
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(LucideIcons.userPlus, size: 18),
              label: Text(
                'Nuevo Vecino',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              onPressed: () => _abrirNuevoCliente(),
            ),
      body: RefreshIndicator(
        onRefresh: () => _cargarDatos(forceRefresh: true),
        color: AppTheme.brandPrimary,
        child: Column(
          children: [
            // 1. Cabecera Compacta Integrada (cuando está embebido en HomeScreen)
            if (!canPop)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: cardBg,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Libreta de Fiados',
                            style: GoogleFonts.outfit(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '$totalVecinos vecinos',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
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
                                      ? (isDark ? const Color(0xFFF87171) : AppTheme.alertRed)
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
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
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
                              const Icon(LucideIcons.download, size: 13, color: AppTheme.accentGreen),
                              const SizedBox(width: 4),
                              Text(
                                'CSV',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppTheme.textDark,
                                ),
                              ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            LucideIcons.refreshCw,
                            size: 13,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón + Nuevo Vecino
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _abrirNuevoCliente();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.userPlus, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Nuevo',
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
                ),
              ),

            // 2. Panel Superior: KPIs de Crédito y Fiados (Diseño Responsivo Simétrico)
            _buildKpisSection(
              isDark: isDark,
              totalPorCobrar: totalPorCobrar,
              vecinosDeudores: vecinosDeudores,
              cobradoMes: cobradoMes,
              vecinosAlDia: vecinosAlDia,
              creditoTotal: creditoTotal,
            ),

            // 3. Toolbar Unificada (Buscador + Filtros por Estado)
            _buildToolbar(isDark, cardBg, isWide, vecinosDeudores, vecinosAlDia),

            // 4. Lista o Grid de Vecinos / Clientes
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _clientesFiltrados.isEmpty
                      ? _buildEmptyState(isDark)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 720) {
                              return GridView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 480,
                                  mainAxisExtent: 232,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                itemCount: _clientesFiltrados.length,
                                itemBuilder: (context, idx) {
                                  final c = _clientesFiltrados[idx];
                                  return _buildClienteCard(c, isDark);
                                },
                              );
                            } else {
                              return ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                itemCount: _clientesFiltrados.length,
                                itemBuilder: (context, idx) {
                                  final c = _clientesFiltrados[idx];
                                  return _buildClienteCard(c, isDark);
                                },
                              );
                            }
                          },
                        ),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          final isTablet = constraints.maxWidth >= 540 && constraints.maxWidth < 900;

          if (isDesktop) {
            return Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    isDark: isDark,
                    icon: LucideIcons.handCoins,
                    title: 'Por Cobrar',
                    value: 'S/ ${totalPorCobrar.toStringAsFixed(2)}',
                    subtitle: '$vecinosDeudores vecinos con saldo',
                    accentColor: AppTheme.alertRed,
                    bgColor: isDark ? const Color(0xFF2A1215) : const Color(0xFFFEF2F2),
                    borderColor: isDark ? const Color(0xFF991B1B).withValues(alpha: 0.6) : const Color(0xFFFECACA),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    isDark: isDark,
                    icon: LucideIcons.checkCheck,
                    title: 'Cobrado Mes',
                    value: 'S/ ${cobradoMes.toStringAsFixed(2)}',
                    subtitle: 'Recuperado a la fecha',
                    accentColor: AppTheme.accentGreen,
                    bgColor: isDark ? const Color(0xFF06231A) : const Color(0xFFECFDF5),
                    borderColor: isDark ? const Color(0xFF047857).withValues(alpha: 0.6) : const Color(0xFFA7F3D0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    isDark: isDark,
                    icon: LucideIcons.shieldCheck,
                    title: 'Vecinos al Día',
                    value: '$vecinosAlDia vecinos',
                    subtitle: '${_clientes.isNotEmpty ? ((vecinosAlDia / _clientes.length) * 100).toStringAsFixed(0) : 100}% de la cartera',
                    accentColor: const Color(0xFF2563EB),
                    bgColor: isDark ? const Color(0xFF101C38) : const Color(0xFFEFF6FF),
                    borderColor: isDark ? const Color(0xFF1D4ED8).withValues(alpha: 0.6) : const Color(0xFFBFDBFE),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    isDark: isDark,
                    icon: LucideIcons.wallet,
                    title: 'Límite Total',
                    value: 'S/ ${creditoTotal.toStringAsFixed(0)}',
                    subtitle: 'Crédito vecinal activo',
                    accentColor: const Color(0xFF7C3AED),
                    bgColor: isDark ? const Color(0xFF1E1338) : const Color(0xFFFAF5FF),
                    borderColor: isDark ? const Color(0xFF6D28D9).withValues(alpha: 0.6) : const Color(0xFFE9D5FF),
                  ),
                ),
              ],
            );
          } else if (isTablet) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        isDark: isDark,
                        icon: LucideIcons.handCoins,
                        title: 'Por Cobrar',
                        value: 'S/ ${totalPorCobrar.toStringAsFixed(2)}',
                        subtitle: '$vecinosDeudores vecinos con saldo',
                        accentColor: AppTheme.alertRed,
                        bgColor: isDark ? const Color(0xFF2A1215) : const Color(0xFFFEF2F2),
                        borderColor: isDark ? const Color(0xFF991B1B).withValues(alpha: 0.6) : const Color(0xFFFECACA),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKpiCard(
                        isDark: isDark,
                        icon: LucideIcons.checkCheck,
                        title: 'Cobrado Mes',
                        value: 'S/ ${cobradoMes.toStringAsFixed(2)}',
                        subtitle: 'Recuperado a la fecha',
                        accentColor: AppTheme.accentGreen,
                        bgColor: isDark ? const Color(0xFF06231A) : const Color(0xFFECFDF5),
                        borderColor: isDark ? const Color(0xFF047857).withValues(alpha: 0.6) : const Color(0xFFA7F3D0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        isDark: isDark,
                        icon: LucideIcons.shieldCheck,
                        title: 'Vecinos al Día',
                        value: '$vecinosAlDia vecinos',
                        subtitle: '${_clientes.isNotEmpty ? ((vecinosAlDia / _clientes.length) * 100).toStringAsFixed(0) : 100}% de la cartera',
                        accentColor: const Color(0xFF2563EB),
                        bgColor: isDark ? const Color(0xFF101C38) : const Color(0xFFEFF6FF),
                        borderColor: isDark ? const Color(0xFF1D4ED8).withValues(alpha: 0.6) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKpiCard(
                        isDark: isDark,
                        icon: LucideIcons.wallet,
                        title: 'Límite Total',
                        value: 'S/ ${creditoTotal.toStringAsFixed(0)}',
                        subtitle: 'Crédito vecinal activo',
                        accentColor: const Color(0xFF7C3AED),
                        bgColor: isDark ? const Color(0xFF1E1338) : const Color(0xFFFAF5FF),
                        borderColor: isDark ? const Color(0xFF6D28D9).withValues(alpha: 0.6) : const Color(0xFFE9D5FF),
                      ),
                    ),
                  ],
                ),
              ],
            );
          } else {
            // Móvil estándar
            return Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    isDark: isDark,
                    icon: LucideIcons.handCoins,
                    title: 'Por Cobrar',
                    value: 'S/ ${totalPorCobrar.toStringAsFixed(2)}',
                    subtitle: '$vecinosDeudores con saldo',
                    accentColor: AppTheme.alertRed,
                    bgColor: isDark ? const Color(0xFF2A1215) : const Color(0xFFFEF2F2),
                    borderColor: isDark ? const Color(0xFF991B1B).withValues(alpha: 0.6) : const Color(0xFFFECACA),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    isDark: isDark,
                    icon: LucideIcons.checkCheck,
                    title: 'Cobrado Mes',
                    value: 'S/ ${cobradoMes.toStringAsFixed(2)}',
                    subtitle: 'Recuperado a la fecha',
                    accentColor: AppTheme.accentGreen,
                    bgColor: isDark ? const Color(0xFF06231A) : const Color(0xFFECFDF5),
                    borderColor: isDark ? const Color(0xFF047857).withValues(alpha: 0.6) : const Color(0xFFA7F3D0),
                  ),
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
    required Color bgColor,
    required Color borderColor,
  }) {
    final effectiveAccent = isDark
        ? (accentColor == AppTheme.alertRed || accentColor == const Color(0xFFEF4444)
            ? const Color(0xFFF87171)
            : accentColor == AppTheme.accentGreen || accentColor == const Color(0xFF10B981)
                ? const Color(0xFF34D399)
                : accentColor == AppTheme.brandPrimary || accentColor == const Color(0xFF2563EB)
                    ? const Color(0xFF60A5FA)
                    : accentColor == const Color(0xFF7C3AED)
                        ? const Color(0xFFA78BFA)
                        : accentColor)
        : accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: effectiveAccent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.outfit(
                fontSize: 18.5,
                fontWeight: FontWeight.w900,
                color: effectiveAccent,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDark, Color cardBg, bool isWide, int vecinosDeudores, int vecinosAlDia) {
    if (isWide) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: _buildSearchTextField(isDark),
            ),
            const SizedBox(width: 14),
            _buildFiltroChip('todos', 'Todos (${_clientes.length})', isDark),
            const SizedBox(width: 8),
            _buildFiltroChip('deudores', 'Con Deuda ($vecinosDeudores)', isDark),
            const SizedBox(width: 8),
            _buildFiltroChip('al_dia', 'Al Día ($vecinosAlDia)', isDark),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            _buildSearchTextField(isDark),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFiltroChip('todos', 'Todos (${_clientes.length})', isDark),
                  const SizedBox(width: 8),
                  _buildFiltroChip('deudores', 'Con Deuda ($vecinosDeudores)', isDark),
                  const SizedBox(width: 8),
                  _buildFiltroChip('al_dia', 'Al Día ($vecinosAlDia)', isDark),
                ],
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
        onChanged: (val) => setState(() => _filtroTexto = val),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppTheme.textDark,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, DNI o teléfono...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: AppTheme.textMuted,
          ),
          prefixIcon: Icon(LucideIcons.search, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          suffixIcon: _filtroTexto.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 15),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _filtroTexto = '');
                  },
                )
              : null,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String clave, String label, bool isDark) {
    final isSelected = _filtroEstado == clave;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : (isDark ? Colors.white : AppTheme.textDark),
      ),
      selectedColor: AppTheme.brandPrimary,
      backgroundColor: isDark ? AppTheme.cardDarkHighlight : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? Colors.transparent : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
        ),
      ),
      onSelected: (_) => setState(() => _filtroEstado = clave),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final esBusqueda = _filtroTexto.isNotEmpty;
    final soloConDeuda = _filtroEstado == 'CON_DEUDA';

    final Color badgeColor = soloConDeuda
        ? AppTheme.accentGreen
        : (esBusqueda ? AppTheme.brandPrimary : const Color(0xFFD97706));

    final IconData icon = soloConDeuda
        ? LucideIcons.badgeCheck
        : (esBusqueda ? LucideIcons.searchX : LucideIcons.bookOpen);

    final String title = esBusqueda
        ? 'Sin resultados para "$_filtroTexto"'
        : (soloConDeuda
            ? '¡Excelente! Nadie tiene deudas pendientes'
            : 'Tu Libreta de Fiados Inteligente');

    final String subtitle = esBusqueda
        ? 'Verifica que el nombre, DNI o celular esté bien escrito o limpia la búsqueda.'
        : (soloConDeuda
            ? 'Todos los fiados y compras al crédito han sido cancelados. La cartera de cobranzas está 100% al día.'
            : 'Lleva el control de los vecinos de confianza, sus límites de crédito y comprobantes de abono para que nunca pierdas capital.');

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
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 20),

              // Caja didáctica "Tip de Negocio" para la bodega
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
                    const Text('💡', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        soloConDeuda
                            ? 'Tip de Finanzas: Un balance en cero te da liquidez inmediata para negociar mejores precios al por mayor con tus proveedores de abarrotes.'
                            : 'Tip de Bodega: Fiar con límite de S/ 50 a S/ 100 fideliza al vecino del barrio. Puedes imprimirle su ticket térmico con el saldo pendiente tras cada compra.',
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

              // Botón de acción principal
              if (esBusqueda)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: Text(
                    'Limpiar Búsqueda',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _filtroTexto = '');
                  },
                )
              else if (soloConDeuda)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.users, size: 16),
                  label: Text(
                    'Ver Todos los Vecinos',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  onPressed: () => setState(() => _filtroEstado = 'TODOS'),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.userPlus, size: 16),
                  label: Text(
                    'Registrar Primer Vecino',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13.5),
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

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isDark ? AppTheme.cardDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: tieneDeuda
              ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.6) : const Color(0xFFFECACA))
              : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
          width: tieneDeuda ? 1.3 : 0.9,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fila 1: Avatar + Nombre + Estado de Deuda + Menú
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: tieneDeuda
                      ? const Color(0xFFFEE2E2)
                      : AppTheme.brandPrimary.withValues(alpha: 0.12),
                  child: Text(
                    c.nombreCompleto.isNotEmpty ? c.nombreCompleto.substring(0, 1).toUpperCase() : 'V',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: tieneDeuda ? AppTheme.alertRed : AppTheme.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nombreCompleto,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (c.documento != null && c.documento!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.idCard, size: 12, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
                                const SizedBox(width: 3),
                                Text(
                                  c.documento!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          if (tieneTelefono)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.phone, size: 12, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
                                const SizedBox(width: 3),
                                Text(
                                  c.telefono!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Badge Deuda
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: tieneDeuda
                        ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                        : (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tieneDeuda ? 'Debe S/ ${c.saldoDeudor.toStringAsFixed(2)}' : 'Al Día ✨',
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: tieneDeuda ? AppTheme.alertRed : AppTheme.accentGreen,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreVertical, size: 17),
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val == 'editar') _abrirNuevoCliente(c);
                    if (val == 'historial') _abrirEstadoCuenta(c);
                    if (val == 'eliminar') _confirmarEliminarCliente(c);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'historial',
                      child: Row(children: [Icon(LucideIcons.fileSpreadsheet, size: 16), SizedBox(width: 8), Text('Estado de Cuenta')]),
                    ),
                    const PopupMenuItem(
                      value: 'editar',
                      child: Row(children: [Icon(LucideIcons.pencil, size: 16), SizedBox(width: 8), Text('Editar Datos')]),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Row(children: [Icon(LucideIcons.trash2, size: 16, color: AppTheme.alertRed), SizedBox(width: 8), Text('Dar de Baja', style: TextStyle(color: AppTheme.alertRed))]),
                    ),
                  ],
                ),
              ],
            ),

            if (c.notas != null && c.notas!.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(LucideIcons.messageCircle, size: 12, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c.notas!,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Barra de Límite de Crédito
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Límite: S/ ${c.limiteCredito.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Disponible: S/ ${c.creditoDisponible.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.creditoDisponible < 20 ? AppTheme.alertRed : AppTheme.accentGreen,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: c.porcentajeCreditoUsado,
                minHeight: 5,
                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  c.porcentajeCreditoUsado > 0.85
                      ? AppTheme.alertRed
                      : (c.porcentajeCreditoUsado > 0.5 ? Colors.amber : AppTheme.brandPrimary),
                ),
              ),
            ),
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
                        backgroundColor: tieneDeuda ? AppTheme.accentGreen : AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _abrirRegistrarAbono(c),
                      icon: const Icon(LucideIcons.circleDollarSign, size: 14),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tieneDeuda ? 'Cobrar / Abonar' : 'Abonar Saldo',
                          maxLines: 1,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _enviarWhatsAppRecordatorio(c),
                      icon: const Icon(LucideIcons.messageSquare, size: 14),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'WhatsApp',
                          maxLines: 1,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
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
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(LucideIcons.fileSpreadsheet, size: 15),
                    tooltip: 'Ver Historial / Estado de Cuenta',
                    onPressed: () => _abrirEstadoCuenta(c),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
