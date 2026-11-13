import '../marketing/kit_marketing_barrio_modal.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/responsive_layout.dart';
import '../../core/widgets/tab_deferred_refresh.dart';
import '../productos/producto_model.dart';
import '../productos/producto_service.dart';
import '../productos/nuevo_producto_sheet.dart';
import '../movimientos/kardex_screen.dart';
import '../auth/auth_service.dart';
import '../home/plan_y_personal_sheet.dart';
import '../home/bodega_service.dart';
import '../home/configuracion_ticket_modal.dart';
import '../../core/offline/offline_queue_sheet.dart';
import '../../core/widgets/briefing_turno_modal.dart';
import '../ventas/venta_model.dart';
import '../ventas/venta_service.dart';
import '../clientes/cliente_model.dart';
import '../clientes/cliente_service.dart';
import '../clientes/clientes_screen.dart';
import '../compras/compras_screen.dart';
import 'dashboard_bi_screen.dart';
import '../movimientos/mermas_screen.dart';
import '../movimientos/vencimientos_screen.dart';
import '../movimientos/auditoria_ciega_screen.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/mi_bodega_online_modal.dart';
import '../../core/widgets/plan_upgrade_modal.dart';
import '../promociones/promociones_screen.dart';

class _OperacionItem {
  final String id;
  final String categoria; // 'almacen', 'ventas', 'gestion', 'mostrador'
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isLocked;
  final bool requiresAdmin;
  final VoidCallback onTap;

  const _OperacionItem({
    required this.id,
    required this.categoria,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isLocked = false,
    this.requiresAdmin = false,
    required this.onTap,
  });
}

class DashboardScreen extends StatefulWidget {
  final Function(int tabIndex) onNavigateTab;
  final ValueListenable<int>? activeTabNotifier;
  final int? tabIndex;

