import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../productos/productos_screen.dart';
import '../ventas/ventas_screen.dart';
import '../ventas/caja_ventas_screen.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/widgets/water_drop_theme_transition.dart';
import '../../core/update_service.dart';
import '../../core/cajaya_vectors.dart';
import '../../core/lock_service.dart';
import '../../core/widgets/karliz_lock_screen.dart';
import '../../core/widgets/briefing_turno_modal.dart';
import '../../core/responsive_layout.dart';
import 'bodega_service.dart';
import 'mi_suscripcion_modal.dart';
import '../productos/sugerencias_precio_modal.dart';
import 'configuracion_marca_modal.dart';
import '../legal/libro_reclamaciones_screen.dart';
import '../legal/terminos_condiciones_screen.dart';
import '../legal/politica_privacidad_screen.dart';
import 'pixel_perfect_navbar.dart';
import '../clientes/clientes_screen.dart';
import '../../core/offline/offline_sync_manager.dart';
import '../../core/offline/offline_queue_sheet.dart';
import '../../core/offline/offline_models.dart';
import '../../core/window/window_service.dart';

import 'package:shorebird_code_push/shorebird_code_push.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final Set<int> _loadedTabs = {0};
  final ValueNotifier<int> _activeTabNotifier = ValueNotifier<int>(0);
  late final List<Widget> _screens;
  String _username = 'admin';
  String _userRol = 'ADMIN';
  String _nombreBodega = 'CajaYa POS';
  String _plan = 'BASICO';
  int? _diasRestantesPlan;
  BodegaInfo? _bodegaInfo;
  Map<String, dynamic> _anuncioGlobal = {};
  bool _anuncioDismissed = false;
  int _sugerenciasPendientes = 0;
  Timer? _inactivityTimer;
  DateTime? _lastInactivityResetAt;
  bool _orientationConfigured = false;
  bool _railCollapsed = false;

  void _selectTab(int index) {
    final safeIndex = index.clamp(0, _screens.length - 1);
    if (!mounted) return;
    if (_selectedIndex == safeIndex && _loadedTabs.contains(safeIndex)) {
      return;
    }
    setState(() {
      _selectedIndex = safeIndex;
      _loadedTabs.add(safeIndex);
    });
    _activeTabNotifier.value = safeIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_orientationConfigured) {
      _orientationConfigured = true;
      ResponsiveLayout.autoConfigureOrientation(context);
    }
  }

  List<Widget> get _builtScreens {
    return List.generate(_screens.length, (index) {
      if (_loadedTabs.contains(index)) {
        return TickerMode(
          enabled: _selectedIndex == index,
          child: _screens[index],
        );
      }
      return const SizedBox.shrink();
    });
  }

  @override
  void initState() {
    super.initState();
    OfflineSyncManager.instance.init();
    BodegaService.sugerenciasPendientesNotifier.addListener(
      _onSugerenciasNotifierChanged,
    );
    _cargarDatosUsuario();
    _resetInactivityTimer();
    _screens = [
      DashboardScreen(
        onNavigateTab: _selectTab,
        activeTabNotifier: _activeTabNotifier,
        tabIndex: 0,
      ),
      VentasScreen(activeTabNotifier: _activeTabNotifier, tabIndex: 1),
      CajaVentasScreen(activeTabNotifier: _activeTabNotifier, tabIndex: 2),
      ProductosScreen(activeTabNotifier: _activeTabNotifier, tabIndex: 3),
      ClientesScreen(activeTabNotifier: _activeTabNotifier, tabIndex: 4),
    ];
  }

  @override
  void dispose() {
    BodegaService.sugerenciasPendientesNotifier.removeListener(
      _onSugerenciasNotifierChanged,
    );
    _inactivityTimer?.cancel();
    _activeTabNotifier.dispose();
    super.dispose();
  }

  void _resetInactivityTimer({bool throttle = false}) {
    final now = DateTime.now();
    if (throttle &&
        _inactivityTimer != null &&
        _lastInactivityResetAt != null &&
        now.difference(_lastInactivityResetAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastInactivityResetAt = now;
    _inactivityTimer?.cancel();
    if (!mounted || LockService().isLocked) return;

    _inactivityTimer = Timer(const Duration(minutes: 5), () async {
      final autoLock = await LockService().isAutoLockEnabled();
      final hasPin = await LockService().hasPin();
      if (autoLock && hasPin && mounted && !LockService().isLocked) {
        _bloquearPantalla();
      }
    });
  }

  Future<void> _bloquearPantalla() async {
    final hasPin = await LockService().hasPin();
    if (!hasPin) {
      if (!mounted) return;
      KarlizLockScreen.mostrarDialogoPinRequerido(
        context,
        onPinConfigurado: () {
          if (mounted) _bloquearPantalla();
        },
      );
      return;
    }

    if (!mounted) return;
    KarlizLockScreen.show(
      context,
      onUnlocked: () {
        _resetInactivityTimer();
      },
      onLogout: () async {
        _inactivityTimer?.cancel();
        await AuthService().logout();
        if (mounted) context.go('/login');
      },
    );
  }

  Future<void> _cargarDatosUsuario() async {
    final auth = AuthService();
    final results = await Future.wait([
      auth.getUsername(),
      auth.getUserRole(),
      auth.getNombreBodega(),
      auth.getPlanBodega(),
    ]);
    if (mounted) {
      setState(() {
        _username = results[0];
        _userRol = results[1];
        _nombreBodega = results[2];
        _plan = results[3];
      });

      // Sincronización en segundo plano del plan real de la bodega desde la nube
      BodegaService()
          .obtenerMiBodega()
          .then((info) {
            if (mounted && info != null) {
              int? dias;
              if (info.fechaVencimientoPlan != null) {
                try {
                  final fv = DateTime.parse(info.fechaVencimientoPlan!);
                  dias = fv.difference(DateTime.now()).inDays;
                } catch (_) {}
              }
              setState(() {
                _bodegaInfo = info;
                if (info.nombreComercial.trim().isNotEmpty &&
                    (_nombreBodega == 'CajaYa POS' || _nombreBodega.isEmpty)) {
                  _nombreBodega = info.nombreComercial.trim();
                }
                if (info.plan.toUpperCase() != _plan.toUpperCase()) {
                  _plan = info.plan;
                }
                _diasRestantesPlan = dias;
                final esPlanPro =
                    info.plan.toUpperCase() == 'PRO' ||
                    info.plan.toUpperCase() == 'CORPORATIVO';
                if (esPlanPro && info.colorPrimario.isNotEmpty) {
                  context.read<ThemeProvider>().setAccentColorFromHex(
                    info.colorPrimario,
                  );
                } else if (!esPlanPro) {
                  context.read<ThemeProvider>().setAccentColorFromHex(
                    '#2563EB',
                  );
                }
              });
            }
          })
          .catchError((_) {});

      try {
        final anuncio = await BodegaService().obtenerAnuncioGlobal();
        if (mounted) setState(() => _anuncioGlobal = anuncio);
      } catch (_) {}

      _verificarSugerenciasSuperadmin();

      if (mounted) {
        // Mostrar Briefing de Turno ejecutivo/operativo al inicio de sesión
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && !LockService().isLocked) {
            BriefingTurnoModal.showIfNeeded(
              context,
              username: _username,
              userRol: _userRol,
              nombreBodega: _nombreBodega,
              onNavigateTab: _selectTab,
            );
          }
        });
      }
    }
  }

  void _onSugerenciasNotifierChanged() {
    if (mounted) {
      setState(() {
        _sugerenciasPendientes =
            BodegaService.sugerenciasPendientesNotifier.value;
      });
    }
  }

  Future<void> _verificarSugerenciasSuperadmin() async {
    try {
      final count = await BodegaService().contarMisSugerenciasPendientes();
      if (mounted) setState(() => _sugerenciasPendientes = count);
    } catch (_) {}
  }

  void _mostrarPanelAdmin() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark
            ? AppTheme.cardDarkElevated
            : const Color(0xFFF8FAFC);
        final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Manija superior
                        Center(
                          child: Container(
                            width: 38,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Cabecera: Título y Cerrar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.brandPrimary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    LucideIcons.user,
                                    size: 18,
                                    color: AppTheme.brandPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Mi Cuenta & Turno',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                LucideIcons.x,
                                size: 20,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF64748B),
                              ),
                              onPressed: () =>
                                  Navigator.pop(bottomSheetContext),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Tarjeta de Usuario en Sesión
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.brandPrimary,
                                      AppTheme.brandDark,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.brandPrimary.withValues(
                                        alpha: 0.30,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _username.isNotEmpty
                                        ? _username
                                              .substring(0, 1)
                                              .toUpperCase()
                                        : 'U',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _username.isNotEmpty
                                                ? _username.toUpperCase()
                                                : 'USUARIO',
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
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: _userRol == 'ADMIN'
                                              ? () {
                                                  Navigator.pop(
                                                    bottomSheetContext,
                                                  );
                                                  MiSuscripcionModal.show(
                                                    context,
                                                    nombreBodega: _nombreBodega,
                                                    planActual: _plan,
                                                    onPlanUpdated:
                                                        _cargarDatosUsuario,
                                                  );
                                                }
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  (_userRol == 'SUPERADMIN'
                                                          ? const Color(
                                                              0xFF8B5CF6,
                                                            )
                                                          : (_userRol == 'ADMIN'
                                                                ? AppTheme
                                                                      .brandPrimary
                                                                : const Color(
                                                                    0xFF64748B,
                                                                  )))
                                                      .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _userRol == 'SUPERADMIN'
                                                      ? 'SUPERADMIN'
                                                      : (_userRol == 'ADMIN'
                                                            ? 'ADMIN • PLAN $_plan'
                                                            : 'CAJERO'),
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        _userRol == 'SUPERADMIN'
                                                        ? const Color(
                                                            0xFF8B5CF6,
                                                          )
                                                        : (_userRol == 'ADMIN'
                                                              ? AppTheme
                                                                    .brandPrimary
                                                              : const Color(
                                                                  0xFF64748B,
                                                                )),
                                                  ),
                                                ),
                                                if (_userRol == 'ADMIN') ...[
                                                  const SizedBox(width: 3),
                                                  const Icon(
                                                    LucideIcons.chevronRight,
                                                    size: 10,
                                                    color:
                                                        AppTheme.brandPrimary,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_bodegaInfo?.nombreComercial ?? (_nombreBodega.isNotEmpty ? _nombreBodega : "CajaYa")} • Terminal Activo',
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Suscripción SaaS (Exclusivo Administrador)
                        if (_userRol == 'ADMIN' ||
                            _userRol == 'SUPERADMIN') ...[
                          InkWell(
                            onTap: () {
                              Navigator.pop(bottomSheetContext);
                              MiSuscripcionModal.show(
                                context,
                                nombreBodega: _nombreBodega,
                                planActual: _plan,
                                onPlanUpdated: _cargarDatosUsuario,
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF3B82F6)
                                            .withValues(alpha: 0.3)
                                      : const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      LucideIcons.crown,
                                      color: Color(0xFF2563EB),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Plan ${_plan.toUpperCase()} • Mi Suscripción',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1E3A8A),
                                          ),
                                        ),
                                        Text(
                                          _diasRestantesPlan != null
                                              ? (_diasRestantesPlan! < 0
                                                    ? 'Suscripción vencida • Renovar ahora'
                                                    : (_diasRestantesPlan! <= 5
                                                          ? '¡Vence en $_diasRestantesPlan días! • Renovar'
                                                          : 'Activa • Vence en $_diasRestantesPlan días'))
                                              : 'Gestionar plan y comprobantes',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                _diasRestantesPlan != null &&
                                                    _diasRestantesPlan! <= 5
                                                ? const Color(0xFFD97706)
                                                : (isDark
                                                      ? const Color(0xFF93C5FD)
                                                      : const Color(
                                                          0xFF2563EB,
                                                        )),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Gestionar',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Acceso directo a Configuración de Marca y Colores (Plan PRO)
                          InkWell(
                            onTap: () {
                              Navigator.pop(bottomSheetContext);
                              ConfiguracionMarcaModal.show(
                                context,
                                isPro:
                                    _plan.toUpperCase() == 'PRO' ||
                                    _plan.toUpperCase() == 'CORPORATIVO',
                                onSaved: _cargarDatosUsuario,
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.cardDarkHighlight
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      LucideIcons.palette,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Personalizar Colores de Tienda',
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
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'PRO',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Elige tu color preferido para la app y tu catálogo web',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: isDark
                                                ? AppTheme.textDarkSecondary
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    LucideIcons.chevronRight,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Acciones de Turno y Seguridad de Mostrador (Fila ergonómica de 2 tarjetas)
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(bottomSheetContext);
                                  _bloquearPantalla();
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: AppTheme.brandPrimary
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          LucideIcons.lock,
                                          color: AppTheme.brandPrimary,
                                          size: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Bloquear Terminal',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Pausa con PIN',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          color: isDark
                                              ? AppTheme.textDarkSecondary
                                              : const Color(0xFF64748B),
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
                                onTap: () {
                                  Navigator.pop(bottomSheetContext);
                                  ConfigurarPinModal.show(
                                    context,
                                    onPinGuardado: () {
                                      if (mounted) setState(() {});
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentGreen
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          LucideIcons.keyRound,
                                          color: AppTheme.accentGreen,
                                          size: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Mi PIN de Caja',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Clave de 4 dígitos',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          color: isDark
                                              ? AppTheme.textDarkSecondary
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (WindowService.instance.isSupported)
                          ValueListenableBuilder<bool>(
                            valueListenable:
                                WindowService.instance.isFullScreenNotifier,
                            builder: (context, isFullScreen, _) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildModalMenuTile(
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  icon: isFullScreen
                                      ? LucideIcons.minimize
                                      : LucideIcons.maximize,
                                  iconColor: AppTheme.brandPrimary,
                                  iconBg: AppTheme.brandPrimary.withValues(
                                    alpha: 0.12,
                                  ),
                                  title: isFullScreen
                                      ? 'Salir de Pantalla Completa'
                                      : 'Pantalla Completa Mostrador',
                                  subtitle:
                                      'Modo Kiosco POS (Atajo con tecla F11)',
                                  trailing: Switch.adaptive(
                                    value: isFullScreen,
                                    activeThumbColor: AppTheme.brandPrimary,
                                    onChanged: (val) {
                                      WindowService.instance.setFullScreen(val);
                                    },
                                  ),
                                  onTap: () {
                                    WindowService.instance.toggleFullScreen();
                                  },
                                ),
                              );
                            },
                          ),

                        // Centro de Ayuda & Atajos de Mostrador
                        _buildModalMenuTile(
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          icon: LucideIcons.helpCircle,
                          iconColor: const Color(0xFF0284C7),
                          iconBg: const Color(0xFF0284C7)
                              .withValues(alpha: 0.12),
                          title: 'Centro de Ayuda & Atajos',
                          subtitle:
                              'Manual del sistema, atajos F2, F4, Esc y guías',
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            _mostrarGuiaDidactica();
                          },
                        ),
                        const SizedBox(height: 10),

                        // Cerrar Sesión del Terminal
                        InkWell(
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            _confirmarCerrarSesion();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.alertRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.alertRed.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.alertRed.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    LucideIcons.logOut,
                                    color: AppTheme.alertRed,
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Cerrar Sesión del Terminal',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.alertRed,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  LucideIcons.chevronRight,
                                  size: 16,
                                  color: AppTheme.alertRed,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Footer sutil: versión y enlaces legales discretos
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.pop(bottomSheetContext);
                                  _verificarActualizacion();
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 4,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        'CajaYa POS v2.4.0',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppTheme.textDarkSecondary
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                      Text(
                                        '• Buscar actualización',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? AppTheme.brandLight
                                              : AppTheme.brandPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () {
                                  Navigator.pop(bottomSheetContext);
                                  _mostrarModalLegal();
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    'Términos & Privacidad • Libro de Reclamaciones',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.getAdaptiveHintText(
                                        isDark,
                                      ),
                                      decoration: TextDecoration.underline,
                                      decorationColor:
                                          AppTheme.getAdaptiveHintText(isDark),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalMenuTile({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF94A3B8),
                ),
          ],
        ),
      ),
    );
  }

  void _mostrarGuiaDidactica() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const CajaYaLogoMark(size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guía Rápida CajaYa POS',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Organización inteligente en 5 módulos',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.getAdaptiveMutedText(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildGuideItem(
              icon: LucideIcons.layoutGrid,
              title: '1. Inicio (Panel de Control)',
              desc: 'Revisa el valor de tu mercadería, alertas de stock por agotarse y accesos directos.',
              isDark: isDark,
            ),
            _buildGuideItem(
              icon: LucideIcons.shoppingBag,
              title: '2. POS (Cobrar Venta)',
              desc: 'Toca productos para armar la canasta, elige Efectivo/Yape/Plin/Tarjeta y cobra al instante.',
              isDark: isDark,
            ),
            _buildGuideItem(
              icon: LucideIcons.banknote,
              title: '3. Caja (Arqueo & Historial)',
              desc: 'Consulta el total recaudado del día por método de pago y audita o anula ventas pasadas.',
              isDark: isDark,
            ),
            _buildGuideItem(
              icon: LucideIcons.boxes,
              title: '4. Stock (Inventario & Kardex)',
              desc: 'Semáforo visual de inventario (Óptimo, Bajo, Crítico), edición de precios y Kardex.',
              isDark: isDark,
            ),
            _buildGuideItem(
              icon: LucideIcons.truck,
              title: '5. Compras (Proveedores)',
              desc: 'Ingresa facturas o boletas de tus proveedores para abastecer tu almacén con múltiples productos a la vez.',
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('¡Entendido, a trabajar!'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                  : AppTheme.surfaceTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppTheme.brandPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.getAdaptiveMutedText(isDark),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarCerrarSesion() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.logOut,
                color: AppTheme.alertRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Cerrar Sesión',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas salir del sistema de caja e inventario?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF334155),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Salir',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      _inactivityTimer?.cancel();
      await AuthService().logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _mostrarModalLegal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.scale,
                    color: Color(0xFF6366F1),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marco Legal & Cumplimiento',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Transparencia, protección al consumidor y privacidad',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.getAdaptiveMutedText(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildModalMenuTile(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              icon: LucideIcons.bookOpen,
              iconColor: const Color(0xFF0D9488),
              iconBg: const Color(0xFF0D9488).withValues(alpha: 0.12),
              title: 'Libro de Reclamaciones Virtual',
              subtitle:
                  'Formulario oficial INDECOPI y seguimiento correlativo anual',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LibroReclamacionesScreen(tiendaNombre: _nombreBodega),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            _buildModalMenuTile(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              icon: LucideIcons.fileText,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFF2563EB).withValues(alpha: 0.12),
              title: 'Términos y Condiciones del Servicio',
              subtitle: 'Ley del Bodeguero N° 30877, alcance del SaaS y responsabilidades',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TerminosCondicionesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            _buildModalMenuTile(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              icon: LucideIcons.shieldCheck,
              iconColor: const Color(0xFF16A34A),
              iconBg: const Color(0xFF16A34A).withValues(alpha: 0.12),
              title: 'Política de Privacidad de Datos',
              subtitle:
                  'Ley N° 29733, derechos ARCO y normativas de Google Play',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PoliticaPrivacidadScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _verificarActualizacion() async {
    final updateService = UpdateService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppTheme.brandPrimary),
      ),
    );

    UpdateStatus status;
    int? patch;
    try {
      status = await updateService.checkManual().timeout(
        const Duration(seconds: 10),
      );
      patch = await updateService.getCurrentPatchNumber().timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo comprobar actualizaciones: '),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.pop(context);

      String titulo;
      String mensaje;
      IconData icon;
      Color iconColor;
      bool canDownload = false;

      switch (status) {
        case UpdateStatus.outdated:
          titulo = '¡Nueva Actualización!';
          mensaje = 'Hay una mejora lista para descargar en segundo plano sin reinstalar el APK.';
          icon = LucideIcons.downloadCloud;
          iconColor = AppTheme.brandPrimary;
          canDownload = true;
          break;
        case UpdateStatus.restartRequired:
          titulo = 'Actualización Lista';
          mensaje = 'El parche más reciente ya fue descargado. Cierra y vuelve a abrir la app para aplicar los cambios.';
          icon = LucideIcons.refreshCw;
          iconColor = AppTheme.accentGreen;
          break;
        case UpdateStatus.upToDate:
          titulo = 'Sistema Actualizado';
          mensaje =
              'Estás en la última versión disponible${patch != null ? " (Parche #$patch)" : ""}.';
          icon = LucideIcons.checkCircle;
          iconColor = AppTheme.accentGreen;
          break;
        case UpdateStatus.unavailable:
          titulo = 'Actualizaciones OTA';
          mensaje = 'El motor de actualizaciones remotas está activo para cuando publiques nuevos parches.';
          icon = LucideIcons.sparkles;
          iconColor = AppTheme.brandPrimary;
          break;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            mensaje,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF334155),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Entendido',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
            if (canDownload)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await updateService.downloadPatch();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Actualización descargada. Reinicia la app para aplicar cambios.',
                        ),
                        backgroundColor: AppTheme.accentGreen,
                      ),
                    );
                  }
                },
                child: const Text('Descargar Ahora'),
              ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 760;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(throttle: true),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_selectedIndex != 0) {
            _selectTab(0);
          } else {
            final salir = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('¿Deseas salir de CajaYa POS?'),
                content: const Text(
                  'El terminal se mantendrá seguro. Si tienes ventas en curso, se recomienda dejarlas en espera antes de salir.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Continuar en el Terminal'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.alertRed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Salir'),
                  ),
                ],
              ),
            );
            if (salir == true) {
              SystemNavigator.pop();
            }
          }
        },
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            elevation: 0,
            backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CajaYaLogoMark(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _nombreBodega.isNotEmpty
                                  ? _nombreBodega
                                  : 'CajaYa POS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                          ),
                          if (screenWidth >= 440) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.brandPrimary.withValues(
                                        alpha: 0.18,
                                      )
                                    : AppTheme.surfaceTint,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.brandPrimary.withValues(
                                          alpha: 0.45,
                                        )
                                      : AppTheme.borderTint,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accentGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4.5),
                                  Text(
                                    'CLOUD POS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: isDark
                                          ? AppTheme.brandLight
                                          : AppTheme.brandPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Caja #01',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.getAdaptiveHintText(isDark),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => OfflineQueueSheet.show(context),
                              borderRadius: BorderRadius.circular(6),
                              child: ValueListenableBuilder<List<OfflineVenta>>(
                                valueListenable: OfflineSyncManager
                                    .instance
                                    .pendingSalesNotifier,
                                builder: (context, ventas, _) {
                                  final hasPending = ventas.isNotEmpty;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: hasPending
                                              ? const Color(0xFFF59E0B)
                                              : AppTheme.accentGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4.5),
                                      Text(
                                        hasPending
                                            ? '${ventas.length} por subir'
                                            : 'En Línea',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          color: hasPending
                                              ? const Color(0xFFD97706)
                                              : AppTheme.accentGreen,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.getAdaptiveHintText(isDark),
                                ),
                              ),
                            ),
                            Text(
                              'CajaYa',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                color: isDark
                                    ? const Color(0xFF38BDF8)
                                    : AppTheme.brandPrimary,
                                fontWeight: FontWeight.w700,
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
            actions: [
              // Botón de alternancia de orientación (Mostrador Horizontal / Rotación libre)
              if (isWideScreen || ResponsiveLayout.isPhysicalTablet(context))
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Center(
                    child: IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.cardDarkElevated
                            : const Color(0xFFF1F5F9),
                        foregroundColor: ResponsiveLayout.isLandscape(context)
                            ? AppTheme.brandPrimary
                            : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569)),
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(36, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      tooltip: ResponsiveLayout.isLandscape(context)
                          ? 'Modo Mostrador Horizontal activo (Toca para rotación libre)'
                          : 'Activar Modo Mostrador Horizontal',
                      icon: Icon(
                        ResponsiveLayout.isLandscape(context)
                            ? LucideIcons.tablet
                            : LucideIcons.smartphone,
                        size: 18,
                      ),
                      onPressed: () async {
                        if (ResponsiveLayout.isLandscape(context)) {
                          await ResponsiveLayout.unlockOrientation();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Rotación de pantalla libre activada',
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        } else {
                          await ResponsiveLayout.lockLandscape();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Modo Mostrador Horizontal activado',
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),

              // Botón rápido de alternancia de tema con efecto de gota de agua líquida
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: WaterDropThemeButton(
                    isDark: isDark,
                    onToggle: () => context.read<ThemeProvider>().toggleTheme(),
                    iconSize: 18,
                    padding: const EdgeInsets.all(8),
                    borderRadius: 12,
                    backgroundColor: isDark
                        ? AppTheme.cardDarkElevated
                        : const Color(0xFFF1F5F9),
                    borderColor: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFCBD5E1),
                  ),
                ),
              ),

              // Botón de Pantalla Completa Mostrador (Windows Desktop & Web PC)
              if (WindowService.instance.isSupported)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: ValueListenableBuilder<bool>(
                      valueListenable:
                          WindowService.instance.isFullScreenNotifier,
                      builder: (context, isFullScreen, _) {
                        return IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? AppTheme.cardDarkElevated
                                : const Color(0xFFF1F5F9),
                            foregroundColor: isFullScreen
                                ? AppTheme.brandPrimary
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF475569)),
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(36, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          tooltip: isFullScreen
                              ? 'Salir de Pantalla Completa (F11)'
                              : 'Pantalla Completa Mostrador (F11)',
                          icon: Icon(
                            isFullScreen
                                ? LucideIcons.minimize
                                : LucideIcons.maximize,
                            size: 18,
                          ),
                          onPressed: () async {
                            final isFull = await WindowService.instance
                                .toggleFullScreen();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isFull
                                        ? 'Modo Pantalla Completa activado (F11)'
                                        : 'Modo Ventana restaurado',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),

              // Botón Oficial de Perfil & Admin en la esquina superior derecha
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _mostrarPanelAdmin,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.cardDarkElevated
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.borderDark
                                : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.brandPrimary,
                                    AppTheme.brandDark,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  _userRol == 'CAJERO'
                                      ? LucideIcons.userCheck
                                      : (_userRol == 'SUPERADMIN'
                                            ? LucideIcons.shieldAlert
                                            : LucideIcons.shieldCheck),
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (screenWidth >= 360) ...[
                              const SizedBox(width: 6),
                              Text(
                                _userRol == 'CAJERO'
                                    ? 'Cajero'
                                    : (_userRol == 'SUPERADMIN'
                                          ? 'Super'
                                          : 'Admin'),
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                            ],
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.accentGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              LucideIcons.chevronDown,
                              size: 13,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF334155),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_userRol == 'SUPERADMIN')
                _buildSuperAdminAuditBanner(context, isDark),
              if (!_anuncioDismissed &&
                  _anuncioGlobal.isNotEmpty &&
                  _anuncioGlobal['activo'] == true)
                _buildAnuncioGlobalBanner(context, isDark),
              ValueListenableBuilder<int>(
                valueListenable: BodegaService.sugerenciasPendientesNotifier,
                builder: (context, pendientes, _) {
                  if (pendientes <= 0) return const SizedBox.shrink();
                  return _buildSugerenciasAlertBanner(
                    context,
                    isDark,
                    pendientes,
                  );
                },
              ),
              if (_userRol == 'ADMIN' &&
                  _diasRestantesPlan != null &&
                  _diasRestantesPlan! <= 5)
                _buildSuscripcionAlertBanner(context, isDark),
              Expanded(
                child: Row(
                  children: [
                    if (isWideScreen)
                      NavigationRail(
                        selectedIndex: _selectedIndex.clamp(
                          0,
                          _screens.length - 1,
                        ),
                        onDestinationSelected: (index) {
                          HapticFeedback.selectionClick();
                          _selectTab(index);
                        },
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: IconButton(
                            tooltip: _railCollapsed
                                ? 'Expandir menú'
                                : 'Compactar menú POS',
                            icon: Icon(
                              _railCollapsed
                                  ? LucideIcons.panelLeftOpen
                                  : LucideIcons.panelLeftClose,
                              size: 18,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF334155),
                            ),
                            onPressed: () => setState(
                              () => _railCollapsed = !_railCollapsed,
                            ),
                          ),
                        ),
                        labelType: _railCollapsed
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        backgroundColor: isDark
                            ? AppTheme.cardDark
                            : Colors.white,
                        indicatorColor: AppTheme.brandPrimary,
                        indicatorShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        selectedIconTheme: const IconThemeData(
                          color: Colors.white,
                          size: 21,
                        ),
                        unselectedIconTheme: IconThemeData(
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF475569),
                          size: 20,
                        ),
                        selectedLabelTextStyle: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.brandPrimary,
                        ),
                        unselectedLabelTextStyle: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF475569),
                        ),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(LucideIcons.layoutGrid),
                            label: Text('Inicio'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(LucideIcons.shoppingBag),
                            label: Text('POS'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(LucideIcons.banknote),
                            label: Text('Caja'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(LucideIcons.boxes),
                            label: Text('Stock'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(LucideIcons.bookUser),
                            label: Text('Fiados'),
                          ),
                        ],
                      ),
                    if (isWideScreen)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: isDark
                            ? AppTheme.borderDark
                            : AppTheme.borderLight,
                      ),
                    Expanded(
                      child: AnimatedIndexedStack(
                        index: _selectedIndex.clamp(0, _screens.length - 1),
                        children: _builtScreens,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWideScreen
              ? null
              : KarlizPixelPerfectNavBar(
                  selectedIndex: _selectedIndex.clamp(0, _screens.length - 1),
                  onItemSelected: _selectTab,
                  isDark: isDark,
                ),
        ),
      ),
    );
  }

  Widget _buildSuperAdminAuditBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF4C1D95), const Color(0xFF1E1B4B)]
              : [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFF7C3AED).withValues(alpha: 0.4)
                : const Color(0xFFC4B5FD),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.shieldCheck,
              size: 16,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MODO AUDITORÍA SUPERADMIN',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isDark
                        ? const Color(0xFFC4B5FD)
                        : const Color(0xFF5B21B6),
                  ),
                ),
                Text(
                  'Inspeccionando tienda "${_nombreBodega.isNotEmpty ? _nombreBodega : 'CajaYa POS'}" con privilegios globales de plataforma.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF4C1D95),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => context.go('/superadmin'),
            icon: const Icon(LucideIcons.arrowLeft, size: 14),
            label: Text(
              'Volver a Consola',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnuncioGlobalBanner(BuildContext context, bool isDark) {
    final tipo = _anuncioGlobal['tipo']?.toString() ?? 'INFO';
    final mensaje = _anuncioGlobal['mensaje']?.toString() ?? '';
    final Color barColor = tipo == 'URGENTE'
        ? AppTheme.alertRed
        : (tipo == 'WARNING' ? Colors.amber.shade800 : const Color(0xFF2563EB));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: barColor.withValues(alpha: isDark ? 0.22 : 0.1),
        border: Border(
          bottom: BorderSide(color: barColor.withValues(alpha: 0.35), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            tipo == 'URGENTE'
                ? LucideIcons.alertTriangle
                : (tipo == 'WARNING' ? LucideIcons.bell : LucideIcons.info),
            size: 16,
            color: barColor,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tipo,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => setState(() => _anuncioDismissed = true),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.x,
                size: 14,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuscripcionAlertBanner(BuildContext context, bool isDark) {
    final int dias = _diasRestantesPlan ?? 0;
    final bool vencido = dias < 0;
    final Color barColor = vencido
        ? AppTheme.alertRed
        : const Color(0xFFD97706);
    final Color bgTint = vencido
        ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB));
    final Color borderTint = vencido
        ? (isDark
              ? AppTheme.alertRed.withValues(alpha: 0.4)
              : const Color(0xFFFECACA))
        : (isDark
              ? const Color(0xFFD97706).withValues(alpha: 0.4)
              : const Color(0xFFFDE68A));

    final String badgeText = vencido
        ? 'PLAN VENCIDO'
        : (dias == 0 ? 'VENCE HOY' : 'VENCE EN $dias DÍAS');
    final String mainText = vencido
        ? 'Tu suscripción al Plan $_plan ha vencido. Renueva hoy para mantener el servicio activo sin interrupciones.'
        : 'Tu Plan $_plan vence pronto. Renueva mediante Yape/Plin o WhatsApp para continuar sin interrupciones.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgTint,
        border: Border(bottom: BorderSide(color: borderTint, width: 1.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              vencido ? LucideIcons.alertOctagon : LucideIcons.clockAlert,
              size: 16,
              color: barColor,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mainText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => MiSuscripcionModal.show(
              context,
              nombreBodega: _nombreBodega,
              planActual: _plan,
              onPlanUpdated: _cargarDatosUsuario,
            ),
            icon: const Icon(LucideIcons.arrowRight, size: 13),
            label: Text(
              'Renovar Plan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: barColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSugerenciasAlertBanner(
    BuildContext context,
    bool isDark, [
    int? countOverride,
  ]) {
    final count = countOverride ?? _sugerenciasPendientes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2E1065).withValues(alpha: 0.5)
            : const Color(0xFFF5F3FF),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 16,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tienes $count sugerencia(s) de precios y catálogo del SuperAdmin.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFDDD6FE)
                    : const Color(0xFF5B21B6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.arrowUpRight, size: 14),
            label: const Text(
              'Revisar',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              await SugerenciasPrecioModal.show(
                context,
                onActualizado: _verificarSugerenciasSuperadmin,
              );
              _verificarSugerenciasSuperadmin();
            },
          ),
        ],
      ),
    );
  }
}

/// Transiciones ultra-fluidas (60/120 FPS) entre pestañas con aislamiento de repintado
class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _currentIndex = widget.index;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: IndexedStack(
        index: _currentIndex,
        children: widget.children
            .map((child) => RepaintBoundary(child: child))
            .toList(growable: false),
      ),
    );
  }
}
