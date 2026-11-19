import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cajaya_vectors.dart';
import '../../core/offline/offline_models.dart';
import '../../core/offline/offline_queue_sheet.dart';
import '../../core/offline/offline_sync_manager.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme.dart';
import '../../core/widgets/adaptive_modal.dart';
import '../../core/widgets/plan_upgrade_modal.dart';
import '../../core/widgets/tab_deferred_refresh.dart';
import '../auth/auth_service.dart';
import '../clientes/cliente_model.dart';
import '../clientes/cliente_service.dart';
import '../clientes/clientes_screen.dart';
import '../compras/compras_screen.dart';
import '../configuracion/configuracion_screen.dart';
import '../home/bodega_service.dart';
import '../home/configuracion_ticket_modal.dart';
import '../home/mi_bodega_online_modal.dart';
import '../marketing/kit_marketing_barrio_modal.dart';
import '../movimientos/auditoria_ciega_screen.dart';
import '../movimientos/kardex_screen.dart';
import '../movimientos/mermas_screen.dart';
import '../movimientos/vencimientos_screen.dart';
import '../productos/nuevo_producto_sheet.dart';
import '../productos/producto_model.dart';
import '../productos/producto_service.dart';
import '../promociones/promociones_screen.dart';
import '../ventas/venta_model.dart';
import '../ventas/venta_service.dart';
import 'dashboard_bi_screen.dart';

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

  /// Controles del topbar (tema, pantalla completa, perfil/admin) inyectados
  /// desde [HomeScreen] para integrarse en la cabecera unificada sin doble barra.
  final WidgetBuilder? topBarActionsBuilder;

  const DashboardScreen({
    super.key,
    required this.onNavigateTab,
    this.activeTabNotifier,
    this.tabIndex,
    this.topBarActionsBuilder,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TabDeferredRefreshMixin<DashboardScreen> {
  final ProductoService _productoService = ProductoService();
  final VentaService _ventaService = VentaService();
  final ClienteService _clienteService = ClienteService();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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
  String _telefono = '';
  String _giroNegocio = 'BODEGA';
  bool _isLoading = true;
  double _metaDiaria = 1000.0;

  bool get _esGastronomico =>
      _giroNegocio == 'POLLERIA' ||
      _giroNegocio == 'CHIFA' ||
      _giroNegocio == 'FASTFOOD' ||
      _giroNegocio == 'RESTAURANTE';

  // Buscador global de productos y módulos
  String _searchQuery = '';
  bool _searchOpen = false;

  // Pestaña activa del Centro de Atención (0 = Stock, 1 = Vencen)
  int _attentionTab = 0;

  // 6 accesos rápidos personalizables mostrados en el inicio
  static const List<String> _defaultFavoritos = [
    'bodega_online',
    'compras',
    'analitica_bi',
    'promociones',
    'impresora',
    'kardex',
  ];
  List<String> _favoritosIds = List<String>.from(_defaultFavoritos);

  @override
  void initState() {
    super.initState();
    initTabVisibilityListener();
    ProductoService.productosRevision.addListener(_onProductosRevisionChanged);
    VentaService.ventasRevision.addListener(_onVentasRevisionChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    HardwareKeyboard.instance.addHandler(_handleSearchShortcut);
    _cargarMetaDiaria();
    _cargarFavoritos();
    _cargarDatos();
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    if (_searchFocusNode.hasFocus && !_searchOpen) {
      setState(() => _searchOpen = true);
    }
  }

  bool _handleSearchShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted || !isTabCurrentlyVisible) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    final isCtrlOrMeta =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isCtrlOrMeta && event.logicalKey == LogicalKeyboardKey.keyK) {
      _searchFocusNode.requestFocus();
      setState(() => _searchOpen = true);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        (_searchOpen || _searchQuery.isNotEmpty)) {
      _searchCtrl.clear();
      _searchFocusNode.unfocus();
      setState(() {
        _searchQuery = '';
        _searchOpen = false;
      });
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleSearchShortcut);
    disposeTabVisibilityListener();
    ProductoService.productosRevision.removeListener(
      _onProductosRevisionChanged,
    );
    VentaService.ventasRevision.removeListener(_onVentasRevisionChanged);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
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
      if (m != null && m > 0 && mounted) {
        setState(() => _metaDiaria = m);
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

  Future<void> _cargarFavoritos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('cajaya_operaciones_favoritas');
      if (list != null && list.isNotEmpty && mounted) {
        setState(() => _favoritosIds = list);
      }
    } catch (_) {}
  }

  Future<bool> _confirmarToggleFavorito(
    String opId,
    String opTitle, {
    bool? isDarkOverride,
  }) async {
    HapticFeedback.selectionClick();
    final bool removing = _favoritosIds.contains(opId);

    if (removing && _favoritosIds.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes mantener al menos un acceso rápido.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final isDark =
        isDarkOverride ?? Theme.of(context).brightness == Brightness.dark;
    final accentColor = removing ? AppTheme.alertRed : AppTheme.brandPrimary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                removing ? LucideIcons.bookmarkMinus : LucideIcons.bookmarkPlus,
                color: accentColor,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                removing
                    ? '¿Quitar de accesos rápidos?'
                    : '¿Añadir a accesos rápidos?',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          removing
              ? '¿Deseas quitar "$opTitle" de tus accesos rápidos en la página de inicio?'
              : '¿Deseas añadir "$opTitle" a tus accesos rápidos en la página de inicio?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            height: 1.4,
            color: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              removing ? 'Sí, quitar' : 'Sí, añadir',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;
    await _toggleFavorito(opId, opTitle);
    return true;
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
              content: Text('Debes mantener al menos un acceso rápido.'),
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
      final String nombre = opTitle ?? 'Herramienta';
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
                      ? 'Se quitó "$nombre" de tus accesos rápidos'
                      : '¡"$nombre" fijado en tus accesos rápidos!',
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
      auth.getTelefonoBodega(),
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
        _telefono = (results[6] as String?) ?? '';
        _resumenCreditos = results[7] as ResumenCreditos?;
        _isLoading = false;
      });

      BodegaService()
          .obtenerMiBodega()
          .then((info) {
            if (mounted && info != null) {
              setState(() {
                if (info.plan.toUpperCase() != _plan.toUpperCase()) {
                  _plan = info.plan;
                }
                if (info.giroNegocio != null && info.giroNegocio!.isNotEmpty) {
                  _giroNegocio = info.giroNegocio!.toUpperCase();
                }
                if (info.telefono != null && info.telefono!.isNotEmpty) {
                  _telefono = info.telefono!;
                }
                if (info.nombreComercial.isNotEmpty) {
                  _nombreBodega = info.nombreComercial;
                }
              });
            }
          })
          .catchError((_) {});
    }
  }

  bool get _esPro {
    final p = _plan.toUpperCase();
    return p == 'PRO' || p == 'CORPORATIVO';
  }

  bool get _esAdmin {
    final r = _userRol.toUpperCase();
    return r == 'ADMIN' || r == 'SUPERADMIN';
  }

  String _fechaHoyCorta() {
    final now = DateTime.now();
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${dias[now.weekday - 1]} ${now.day} ${meses[now.month - 1]}';
  }

  void _abrirNuevoProducto() {
    if (!_esPro && _productos.length >= 150) {
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
  }

  void _mostrarDialogoEditarMeta(BuildContext context, bool isDark) {
    if (!_esPro) {
      PlanUpgradeModal.show(
        context,
        featureName: 'Termómetro de Meta Diaria de Venta',
        featureDescription: 'Establece tu meta de ventas diaria y mira en vivo la barra de progreso avanzando con cada cobro en caja.',
        icon: LucideIcons.target,
        onPlanUpdated: _cargarDatos,
      );
      return;
    }
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

  List<_OperacionItem> _obtenerTodasLasOperaciones(bool isDark) {
    final bool esPro = _esPro;

    return [
      // --- ALMACÉN ---
      _OperacionItem(
        id: 'nuevo_producto',
        categoria: 'almacen',
        title: _esGastronomico ? '+ Nuevo Plato / Ítem' : '+ Nuevo Producto',
        subtitle: _esGastronomico ? 'Crear en Carta' : 'Crear en Catálogo',
        icon: LucideIcons.plusCircle,
        color: AppTheme.brandPrimary,
        onTap: _abrirNuevoProducto,
      ),
      _OperacionItem(
        id: 'compras',
        categoria: 'almacen',
        title: _esGastronomico ? 'Compras & Insumos' : 'Compras & Lotes',
        subtitle: _esGastronomico
            ? 'Ingreso de ingredientes'
            : 'Ingreso de proveedores',
        icon: LucideIcons.truck,
        color: AppTheme.brandPrimary,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ComprasScreen()),
          ).then((_) => _cargarDatos(forceRefresh: true));
        },
      ),
      if (!_esGastronomico)
        _OperacionItem(
          id: 'vencimientos',
          categoria: 'almacen',
          title: 'Control Vencimientos',
          subtitle: 'Semáforo de caducidad FIFO',
          icon: LucideIcons.calendarClock,
          color: const Color(0xFFD97706),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VencimientosScreen()),
            ).then((_) => _cargarDatos(forceRefresh: true));
          },
        ),
      _OperacionItem(
        id: 'mermas',
        categoria: 'almacen',
        title: _esGastronomico ? 'Mermas de Cocina' : 'Registro de Mermas',
        subtitle: _esGastronomico
            ? 'Desperdicios y sobrantes'
            : 'Bajas & pérdidas',
        icon: LucideIcons.trash2,
        color: const Color(0xFFEF4444),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MermasScreen()),
          ).then((_) => _cargarDatos(forceRefresh: true));
        },
      ),
      if (!_esGastronomico)
        _OperacionItem(
          id: 'auditoria_ciega',
          categoria: 'almacen',
          title: 'Auditoría Ciega',
          subtitle: 'Conteo rápido anti-robo',
          icon: LucideIcons.clipboardCheck,
          color: AppTheme.brandPrimary,
          isLocked: !esPro,
          onTap: () {
            if (!esPro) {
              PlanUpgradeModal.show(
                context,
                featureName: 'Auditoría Rápida por Pasillo',
                featureDescription: 'Realiza conteos físicos aleatorios de 5 minutos por góndola o pasillo sin mostrar el stock real al personal.',
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
        subtitle: 'Historial de movimientos',
        icon: LucideIcons.fileSpreadsheet,
        color: const Color(0xFF64748B),
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
        title: _esGastronomico ? 'Mi Carta Web Online' : 'Mi Bodega Online',
        subtitle: _esGastronomico
            ? 'Carta Digital & WhatsApp'
            : 'Catálogo Web & WhatsApp',
        icon: LucideIcons.globe,
        color: const Color(0xFF10B981),
        isLocked: !esPro,
        onTap: () {
          if (!esPro) {
            PlanUpgradeModal.show(
              context,
              featureName: _esGastronomico
                  ? 'Mi Carta Web Online'
                  : 'Mi Bodega Online',
              featureDescription: _esGastronomico
                  ? 'Obtén tu propio enlace web oficial para compartir tu carta en redes sociales y recibir pedidos directos a tu WhatsApp sin comisiones.'
                  : 'Obtén tu propio enlace web oficial para compartir en redes sociales y recibir pedidos directos en tu WhatsApp sin comisiones.',
              icon: LucideIcons.globe,
              onPlanUpdated: _cargarDatos,
            );
            return;
          }
          MiBodegaOnlineModal.show(
            context,
            nombreBodega: _nombreBodega,
            telefonoBodega: _telefono,
            isPro: true,
          );
        },
      ),
      _OperacionItem(
        id: 'promociones',
        categoria: 'ventas',
        title: 'Promociones & Combos',
        subtitle: 'Descuentos y ofertas',
        icon: LucideIcons.tag,
        color: const Color(0xFFF59E0B),
        isLocked: !esPro,
        onTap: () {
          if (!esPro) {
            PlanUpgradeModal.show(
              context,
              featureName: 'Promociones y Descuentos',
              featureDescription: 'Configura descuentos por marcas, categorías y combos estratégicos para liquidar productos estancados.',
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
        title: 'Analítica & BI',
        subtitle: 'Márgenes y horas pico',
        icon: LucideIcons.trendingUp,
        color: const Color(0xFF8B5CF6),
        isLocked: !esPro,
        onTap: () {
          if (!esPro) {
            PlanUpgradeModal.show(
              context,
              featureName: 'Analítica de Negocio & BI',
              featureDescription: 'Calcula tu margen bruto real en soles y porcentaje restando el costo de compra en cada venta.',
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
        title: _esGastronomico ? 'Marketing & Carta QR' : 'Marketing de Barrio',
        subtitle: _esGastronomico
            ? 'Afiche salón y volante QR'
            : 'Afiche vitrina y volante QR',
        icon: LucideIcons.megaphone,
        color: const Color(0xFFD97706),
        requiresAdmin: true,
        onTap: () {
          KitMarketingBarrioModal.show(
            context,
            nombreBodega: _nombreBodega,
            telefono: _telefono.isNotEmpty ? _telefono : null,
            slugOrId: KitMarketingBarrioModal.normalizarSlug(_nombreBodega),
            giroNegocio: _giroNegocio,
          );
        },
      ),

      // --- GESTIÓN & HARDWARE ---
      _OperacionItem(
        id: 'impresora',
        categoria: 'gestion',
        title: 'Impresora Térmica',
        subtitle: 'Tickets & gaveta ESC/POS',
        icon: LucideIcons.printer,
        color: const Color(0xFF0EA5E9),
        onTap: () => ConfiguracionTicketModal.show(context),
      ),
      _OperacionItem(
        id: 'personal',
        categoria: 'gestion',
        title: 'Personal & Cajeros',
        subtitle: 'Turnos y accesos',
        icon: LucideIcons.users,
        color: AppTheme.brandPrimary,
        requiresAdmin: true,
        onTap: () => ConfiguracionScreen.abrir(
          context,
          tabInicial: ConfiguracionTab.usuarios,
          onConfigSaved: () => _cargarDatos(forceRefresh: true),
        ),
      ),
      _OperacionItem(
        id: 'suscripcion',
        categoria: 'gestion',
        title: 'Mi Suscripción',
        subtitle: esPro ? 'Plan PRO activo' : 'Plan Básico • Mejorar',
        icon: LucideIcons.crown,
        color: const Color(0xFF0D9488),
        requiresAdmin: true,
        onTap: () => ConfiguracionScreen.abrir(
          context,
          tabInicial: ConfiguracionTab.plan,
          onConfigSaved: () => _cargarDatos(forceRefresh: true),
        ),
      ),

      // --- MOSTRADOR ---
      _OperacionItem(
        id: 'cobrar_pos',
        categoria: 'mostrador',
        title: 'Cobrar en POS',
        subtitle: 'Terminal de venta rápida',
        icon: LucideIcons.shoppingBag,
        color: AppTheme.brandPrimary,
        onTap: () => widget.onNavigateTab(1),
      ),
      _OperacionItem(
        id: 'arqueo_caja',
        categoria: 'mostrador',
        title: 'Arqueo de Caja',
        subtitle: 'Corte, historial y cuadre',
        icon: LucideIcons.banknote,
        color: AppTheme.accentGreen,
        onTap: () => widget.onNavigateTab(2),
      ),
      _OperacionItem(
        id: 'fiados',
        categoria: 'mostrador',
        title: _esGastronomico ? 'Clientes & Delivery' : 'Libreta de Fiados',
        subtitle: _esGastronomico
            ? 'Historial y pedidos frecuentes'
            : 'Cobros y WhatsApp',
        icon: _esGastronomico ? LucideIcons.users : LucideIcons.bookUser,
        color: const Color(0xFFD97706),
        onTap: () {
          widget.onNavigateTab(4);
          ClientesScreen.cambiarPestana(0);
        },
      ),
      if (!_esGastronomico)
        _OperacionItem(
          id: 'garantias',
          categoria: 'mostrador',
          title: 'Garantía Botellas',
          subtitle: 'Envases retornables',
          icon: LucideIcons.wine,
          color: const Color(0xFF2563EB),
          onTap: () {
            widget.onNavigateTab(4);
            ClientesScreen.cambiarPestana(1);
          },
        ),
    ];
  }

  List<_OperacionItem> _obtenerAccesosRapidos(bool isDark) {
    final todas = _obtenerTodasLasOperaciones(isDark)
        .where((op) => !op.requiresAdmin || _esAdmin)
        .toList();
    final List<_OperacionItem> seleccionados = [];

    // Mostrar exactamente los accesos directos elegidos por el usuario, sin
    // truncarlos a 6 ni volver a inyectar los que el usuario quitó.
    for (final id in _favoritosIds) {
      final idx = todas.indexWhere((op) => op.id == id);
      if (idx != -1 && !seleccionados.contains(todas[idx])) {
        seleccionados.add(todas[idx]);
      }
    }

    // Respaldo solo si todos los guardados no fueran visibles para el rol actual
    if (seleccionados.isEmpty && todas.isNotEmpty) {
      for (final id in _defaultFavoritos) {
        final idx = todas.indexWhere((op) => op.id == id);
        if (idx != -1 && !seleccionados.contains(todas[idx])) {
          seleccionados.add(todas[idx]);
        }
      }
      if (seleccionados.isEmpty) {
        seleccionados.add(todas.first);
      }
    }
    return seleccionados;
  }

  void _mostrarModalTodasHerramientas(BuildContext context, bool isDark) {
    HapticFeedback.selectionClick();
    final todas = _obtenerTodasLasOperaciones(isDark)
        .where((op) => !op.requiresAdmin || _esAdmin)
        .toList();

    AdaptiveModal.show(
      context: context,
      maxWidth: 680,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isWide = ResponsiveLayout.isTabletOrLarger(ctx);
            final surface = isDark ? AppTheme.cardDarkElevated : Colors.white;
            final border = isDark ? AppTheme.borderDark : AppTheme.borderLight;

            Widget buildCategoryGroup(String heading, String catKey) {
              final items = todas.where((o) => o.categoria == catKey).toList();
              if (items.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((op) {
                    final isFav = _favoritosIds.contains(op.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.cardDark
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(modalCtx);
                            op.onTap();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: op.color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    op.icon,
                                    size: 17,
                                    color: op.color,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              op.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white
                                                    : AppTheme.textDark,
                                              ),
                                            ),
                                          ),
                                          if (op.isLocked) ...[
                                            const SizedBox(width: 5),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD97706)
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                'PRO',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: const Color(
                                                    0xFFD97706,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        op.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                IconButton(
                                  tooltip: isFav
                                      ? 'Quitar de accesos rápidos'
                                      : 'Fijar en accesos rápidos',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    isFav
                                        ? LucideIcons.bookmarkCheck
                                        : LucideIcons.bookmark,
                                    size: 16,
                                    color: isFav
                                        ? AppTheme.brandPrimary
                                        : (isDark
                                              ? AppTheme.textDarkSecondary
                                              : const Color(0xFF94A3B8)),
                                  ),
                                  onPressed: () async {
                                    final changed =
                                        await _confirmarToggleFavorito(
                                          op.id,
                                          op.title,
                                          isDarkOverride: isDark,
                                        );
                                    if (changed) {
                                      setModalState(() {});
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }

            return Align(
              alignment: isWide ? Alignment.center : Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: isWide
                        ? BorderRadius.circular(24)
                        : const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: border),
                  ),
                  child: SafeArea(
                    top: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Todas las Herramientas',
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textDark,
                                        ),
                                      ),
                                      Text(
                                        'Toca el marcador para añadir o quitar accesos rápidos en el inicio.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppTheme.textDarkSecondary
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(modalCtx),
                                  icon: Icon(
                                    LucideIcons.x,
                                    size: 20,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        buildCategoryGroup(
                                          'ALMACÉN',
                                          'almacen',
                                        ),
                                        const SizedBox(height: 12),
                                        buildCategoryGroup(
                                          'MOSTRADOR',
                                          'mostrador',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        buildCategoryGroup(
                                          'VENTAS & WEB',
                                          'ventas',
                                        ),
                                        const SizedBox(height: 12),
                                        buildCategoryGroup(
                                          'GESTIÓN & HARDWARE',
                                          'gestion',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              buildCategoryGroup('ALMACÉN', 'almacen'),
                              const SizedBox(height: 12),
                              buildCategoryGroup('VENTAS & WEB', 'ventas'),
                              const SizedBox(height: 12),
                              buildCategoryGroup(
                                'GESTIÓN & HARDWARE',
                                'gestion',
                              ),
                              const SizedBox(height: 12),
                              buildCategoryGroup('MOSTRADOR', 'mostrador'),
                            ],
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
      },
    );
  }

  void _mostrarDetalleProductoRapido(Producto p, bool isDark) {
    final double umbral = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
    final bool isLow = p.stockActual <= umbral;

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
                LucideIcons.package,
                color: AppTheme.brandPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                p.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 16,
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
              '${p.nombreCategoria ?? 'General'} · Cód. ${p.codigo}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.cardDark
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.borderDark
                            : AppTheme.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precio venta',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'S/ ${p.precioVenta.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isLow ? AppTheme.alertRed : AppTheme.accentGreen)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            (isLow ? AppTheme.alertRed : AppTheme.accentGreen)
                                .withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock actual',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: isLow
                                ? AppTheme.alertRed
                                : AppTheme.accentGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.stockActual % 1 == 0 ? p.stockActual.toInt() : p.stockActual.toStringAsFixed(2)} u.',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isLow
                                ? AppTheme.alertRed
                                : AppTheme.accentGreen,
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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onNavigateTab(3); // Stock / Catálogo
            },
            child: Text(
              'Ver en Stock',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onNavigateTab(1); // Venta POS
            },
            icon: const Icon(LucideIcons.shoppingBag, size: 15),
            label: Text(
              'Ir a Cobrar',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
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

    final List<Producto> productosFifoRiesgo =
        _productos.where((p) {
          final dias = p.diasParaVencer ?? 999;
          return p.controlaVencimiento &&
              p.fechaVencimiento != null &&
              dias <= 30;
        }).toList()..sort(
          (a, b) =>
              (a.diasParaVencer ?? 999).compareTo(b.diasParaVencer ?? 999),
        );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocusNode.requestFocus();
          setState(() => _searchOpen = true);
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocusNode.requestFocus();
          setState(() => _searchOpen = true);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchOpen || _searchQuery.isNotEmpty) {
            _searchCtrl.clear();
            _searchFocusNode.unfocus();
            setState(() {
              _searchQuery = '';
              _searchOpen = false;
            });
          }
        },
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: () => _cargarDatos(forceRefresh: true),
          color: AppTheme.brandPrimary,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.brandPrimary,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxW = constraints.maxWidth;
                    final bool isDesktopHeader = maxW >= 880;
                    final bool isTwoColBottom = maxW >= 900;
                    final bool isThreeColKpi = maxW >= 720;

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_searchOpen) {
                          _searchFocusNode.unfocus();
                          setState(() => _searchOpen = false);
                        }
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: maxW >= 900 ? 24 : 16,
                          vertical: maxW >= 900 ? 20 : 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. CABECERA UNIFICADA (Saludo + Buscador + CTAs + Controles TopBar en 1 línea)
                            _buildUnifiedHeader(
                              context: context,
                              isDark: isDark,
                              isDesktopHeader: isDesktopHeader,
                              maxWidth: maxW,
                            ),

                            // Panel desplegable de resultados del buscador global
                            if (_searchOpen || _searchQuery.trim().isNotEmpty)
                              _buildSearchResultsPanel(isDark),

                            const SizedBox(height: 18),

                            // 2. HERO FINANCIERO UNIFICADO (Ventas de Hoy + Meta Diaria + Canales de Pago)
                            _buildUnifiedSalesHero(
                              isDark: isDark,
                              isWide: maxW >= 720,
                            ),

                            const SizedBox(height: 16),

                            // 3. 3 KPIs SECUNDARIOS EN FILA LIMPIA
                            _buildSecondaryKpisRow(
                              isDark: isDark,
                              isThreeCol: isThreeColKpi,
                              valorInventario: valorInventario,
                              stockTotalUnidades: stockTotalUnidades,
                              totalProductos: totalProductos,
                              alertasStockCount:
                                  productosCriticos.length +
                                  productosBajos.length,
                            ),

                            const SizedBox(height: 18),

                            // 4. ZONA INFERIOR EQUILIBRADA: Accesos Rápidos (6) + Requiere Atención (Stock / Vencen)
                            if (isTwoColBottom)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: _buildQuickToolsCard(
                                      isDark: isDark,
                                      columns: 3,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _buildAttentionCenterCard(
                                      isDark: isDark,
                                      productosCriticos: productosCriticos,
                                      productosBajos: productosBajos,
                                      productosFifo: productosFifoRiesgo,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildQuickToolsCard(
                                isDark: isDark,
                                columns: maxW >= 540 ? 3 : 2,
                              ),
                              const SizedBox(height: 16),
                              _buildAttentionCenterCard(
                                isDark: isDark,
                                productosCriticos: productosCriticos,
                                productosBajos: productosBajos,
                                productosFifo: productosFifoRiesgo,
                              ),
                            ],

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. CABECERA UNIFICADA (SIN DOBLE TOPBAR NI PALABRA "INICIO")
  // ===========================================================================
  Widget _buildUnifiedHeader({
    required BuildContext context,
    required bool isDark,
    required bool isDesktopHeader,
    required double maxWidth,
  }) {
    final Widget? topActions = widget.topBarActionsBuilder?.call(context);
    final bool showMobileLogo = maxWidth < 760;

    final planBadge = InkWell(
      onTap: () {
        ConfiguracionScreen.abrir(
          context,
          tabInicial: ConfiguracionTab.plan,
          onConfigSaved: () => _cargarDatos(forceRefresh: true),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _esPro
              ? AppTheme.brandPrimary.withValues(alpha: isDark ? 0.22 : 0.10)
              : (isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _esPro
                ? AppTheme.brandPrimary.withValues(alpha: 0.35)
                : (isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          _esPro ? 'PRO' : 'BÁSICO',
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: _esPro
                ? (isDark ? const Color(0xFF60A5FA) : AppTheme.brandPrimary)
                : (isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF475569)),
          ),
        ),
      ),
    );

    final Widget syncSubtitle = ValueListenableBuilder<List<OfflineVenta>>(
      valueListenable: OfflineSyncManager.instance.pendingSalesNotifier,
      builder: (context, pendientes, _) {
        final hasPending = pendientes.isNotEmpty;
        return InkWell(
          onTap: hasPending ? () => OfflineQueueSheet.show(context) : null,
          borderRadius: BorderRadius.circular(6),
          child: Text(
            hasPending
                ? '${_fechaHoyCorta()} · ${pendientes.length} ventas por subir'
                : (showMobileLogo
                      ? '$_nombreBodega · Caja #01'
                      : '${_fechaHoyCorta()} · Caja #01 abierta · Sincronizado'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: hasPending ? FontWeight.w700 : FontWeight.w500,
              color: hasPending
                  ? const Color(0xFFD97706)
                  : (isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B)),
            ),
          ),
        );
      },
    );

    final Widget nuevaVentaBtn = ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        widget.onNavigateTab(1);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: isDesktopHeader ? 14 : 12,
          vertical: 11,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.shoppingBag, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Nueva Venta',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (isDesktopHeader) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'F2',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (isDesktopHeader) {
      return Row(
        children: [
          // Saludo compacto a la izquierda
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Hola, $_username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      planBadge,
                    ],
                  ),
                  const SizedBox(height: 2),
                  syncSubtitle,
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Derecha del saludo: Buscador Global + CTAs + Controles del TopBar
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 200,
                      maxWidth: 380,
                    ),
                    child: _buildGlobalSearchField(
                      isDark: isDark,
                      showShortcutHint: maxWidth >= 1060,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                nuevaVentaBtn,
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Nuevo Producto',
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: OutlinedButton(
                      onPressed: _abrirNuevoProducto,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: isDark
                            ? AppTheme.cardDark
                            : Colors.white,
                        foregroundColor: isDark
                            ? Colors.white
                            : AppTheme.textDark,
                        side: BorderSide(
                          color: isDark
                              ? AppTheme.borderDark
                              : const Color(0xFFCBD5E1),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(LucideIcons.plus, size: 17),
                    ),
                  ),
                ),
                if (topActions != null) ...[
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFCBD5E1),
                  ),
                  topActions,
                ],
              ],
            ),
          ),
        ],
      );
    }

    // MÓVIL / TABLET COMPACTA: Fila 1 (Saludo + TopBar controls), Fila 2 (Buscador), Fila 3 (CTAs)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showMobileLogo) ...[
              const CajaYaLogoMark(size: 32),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Hola, $_username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      planBadge,
                    ],
                  ),
                  const SizedBox(height: 1),
                  syncSubtitle,
                ],
              ),
            ),
            if (topActions != null) ...[const SizedBox(width: 8), topActions],
          ],
        ),
        const SizedBox(height: 12),
        _buildGlobalSearchField(isDark: isDark, showShortcutHint: false),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: nuevaVentaBtn),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _abrirNuevoProducto,
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
                foregroundColor: isDark ? Colors.white : AppTheme.textDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                side: BorderSide(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(LucideIcons.plus, size: 15),
              label: Text(
                'Producto',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlobalSearchField({
    required bool isDark,
    required bool showShortcutHint,
  }) {
    final borderColor = _searchOpen
        ? AppTheme.brandPrimary
        : (isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1));

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: _searchOpen ? 1.4 : 1.0),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: 16,
            color: _searchOpen
                ? AppTheme.brandPrimary
                : (isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              onChanged: (val) => setState(() {
                _searchQuery = val;
                _searchOpen = true;
              }),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Buscar producto, stock o módulo...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            InkWell(
              onTap: () {
                _searchCtrl.clear();
                setState(() {
                  _searchQuery = '';
                  _searchOpen = false;
                });
                _searchFocusNode.unfocus();
              },
              borderRadius: BorderRadius.circular(8),
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
            )
          else if (showShortcutHint)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.cardDarkElevated
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                'Ctrl K',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
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

  Widget _buildSearchResultsPanel(bool isDark) {
    final q = _searchQuery.trim().toLowerCase();
    final surface = isDark ? AppTheme.cardDark : Colors.white;
    final border = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    if (q.isEmpty) {
      const quickSuggestions = [
        'Kardex',
        'Impresora',
        'Bodega Online',
        'Promociones',
        'Analítica',
        'Compras',
      ];
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BÚSQUEDAS RÁPIDAS',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
                InkWell(
                  onTap: () {
                    _searchFocusNode.unfocus();
                    setState(() => _searchOpen = false);
                  },
                  child: Text(
                    'Cerrar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickSuggestions.map((label) {
                return ActionChip(
                  label: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  backgroundColor: isDark
                      ? AppTheme.cardDarkElevated
                      : const Color(0xFFF1F5F9),
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onPressed: () {
                    _searchCtrl.text = label;
                    setState(() {
                      _searchQuery = label;
                      _searchOpen = true;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    final productosMatch = _productos
        .where(
          (p) =>
              p.nombre.toLowerCase().contains(q) ||
              p.codigo.toLowerCase().contains(q) ||
              (p.codigoBarras ?? '').toLowerCase().contains(q) ||
              (p.marca ?? '').toLowerCase().contains(q) ||
              (p.nombreCategoria ?? '').toLowerCase().contains(q),
        )
        .take(5)
        .toList();

    final modulosMatch = _obtenerTodasLasOperaciones(isDark)
        .where(
          (op) =>
              (!op.requiresAdmin || _esAdmin) &&
              (op.title.toLowerCase().contains(q) ||
                  op.subtitle.toLowerCase().contains(q) ||
                  op.categoria.toLowerCase().contains(q)),
        )
        .take(5)
        .toList();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (productosMatch.isEmpty && modulosMatch.isEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Sin coincidencias para "$_searchQuery"',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    _searchFocusNode.unfocus();
                    setState(() {
                      _searchQuery = '';
                      _searchOpen = false;
                    });
                  },
                  child: const Text('Limpiar'),
                ),
              ],
            )
          else ...[
            if (productosMatch.isNotEmpty) ...[
              Text(
                'PRODUCTOS (${productosMatch.length})',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              ...productosMatch.map((p) {
                final umbral = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
                final isLow = p.stockActual <= umbral;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _searchFocusNode.unfocus();
                    setState(() => _searchOpen = false);
                    _mostrarDetalleProductoRapido(p, isDark);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            LucideIcons.package,
                            size: 15,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                '${p.nombreCategoria ?? 'General'} · Cód. ${p.codigo}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        const SizedBox(width: 8),
                        Text(
                          'S/ ${p.precioVenta.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isLow
                                        ? AppTheme.alertRed
                                        : AppTheme.accentGreen)
                                    .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${p.stockActual % 1 == 0 ? p.stockActual.toInt() : p.stockActual.toStringAsFixed(1)} u.',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: isLow
                                  ? AppTheme.alertRed
                                  : AppTheme.accentGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (productosMatch.isNotEmpty && modulosMatch.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: border),
              ),
            if (modulosMatch.isNotEmpty) ...[
              Text(
                'MÓDULOS Y HERRAMIENTAS (${modulosMatch.length})',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              ...modulosMatch.map((op) {
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _searchCtrl.clear();
                    _searchFocusNode.unfocus();
                    setState(() {
                      _searchQuery = '';
                      _searchOpen = false;
                    });
                    op.onTap();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: op.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(op.icon, size: 15, color: op.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                op.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                op.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary.withValues(
                              alpha: isDark ? 0.20 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            op.isLocked ? 'PRO' : 'Abrir →',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? const Color(0xFF60A5FA)
                                  : AppTheme.brandPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. HERO FINANCIERO UNIFICADO (Ventas de Hoy + Meta Diaria + Canales de Pago)
  // ===========================================================================
  Widget _buildUnifiedSalesHero({required bool isDark, required bool isWide}) {
    final double totalVentas = _cierreHoy?.totalVentas ?? 0.0;
    final int cantVentas = _cierreHoy?.cantidadVentas ?? 0;
    final double ticketPromedio = cantVentas > 0
        ? totalVentas / cantVentas
        : 0.0;

    final double ef = _cierreHoy?.totalEfectivo ?? 0.0;
    final double yp = _cierreHoy?.totalYape ?? 0.0;
    final double pl = _cierreHoy?.totalPlin ?? 0.0;
    final double tj = _cierreHoy?.totalTarjeta ?? 0.0;
    final double cr = _cierreHoy?.totalCredito ?? 0.0;
    final double sumaCanales = ef + yp + pl + tj + cr;

    final double progreso = _metaDiaria > 0
        ? (totalVentas / _metaDiaria).clamp(0.0, 1.0)
        : 0.0;
    final int porcentaje = _metaDiaria > 0
        ? ((totalVentas / _metaDiaria) * 100).round()
        : 0;
    final bool metaCumplida = totalVentas >= _metaDiaria;
    final double falta = (_metaDiaria - totalVentas).clamp(
      0.0,
      double.infinity,
    );

    final surface = isDark ? AppTheme.cardDark : Colors.white;
    final surfaceAlt = isDark
        ? AppTheme.cardDarkElevated
        : const Color(0xFFF8FAFC);
    final border = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    final Widget salesFigureBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ventas de Hoy',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
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
                    'En vivo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'S/ ${totalVentas.toStringAsFixed(2)}',
              style: GoogleFonts.outfit(
                fontSize: isWide ? 36 : 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            Text(
              '$cantVentas cobros · Ticket prom. S/ ${ticketPromedio.toStringAsFixed(2)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );

    final Widget goalBox = InkWell(
      onTap: () => _mostrarDialogoEditarMeta(context, isDark),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: isWide ? 285 : double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _esPro
                ? (metaCumplida ? AppTheme.accentGreen : border)
                : const Color(0xFFD97706).withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _esPro
                              ? (metaCumplida
                                    ? 'Meta superada · $porcentaje%'
                                    : 'Meta diaria · $porcentaje%')
                              : 'Meta diaria',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (!_esPro) ...[
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
                          child: Text(
                            'PRO',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _esPro
                          ? 'S/ ${_metaDiaria.toStringAsFixed(0)}'
                          : 'Desbloquear',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: _esPro
                            ? (isDark
                                  ? const Color(0xFF60A5FA)
                                  : AppTheme.brandPrimary)
                            : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _esPro ? LucideIcons.pencil : LucideIcons.lock,
                      size: 12,
                      color: _esPro
                          ? (isDark
                                ? const Color(0xFF60A5FA)
                                : AppTheme.brandPrimary)
                          : const Color(0xFFD97706),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _esPro ? progreso : 0.30),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) => LinearProgressIndicator(
                  value: val,
                  minHeight: 7,
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    !_esPro
                        ? const Color(0xFFD97706).withValues(alpha: 0.55)
                        : (metaCumplida
                              ? AppTheme.accentGreen
                              : AppTheme.brandPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              !_esPro
                  ? 'Activa el Plan PRO para seguir tu meta en vivo'
                  : (metaCumplida
                        ? '¡Superaste tu meta de venta del día!'
                        : 'Faltan S/ ${falta.toStringAsFixed(2)} para llegar a la meta'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: metaCumplida && _esPro
                    ? (isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF059669))
                    : (isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );

    Widget buildChannelLegend(String name, double amount, Color color) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'S/ ${amount.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
        ],
      );
    }

    final colorEfectivo = isDark
        ? const Color(0xFF34D399)
        : AppTheme.accentGreen;
    final colorYape = isDark
        ? const Color(0xFFE879F9)
        : const Color(0xFF9333EA);
    final colorPlin = isDark
        ? const Color(0xFF38BDF8)
        : const Color(0xFF0284C7);
    final colorTarjeta = isDark
        ? const Color(0xFF818CF8)
        : const Color(0xFF4F46E5);
    final colorCredito = isDark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFD97706);

    return Container(
      padding: EdgeInsets.all(isWide ? 22 : 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: salesFigureBlock),
                const SizedBox(width: 20),
                goalBox,
              ],
            )
          else ...[
            salesFigureBlock,
            const SizedBox(height: 14),
            goalBox,
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: border),
          ),

          // Barra proporcional de medios de pago
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: sumaCanales <= 0
                  ? Container(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                    )
                  : Row(
                      children: [
                        if (ef > 0)
                          Expanded(
                            flex: (ef * 100).round().clamp(1, 1000000),
                            child: Container(color: colorEfectivo),
                          ),
                        if (yp > 0)
                          Expanded(
                            flex: (yp * 100).round().clamp(1, 1000000),
                            child: Container(color: colorYape),
                          ),
                        if (pl > 0)
                          Expanded(
                            flex: (pl * 100).round().clamp(1, 1000000),
                            child: Container(color: colorPlin),
                          ),
                        if (tj > 0)
                          Expanded(
                            flex: (tj * 100).round().clamp(1, 1000000),
                            child: Container(color: colorTarjeta),
                          ),
                        if (cr > 0)
                          Expanded(
                            flex: (cr * 100).round().clamp(1, 1000000),
                            child: Container(color: colorCredito),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Leyenda de canales + Link Ver arqueo
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  buildChannelLegend('Efectivo', ef, colorEfectivo),
                  buildChannelLegend('Yape', yp, colorYape),
                  buildChannelLegend('Plin', pl, colorPlin),
                  buildChannelLegend('Tarjeta', tj, colorTarjeta),
                  if (cr > 0) buildChannelLegend('Crédito', cr, colorCredito),
                ],
              ),
              InkWell(
                onTap: () => widget.onNavigateTab(2),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver arqueo',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : AppTheme.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 15,
                        color: isDark
                            ? const Color(0xFF60A5FA)
                            : AppTheme.brandPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. 3 KPIs SECUNDARIOS EN FILA LIMPIA
  // ===========================================================================
  Widget _buildSecondaryKpisRow({
    required bool isDark,
    required bool isThreeCol,
    required double valorInventario,
    required double stockTotalUnidades,
    required int totalProductos,
    required int alertasStockCount,
  }) {
    final double totalDeuda = _resumenCreditos?.totalDeuda ?? 0.0;
    final int vecinosConSaldo = _resumenCreditos?.clientesConDeuda ?? 0;
    final double totalVentasHoy = _cierreHoy?.totalVentas ?? 0.0;
    final int cantVentasHoy = _cierreHoy?.cantidadVentas ?? 0;
    final double ticketPromedio = cantVentasHoy > 0
        ? (totalVentasHoy / cantVentasHoy)
        : 0.0;

    final String unidadesStr = stockTotalUnidades % 1 == 0
        ? stockTotalUnidades.toInt().toString()
        : stockTotalUnidades.toStringAsFixed(1);

    final cards = [
      _esGastronomico
          ? _buildKpiTile(
              isDark: isDark,
              title: 'Ticket Promedio',
              value: 'S/ ${ticketPromedio.toStringAsFixed(2)}',
              subtitle: cantVentasHoy > 0
                  ? '$cantVentasHoy comandas hoy'
                  : 'Sin comandas hoy',
              subtitleColor: const Color(0xFF10B981),
              icon: LucideIcons.receipt,
              accent: const Color(0xFF10B981),
              onTap: () => widget.onNavigateTab(2),
            )
          : _buildKpiTile(
              isDark: isDark,
              title: 'Fiados por Cobrar',
              value: 'S/ ${totalDeuda.toStringAsFixed(2)}',
              subtitle: '$vecinosConSaldo vecinos con saldo',
              subtitleColor: const Color(0xFFD97706),
              icon: LucideIcons.bookUser,
              accent: const Color(0xFFD97706),
              onTap: () {
                widget.onNavigateTab(4);
                ClientesScreen.cambiarPestana(0);
              },
            ),
      _buildKpiTile(
        isDark: isDark,
        title: _esGastronomico ? 'Carta & Menú' : 'Catálogo & Stock',
        value: _esGastronomico
            ? '$totalProductos platos/ítems'
            : '$totalProductos ítems',
        subtitle: alertasStockCount > 0
            ? (_esGastronomico
                  ? '$alertasStockCount por agotar'
                  : '$alertasStockCount por reponer')
            : (_esGastronomico
                  ? 'Carta 100% disponible'
                  : 'Existencias saludables'),
        subtitleColor: alertasStockCount > 0
            ? AppTheme.alertRed
            : AppTheme.accentGreen,
        icon: _esGastronomico ? LucideIcons.utensilsCrossed : LucideIcons.boxes,
        accent: alertasStockCount > 0
            ? AppTheme.alertRed
            : AppTheme.brandPrimary,
        onTap: () => widget.onNavigateTab(3),
      ),
      _buildKpiTile(
        isDark: isDark,
        title: _esGastronomico ? 'Valor en Insumos' : 'Valor en Mercadería',
        value: 'S/ ${valorInventario.toStringAsFixed(2)}',
        subtitle: _esGastronomico
            ? '$unidadesStr u. en cocina'
            : '$unidadesStr u. en almacén',
        subtitleColor: isDark
            ? AppTheme.textDarkSecondary
            : const Color(0xFF64748B),
        icon: _esGastronomico ? LucideIcons.packageOpen : LucideIcons.wallet,
        accent: AppTheme.brandPrimary,
        onTap: () => widget.onNavigateTab(3),
      ),
    ];

    if (isThreeCol) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12),
          Expanded(child: cards[1]),
          const SizedBox(width: 12),
          Expanded(child: cards[2]),
        ],
      );
    }

    return Column(
      children: [
        cards[0],
        const SizedBox(height: 10),
        cards[1],
        const SizedBox(height: 10),
        cards[2],
      ],
    );
  }

  Widget _buildKpiTile({
    required bool isDark,
    required String title,
    required String value,
    required String subtitle,
    required Color subtitleColor,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final surface = isDark ? AppTheme.cardDark : Colors.white;
    final border = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.18 : 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4A. ACCESOS RÁPIDOS (6 LIMPIOS + MODAL "VER TODAS")
  // ===========================================================================
  Widget _buildQuickToolsCard({required bool isDark, required int columns}) {
    final surface = isDark ? AppTheme.cardDark : Colors.white;
    final tileBg = isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC);
    final border = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    final todasCount = _obtenerTodasLasOperaciones(isDark)
        .where((op) => !op.requiresAdmin || _esAdmin)
        .length;
    final quickOps = _obtenerAccesosRapidos(isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Accesos rápidos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _mostrarModalTodasHerramientas(context, isDark),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver todas ($todasCount)',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : AppTheme.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 15,
                        color: isDark
                            ? const Color(0xFF60A5FA)
                            : AppTheme.brandPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, gridConstraints) {
              final double spacing = 10;
              final double itemW =
                  (gridConstraints.maxWidth - (spacing * (columns - 1))) /
                  columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: quickOps.map((op) {
                  return SizedBox(
                    width: itemW,
                    child: Material(
                      color: tileBg,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        mouseCursor: SystemMouseCursors.click,
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          op.onTap();
                        },
                        onLongPress: () => _confirmarToggleFavorito(
                          op.id,
                          op.title,
                          isDarkOverride: isDark,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: op.color.withValues(
                                        alpha: isDark ? 0.20 : 0.13,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      op.icon,
                                      size: 17,
                                      color: op.color,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (op.isLocked) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD97706)
                                                .withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          child: Text(
                                            'PRO',
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Tooltip(
                                        message: 'Quitar de accesos rápidos',
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          onTap: () => _confirmarToggleFavorito(
                                            op.id,
                                            op.title,
                                            isDarkOverride: isDark,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              LucideIcons.bookmarkCheck,
                                              size: 14,
                                              color: isDark
                                                  ? AppTheme.textDarkSecondary
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                op.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                op.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
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
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4B. CENTRO DE ATENCIÓN UNIFICADO (STOCK + VENCIMIENTOS FIFO)
  // ===========================================================================
  Widget _buildAttentionCenterCard({
    required bool isDark,
    required List<Producto> productosCriticos,
    required List<Producto> productosBajos,
    required List<Producto> productosFifo,
  }) {
    final surface = isDark ? AppTheme.cardDark : Colors.white;
    final rowBg = isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC);
    final border = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    final stockAlerts = [...productosCriticos, ...productosBajos];
    final int stockCount = stockAlerts.length;
    final int fifoCount = productosFifo.length;
    final int activeTab = _esGastronomico ? 0 : _attentionTab;

    Widget buildTabChip(int index, String label) {
      final active = activeTab == index;
      return InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _attentionTab = index);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.06,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active
                  ? (isDark ? Colors.white : AppTheme.textDark)
                  : (isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                _esGastronomico
                    ? 'Disponibilidad e Insumos'
                    : 'Requiere atención',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: rowBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildTabChip(
                      0,
                      _esGastronomico
                          ? 'Insumos ($stockCount)'
                          : 'Stock ($stockCount)',
                    ),
                    if (!_esGastronomico) ...[
                      const SizedBox(width: 2),
                      buildTabChip(1, 'Vencen ($fifoCount)'),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (activeTab == 0) ...[
            if (stockAlerts.isEmpty)
              _buildHealthyState(
                isDark: isDark,
                title: _esGastronomico
                    ? '¡Cocina y carta abastecidas!'
                    : '¡Inventario en estado óptimo!',
                subtitle: _esGastronomico
                    ? 'Todos los platos e insumos tienen disponibilidad.'
                    : 'Todos los productos tienen existencias saludables.',
              )
            else ...[
              ...stockAlerts.take(4).map((p) {
                final double umbral = p.stockMinimo > 0 ? p.stockMinimo : 5.0;
                final bool isCritico = p.stockActual <= (umbral * 0.5);
                final color = isCritico
                    ? AppTheme.alertRed
                    : const Color(0xFFD97706);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: rowBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                            Text(
                              'Mín. ${umbral % 1 == 0 ? umbral.toInt() : umbral.toStringAsFixed(1)} u.',
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${p.stockActual % 1 == 0 ? p.stockActual.toInt() : p.stockActual.toStringAsFixed(1)} u.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => widget.onNavigateTab(3),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary.withValues(
                      alpha: isDark ? 0.18 : 0.09,
                    ),
                    foregroundColor: isDark
                        ? const Color(0xFF60A5FA)
                        : AppTheme.brandPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _esGastronomico
                        ? 'Ir a gestionar carta e insumos →'
                        : 'Ir a reponer stock →',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ] else ...[
            if (productosFifo.isEmpty)
              _buildHealthyState(
                isDark: isDark,
                title: 'Sin lotes próximos a vencer',
                subtitle: 'Tus productos perecibles están al día.',
              )
            else ...[
              ...productosFifo.take(4).map((p) {
                final dias = p.diasParaVencer ?? 0;
                final bool vencido = dias <= 0;
                final bool critico = dias > 0 && dias <= 7;
                final color = vencido
                    ? AppTheme.alertRed
                    : (critico
                          ? const Color(0xFFEA580C)
                          : const Color(0xFFD97706));

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: rowBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                            Text(
                              'Cód. ${p.codigo}',
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          vencido ? 'Vencido' : 'En $dias d.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VencimientosScreen(),
                      ),
                    ).then((_) => _cargarDatos(forceRefresh: true));
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary.withValues(
                      alpha: isDark ? 0.18 : 0.09,
                    ),
                    foregroundColor: isDark
                        ? const Color(0xFF60A5FA)
                        : AppTheme.brandPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Abrir semáforo FIFO →',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHealthyState({
    required bool isDark,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppTheme.accentGreen.withValues(alpha: 0.30)
              : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.checkCircle2,
              color: AppTheme.accentGreen,
              size: 19,
            ),
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
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