  const DashboardScreen({
    super.key,
    required this.onNavigateTab,
    this.activeTabNotifier,
    this.tabIndex,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TabDeferredRefreshMixin<DashboardScreen> {
  final ProductoService _productoService = ProductoService();
  final VentaService _ventaService = VentaService();
  final ClienteService _clienteService = ClienteService();
  bool _pendingProductosRefresh = false;

  @override
  ValueListenable<int>? get tabVisibilityNotifier => widget.activeTabNotifier;

  @override
  int? get assignedTabIndex => widget.tabIndex;

  @override
  void onDeferredTabRefresh() {
    if (_pendingProductosRefresh) {
      _pendingProductosRefresh = false;
      _cargarDatos(forceRefresh: true);
    } else {
      _cargarCierreHoy();
    }
  }

  List<Producto> _productos = [];
  CierreCaja? _cierreHoy;
  ResumenCreditos? _resumenCreditos;
  String _nombreBodega = 'CajaYa POS';
  String _username = 'Usuario';
  String _userRol = 'ADMIN';
  String _plan = 'BASICO';
  String _ruc = '';
  String _telefono = '';
  String _direccion = '';
  bool _isLoading = true;
  double _metaDiaria = 1000.0;
  int _tabOperaciones =
      0; // 0 = Favoritos, 1 = Almacén, 2 = Ventas & Web, 3 = Gestión
  List<String> _favoritosIds = [
    'nuevo_producto',
    'compras',
    'bodega_online',
    'impresora',
  ];

  @override
  void initState() {
    super.initState();
    initTabVisibilityListener();
    ProductoService.productosRevision.addListener(_onProductosRevisionChanged);
    VentaService.ventasRevision.addListener(_onVentasRevisionChanged);
    _cargarMetaDiaria();
    _cargarFavoritos();
    _cargarDatos();
  }

  Future<void> _cargarFavoritos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('cajaya_operaciones_favoritas');
      if (list != null && list.isNotEmpty) {
        if (mounted) setState(() => _favoritosIds = list);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorito(String opId, [String? opTitle]) async {
    HapticFeedback.mediumImpact();
    final updated = List<String>.from(_favoritosIds);
    final bool removing = updated.contains(opId);
    if (removing) {
      if (updated.length <= 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes mantener al menos un acceso favorito.'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      updated.remove(opId);
    } else {
      updated.add(opId);
    }
    setState(() => _favoritosIds = updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cajaya_operaciones_favoritas', updated);
    } catch (_) {}

    if (mounted) {
      final String nombre = opTitle ?? 'Operación';
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                removing
                    ? LucideIcons.bookmarkMinus
                    : LucideIcons.bookmarkCheck,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  removing
                      ? 'Se quitó "$nombre" de tus accesos directos'
                      : '¡"$nombre" agregado a tus accesos directos!',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: removing
              ? const Color(0xFF475569)
              : AppTheme.brandPrimary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    disposeTabVisibilityListener();
    ProductoService.productosRevision.removeListener(
      _onProductosRevisionChanged,
    );
    VentaService.ventasRevision.removeListener(_onVentasRevisionChanged);
    super.dispose();
  }

  void _onProductosRevisionChanged() {
    if (!isTabCurrentlyVisible) {
      _pendingProductosRefresh = true;
    }
    runWhenTabVisible(() {
      _pendingProductosRefresh = false;
      _cargarDatos(forceRefresh: true);
    });
  }

  void _onVentasRevisionChanged() {
    runWhenTabVisible(() => _cargarCierreHoy());
  }

  Future<void> _cargarMetaDiaria() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final m = prefs.getDouble('meta_diaria_cajaya');
      if (m != null && m > 0) {
        if (mounted) setState(() => _metaDiaria = m);
      }
    } catch (_) {}
  }

  Future<void> _guardarMetaDiaria(double nuevaMeta) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('meta_diaria_cajaya', nuevaMeta);
      if (mounted) setState(() => _metaDiaria = nuevaMeta);
    } catch (_) {}
  }

  void _mostrarDialogoEditarMeta(BuildContext context, bool isDark) {
    final ctrl = TextEditingController(text: _metaDiaria.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.target,
                color: AppTheme.brandPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Meta Diaria de Venta',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18),
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingresa tu objetivo de venta para hoy en Soles (S/):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
              decoration: InputDecoration(
                prefixText: 'S/ ',
                prefixStyle: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandPrimary,
                ),
                filled: true,
                fillColor: isDark
                    ? AppTheme.cardDarkSunken
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                _guardarMetaDiaria(val);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Meta diaria actualizada a S/ ${val.toStringAsFixed(2)}',
                    ),
                    backgroundColor: AppTheme.accentGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              'Guardar Meta',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermometroMetaDiaria(bool isDark) {
    final bool isPro = _plan.toUpperCase() == 'PRO';
    if (!isPro) {
      return Container(
        margin: const EdgeInsets.only(top: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD97706)
                  .withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              PlanUpgradeModal.show(
                context,
                featureName: 'Termómetro de Meta Diaria de Venta',
                featureDescription: 'Establece tu meta de ventas diaria y mira en vivo la barra de progreso avanzando con cada cobro en caja. Conoce cuánto te falta para superar tu punto de equilibrio.',
                icon: LucideIcons.target,
                onPlanUpdated: _cargarDatos,
              );
            },
            child: Padding(
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
                              color: const Color(0xFFD97706)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              LucideIcons.target,
                              size: 18,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Termómetro de Meta Diaria',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          LucideIcons.lock,
                                          size: 9,
                                          color: Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'PRO',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '🔒 Función Exclusiva Plan PRO • Toca para desbloquear',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFD97706)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.lock,
                              size: 12,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Desbloquear',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 10,
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            color: const Color(0xFFD97706)
                                .withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final totalVentas = _cierreHoy?.totalVentas ?? 0.0;
    final double progreso = _metaDiaria > 0
        ? (totalVentas / _metaDiaria).clamp(0.0, 1.0)
        : 0.0;
    final bool metaCumplida = totalVentas >= _metaDiaria;
    final double falta = (_metaDiaria - totalVentas).clamp(
      0.0,
      double.infinity,
    );
    final double porcentaje = _metaDiaria > 0
        ? ((totalVentas / _metaDiaria) * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  metaCumplida
                      ? const Color(0xFF064E3B)
                      : const Color(0xFF1E1B4B),
                ]
              : [
                  Colors.white,
                  metaCumplida
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF8FAFC),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: metaCumplida
              ? AppTheme.accentGreen
              : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
          width: metaCumplida ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (metaCumplida ? AppTheme.accentGreen : AppTheme.brandPrimary)
                .withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
                      color:
                          (metaCumplida
                                  ? AppTheme.accentGreen
                                  : AppTheme.brandPrimary)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      metaCumplida ? LucideIcons.flame : LucideIcons.target,
                      size: 18,
                      color: metaCumplida
                          ? AppTheme.accentGreen
                          : AppTheme.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Termómetro de Meta Diaria',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isPro
                                          ? const Color(0xFF0D9488)
                                          : const Color(0xFFD97706))
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isPro) ...[
                                  const Icon(
                                    LucideIcons.lock,
                                    size: 9,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  'PRO',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isPro
                                        ? const Color(0xFF0F766E)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isPro
                            ? (metaCumplida
                                  ? '🎉 ¡Excelente! Superaste tu meta de venta diaria'
                                  : (totalVentas > 0
                                        ? 'Faltan S/ ${falta.toStringAsFixed(2)} para llegar a la meta'
                                        : 'Registra tus ventas de hoy para avanzar'))
                            : '🔒 Función Exclusiva Plan PRO • Toca para desbloquear',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPro
                              ? (metaCumplida
                                    ? (isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF059669))
                                    : (isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF64748B)))
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.pencil, size: 15),
                tooltip: isPro
                    ? 'Cambiar Meta Diaria'
                    : 'Desbloquear con Plan PRO',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: isPro
                    ? (isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B))
                    : const Color(0xFFD97706),
                onPressed: () {
                  if (!isPro) {
                    PlanUpgradeModal.show(
                      context,
                      featureName: 'Termómetro de Meta Diaria de Venta',
                      featureDescription: 'Establece tu meta de ventas diaria y mira en vivo la barra de progreso avanzando con cada cobro en caja. Conoce cuánto te falta para superar tu punto de equilibrio.',
                      icon: LucideIcons.target,
                      onPlanUpdated: _cargarDatos,
                    );
                    return;
                  }
                  _mostrarDialogoEditarMeta(context, isDark);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Row(
                children: [
                  Text(
                    'S/ ${totalVentas.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: metaCumplida
                          ? AppTheme.accentGreen
                          : (isDark ? Colors.white : AppTheme.textDark),
                    ),
                  ),
                  Text(
                    ' / S/ ${_metaDiaria.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Text(
                '${porcentaje.toStringAsFixed(0)}% cumplido',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: metaCumplida
                      ? AppTheme.accentGreen
                      : (porcentaje >= 50
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFD97706)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 10,
              backgroundColor: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                metaCumplida ? AppTheme.accentGreen : const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cargarCierreHoy() async {
    final cierre = await _ventaService.getCierreCajaHoy();
    if (mounted) {
      setState(() => _cierreHoy = cierre);
    }
  }

  Future<void> _cargarDatos({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final auth = AuthService();
    final results = await Future.wait([
      _productoService.getProductos(forceRefresh: forceRefresh),
      _ventaService.getCierreCajaHoy(),
      auth.getNombreBodega(),
      auth.getUsername(),
      auth.getUserRole(),
      auth.getPlanBodega(),
      auth.getRucBodega(),
      auth.getTelefonoBodega(),
      auth.getDireccionBodega(),
      _clienteService.obtenerResumenCreditos(),
    ]);
    if (mounted) {
      setState(() {
        _productos = results[0] as List<Producto>;
        _cierreHoy = results[1] as CierreCaja?;
        _nombreBodega = (results[2] as String?) ?? 'CajaYa POS';
        _username = (results[3] as String?) ?? 'Usuario';
        _userRol = (results[4] as String?) ?? 'ADMIN';
        _plan = (results[5] as String?) ?? 'BASICO';
        _ruc = (results[6] as String?) ?? '';
        _telefono = (results[7] as String?) ?? '';
        _direccion = (results[8] as String?) ?? '';
        _resumenCreditos = results[9] as ResumenCreditos?;
        _isLoading = false;
      });

      // Sincronización en vivo de los datos e identidad de la bodega
      BodegaService()
          .obtenerMiBodega()
          .then((info) {
            if (mounted && info != null) {
              setState(() {
                if (info.plan.toUpperCase() != _plan.toUpperCase()) {
                  _plan = info.plan;
                }
                if (info.telefono != null && info.telefono!.isNotEmpty) {
                  _telefono = info.telefono!;
                }
                if (info.nombreComercial.isNotEmpty) {
                  _nombreBodega = info.nombreComercial;
                }
                if (info.direccion != null && info.direccion!.isNotEmpty) {
                  _direccion = info.direccion!;
                }
              });
            }
          })
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Métricas calculadas en tiempo real
    final int totalProductos = _productos.length;
    final double stockTotalUnidades = _productos.fold(
      0.0,
      (acc, p) => acc + p.stockActual,
    );
    final double valorInventario = _productos.fold(
      0.0,
      (acc, p) => acc + (p.stockActual * p.precioVenta),
    );
    final List<Producto> productosCriticos = _productos.where((p) {
      final double umbralMinimo = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
      return p.stockActual <= (umbralMinimo * 0.5);
    }).toList();
    final List<Producto> productosBajos = _productos.where((p) {
      final double umbralMinimo = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
      return p.stockActual > (umbralMinimo * 0.5) &&
          p.stockActual <= umbralMinimo;
    }).toList();
    final int totalAlertas = productosCriticos.length + productosBajos.length;
    final List<Producto> productosVencidosFIFO = _productos.where((p) {
      return p.controlaVencimiento &&
          p.fechaVencimiento != null &&
          (p.diasParaVencer ?? 999) <= 0;
    }).toList();
    final List<Producto> productosCriticosFIFO = _productos.where((p) {
      final dias = p.diasParaVencer ?? 999;
      return p.controlaVencimiento &&
          p.fechaVencimiento != null &&
          dias > 0 &&
          dias <= 7;
    }).toList();
    final List<Producto> productosAtencionFIFO = _productos.where((p) {
      final dias = p.diasParaVencer ?? 999;
      return p.controlaVencimiento &&
          p.fechaVencimiento != null &&
          dias > 7 &&
          dias <= 30;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => _cargarDatos(forceRefresh: true),
        color: AppTheme.brandPrimary,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.brandPrimary),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Ejecutivo Rebrandeado CajaYa con badge sutil de stock
                    _buildGreetingBanner(isDark, productosCriticos),
                    const SizedBox(height: 18),

                    // Título de Métricas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Métricas Clave del Negocio',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Actualizado hoy (En vivo)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppTheme.accentGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cuadrícula de KPIs Responsiva (4 Pilares Fundamentales)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildMetricTile(
                              constraints: constraints,
                              title: 'Ventas de Hoy',
                              value:
                                  'S/ ${(_cierreHoy?.totalVentas ?? 0.0).toStringAsFixed(2)}',
                              subtitle:
                                  '${_cierreHoy?.cantidadVentas ?? 0} ventas hoy',
                              icon: LucideIcons.badgePercent,
                              accentColor: AppTheme.accentGreen,
                              isDark: isDark,
                              onTap: () =>
                                  widget.onNavigateTab(2), // Tab Arqueo
                            ),
                            _buildMetricTile(
                              constraints: constraints,
                              title: 'Fiados por Cobrar',
                              value:
                                  'S/ ${(_resumenCreditos?.totalDeuda ?? 0.0).toStringAsFixed(2)}',
                              subtitle:
                                  '${_resumenCreditos?.clientesConDeuda ?? 0} vecinos con saldo',
                              icon: LucideIcons.bookUser,
                              accentColor: const Color(0xFFD97706),
                              isDark: isDark,
                              onTap: () {
                                widget.onNavigateTab(4);
                                ClientesScreen.cambiarPestana(0);
                              },
                            ),
                            _buildMetricTile(
                              constraints: constraints,
                              title: 'Valor en Mercadería',
                              value: 'S/ ${valorInventario.toStringAsFixed(2)}',
                              subtitle:
                                  '${stockTotalUnidades % 1 == 0 ? stockTotalUnidades.toInt().toString() : stockTotalUnidades.toStringAsFixed(1)} u. en almacén',
                              icon: LucideIcons.wallet,
                              accentColor: AppTheme.brandPrimary,
                              isDark: isDark,
                              onTap: () =>
                                  widget.onNavigateTab(3), // Tab Inventario
                            ),
                            _buildMetricTile(
                              constraints: constraints,
                              title: 'Catálogo & Stock',
                              value: '$totalProductos Items',
                              subtitle: productosCriticos.isNotEmpty
                                  ? '${productosCriticos.length} por reponer • Ver catálogo'
                                  : 'Existencias saludables',
                              icon: LucideIcons.boxes,
                              accentColor: productosCriticos.isNotEmpty
                                  ? AppTheme.alertRed
                                  : AppTheme.brandPrimary,
                              isDark: isDark,
                              onTap: () =>
                                  widget.onNavigateTab(3), // Tab Inventario
                            ),
                          ],
                        );
                      },
                    ),

                    // Tarjeta en Directo de Canales de Pago
                    _buildPaymentBreakdownCard(isDark),

                    // Termómetro de Meta Diaria de Venta (PRO)
                    _buildTermometroMetaDiaria(isDark),
                    const SizedBox(height: 22),

                    // Hub de Operaciones & Herramientas con Pestañas y Favoritos Personalizables
                    _buildHubOperaciones(isDark),
                    const SizedBox(height: 22),

                    // Banner de Inteligencia de Negocio & BI
                    _buildBiBanner(isDark),
                    const SizedBox(height: 24),

                    // Control de Vencimientos FIFO (Semáforo de Lotes Críticos)
                    if (productosVencidosFIFO.isNotEmpty ||
                        productosCriticosFIFO.isNotEmpty ||
                        productosAtencionFIFO.isNotEmpty) ...[
                      _buildFifoDashboardCard(
                        isDark,
                        vencidos: productosVencidosFIFO.length,
                        criticos: productosCriticosFIFO.length,
                        atencion: productosAtencionFIFO.length,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Alertas de Reposición
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Alertas de Reposición',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (totalAlertas > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.alertRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$totalAlertas productos por agotar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.alertRed,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (productosCriticos.isEmpty && productosBajos.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.borderDark
                                : const Color(0xFFD1FAE5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFD1FAE5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.checkCircle,
                                color: AppTheme.accentGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¡Inventario en Estado Óptimo!',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                  ),
                                  Text(
                                    'Todos los productos tienen existencias saludables.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final items = [
                            ...productosCriticos,
                            ...productosBajos,
                          ].take(6).toList();
                          final double itemWidth = constraints.maxWidth >= 750
                              ? (constraints.maxWidth - 10) / 2
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: items.map((p) {
                              final double umbralMinimo = p.stockMinimo > 0
                                  ? p.stockMinimo
                                  : 5.0;
                              final isCritico =
                                  p.stockActual <= (umbralMinimo * 0.5);
                              final color = isCritico
                                  ? AppTheme.alertRed
                                  : AppTheme.warningAmber;

                              return Container(
                                width: itemWidth,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.cardDark
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark
                                        ? AppTheme.borderDark
                                        : AppTheme.borderLight,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCritico
                                            ? LucideIcons.alertCircle
                                            : LucideIcons.alertTriangle,
                                        color: color,
                                        size: 17,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.nombre,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppTheme.textDark,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Código: ${p.codigo}',
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
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${p.stockActual % 1 == 0 ? p.stockActual.toInt().toString() : p.stockActual.toStringAsFixed(2)} u.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGreetingBanner(
    bool isDark, [
    List<Producto> criticos = const [],
  ]) {
    final String initial = _username.isNotEmpty
        ? _username[0].toUpperCase()
        : 'U';
    final bool isAdmin =
        _userRol.toUpperCase() == 'ADMIN' ||
        _userRol.toUpperCase() == 'SUPERADMIN';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.cardDarkElevated, AppTheme.cardDark]
              : [AppTheme.brandInk, const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFF334155),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila Superior: Badges de Bodega, Plan y Estado en Vivo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge de Bodega
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.store,
                        size: 12,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _nombreBodega,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFF1F5F9),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
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

              // Badges de Plan y Live Sync
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge Plan (Acceso directo a suscripción)
                      InkWell(
                        onTap: () {
                          PlanYPersonalSheet.show(
                            context,
                            nombreBodega: _nombreBodega,
                            plan: _plan,
                            currentUsername: _username,
                            userRol: _userRol,
                            seccionInicial: PlanSheetSeccion.suscripcion,
                            onPlanUpdated: () =>
                                _cargarDatos(forceRefresh: true),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (_plan == 'PRO'
                                        ? const Color(0xFF38BDF8)
                                        : AppTheme.brandPrimary)
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  (_plan == 'PRO'
                                          ? const Color(0xFF38BDF8)
                                          : AppTheme.brandPrimary)
                                      .withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _plan == 'PRO'
                                    ? LucideIcons.sparkles
                                    : LucideIcons.shield,
                                size: 10.5,
                                color: _plan == 'PRO'
                                    ? const Color(0xFF38BDF8)
                                    : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _plan == 'PRO' ? 'PRO' : 'BÁSICO',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Live Dot (Acceso directo a cola offline)
                      InkWell(
                        onTap: () => OfflineQueueSheet.show(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.accentGreen.withValues(
                                alpha: 0.4,
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
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'En Vivo',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF86EFAC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Botón Acceso Rápido a Consejos de Turno (Modal Ejecutivo)
                      InkWell(
                        onTap: () {
                          BriefingTurnoModal.show(
                            context,
                            username: _username,
                            userRol: _userRol,
                            nombreBodega: _nombreBodega,
                            onNavigateTab: widget.onNavigateTab,
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8)
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.45),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.sparkles,
                                size: 11,
                                color: Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Consejos',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Badge sutil de quiebre de stock si hay productos críticos
                      if (criticos.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () =>
                              widget.onNavigateTab(3), // Tab Inventario
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.alertRed.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.alertRed.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.triangleAlert,
                                  size: 11,
                                  color: Color(0xFFFCA5A5),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${criticos.length} por reponer',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fila Principal: Avatar de Usuario + Saludo y Rol Ampliados
          Row(
            children: [
              InkWell(
                onTap: () {
                  PlanYPersonalSheet.show(
                    context,
                    nombreBodega: _nombreBodega,
                    plan: _plan,
                    currentUsername: _username,
                    userRol: _userRol,
                    onPlanUpdated: () => _cargarDatos(forceRefresh: true),
                  );
                },
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.brandPrimary, Color(0xFF0EA5E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Textos de Bienvenida del Usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Bienvenido, $_username!',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          isAdmin
                              ? LucideIcons.shieldCheck
                              : LucideIcons.userCheck,
                          size: 13,
                          color: const Color(0xFF60A5FA),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            isAdmin
                                ? 'Administrador General • Acceso Total'
                                : 'Operador de Tienda • Turno Activo',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF93C5FD),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barra Inferior de Datos de Turno y Fiscales
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _ruc.isNotEmpty ? LucideIcons.fileText : LucideIcons.layers,
                  size: 13,
                  color: const Color(0xFFCBD5E1),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    () {
                      if (_ruc.isNotEmpty && _telefono.isNotEmpty) {
                        return 'RUC: $_ruc • Tel: $_telefono';
                      } else if (_ruc.isNotEmpty) {
                        return 'RUC: $_ruc • ${_direccion.isNotEmpty ? _direccion : 'CajaYa Cloud POS'}';
                      } else if (_telefono.isNotEmpty) {
                        return 'Tel: $_telefono • CajaYa Cloud POS';
                      } else {
                        return 'CajaYa Cloud POS • Ventas, caja e inventario en tiempo real';
                      }
                    }(),
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.checkCheck,
                        size: 11,
                        color: AppTheme.accentGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'POS Activo',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFE2E8F0),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdownCard(bool isDark) {
    final double totalVentas = _cierreHoy?.totalVentas ?? 0.0;
    final int cantVentas = _cierreHoy?.cantidadVentas ?? 0;
    final double ef = _cierreHoy?.totalEfectivo ?? 0.0;
    final double yp = _cierreHoy?.totalYape ?? 0.0;
    final double pl = _cierreHoy?.totalPlin ?? 0.0;
    final double tj = _cierreHoy?.totalTarjeta ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.circleDollarSign,
                        color: AppTheme.brandPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Flujo de Caja en Directo (Hoy)',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$cantVentas cobros sincronizados • Total S/ ${totalVentas.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF334155),
                              fontWeight: FontWeight.w600,
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
              const SizedBox(width: 6),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.brandPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => widget.onNavigateTab(2), // Tab Arqueo de Caja
                icon: const Icon(LucideIcons.arrowRight, size: 14),
                label: Text(
                  'Ver Cuadre',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mini tiles por canal
          LayoutBuilder(
            builder: (context, constraints) {
              final double tileWidth = constraints.maxWidth >= 700
                  ? (constraints.maxWidth - 30) / 4
                  : (constraints.maxWidth >= 300
                        ? (constraints.maxWidth - 10) / 2
                        : constraints.maxWidth);

              Widget buildChannelBox(
                String nombre,
                double monto,
                Color color,
                IconData icon,
              ) {
                final Color effectiveColor = isDark
                    ? (nombre == 'Yape'
                          ? const Color(0xFFE879F9) // Fuchsia 400 radiante
                          : nombre == 'Plin'
                          ? const Color(0xFF38BDF8) // Sky 400 luminoso
                          : nombre == 'Efectivo'
                          ? const Color(0xFF34D399) // Emerald 400 nítido
                          : nombre == 'Tarjeta'
                          ? const Color(0xFFA5B4FC) // Indigo 300
                          : nombre.contains('Cr')
                          ? const Color(0xFFFBBF24) // Amber 400
                          : color)
                    : color;

                return Container(
                  width: tileWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(
                      alpha: isDark ? 0.16 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: effectiveColor.withValues(
                        alpha: isDark ? 0.40 : 0.25,
                      ),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 17, color: effectiveColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: effectiveColor,
                              ),
                            ),
                            Text(
                              'S/ ${monto.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  buildChannelBox(
                    'Efectivo',
                    ef,
                    AppTheme.accentGreen,
                    LucideIcons.banknote,
                  ),
                  buildChannelBox(
                    'Yape',
                    yp,
                    const Color(0xFF732283),
                    LucideIcons.smartphone,
                  ),
                  buildChannelBox(
                    'Plin',
                    pl,
                    const Color(0xFF0084FF),
                    LucideIcons.smartphone,
                  ),
                  buildChannelBox(
                    'Tarjeta',
                    tj,
                    const Color(0xFF6366F1),
                    LucideIcons.creditCard,
                  ),
                  if ((_cierreHoy?.totalCredito ?? 0.0) > 0)
                    buildChannelBox(
                      'Crédito',
                      _cierreHoy!.totalCredito,
                      const Color(0xFFD97706),
                      LucideIcons.handCoins,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBiBanner(bool isDark) {
    final bool isPro = _plan.toUpperCase() == 'PRO';
    return InkWell(
      onTap: () {
        if (!isPro) {
          PlanUpgradeModal.show(
            context,
            featureName: 'Analítica de Rentabilidad Real & BI',
            featureDescription: 'Calcula tu margen bruto real en soles y porcentaje restando el costo de compra en cada venta, conociendo tus horas punta de afluencia y rotación de productos estrella vs huesos.',
            icon: LucideIcons.trendingUp,
            onPlanUpdated: _cargarDatos,
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DashboardBiScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [AppTheme.surfaceTint, const Color(0xFFE0E7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderTint,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brandPrimary.withValues(
                alpha: isDark ? 0.12 : 0.06,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                LucideIcons.trendingUp,
                color: AppTheme.brandPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Analítica de Negocio & BI',
                          style: GoogleFonts.outfit(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isPro
                              ? AppTheme.brandPrimary
                              : const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isPro) ...[
                              const Icon(
                                LucideIcons.lock,
                                size: 9,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              isPro ? 'NUEVO' : 'PRO',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isPro
                        ? 'Margen bruto real, rotación de productos estrella/hueso y horas pico 24h.'
                        : '🔒 Margen bruto real, detector de huesos y horas pico 24h • Toca para desbloquear con Plan PRO.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPro
                          ? (isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF334155))
                          : const Color(0xFFD97706),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.chevronRight,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required BoxConstraints constraints,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final double cardWidth = constraints.maxWidth >= 1050
        ? (constraints.maxWidth - 30) / 4
        : (constraints.maxWidth >= 580
              ? (constraints.maxWidth - 10) / 2
              : (constraints.maxWidth > 350
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth));

    // Acentos luminosos vibrantes para máxima legibilidad WCAG AAA en Modo Oscuro
    final Color displayAccent = isDark
        ? (accentColor == AppTheme.accentGreen
              ? const Color(0xFF34D399) // Emerald 400 nítido
              : accentColor == const Color(0xFFD97706) ||
                    accentColor == AppTheme.warningAmber
              ? const Color(0xFFFBBF24) // Amber 400 luminoso
              : accentColor == AppTheme.alertRed
              ? const Color(0xFFF87171) // Red 400 radiante
              : accentColor == AppTheme.brandPrimary
              ? const Color(0xFF60A5FA) // Blue 400 vivo
              : accentColor == AppTheme.infoIndigo
              ? const Color(0xFFA78BFA) // Violet 400
              : accentColor)
        : accentColor;

    // Título con contraste nítido: Slate 100 en oscuro, Slate 800 en claro
    final Color titleColor = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E293B);

    final card = Container(
      width: cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.borderDarkElevated : AppTheme.borderLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black12).withValues(
              alpha: isDark ? 0.35 : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: displayAccent.withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: displayAccent.withValues(alpha: isDark ? 0.35 : 0.18),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: displayAccent,
              size: ResponsiveLayout.iconSize(context, base: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ResponsiveLayout.fontSize(context, base: 12.5),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: ResponsiveLayout.fontSize(context, base: 19.0),
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                    maxLines: 1,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: ResponsiveLayout.fontSize(context, base: 11.5),
                    fontWeight: FontWeight.w700,
                    color: displayAccent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: card,
        ),
      );
    }
    return card;
  }

  Widget _buildHubOperaciones(bool isDark) {
    final todas = _obtenerTodasLasOperaciones(isDark);
    final esAdmin = _userRol == 'ADMIN' || _userRol == 'SUPERADMIN';

    // Filtrar operaciones de la pestaña seleccionada
    List<_OperacionItem> activas = [];
    if (_tabOperaciones == 0) {
      // Favoritos: en el orden exacto configurado por el usuario
      for (final id in _favoritosIds) {
        final match = todas.firstWhere(
          (op) => op.id == id,
          orElse: () => todas.first,
        );
        if ((!match.requiresAdmin || esAdmin) && !activas.contains(match)) {
          activas.add(match);
        }
      }
    } else if (_tabOperaciones == 1) {
      activas = todas
          .where(
            (op) => op.categoria == 'almacen' && (!op.requiresAdmin || esAdmin),
          )
          .toList();
    } else if (_tabOperaciones == 2) {
      activas = todas
          .where(
            (op) => op.categoria == 'ventas' && (!op.requiresAdmin || esAdmin),
          )
          .toList();
    } else if (_tabOperaciones == 3) {
      activas = todas
          .where(
            (op) => op.categoria == 'gestion' && (!op.requiresAdmin || esAdmin),
          )
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con título y botón para gestionar favoritos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Operaciones & Herramientas',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            InkWell(
              onTap: () =>
                  _mostrarModalInstruccionPersonalizar(context, isDark),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.slidersHorizontal,
                      size: 14,
                      color: AppTheme.brandPrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Personalizar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Barra de pestañas / chips segmentados
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTabPill(
                index: 0,
                label: 'Favoritos',
                icon: LucideIcons.bookmarkCheck,
                badge: '${_favoritosIds.length}',
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildTabPill(
                index: 1,
                label: 'Almacén',
                icon: LucideIcons.boxes,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildTabPill(
                index: 2,
                label: 'Ventas & Web',
                icon: LucideIcons.trendingUp,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildTabPill(
                index: 3,
                label: 'Gestión',
                icon: LucideIcons.settings,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Cuadrícula de botones
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 850;
            final double btnWidth = isDesktop
                ? (constraints.maxWidth - 20) / 3
                : (constraints.maxWidth - 10) / 2;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...activas.map((op) {
                  return _buildQuickActionBtn(
                    width: btnWidth,
                    opId: op.id,
                    onLongPress: () => _toggleFavorito(op.id, op.title),
                    title: op.title,
                    subtitle: op.subtitle,
                    icon: op.icon,
                    color: op.color,
                    isDark: isDark,
                    isLocked: op.isLocked,
                    onTap: op.onTap,
                  );
                }),
                // Si está en la pestaña de favoritos, tarjeta dashed para agregar o editar
                if (_tabOperaciones == 0)
                  _buildAddFavoriteDashedCard(
                    width: btnWidth,
                    isDark: isDark,
                    onTap: () =>
                        _mostrarModalInstruccionPersonalizar(context, isDark),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTabPill({
    required int index,
    required String label,
    required IconData icon,
    String? badge,
    required bool isDark,
  }) {
    final isSelected = _tabOperaciones == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _tabOperaciones = index);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.brandPrimary
                : (isDark ? AppTheme.cardDark : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppTheme.brandPrimary
                  : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155)),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppTheme.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : AppTheme.brandPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddFavoriteDashedCard({
    required double width,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.cardDark.withValues(alpha: 0.35)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.plus,
                      color: AppTheme.brandPrimary,
                      size: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'AJUSTES',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.brandPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '+ Añadir Favorito',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Mantén presionado para fijar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildPasoItem({
    required String numero,
    required String texto,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.brandPrimary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            numero,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.brandPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarModalInstruccionPersonalizar(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDarkElevated : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Manija de arrastre
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Icono táctil
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.hand,
                  color: AppTheme.brandPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),

              // Texto requerido
              Text(
                'Mantén apretada una operación para agregar a acceso directo',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Para personalizar qué operaciones aparecen en tu pantalla de inicio, ve a cualquier categoría (Almacén, Ventas & Web o Gestión) y mantén presionado el dedo sobre cualquier tarjeta durante un segundo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Pasos claros
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _buildPasoItem(
                      numero: '1',
                      texto: 'Entra a la pestaña que desees (ej: Almacén o Ventas).',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildPasoItem(
                      numero: '2',
                      texto: 'Mantén pulsada la tarjeta por 1 segundo.',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildPasoItem(
                      numero: '3',
                      texto:
                          '¡Listo! Quedará fijada o removida de tus Favoritos.',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Botón de acción principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Entendido, ¡voy a probarlo!',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_OperacionItem> _obtenerTodasLasOperaciones(bool isDark) {
    final bool esPro = _plan.toUpperCase() == 'PRO';

    return [
      // --- ALMACÉN ---
      _OperacionItem(
        id: 'nuevo_producto',
        categoria: 'almacen',
        title: '+ Nuevo Producto',
        subtitle: 'Crear en Catálogo',
        icon: LucideIcons.plusCircle,
        color: AppTheme.brandPrimary,
        onTap: () {
          final esBasico = !esPro;
          if (esBasico && _productos.length >= 150) {
            PlanUpgradeModal.show(
              context,
              featureName: 'Catálogo de Productos Ilimitado',
              featureDescription: 'Has alcanzado el límite de 150 productos activos para el Plan Bodega Básico. Actualiza al Plan Minimarket PRO para registrar productos ilimitados.',
              icon: LucideIcons.boxes,
              onPlanUpdated: _cargarDatos,
            );
            return;
          }
          NuevoProductoSheet.show(context, _cargarDatos);
        },
      ),
      _OperacionItem(
        id: 'compras',
        categoria: 'almacen',
        title: 'Compras & Lotes',
        subtitle: 'Ingreso Proveedores',
        icon: LucideIcons.truck,
        color: AppTheme.brandPrimary,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ComprasScreen()),
          );
        },
      ),
      _OperacionItem(
        id: 'vencimientos',
        categoria: 'almacen',
        title: 'Control Vencimientos',
        subtitle: 'Semáforo de Caducidad FIFO',
        icon: LucideIcons.calendarClock,
        color: AppTheme.brandPrimary,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VencimientosScreen()),
          );
        },
      ),
      _OperacionItem(
        id: 'mermas',
        categoria: 'almacen',
        title: 'Registro de Mermas',
        subtitle: 'Bajas & Pérdidas',
        icon: LucideIcons.trash2,
        color: AppTheme.brandPrimary,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MermasScreen()),
          );
        },
      ),
      _OperacionItem(
        id: 'auditoria_ciega',
        categoria: 'almacen',
        title: 'Auditoría Ciega',
        subtitle: 'Conteo Rápido (Anti-Robo)',
        icon: LucideIcons.clipboardCheck,
        color: AppTheme.brandPrimary,
        isLocked: !esPro,
        onTap: () {
          if (!esPro) {
            PlanUpgradeModal.show(
              context,
              featureName: 'Auditoría Rápida por Pasillo',
              featureDescription: 'Realiza conteos físicos aleatorios de 5 minutos por góndola o pasillo sin mostrar el stock real al personal, detectando mermas y robo hormiga a tiempo.',
              icon: LucideIcons.clipboardCheck,
              onPlanUpdated: _cargarDatos,
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AuditoriaCiegaScreen()),
          );
        },
      ),
      _OperacionItem(
        id: 'kardex',
        categoria: 'almacen',
        title: 'Kardex Auditoría',
        subtitle: 'Historial de Movimientos',
        icon: LucideIcons.fileSpreadsheet,
        color: AppTheme.brandPrimary,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const KardexScreen()),
          );
        },
      ),

      // --- VENTAS & WEB ---
      _OperacionItem(
        id: 'bodega_online',
        categoria: 'ventas',
        title: 'Mi Bodega Online',
        subtitle: 'Catálogo Web & WhatsApp',
        icon: LucideIcons.globe,
        color: const Color(0xFF16A34A),
        isLocked: !esPro,
        onTap: () {
          if (!esPro) {
            PlanUpgradeModal.show(
              context,
              featureName: 'Mi Bodega Online',
              featureDescription: 'Obtén tu propio enlace web oficial (cajaya-pos.onrender.com/#/catalogo?tienda=tu-bodega) para compartir en redes sociales y recibir pedidos directos en tu WhatsApp sin comisiones.',
              icon: LucideIcons.globe,
              onPlanUpdated: _cargarDatos,
            );
            return;
          }
          MiBodegaOnlineModal.show(
            context,
            nombreBodega: _nombreBodega,
            telefonoBodega: _telefono,
          );
        },
      ),
      _OperacionItem(
        id: 'promociones',
        categoria: 'ventas',
        title: 'Promociones & Combos',
        subtitle: 'Descuentos & Huesos',
        icon: LucideIcons.tag,
        color: AppTheme.brandDark,
        isLocked: !esPro,
        onTap: () {
          if (!esPro) {
            PlanUpgradeModal.show(
              context,
              featureName: 'Promociones y Descuentos',
              featureDescription: 'Configura descuentos por marcas, categorías y combos estratégicos para liquidar productos estancados en tu catálogo online.',
              icon: LucideIcons.tag,
              onPlanUpdated: _cargarDatos,
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PromocionesScreen(
                isPro: true,
                nombreBodega: _nombreBodega,
                onPlanUpdated: _cargarDatos,
              ),
            ),
          );
        },
      ),
      _OperacionItem(
        id: 'analitica_bi',
        categoria: 'ventas',
        title: 'Analítica & Rentabilidad',
        subtitle: 'Márgenes, Horas & Stock',
        icon: LucideIcons.trendingUp,
        color: const Color(0xFF8B5CF6),
        isLocked: !esPro,
        onTap: () {
          if (!esPro) {
            PlanUpgradeModal.show(
              context,
              featureName: 'Analítica de Negocio & BI',
              featureDescription: 'Calcula tu margen bruto real en soles y porcentaje restando el costo de compra en cada venta, conociendo tu rentabilidad exacta sin estimaciones.',
              icon: LucideIcons.trendingUp,
              onPlanUpdated: _cargarDatos,
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DashboardBiScreen()),
          );
        },
      ),
      _OperacionItem(
        id: 'marketing',
        categoria: 'ventas',
        title: 'Marketing de Barrio',
        subtitle: 'Afiche Vitrina & Volante QR',
        icon: LucideIcons.megaphone,
        color: const Color(0xFFD97706),
        requiresAdmin: true,
        onTap: () {
          KitMarketingBarrioModal.show(
            context,
            nombreBodega: _nombreBodega,
            telefono: _telefono.isNotEmpty ? _telefono : null,
            slugOrId: KitMarketingBarrioModal.normalizarSlug(_nombreBodega),
          );
        },
      ),

      // --- GESTIÓN & HARDWARE ---
      _OperacionItem(
        id: 'impresora',
        categoria: 'gestion',
        title: 'Impresora Térmica',
        subtitle: 'Tickets & Gaveta ESC/POS',
        icon: LucideIcons.printer,
        color: AppTheme.brandPrimary,
        onTap: () => ConfiguracionTicketModal.show(context),
      ),
      _OperacionItem(
        id: 'personal',
        categoria: 'gestion',
        title: 'Personal & Cajeros',
        subtitle: 'Turnos & Accesos del Equipo',
        icon: LucideIcons.users,
        color: AppTheme.brandPrimary,
        requiresAdmin: true,
        onTap: () => PlanYPersonalSheet.show(
          context,
          nombreBodega: _nombreBodega,
          plan: _plan,
          currentUsername: _username,
          userRol: _userRol,
          seccionInicial: PlanSheetSeccion.personal,
          onPlanUpdated: () => _cargarDatos(forceRefresh: true),
        ),
      ),
      _OperacionItem(
        id: 'suscripcion',
        categoria: 'gestion',
        title: 'Mi Suscripción',
        subtitle: _plan == 'PRO'
            ? 'Plan Minimarket Pro • Ilimitado'
            : 'Plan Bodega Básico • Renovar',
        icon: LucideIcons.crown,
        color: const Color(0xFF0D9488),
        requiresAdmin: true,
        onTap: () => PlanYPersonalSheet.show(
          context,
          nombreBodega: _nombreBodega,
          plan: _plan,
          currentUsername: _username,
          userRol: _userRol,
          seccionInicial: PlanSheetSeccion.suscripcion,
          onPlanUpdated: () => _cargarDatos(forceRefresh: true),
        ),
      ),

      // --- ACCESOS DE MOSTRADOR (Disponibles para agregar a favoritos) ---
      _OperacionItem(
        id: 'cobrar_pos',
        categoria: 'mostrador',
        title: 'Cobrar en POS',
        subtitle: 'Terminal de Venta Rápida',
        icon: LucideIcons.shoppingBag,
        color: AppTheme.brandPrimary,
        onTap: () => widget.onNavigateTab(1),
      ),
      _OperacionItem(
        id: 'arqueo_caja',
        categoria: 'mostrador',
        title: 'Arqueo de Caja',
        subtitle: 'Corte, Historial & Cuadre',
        icon: LucideIcons.banknote,
        color: AppTheme.brandPrimary,
        onTap: () => widget.onNavigateTab(2),
      ),
      _OperacionItem(
        id: 'fiados',
        categoria: 'mostrador',
        title: 'Libreta de Fiados',
        subtitle: 'Cobros & WhatsApp',
        icon: LucideIcons.bookUser,
        color: const Color(0xFFD97706),
        onTap: () {
          widget.onNavigateTab(4);
          ClientesScreen.cambiarPestana(0);
        },
      ),
      _OperacionItem(
        id: 'garantias',
        categoria: 'mostrador',
        title: 'Garantía Botellas',
        subtitle: 'Envases & Devolución Retornable',
        icon: LucideIcons.wine,
        color: const Color(0xFF2563EB),
        onTap: () {
          widget.onNavigateTab(4);
          ClientesScreen.cambiarPestana(1);
        },
      ),
    ];
  }

  Widget _buildQuickActionBtn({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    String? opId,
    double? width,
    bool isBanner = false,
    bool isPrimaryHero = false,
    bool isLocked = false,
    String? lockedBadge = 'PRO',
  }) {
    final Color cardBg = isPrimaryHero
        ? (isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
              : const Color(0xFFEFF6FF))
        : (isDark ? AppTheme.cardDark : Colors.white);

    final Color borderColor = isPrimaryHero
        ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD))
        : (isLocked
              ? (isDark
                    ? const Color(0xFFD97706).withValues(alpha: 0.35)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.45))
              : (isDark ? AppTheme.borderDarkElevated : AppTheme.borderLight));

    final Color iconBg = isPrimaryHero
        ? AppTheme.brandPrimary
        : color.withValues(alpha: isDark ? 0.20 : 0.10);

    final Color iconColor = isPrimaryHero
        ? Colors.white
        : (isDark ? const Color(0xFF60A5FA) : color);

    final card = Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress:
            onLongPress ??
            (opId != null ? () => _toggleFavorito(opId, title) : null),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: isPrimaryHero ? 1.6 : 1.2,
            ),
          ),
          child: isBanner
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: ResponsiveLayout.iconSize(context, base: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: ResponsiveLayout.fontSize(
                                    context,
                                    base: 13.5,
                                  ),
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isPrimaryHero) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.brandPrimary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'PRINCIPAL',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ] else if (isLocked) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFD97706,
                                    ).withValues(alpha: isDark ? 0.22 : 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFD97706)
                                          .withValues(alpha: 0.4),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.lock,
                                        size: 9,
                                        color: Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        lockedBadge ?? 'PRO',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF94A3B8),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            color: iconColor,
                            size: ResponsiveLayout.iconSize(context, base: 18),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPrimaryHero)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandPrimary,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'PRINCIPAL',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else if (isLocked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706)
                                      .withValues(alpha: isDark ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFD97706)
                                        .withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.lock,
                                      size: 9.5,
                                      color: Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      lockedBadge ?? 'PRO',
                                      style: GoogleFonts.outfit(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFD97706),
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
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: ResponsiveLayout.fontSize(
                          context,
                          base: 13.5,
                        ),
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: ResponsiveLayout.fontSize(
                          context,
                          base: 11.5,
                        ),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );

    if (width != null) return card;
    return Expanded(child: card);
  }

  Widget _buildFifoDashboardCard(
    bool isDark, {
    required int vencidos,
    required int criticos,
    required int atencion,
  }) {
    final int totalRiesgo = vencidos + criticos + atencion;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? (vencidos > 0
                  ? const Color(0xFF450A0A).withValues(alpha: 0.6)
                  : const Color(0xFF422006).withValues(alpha: 0.5))
            : (vencidos > 0
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFFFFBEB)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: vencidos > 0
              ? const Color(0xFFEF4444).withValues(alpha: 0.45)
              : const Color(0xFFF59E0B).withValues(alpha: 0.45),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (vencidos > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFD97706))
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  vencidos > 0
                      ? LucideIcons.alertTriangle
                      : LucideIcons.calendarClock,
                  color: vencidos > 0
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFD97706),
                  size: 18,
                ),
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
                            'Control de Vencimientos FIFO',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : (vencidos > 0
                                        ? const Color(0xFF991B1B)
                                        : const Color(0xFF92400E)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (vencidos > 0
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFFD97706))
                                    .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$totalRiesgo en riesgo',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: vencidos > 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lotes prioritarios para rotar en repisa o retirar del mostrador.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (vencidos > 0)
                      _buildFifoDashboardBadge(
                        label: '$vencidos Vencidos (Retirar)',
                        color: const Color(0xFFEF4444),
                        isDark: isDark,
                      ),
                    if (criticos > 0)
                      _buildFifoDashboardBadge(
                        label: '$criticos Críticos (≤ 7d - Liquidar)',
                        color: const Color(0xFFEA580C),
                        isDark: isDark,
                      ),
                    if (atencion > 0)
                      _buildFifoDashboardBadge(
                        label: '$atencion En Rotación (≤ 30d)',
                        color: const Color(0xFFD97706),
                        isDark: isDark,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VencimientosScreen(),
                    ),
                  ).then((_) => _cargarDatos(forceRefresh: true));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: vencidos > 0
                      ? const Color(0xFFEF4444)
                      : primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(LucideIcons.arrowUpRight, size: 13),
                label: Text(
                  'Revisar Lotes',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFifoDashboardBadge({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
