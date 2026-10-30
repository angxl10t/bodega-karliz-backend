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
import '../../core/update_service.dart';
import '../../core/cajaya_vectors.dart';
import '../../core/lock_service.dart';
import '../../core/widgets/karliz_lock_screen.dart';
import '../../core/widgets/briefing_turno_modal.dart';
import '../../core/responsive_layout.dart';
import 'bodega_service.dart';
import 'pixel_perfect_navbar.dart';
import '../clientes/clientes_screen.dart';
import '../../core/offline/offline_sync_manager.dart';
import '../../core/offline/offline_queue_sheet.dart';
import '../../core/offline/offline_models.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final Set<int> _loadedTabs = {0};
  late final List<Widget> _screens;
  String _username = 'admin';
  String _userRol = 'ADMIN';
  String _nombreBodega = 'CajaYa POS';
  String _plan = 'PRO';
  Map<String, dynamic> _anuncioGlobal = {};
  bool _anuncioDismissed = false;
  Timer? _inactivityTimer;
  bool _orientationConfigured = false;
  bool _railCollapsed = false;

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
        return _screens[index];
      }
      return const SizedBox.shrink();
    });
  }

  @override
  void initState() {
    super.initState();
    OfflineSyncManager.instance.init();
    _cargarDatosUsuario();
    _resetInactivityTimer();
    _screens = [
      DashboardScreen(
        onNavigateTab: (index) {
          if (mounted) {
            setState(() {
              _selectedIndex = index;
              _loadedTabs.add(index);
            });
          }
        },
      ),
      const VentasScreen(),
      const CajaVentasScreen(),
      const ProductosScreen(),
      const ClientesScreen(),
    ];
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
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

  void _bloquearPantalla() {
    KarlizLockScreen.show(
      context,
      onUnlocked: () {
        _resetInactivityTimer();
      },
      onLogout: () async {
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

      try {
        final anuncio = await BodegaService().obtenerAnuncioGlobal();
        if (mounted) setState(() => _anuncioGlobal = anuncio);
      } catch (_) {}

      if (mounted) {
        // Mostrar Briefing de Turno ejecutivo/operativo al inicio de sesión
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && !LockService().isLocked) {
            BriefingTurnoModal.showIfNeeded(
              context,
              username: _username,
              userRol: _userRol,
              nombreBodega: _nombreBodega,
              onNavigateTab: (index) {
                if (mounted) {
                  setState(() {
                    _selectedIndex = index;
                    _loadedTabs.add(index);
                  });
                }
              },
            );
          }
        });
      }
    }
  }

  void _mostrarPanelAdmin() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC);
        final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                child: Padding(
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
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
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
                                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
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
                                  color: isDark ? Colors.white : AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              LucideIcons.x,
                              size: 20,
                              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
                            ),
                            onPressed: () => Navigator.pop(bottomSheetContext),
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
                                  colors: [AppTheme.brandPrimary, AppTheme.brandDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.brandPrimary.withValues(alpha: 0.30),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _username.isNotEmpty ? _username.substring(0, 1).toUpperCase() : 'U',
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
                                          _username.isNotEmpty ? _username.toUpperCase() : 'USUARIO',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : AppTheme.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (_userRol == 'SUPERADMIN'
                                                  ? const Color(0xFF8B5CF6)
                                                  : (_userRol == 'ADMIN' ? AppTheme.brandPrimary : const Color(0xFF64748B)))
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _userRol == 'SUPERADMIN'
                                              ? 'SUPERADMIN'
                                              : (_userRol == 'ADMIN' ? 'ADMIN • PLAN $_plan' : 'CAJERO'),
                                          style: GoogleFonts.outfit(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: _userRol == 'SUPERADMIN'
                                                ? const Color(0xFF8B5CF6)
                                                : (_userRol == 'ADMIN' ? AppTheme.brandPrimary : const Color(0xFF64748B)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_nombreBodega.isNotEmpty ? _nombreBodega : "CajaYa"} • Terminal Activo',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
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

                      // 1. Configurar PIN de Caja
                      _buildModalMenuTile(
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        icon: LucideIcons.keyRound,
                        iconColor: AppTheme.accentGreen,
                        iconBg: AppTheme.accentGreen.withValues(alpha: 0.12),
                        title: 'Configurar mi PIN de Caja',
                        subtitle: 'Clave de 4 dígitos para desbloqueo de turno',
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          ConfigurarPinModal.show(context, onPinGuardado: () {
                            if (mounted) setState(() {});
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // 2. Bloquear Terminal Ahora
                      _buildModalMenuTile(
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        icon: LucideIcons.lock,
                        iconColor: AppTheme.brandPrimary,
                        iconBg: AppTheme.brandPrimary.withValues(alpha: 0.12),
                        title: 'Bloquear Terminal Ahora',
                        subtitle: 'Pausa de turno protegida con PIN de seguridad',
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _bloquearPantalla();
                        },
                      ),
                      const SizedBox(height: 8),

                      // 3. Guía Rápida & Centro de Ayuda
                      _buildModalMenuTile(
                        isDark: isDark,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        icon: LucideIcons.helpCircle,
                        iconColor: const Color(0xFF3B82F6),
                        iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        title: 'Centro de Ayuda & Guía',
                        subtitle: 'Atajos de teclado y manual del sistema',
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _mostrarGuiaDidactica();
                        },
                      ),
                      const SizedBox(height: 12),

                      // 4. Salir de Sesión
                      InkWell(
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _confirmarCerrarSesion();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppTheme.alertRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.alertRed.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.alertRed.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  LucideIcons.logOut,
                                  color: AppTheme.alertRed,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cerrar Sesión del Terminal',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
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
                      const SizedBox(height: 12),

                      // Pie sutil con versión del sistema
                      Center(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(bottomSheetContext);
                            _verificarActualizacion();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'CajaYa POS v2.4.0',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '• Comprobar actualizaciones',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
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
                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF94A3B8),
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
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
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
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
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
              color: isDark ? AppTheme.brandPrimary.withValues(alpha: 0.15) : AppTheme.surfaceTint,
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
                    color: AppTheme.textMuted,
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
              child: const Icon(LucideIcons.logOut, color: AppTheme.alertRed, size: 20),
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
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w500, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      await AuthService().logout();
      if (mounted) {
        context.go('/login');
      }
    }
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

    final status = await updateService.checkManual();
    final patch = await updateService.getCurrentPatchNumber();

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
          mensaje = 'Estás en la última versión disponible${patch != null ? " (Parche #$patch)" : ""}.';
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            mensaje,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Entendido', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
            if (canDownload)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await updateService.downloadPatch();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Actualización descargada. Reinicia la app para aplicar cambios.'),
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
      onPointerMove: (_) => _resetInactivityTimer(),
      child: PopScope(
        canPop: _selectedIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
              _loadedTabs.add(0);
            });
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
                          _nombreBodega.isNotEmpty ? _nombreBodega : 'CajaYa POS',
                          maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (screenWidth >= 440) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.brandPrimary.withValues(alpha: 0.18) : AppTheme.surfaceTint,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? AppTheme.brandPrimary.withValues(alpha: 0.45) : AppTheme.borderTint,
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
                                  color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
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
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => OfflineQueueSheet.show(context),
                          borderRadius: BorderRadius.circular(6),
                          child: ValueListenableBuilder<List<OfflineVenta>>(
                            valueListenable: OfflineSyncManager.instance.pendingSalesNotifier,
                            builder: (context, ventas, _) {
                              final hasPending = ventas.isNotEmpty;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: hasPending ? const Color(0xFFF59E0B) : AppTheme.accentGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4.5),
                                  Text(
                                    hasPending ? '${ventas.length} por subir' : 'En Línea',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      color: hasPending ? const Color(0xFFD97706) : AppTheme.accentGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        Text(
                          'CajaYa',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFF38BDF8) : AppTheme.brandPrimary,
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
                    backgroundColor: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                    foregroundColor: ResponsiveLayout.isLandscape(context) ? AppTheme.brandPrimary : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  tooltip: ResponsiveLayout.isLandscape(context)
                      ? 'Modo Mostrador Horizontal activo (Toca para rotación libre)'
                      : 'Activar Modo Mostrador Horizontal',
                  icon: Icon(
                    ResponsiveLayout.isLandscape(context) ? LucideIcons.tablet : LucideIcons.smartphone,
                    size: 18,
                  ),
                  onPressed: () async {
                    if (ResponsiveLayout.isLandscape(context)) {
                      await ResponsiveLayout.unlockOrientation();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Rotación de pantalla libre activada'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    } else {
                      await ResponsiveLayout.lockLandscape();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Modo Mostrador Horizontal activado'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ),

          // Botón rápido de alternancia de tema (Modo Claro Pro <-> Warm Titanium)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                  foregroundColor: isDark ? const Color(0xFFFACC15) : const Color(0xFF475569),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                ),
                tooltip: isDark
                    ? 'Cambiar a Modo Claro Pro (Porcelana)'
                    : 'Cambiar a Modo Oscuro (Warm Titanium)',
                icon: Icon(
                  isDark ? LucideIcons.sun : LucideIcons.moon,
                  size: 18,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.read<ThemeProvider>().toggleTheme();
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
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
                              colors: [AppTheme.brandPrimary, AppTheme.brandDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              LucideIcons.shieldCheck,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (screenWidth >= 360) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Admin',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
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
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
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
          if (!_anuncioDismissed && _anuncioGlobal.isNotEmpty && _anuncioGlobal['activo'] == true)
            _buildAnuncioGlobalBanner(context, isDark),
          Expanded(
            child: Row(
              children: [
                if (isWideScreen)
                  NavigationRail(
                    selectedIndex: _selectedIndex.clamp(0, _screens.length - 1),
                    onDestinationSelected: (index) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedIndex = index;
                        _loadedTabs.add(index);
                      });
                    },
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: IconButton(
                        tooltip: _railCollapsed ? 'Expandir menú' : 'Compactar menú POS',
                        icon: Icon(
                          _railCollapsed ? LucideIcons.panelLeftOpen : LucideIcons.panelLeftClose,
                          size: 18,
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        ),
                        onPressed: () => setState(() => _railCollapsed = !_railCollapsed),
                      ),
                    ),
                    labelType: _railCollapsed ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                    backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
                    indicatorColor: AppTheme.brandPrimary,
                    indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    selectedIconTheme: const IconThemeData(
                      color: Colors.white,
                      size: 21,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
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
                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
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
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
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
              onItemSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                  _loadedTabs.add(index);
                });
              },
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
            color: isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.4) : const Color(0xFFC4B5FD),
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
            child: const Icon(LucideIcons.shieldCheck, size: 16, color: Color(0xFF8B5CF6)),
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
                    color: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF5B21B6),
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
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white),
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
              child: Icon(LucideIcons.x, size: 14, color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B)),
            ),
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
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
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
